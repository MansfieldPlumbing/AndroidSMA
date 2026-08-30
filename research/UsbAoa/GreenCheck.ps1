$ErrorActionPreference='Stop'
if($null-eq$Activity){throw 'ACTIVITY_NOT_PROJECTED'}
$receipt=[IO.Path]::Combine($AndroidSmaHome,'GreenCheck.result')
if([IO.File]::Exists($receipt)){[IO.File]::Delete($receipt)}
$Activity.RunOnUiThread([Action]{
try{
$green=[Android.Graphics.Color]::Rgb(0,190,70)
$window=$Activity.Window
$window.SetStatusBarColor($green)
$window.SetNavigationBarColor($green)
$window.AddFlags([Android.Views.WindowManagerFlags]::KeepScreenOn)
$view=[Android.Widget.TextView]::new($Activity)
$view.Text=[string][char]0x2713
$view.TextSize=180
$view.Gravity=[Android.Views.GravityFlags]::Center
$view.SetTextColor([Android.Graphics.Color]::White)
$view.SetBackgroundColor($green)
$view.ContentDescription='AndroidSMA ready'
$Activity.SetContentView($view)
[IO.File]::WriteAllText($receipt,'OK pid='+[Environment]::ProcessId+' utc='+[DateTime]::UtcNow.ToString('o'),[Text.UTF8Encoding]::new($false))
}catch{
$failure=$_.Exception
while($null-ne$failure.InnerException){$failure=$failure.InnerException}
[IO.File]::WriteAllText($receipt,'ERROR type='+$failure.GetType().FullName+' message='+$failure.Message,[Text.UTF8Encoding]::new($false))
}
})
'GREEN_CHECK_SCHEDULED receipt='+$receipt
