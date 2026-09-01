#requires -Version 7.0
using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Net.Sockets
using namespace System.Text
using namespace System.Text.Json

function Invoke-LocalModelHttpJson {
    param(
        [Parameter(Mandatory)] [string] $Endpoint,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Json
    )

    $uri = [Uri]::new($Endpoint)
    if ($uri.Scheme -ne 'http') {
        throw "The direct Bonsai transport currently accepts http placement, not $($uri.Scheme)."
    }
    $port = if ($uri.IsDefaultPort) { 80 } else { $uri.Port }
    $payload = [Encoding]::UTF8.GetBytes($Json)
    $tcp = [TcpClient]::new()
    try {
        $tcp.Connect($uri.Host, $port)
        $stream = $tcp.GetStream()
        $head = [Encoding]::ASCII.GetBytes(
            "POST $Path HTTP/1.1`r`n" +
            "Host: $($uri.Host):$port`r`n" +
            "Content-Type: application/json`r`n" +
            "Content-Length: $($payload.Length)`r`n" +
            "Connection: close`r`n`r`n")
        $stream.Write($head, 0, $head.Length)
        $stream.Write($payload, 0, $payload.Length)
        $stream.Flush()

        $reader = [StreamReader]::new($stream, [Encoding]::UTF8)
        $wire = $reader.ReadToEnd()
        $boundary = $wire.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
        if ($boundary -lt 0) { throw 'Bonsai returned no HTTP header boundary.' }
        $headers = $wire.Substring(0, $boundary)
        $body = $wire.Substring($boundary + 4)
        if ($headers -notmatch '^HTTP/1\.[01] 2\d\d ') {
            throw "$headers`n$body"
        }
        $body
    } finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
        $tcp.Dispose()
    }
}

function New-LocalModelChat {
    param(
        [string] $Endpoint = 'http://127.0.0.1:8080',
        [string] $Model = 'Bonsai-8B-Q1_0.gguf',
        [string] $System = 'You are Bonsai, a concise local chatbot.'
    )

    $messages = [List[object]]::new()
    if (-not [string]::IsNullOrWhiteSpace($System)) {
        $message = [Dictionary[string, object]]::new()
        $message['role'] = 'system'
        $message['content'] = $System
        $messages.Add($message)
    }

    [pscustomobject]@{
        Endpoint = $Endpoint.TrimEnd('/')
        Model = $Model
        Messages = $messages
        Transport = 'DirectTcpHttp'
        Turns = 0
    }
}

function Reset-LocalModelChat {
    param([Parameter(Mandatory, ValueFromPipeline)] $Chat)
    $system = if ($Chat.Messages.Count -and $Chat.Messages[0].role -eq 'system') {
        $Chat.Messages[0]
    } else { $null }
    $Chat.Messages.Clear()
    if ($system) { $Chat.Messages.Add($system) }
    $Chat.Turns = 0
    $Chat
}

function Send-LocalModelChat {
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $Chat,
        [Parameter(Mandatory, Position = 0)] [string] $Text,
        [int] $MaxTokens = 512,
        [double] $Temperature = 0.7
    )

    $userMessage = [Dictionary[string, object]]::new()
    $userMessage['role'] = 'user'
    $userMessage['content'] = $Text
    $Chat.Messages.Add($userMessage)

    $payload = [Dictionary[string, object]]::new()
    $payload['model'] = $Chat.Model
    $payload['messages'] = $Chat.Messages
    $payload['max_tokens'] = $MaxTokens
    $payload['temperature'] = $Temperature
    $payload['stream'] = $false
    $json = [JsonSerializer]::Serialize(
        [object]$payload, $payload.GetType(), [JsonSerializerOptions]::new())
    try {
        $body = Invoke-LocalModelHttpJson -Endpoint $Chat.Endpoint -Path '/v1/chat/completions' -Json $json

        $document = [JsonDocument]::Parse($body)
        try {
            $root = $document.RootElement
            $content = $root.GetProperty('choices')[0].GetProperty('message').GetProperty('content').GetString()
            $assistantMessage = [Dictionary[string, object]]::new()
            $assistantMessage['role'] = 'assistant'
            $assistantMessage['content'] = $content
            $Chat.Messages.Add($assistantMessage)
            $Chat.Turns++

            $timingElement = [JsonElement]::new()
            $timings = if ($root.TryGetProperty('timings', [ref]$timingElement)) {
                [pscustomobject]@{
                    PromptTokensPerSecond = $timingElement.GetProperty('prompt_per_second').GetDouble()
                    PredictedTokensPerSecond = $timingElement.GetProperty('predicted_per_second').GetDouble()
                    PromptMilliseconds = $timingElement.GetProperty('prompt_ms').GetDouble()
                    PredictedMilliseconds = $timingElement.GetProperty('predicted_ms').GetDouble()
                }
            } else { $null }

            [pscustomobject]@{
                Content = $content
                Model = $root.GetProperty('model').GetString()
                Turn = $Chat.Turns
                Timings = $timings
            }
        } finally {
            $document.Dispose()
        }
    } catch {
        # A failed admission does not become conversation history.
        $Chat.Messages.RemoveAt($Chat.Messages.Count - 1)
        throw
    }
}

function Close-LocalModelChat {
    param([Parameter(Mandatory, ValueFromPipeline)] $Chat)
    # One connection per turn for now. Kept as a lifecycle verb so a persistent
    # streaming transport can replace it without changing callers.
}
