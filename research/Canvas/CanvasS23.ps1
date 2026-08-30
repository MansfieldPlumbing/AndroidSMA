$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
$sourcePath=[IO.Path]::Combine($AndroidSmaHome,'PS1','canvastest.ps1')
$receipt=[IO.Path]::Combine($AndroidSmaHome,'PS1','CanvasS23.result')
$expected='987C54023ABAD366F387442D9CB004DBE4877BCE51E0298B75B7CB0CF77E0465'
$bytes=[IO.File]::ReadAllBytes($sourcePath)
$actual=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
if($actual-ne$expected){throw 'CANVAS_SOURCE_HASH_MISMATCH expected='+$expected+' actual='+$actual}
$source=$utf8.GetString($bytes)
$source=$source.Replace('param([Parameter(Mandatory)] $Event)',"param()`n`$CanvasS23Receipt='$receipt'")
$source=$source.Replace('$activity = $Event.Activity','$activity = $Activity')
$source=$source.Replace('$service = $PSAndroid.Service','$service = $null')
$source=$source.Replace('$tick = [TerminalMvp.AndroidAnimationRunnable]::new($onAnimation)','$tick = $onAnimation')
$source=$source.Replace("    `$activity.SetContentView(`$surface)","    `$activity.SetContentView(`$surface)`n    [IO.File]::WriteAllText(`$CanvasS23Receipt,'ATTACHED pid='+[Environment]::ProcessId+' utc='+[DateTime]::UtcNow.ToString('o'),[Text.UTF8Encoding]::new(`$false))")
$source=$source.Replace("            [Android.Util.Log]::Info('PowerShell', 'Canvas READY')","            [Android.Util.Log]::Info('PowerShell', 'Canvas READY')`n            [IO.File]::WriteAllText(`$CanvasS23Receipt,'READY pid='+[Environment]::ProcessId+' fps='+`$script:LastFps+' utc='+[DateTime]::UtcNow.ToString('o'),[Text.UTF8Encoding]::new(`$false))")
$dispatch=@'
$activity.RunOnUiThread([Action]{
try{$attach.Invoke()}
catch{
$failure=$_.Exception
while($null-ne$failure.InnerException){$failure=$failure.InnerException}
[IO.File]::WriteAllText($CanvasS23Receipt,'ERROR type='+$failure.GetType().FullName+' message='+$failure.Message,[Text.UTF8Encoding]::new($false))
}
})
'@
$source=$source.Replace('$service.RunOnMainThread($activity, $attach)',$dispatch)
if([IO.File]::Exists($receipt)){[IO.File]::Delete($receipt)}
$Activity.RequestedOrientation=[Android.Content.PM.ScreenOrientation]::SensorLandscape
$scriptBlock=[Management.Automation.ScriptBlock]::Create($source)
[void]$scriptBlock.Invoke()
'CANVAS_S23_SCHEDULED sourceSha256='+$actual+' receipt='+$receipt
