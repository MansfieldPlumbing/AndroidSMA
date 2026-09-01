#requires -Version 7.0

function Connect-BonsaiPsrp {
    param(
        [string] $HostName = '127.0.0.1',
        [int] $Port = 8091,
        [Parameter(Mandatory)] [string] $Capability
    )
    $tcp = [Net.Sockets.TcpClient]::new()
    $tcp.Connect($HostName, $Port)
    $peer = [pscustomobject]@{
        Tcp = $tcp
        Stream = $tcp.GetStream()
        SessionId = [guid]::NewGuid().ToString('N')
    }
    Write-PsrpFrame $peer.Stream ([pscustomobject]@{
        Kind = 'Open'; SessionId = $peer.SessionId; Capability = $Capability
    })
    $opened = Read-PsrpFrame $peer.Stream
    if ($opened.Kind -ne 'SessionState' -or $opened.State -ne 'Opened') {
        throw "Bonsai PSRP session did not open: $opened"
    }
    $peer
}

function Invoke-BonsaiPsrpChat {
    param(
        [Parameter(Mandatory)] $Peer,
        [Parameter(Mandatory)] [string] $Text,
        [int] $MaxTokens = 512,
        [double] $Temperature = 0.7
    )
    $pipelineId = [guid]::NewGuid().ToString('N')
    Write-PsrpFrame $Peer.Stream ([pscustomobject]@{
        Kind = 'CreatePipeline'
        SessionId = $Peer.SessionId
        PipelineId = $pipelineId
        Command = 'Send-BonsaiChat'
        Input = $Text
        MaxTokens = $MaxTokens
        Temperature = $Temperature
    })

    $output = $null
    while ($true) {
        $frame = Read-PsrpFrame $Peer.Stream
        if ($frame.PipelineId -and $frame.PipelineId -ne $pipelineId) { continue }
        if ($frame.Kind -eq 'Stream' -and $frame.Stream -eq 'Output') { $output = $frame.Value }
        if ($frame.Kind -eq 'Stream' -and $frame.Stream -eq 'Error') { throw [string]$frame.Value }
        if ($frame.Kind -eq 'PipelineState' -and $frame.State -eq 'Completed') { return $output }
        if ($frame.Kind -eq 'PipelineState' -and $frame.State -eq 'Failed') { throw 'Bonsai pipeline failed.' }
    }
}

function Disconnect-BonsaiPsrp {
    param([Parameter(Mandatory, ValueFromPipeline)] $Peer)
    try {
        Write-PsrpFrame $Peer.Stream ([pscustomobject]@{
            Kind = 'Close'; SessionId = $Peer.SessionId
        })
        $null = Read-PsrpFrame $Peer.Stream
    } finally {
        $Peer.Stream.Dispose()
        $Peer.Tcp.Dispose()
    }
}
