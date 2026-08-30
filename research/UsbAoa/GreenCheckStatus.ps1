$ErrorActionPreference='Stop'
$receipt=[IO.Path]::Combine($AndroidSmaHome,'GreenCheck.result')
if(-not[IO.File]::Exists($receipt)){throw 'GREEN_CHECK_NO_COMPLETION_RECEIPT'}
$result=[IO.File]::ReadAllText($receipt,[Text.UTF8Encoding]::new($false))
if(-not$result.StartsWith('OK ',[StringComparison]::Ordinal)){throw $result}
$result
