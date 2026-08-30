$ErrorActionPreference='Stop'
if($null-eq$Activity){throw 'ACTIVITY_NOT_PROJECTED'}
$intent=[Android.Content.Intent]::new($Activity,[AndroidSMA.MainActivity])
$intent.AddFlags([Android.Content.ActivityFlags]::NewTask-bor[Android.Content.ActivityFlags]::ReorderToFront-bor[Android.Content.ActivityFlags]::SingleTop)
$Activity.StartActivity($intent)
'FOREGROUND_REQUESTED pid='+[Environment]::ProcessId+' utc='+[DateTime]::UtcNow.ToString('o')
