#requires -Version 7.0
using namespace System
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text

# Minimal PSRP-shaped transport substrate: ordered, length-framed CLIXML Values.
# It deliberately does not claim MS-PSRP wire compatibility.

function Read-PsrpExact {
    param([Parameter(Mandatory)] [Stream] $Stream, [Parameter(Mandatory)] [int] $Count)
    $bytes = [byte[]]::new($Count)
    $at = 0
    while ($at -lt $Count) {
        $read = $Stream.Read($bytes, $at, $Count - $at)
        if ($read -le 0) { throw [EndOfStreamException]::new('PSRP peer closed the stream.') }
        $at += $read
    }
    $bytes
}

function Write-PsrpFrame {
    param([Parameter(Mandatory)] [Stream] $Stream, [Parameter(Mandatory)] $Value)
    $xml = [PSSerializer]::Serialize($Value, 8)
    $payload = [Encoding]::UTF8.GetBytes($xml)
    $length = [BitConverter]::GetBytes([Net.IPAddress]::HostToNetworkOrder($payload.Length))
    $Stream.Write($length, 0, $length.Length)
    $Stream.Write($payload, 0, $payload.Length)
    $Stream.Flush()
}

function Read-PsrpFrame {
    param([Parameter(Mandatory)] [Stream] $Stream)
    $prefix = Read-PsrpExact -Stream $Stream -Count 4
    $length = [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($prefix, 0))
    if ($length -lt 1 -or $length -gt 16MB) {
        throw [InvalidDataException]::new("Invalid PSRP frame length: $length")
    }
    $payload = Read-PsrpExact -Stream $Stream -Count $length
    [PSSerializer]::Deserialize([Encoding]::UTF8.GetString($payload))
}

