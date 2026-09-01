#requires -Version 7.0
param(
    [int] $Port = 8091,
    [string] $BindAddress = '127.0.0.1',
    [Parameter(Mandatory)] [string] $Capability
)

$root = Split-Path -Parent $PSCommandPath
. "$root\FramedClixmlWire.ps1"
. "$root\LocalModelChat.ps1"

$sessions = [Collections.Generic.Dictionary[string, object]]::new()
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Parse($BindAddress), $Port)
$listener.Start()
Write-Host "FRAMED_CLIXML_CHAT_LISTENING ${BindAddress}:$Port"

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        try {
            while ($client.Connected) {
                $frame = Read-ClixmlFrame -Stream $stream
                $kind = [string]$frame.Kind
                $sessionId = [string]$frame.SessionId
                $pipelineId = [string]$frame.PipelineId

                switch ($kind) {
                    'Open' {
                        if (-not [Security.Cryptography.CryptographicOperations]::FixedTimeEquals(
                            [Text.Encoding]::UTF8.GetBytes([string]$frame.Capability),
                            [Text.Encoding]::UTF8.GetBytes($Capability))) {
                            throw 'Framed CLIXML chat capability rejected.'
                        }
                        if ([string]::IsNullOrWhiteSpace($sessionId)) {
                            $sessionId = [guid]::NewGuid().ToString('N')
                        }
                        if (-not $sessions.ContainsKey($sessionId)) {
                            $sessions[$sessionId] = New-LocalModelChat
                        }
                        Write-ClixmlFrame $stream ([pscustomobject]@{
                            Kind = 'SessionState'; SessionId = $sessionId; State = 'Opened'
                        })
                    }
                    'CreatePipeline' {
                        Write-ClixmlFrame $stream ([pscustomobject]@{
                            Kind = 'PipelineState'; SessionId = $sessionId
                            PipelineId = $pipelineId; State = 'Running'
                        })
                        try {
                            if (-not $sessions.ContainsKey($sessionId)) {
                                throw "Unknown chat session: $sessionId"
                            }
                            if ([string]$frame.Command -ne 'Send-LocalModelChat') {
                                throw "Command is not admitted: $($frame.Command)"
                            }
                            $invoke = @{
                                Chat = $sessions[$sessionId]
                                Text = [string]$frame.Input
                                MaxTokens = [int]$frame.MaxTokens
                                Temperature = [double]$frame.Temperature
                            }
                            $reply = Send-LocalModelChat @invoke
                            Write-ClixmlFrame $stream ([pscustomobject]@{
                                Kind = 'Stream'; Stream = 'Output'; SessionId = $sessionId
                                PipelineId = $pipelineId; Sequence = 0; Value = $reply
                            })
                            Write-ClixmlFrame $stream ([pscustomobject]@{
                                Kind = 'PipelineState'; SessionId = $sessionId
                                PipelineId = $pipelineId; State = 'Completed'
                            })
                        } catch {
                            Write-ClixmlFrame $stream ([pscustomobject]@{
                                Kind = 'Stream'; Stream = 'Error'; SessionId = $sessionId
                                PipelineId = $pipelineId; Sequence = 0; Value = $_
                            })
                            Write-ClixmlFrame $stream ([pscustomobject]@{
                                Kind = 'PipelineState'; SessionId = $sessionId
                                PipelineId = $pipelineId; State = 'Failed'
                            })
                        }
                    }
                    'Close' {
                        if ($sessions.ContainsKey($sessionId)) {
                            Close-LocalModelChat $sessions[$sessionId]
                            $sessions.Remove($sessionId)
                        }
                        Write-ClixmlFrame $stream ([pscustomobject]@{
                            Kind = 'SessionState'; SessionId = $sessionId; State = 'Closed'
                        })
                    }
                    default { throw "Unknown framed CLIXML message: $kind" }
                }
            }
        } catch [EndOfStreamException] {
            # Peer detached. Sessions remain addressable until an explicit Close.
        } finally {
            $stream.Dispose()
            $client.Dispose()
        }
    }
} finally {
    foreach ($chat in $sessions.Values) { Close-LocalModelChat $chat }
    $listener.Stop()
}
