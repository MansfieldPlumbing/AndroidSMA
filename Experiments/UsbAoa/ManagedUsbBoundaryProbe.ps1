$ErrorActionPreference = 'Stop'
$receipt = [IO.Path]::Combine($Activity.FilesDir.AbsolutePath, 'managed-usb-boundary-proof.txt')
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('UTC=' + [DateTimeOffset]::UtcNow.ToString('O'))
$lines.Add('ACTIVITY_TYPE=' + $Activity.GetType().AssemblyQualifiedName)

try {
    $usb = $Activity.GetSystemService([Android.Content.Context]::UsbService)
    if ($null -eq $usb) { throw 'GetSystemService(UsbService) returned null.' }

    $lines.Add('USB_MANAGER_TYPE=' + $usb.GetType().AssemblyQualifiedName)
    $lines.Add('MANAGED_USB_MANAGER=' + ($usb -is [Android.Hardware.Usb.UsbManager]))
    $lines.Add('INTENT_ACTION=' + [string]$Activity.Intent.Action)

    $accessories = @($usb.AccessoryList)
    $lines.Add('ACCESSORY_COUNT=' + $accessories.Count)
    for ($i = 0; $i -lt $accessories.Count; $i++) {
        $accessory = $accessories[$i]
        if ($null -eq $accessory) {
            $lines.Add("ACCESSORY_${i}=NULL")
            continue
        }

        $lines.Add("ACCESSORY_${i}_TYPE=" + $accessory.GetType().AssemblyQualifiedName)
        $lines.Add("ACCESSORY_${i}_MANUFACTURER=" + [string]$accessory.Manufacturer)
        $lines.Add("ACCESSORY_${i}_MODEL=" + [string]$accessory.Model)
        $lines.Add("ACCESSORY_${i}_PERMISSION=" + $usb.HasPermission($accessory))
    }

    $lines.Add('RESULT=PASS')
}
catch {
    $lines.Add('RESULT=FAIL')
    $lines.Add('ERROR_TYPE=' + $_.Exception.GetType().FullName)
    $lines.Add('ERROR=' + $_.Exception.Message)
    $lines.Add('STACK=' + $_.ScriptStackTrace)
}
finally {
    [IO.File]::WriteAllLines($receipt, $lines, [Text.UTF8Encoding]::new($false))
}
