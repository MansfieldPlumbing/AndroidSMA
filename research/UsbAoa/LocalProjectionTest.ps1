$ErrorActionPreference='Stop'
if($null-eq$Activity){throw 'ACTIVITY_NOT_PROJECTED'}
$Activity.RunOnUiThread([Action]{
$green=[Android.Graphics.Color]::Rgb(0,190,70)
$window=$Activity.Window
$window.StatusBarColor=$green
$window.NavigationBarColor=$green
$window.AddFlags([Android.Views.WindowManagerFlags]::KeepScreenOn)
$view=[Android.Widget.TextView]::new($Activity)
$view.Text=[string][char]0x2713
$view.TextSize=180
$view.Gravity=[Android.Views.GravityFlags]::Center
$view.SetTextColor([Android.Graphics.Color]::White)
$view.SetBackgroundColor($green)
$view.ContentDescription='AndroidSMA ready'
$Activity.SetContentView($view)
$intent=$Activity.Intent
$intent.AddFlags([Android.Content.ActivityFlags]::ReorderToFront)
$Activity.StartActivity($intent)
})
'GREEN_CHECK_QUEUED'
