$ErrorActionPreference = 'Stop'

if ($global:AOAX -and -not $global:AOAX[2].IsCompleted) {
    [void][Android.Util.Log]::Info('AndroidSMA', 'AOA COMMAND SURFACE REUSED')
    return
}

if ($global:AOAX) {
    try { $global:AOAX[1].Dispose() } catch {}
    try { $global:AOAX[0].Dispose() } catch {}
    $global:AOAX = $null
}

$aoaWorker = {
    param($Activity)

    $ErrorActionPreference = 'Stop'
    $manager = [Android.Hardware.Usb.UsbManager]$Activity.GetSystemService(
        [Android.Content.Context]::UsbService
    )

    [void][Android.Util.Log]::Info(
        'AndroidSMA',
        "AOA COMMAND SURFACE ARMED PID=$([Environment]::ProcessId)"
    )

    [bool]$reportedAccessoryState = $false
    while ($true) {
        $pfd = $null
        $input = $null
        $output = $null

        try {
            $accessories = @($manager.AccessoryList)
            if (-not $reportedAccessoryState) {
                [void][Android.Util.Log]::Info(
                    'AndroidSMA',
                    "AOA ACCESSORY COUNT=$($accessories.Count) FIRST_NULL=$($null -eq $accessories[0])"
                )
                $reportedAccessoryState = $true
            }
            if ($accessories.Count -eq 0 -or $null -eq $accessories[0]) {
                [Threading.Thread]::Sleep(100)
                continue
            }

            $accessory = $accessories[0]
            if (-not $manager.HasPermission($accessory)) {
                [void][Android.Util.Log]::Warn('AndroidSMA', 'AOA WAITING FOR ACCESSORY PERMISSION')
                [Threading.Thread]::Sleep(500)
                continue
            }

            $pfd = $manager.OpenAccessory($accessory)
            if ($null -eq $pfd) {
                throw 'OpenAccessory returned null.'
            }

            $input = [Java.IO.FileInputStream]::new($pfd.FileDescriptor)
            $output = [Java.IO.FileOutputStream]::new($pfd.FileDescriptor)

            [void][Android.Util.Log]::Info(
                'AndroidSMA',
                "AOA COMMAND SURFACE READY FD=$($pfd.Fd)"
            )

            while ($true) {
                [byte[]]$header = [byte[]]::new(4)
                [int]$offset = 0
                while ($offset -lt 4) {
                    [int]$n = $input.Read($header, $offset, 4 - $offset)
                    if ($n -lt 0) { throw 'AOA disconnected while reading a frame header.' }
                    if ($n -eq 0) { continue }
                    $offset += $n
                }

                [uint32]$length = [BitConverter]::ToUInt32($header, 0)
                if ($length -gt 1048576) {
                    throw "AOA command frame is $length bytes; maximum is 1048576."
                }

                [byte[]]$payload = [byte[]]::new([int]$length)
                $offset = 0
                while ($offset -lt $payload.Length) {
                    [int]$n = $input.Read($payload, $offset, $payload.Length - $offset)
                    if ($n -lt 0) { throw 'AOA disconnected while reading a frame body.' }
                    if ($n -eq 0) { continue }
                    $offset += $n
                }

                try {
                    $source = [Text.Encoding]::UTF8.GetString($payload)
                    $values = @(. ([scriptblock]::Create($source)) 2>&1)
                    [string[]]$texts = @()
                    foreach ($value in $values) {
                        $texts += $(if ($null -eq $value) { 'NULL' } else { [string]$value })
                    }
                    $outputJson = [System.Text.Json.JsonSerializer]::Serialize(
                        [object]$texts,
                        [Type][string[]],
                        $null
                    )
                    $replyJson = '{"ok":true,"output":' + $outputJson + '}'
                }
                catch {
                    $errorText = "$(($_.Exception.GetType()).FullName): $($_.Exception.Message)"
                    $errorJson = [System.Text.Json.JsonSerializer]::Serialize(
                        [object]$errorText,
                        [Type][string],
                        $null
                    )
                    $replyJson = '{"ok":false,"error":' + $errorJson + '}'
                }

                [byte[]]$body = [Text.Encoding]::UTF8.GetBytes($replyJson)
                [byte[]]$replyHeader = [BitConverter]::GetBytes([uint32]$body.Length)
                $output.Write($replyHeader, 0, $replyHeader.Length)
                if ($body.Length -gt 0) {
                    $output.Write($body, 0, $body.Length)
                }
                $output.Flush()
            }
        }
        catch {
            [void][Android.Util.Log]::Error(
                'AndroidSMA',
                "AOA COMMAND SURFACE $($_.Exception.Message)"
            )
            [Threading.Thread]::Sleep(250)
        }
        finally {
            try { $input.Dispose() } catch {}
            try { $output.Dispose() } catch {}
            try { $pfd.Close() } catch {}
        }
    }
}

$initial = [System.Management.Automation.Runspaces.InitialSessionState]::Create()
$initial.LanguageMode = [System.Management.Automation.PSLanguageMode]::FullLanguage
$initial.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::UseNewThread

$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($initial)
$runspace.Open()

$powershell = [System.Management.Automation.PowerShell]::Create()
$powershell.Runspace = $runspace
[void]$powershell.AddScript($aoaWorker.ToString()).AddArgument($Activity)
$async = $powershell.BeginInvoke()

$global:AOAX = @($runspace, $powershell, $async)
