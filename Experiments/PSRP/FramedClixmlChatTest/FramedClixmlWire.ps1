#requires -Version 7.0
using namespace System
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

# Ordered values encoded as CLIXML behind a four-byte network-order length.
# This is a local test wire, not an implementation of a remoting standard.

function Read-ClixmlExact {
    param([Parameter(Mandatory)] [Stream] $Stream, [Parameter(Mandatory)] [int] $Count)
    $bytes = [byte[]]::new($Count)
    $at = 0
    while ($at -lt $Count) {
        $read = $Stream.Read($bytes, $at, $Count - $at)
        if ($read -le 0) { throw [EndOfStreamException]::new('CLIXML peer closed the stream.') }
        $at += $read
    }
    $bytes
}

function Write-ClixmlFrame {
    param([Parameter(Mandatory)] [Stream] $Stream, [Parameter(Mandatory)] $Value)
    $xml = [PSSerializer]::Serialize($Value, 8)
    $payload = [Encoding]::UTF8.GetBytes($xml)
    $length = [BitConverter]::GetBytes([Net.IPAddress]::HostToNetworkOrder($payload.Length))
    $Stream.Write($length, 0, $length.Length)
    $Stream.Write($payload, 0, $payload.Length)
    $Stream.Flush()
}

function Read-ClixmlFrame {
    param([Parameter(Mandatory)] [Stream] $Stream)
    $prefix = Read-ClixmlExact -Stream $Stream -Count 4
    $length = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($prefix, 0))
    if ($length -lt 1 -or $length -gt 16MB) {
        throw [InvalidDataException]::new("Invalid CLIXML frame length: $length")
    }
    $payload = Read-ClixmlExact -Stream $Stream -Count $length
    [PSSerializer]::Deserialize([Encoding]::UTF8.GetString($payload))
}
