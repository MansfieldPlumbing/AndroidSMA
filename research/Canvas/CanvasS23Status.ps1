$ErrorActionPreference='Stop'
$receipt=[IO.Path]::Combine($AndroidSmaHome,'PS1','CanvasS23.result')
if(-not[IO.File]::Exists($receipt)){throw 'CANVAS_S23_NO_RECEIPT'}
[IO.File]::ReadAllText($receipt,[Text.UTF8Encoding]::new($false))
