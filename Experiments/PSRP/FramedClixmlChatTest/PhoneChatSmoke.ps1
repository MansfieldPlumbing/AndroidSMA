$root = $Activity.FilesDir.AbsolutePath
$receipt = [IO.Path]::Combine($root, 'bonsai-bridge-receipt.txt')
$fault = [IO.Path]::Combine($root, 'bonsai-bridge-fault.txt')

try {
    $json = '{"model":"Bonsai-8B-Q1_0.gguf","messages":[{"role":"user","content":"Reply with exactly: PHONE BONSAI BRIDGE ALIVE"}],"max_tokens":32,"temperature":0}'
    $payload = [Text.Encoding]::UTF8.GetBytes($json)
    $tcp = [Net.Sockets.TcpClient]::new()
    $tcp.Connect('127.0.0.1', 8080)
    $stream = $tcp.GetStream()
    $head = [Text.Encoding]::ASCII.GetBytes(
        "POST /v1/chat/completions HTTP/1.1`r`n" +
        "Host: 127.0.0.1:8080`r`n" +
        "Content-Type: application/json`r`n" +
        "Content-Length: $($payload.Length)`r`n" +
        "Connection: close`r`n`r`n")
    $stream.Write($head, 0, $head.Length)
    $stream.Write($payload, 0, $payload.Length)
    $stream.Flush()
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
    $wire = $reader.ReadToEnd()
    $split = $wire.IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
    if ($split -lt 0) { throw 'Bonsai returned no HTTP header boundary.' }
    $headers = $wire.Substring(0, $split)
    $body = $wire.Substring($split + 4)
    if ($headers -notmatch '^HTTP/1\.[01] 200 ') { throw "$headers`n$body" }
    $document = [Text.Json.JsonDocument]::Parse($body)
    $answer = $document.RootElement.GetProperty('choices')[0].GetProperty('message').GetProperty('content').GetString()
    [IO.File]::WriteAllText($receipt, $answer)

    $view = [Android.Widget.TextView]::new($Activity)
    $view.Text = "BONSAI / LOCAL`n`n$answer"
    $view.SetTextColor([Android.Graphics.Color]::White)
    $view.SetTextSize([Android.Util.ComplexUnitType]::Sp, 24)
    $view.SetPadding(32, 32, 32, 32)
    $view.SetBackgroundColor([Android.Graphics.Color]::Rgb(9, 12, 18))
    $Activity.SetContentView($view)
} catch {
    [IO.File]::WriteAllText($fault, ($_.Exception.ToString() + "`n" + $_.ScriptStackTrace))
    throw
} finally {
    if ($document) { $document.Dispose() }
    if ($reader) { $reader.Dispose() }
    elseif ($stream) { $stream.Dispose() }
    if ($tcp) { $tcp.Dispose() }
}
