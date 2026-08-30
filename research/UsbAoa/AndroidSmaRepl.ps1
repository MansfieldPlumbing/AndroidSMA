$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
$magic=[byte[]](0x41,0x53,0x4d,0x41)
$version=[uint16]1
$maxFrame=16777216
$timeoutMs=60000
$port=45888
$httpPort=45889
$cleanPort=45890
$hostName='127.0.0.1'
$bindName='127.0.0.1'
$server=$false
$android=$false
$httpEnabled=$true
$cleanClient=$false
$portExplicit=$false

try{$android=[OperatingSystem]::IsAndroid()}catch{$android=[Runtime.InteropServices.RuntimeInformation]::OSDescription.Contains('Android',[StringComparison]::OrdinalIgnoreCase)}
if($android){$server=$true;$bindName='0.0.0.0'}

for($i=0;$i-lt$args.Count;$i++){
if($args[$i]-eq'--server'){$server=$true}
if($args[$i]-eq'--host'-and$i+1-lt$args.Count){$i++;$hostName=[string]$args[$i]}
if($args[$i]-eq'--bind'-and$i+1-lt$args.Count){$i++;$bindName=[string]$args[$i]}
if($args[$i]-eq'--port'-and$i+1-lt$args.Count){$i++;$port=[int]$args[$i];$portExplicit=$true}
if($args[$i]-eq'--http-port'-and$i+1-lt$args.Count){$i++;$httpPort=[int]$args[$i]}
if($args[$i]-eq'--clean-port'-and$i+1-lt$args.Count){$i++;$cleanPort=[int]$args[$i]}
if($args[$i]-eq'--clean'){$cleanClient=$true}
if($args[$i]-eq'--no-http'){$httpEnabled=$false}
if($args[$i]-eq'--timeout-ms'-and$i+1-lt$args.Count){$i++;$timeoutMs=[int]$args[$i]}
}
if($cleanClient-and-not$portExplicit){$port=$cleanPort}

if(-not[BitConverter]::IsLittleEndian){throw 'ASMA_REPL_REQUIRES_LITTLE_ENDIAN'}
if($port-lt1-or$port-gt65535){throw 'PORT_OUT_OF_RANGE'}
if($httpPort-lt1-or$httpPort-gt65535-or($server-and($httpPort-eq$port-or$httpPort-eq$cleanPort))){throw 'HTTP_PORT_OUT_OF_RANGE'}
if($cleanPort-lt1-or$cleanPort-gt65535-or($server-and$cleanPort-eq$port)){throw 'CLEAN_PORT_OUT_OF_RANGE'}
if($timeoutMs-lt1000-or$timeoutMs-gt3600000){throw 'TIMEOUT_OUT_OF_RANGE'}

if($android-and-not$global:AndroidSmaReplWorker){
if($global:AndroidSmaReplOwner-and-not$global:AndroidSmaReplOwner[2].IsCompleted){return}
if($global:AndroidSmaReplOwner){
try{$global:AndroidSmaReplOwner[1].Dispose()}catch{}
try{$global:AndroidSmaReplOwner[0].Dispose()}catch{}
$global:AndroidSmaReplOwner=$null
}
$workerRoot='/data/user/0/dev.mansfieldplumbing.androidsma/files'
$workerPath=[IO.Path]::Combine($workerRoot,'PROFILE.PS1')
$workerSource=[IO.File]::ReadAllText($workerPath,$utf8)
$workerInitial=[Management.Automation.Runspaces.InitialSessionState]::Create()
$workerInitial.LanguageMode=[Management.Automation.PSLanguageMode]::FullLanguage
$workerInitial.ThreadOptions=[Management.Automation.Runspaces.PSThreadOptions]::UseNewThread
$workerRunspace=[Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($workerInitial)
$workerPowerShell=$null
try{
$workerRunspace.Open()
$workerRunspace.SessionStateProxy.SetVariable('AndroidSmaReplWorker',$true)
$workerRunspace.SessionStateProxy.SetVariable('Activity',$Activity)
$workerPowerShell=[Management.Automation.PowerShell]::Create()
$workerPowerShell.Runspace=$workerRunspace
[void]$workerPowerShell.AddScript($workerSource,$false)
$workerAsync=$workerPowerShell.BeginInvoke()
$global:AndroidSmaReplOwner=[object[]]@($workerRunspace,$workerPowerShell,$workerAsync)
[IO.File]::AppendAllText([IO.Path]::Combine($workerRoot,'AndroidSmaRepl.log'),[DateTime]::UtcNow.ToString('o')+' BOOTSTRAP worker=STARTED pid='+[Environment]::ProcessId+[Environment]::NewLine,$utf8)
}catch{
if($null-ne$workerPowerShell){try{$workerPowerShell.Dispose()}catch{}}
try{$workerRunspace.Dispose()}catch{}
throw
}
return
}

$readExact=[Func[IO.Stream,int,byte[]]]{
param([IO.Stream]$stream,[int]$count)
$buffer=[byte[]]::new($count)
$offset=0
while($offset-lt$count){
$read=$stream.Read($buffer,$offset,$count-$offset)
if($read-le0){throw 'PEER_CLOSED'}
$offset+=$read
}
return $buffer
}

$writeFrame=[Action[IO.Stream,uint16,uint32,byte[]]]{
param([IO.Stream]$stream,[uint16]$opcode,[uint32]$requestId,[byte[]]$payload)
if($null-eq$payload){$payload=[byte[]]::new(0)}
if($payload.Length-gt$maxFrame){throw 'FRAME_TOO_LARGE'}
$header=[byte[]]::new(16)
[Array]::Copy($magic,0,$header,0,4)
[Array]::Copy([BitConverter]::GetBytes($version),0,$header,4,2)
[Array]::Copy([BitConverter]::GetBytes($opcode),0,$header,6,2)
[Array]::Copy([BitConverter]::GetBytes($requestId),0,$header,8,4)
[Array]::Copy([BitConverter]::GetBytes([uint32]$payload.Length),0,$header,12,4)
$stream.Write($header,0,$header.Length)
if($payload.Length-gt0){$stream.Write($payload,0,$payload.Length)}
$stream.Flush()
}

$readFrame=[Func[IO.Stream,object[]]]{
param([IO.Stream]$stream)
$header=$readExact.Invoke($stream,16)
for($n=0;$n-lt4;$n++){if($header[$n]-ne$magic[$n]){throw 'BAD_MAGIC'}}
$wireVersion=[BitConverter]::ToUInt16($header,4)
if($wireVersion-ne$version){throw 'BAD_VERSION'}
$opcode=[BitConverter]::ToUInt16($header,6)
$requestId=[BitConverter]::ToUInt32($header,8)
$length=[BitConverter]::ToUInt32($header,12)
if($length-gt$maxFrame){throw 'FRAME_TOO_LARGE'}
$payload=if($length-eq0){[byte[]]::new(0)}else{$readExact.Invoke($stream,[int]$length)}
return [object[]]@($opcode,$requestId,$payload)
}

if($server){
if($global:AndroidSmaReplActive){return}
$global:AndroidSmaReplActive=$true
$root=if($android){'/data/user/0/dev.mansfieldplumbing.androidsma/files'}elseif($PSScriptRoot){$PSScriptRoot}else{[Environment]::CurrentDirectory}
$root=[IO.Path]::GetFullPath($root)
$rootPrefix=$root.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
$log=[IO.Path]::Combine($root,'AndroidSmaRepl.log')
$processName=if($android){'dev.mansfieldplumbing.androidsma'}else{[IO.Path]::GetFileNameWithoutExtension([Environment]::ProcessPath)}
$processUid=if($android){'UNKNOWN'}else{[Environment]::UserName}
if($android-and[IO.File]::Exists('/proc/self/cmdline')){$processName=[IO.File]::ReadAllText('/proc/self/cmdline').Trim([char[]]@([char]0))}
if($android-and[IO.File]::Exists('/proc/self/status')){
$statusText=[IO.File]::ReadAllText('/proc/self/status')
foreach($statusLine in $statusText.Split([string[]]@("`r`n","`n"),[StringSplitOptions]::RemoveEmptyEntries)){
if($statusLine.StartsWith('Uid:',[StringComparison]::Ordinal)){$uidParts=$statusLine.Split([char[]]@("`t",' '),[StringSplitOptions]::RemoveEmptyEntries);if($uidParts.Length-ge2){$processUid=$uidParts[1]};break}
}
}
$listener=$null
$cleanListener=$null
$runspace=$null
$httpRunspace=$null
$httpPowerShell=$null
$httpAsync=$null
$httpCancellation=$null
$running=$true
$sessionId=[Guid]::NewGuid().ToString('D')

$appendLog=[Action[string]]{
param([string]$text)
try{[IO.File]::AppendAllText($log,[DateTime]::UtcNow.ToString('o')+' '+$text+[Environment]::NewLine,$utf8)}catch{}
}

$resolveRemote=[Func[string,string]]{
param([string]$relative)
if([string]::IsNullOrWhiteSpace($relative)){throw 'EMPTY_PATH'}
if([IO.Path]::IsPathRooted($relative)){throw 'ROOTED_PATH_REJECTED'}
$target=[IO.Path]::GetFullPath([IO.Path]::Combine($root,$relative))
if(-not$target.StartsWith($rootPrefix,[StringComparison]::Ordinal)){throw 'PATH_ESCAPE_REJECTED'}
if(-not[string]::Equals([IO.Path]::GetExtension($target),'.ps1',[StringComparison]::OrdinalIgnoreCase)){throw 'ONLY_PS1_ALLOWED'}
return $target
}

try{
$initial=[Management.Automation.Runspaces.InitialSessionState]::Create()
$initial.LanguageMode=[Management.Automation.PSLanguageMode]::FullLanguage
$initial.ThreadOptions=[Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
$runspace=[Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($initial)
$runspace.Open()
$runspace.SessionStateProxy.SetVariable('AndroidSmaHome',$root)
$runspace.SessionStateProxy.SetVariable('AndroidSmaSessionId',$sessionId)
$runspace.SessionStateProxy.SetVariable('AndroidSmaProcessName',$processName)
$runspace.SessionStateProxy.SetVariable('AndroidSmaUid',$processUid)
$runspace.SessionStateProxy.SetVariable('AndroidSmaPid',[Environment]::ProcessId)
if($android){$runspace.SessionStateProxy.SetVariable('Activity',$Activity)}

if($httpEnabled){
$httpCancellation=[Threading.CancellationTokenSource]::new()
$httpSource=@'
param($BindName,$Port,$Root,$ReplPort,$CleanPort,$SessionId,$ProcessName,$ProcessUid,$Cancellation)
$ErrorActionPreference='Stop'
$utf8=[Text.UTF8Encoding]::new($false)
$address=if($BindName-eq'0.0.0.0'){[Net.IPAddress]::Any}elseif($BindName-eq'127.0.0.1'){[Net.IPAddress]::Loopback}else{[Net.IPAddress]::Parse($BindName)}
$listener=[Net.Sockets.TcpListener]::new($address,$Port)
try{
$listener.Server.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,[Net.Sockets.SocketOptionName]::ReuseAddress,$true)
$listener.Start(8)
while(-not$Cancellation.IsCancellationRequested){
if(-not$listener.Pending()){[Threading.Thread]::Sleep(50);continue}
$client=$null
$stream=$null
$reader=$null
try{
$client=$listener.AcceptTcpClient()
$client.ReceiveTimeout=5000
$client.SendTimeout=5000
$stream=$client.GetStream()
$reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
$request=$reader.ReadLine()
while($true){$line=$reader.ReadLine();if($null-eq$line-or$line.Length-eq0){break}}
$method=''
$path=''
if($request){$parts=$request.Split([char[]]@(' '),3,[StringSplitOptions]::RemoveEmptyEntries);if($parts.Length-ge2){$method=$parts[0];$path=$parts[1]}}
$status='200 OK'
$contentType='text/plain; charset=utf-8'
if($method-ne'GET'){$status='405 Method Not Allowed';$body='METHOD_NOT_ALLOWED'}
elseif($path-eq'/health'){$contentType='application/json; charset=utf-8';$body='{"ok":true,"endpoint":"AndroidSMA","session":"'+$SessionId+'","process":"'+$ProcessName+'","pid":'+[Environment]::ProcessId+',"uid":"'+$ProcessUid+'","developmentPort":'+$ReplPort+',"cleanPort":'+$CleanPort+',"httpPort":'+$Port+',"auth":"none","utc":"'+[DateTime]::UtcNow.ToString('o')+'"}'}
elseif($path-eq'/files'){$names=[Collections.Generic.List[string]]::new();foreach($file in [IO.Directory]::EnumerateFiles($Root,'*.ps1',[IO.SearchOption]::TopDirectoryOnly)){[void]$names.Add([IO.Path]::GetFileName($file))};$body=[string]::Join("`n",$names)}
elseif($path-eq'/log'){$logPath=[IO.Path]::Combine($Root,'AndroidSmaRepl.log');if([IO.File]::Exists($logPath)){$logLength=[IO.FileInfo]::new($logPath).Length;$logOffset=[Math]::Max(0,$logLength-262144);$logStream=[IO.File]::Open($logPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$logStream.Position=$logOffset;$logBytes=[byte[]]::new([int]($logLength-$logOffset));$logRead=$logStream.Read($logBytes,0,$logBytes.Length);$body=$utf8.GetString($logBytes,0,$logRead)}finally{$logStream.Dispose()}}else{$body=''}}
elseif($path-eq'/'){$contentType='text/html; charset=utf-8';$body='<!doctype html><meta charset="utf-8"><title>AndroidSMA</title><h1>AndroidSMA projection</h1><p>REPL '+$ReplPort+'</p><a href="/health">health</a> <a href="/files">files</a> <a href="/log">log</a>'}
else{$status='404 Not Found';$body='NOT_FOUND'}
$bytes=$utf8.GetBytes($body)
$header='HTTP/1.1 '+$status+"`r`nContent-Type: "+$contentType+"`r`nContent-Length: "+$bytes.Length+"`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
$head=[Text.Encoding]::ASCII.GetBytes($header)
$stream.Write($head,0,$head.Length)
$stream.Write($bytes,0,$bytes.Length)
$stream.Flush()
}catch{}finally{if($null-ne$reader){try{$reader.Dispose()}catch{}};if($null-ne$stream){try{$stream.Dispose()}catch{}};if($null-ne$client){try{$client.Dispose()}catch{}}}
}
}finally{$listener.Stop()}
'@
$httpInitial=[Management.Automation.Runspaces.InitialSessionState]::Create()
$httpInitial.LanguageMode=[Management.Automation.PSLanguageMode]::FullLanguage
$httpInitial.ThreadOptions=[Management.Automation.Runspaces.PSThreadOptions]::UseNewThread
$httpRunspace=[Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($httpInitial)
$httpRunspace.Open()
$httpPowerShell=[Management.Automation.PowerShell]::Create()
$httpPowerShell.Runspace=$httpRunspace
[void]$httpPowerShell.AddScript($httpSource).AddArgument($bindName).AddArgument($httpPort).AddArgument($root).AddArgument($port).AddArgument($cleanPort).AddArgument($sessionId).AddArgument($processName).AddArgument($processUid).AddArgument($httpCancellation.Token)
$httpAsync=$httpPowerShell.BeginInvoke()
$appendLog.Invoke('HTTP_START bind='+$bindName+' port='+$httpPort+' auth=NONE')
}
$execute=[Action[string,uint32,IO.Stream]]{
param([string]$code,[uint32]$requestId,[IO.Stream]$stream)
$pipeline=$null
$async=$null
$timedOut=$false
try{
$pipeline=[Management.Automation.PowerShell]::Create()
$pipeline.Runspace=$runspace
[void]$pipeline.AddScript($code,$false)
$async=$pipeline.BeginInvoke()
if(-not$async.AsyncWaitHandle.WaitOne($timeoutMs)){
$timedOut=$true
$pipeline.Stop()
}
$output=$pipeline.EndInvoke($async)
foreach($value in $output){
$text=if($null-eq$value){'NULL'}else{[string]$value}
$writeFrame.Invoke($stream,0x8002,$requestId,$utf8.GetBytes($text))
}
foreach($value in $pipeline.Streams.Error){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('ERROR '+[string]$value))}
foreach($value in $pipeline.Streams.Warning){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('WARNING '+[string]$value))}
foreach($value in $pipeline.Streams.Verbose){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('VERBOSE '+[string]$value))}
foreach($value in $pipeline.Streams.Debug){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('DEBUG '+[string]$value))}
foreach($value in $pipeline.Streams.Information){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('INFORMATION '+[string]$value))}
$done=if($timedOut){'TIMEOUT'}elseif($pipeline.HadErrors){'ERROR'}else{'OK'}
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes($done))
$appendLog.Invoke('EXEC id='+$requestId+' status='+$done)
}catch{
try{
if($timedOut){$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('Pipeline execution timed out after '+$timeoutMs+' ms.'))}
elseif($null-ne$pipeline-and$pipeline.Streams.Error.Count-gt0){foreach($value in $pipeline.Streams.Error){$failure=$value.Exception;while($null-ne$failure.InnerException){$failure=$failure.InnerException};$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes($failure.GetType().FullName+[char]0+$failure.Message))}}
else{$failure=$_.Exception;while($null-ne$failure.InnerException){$failure=$failure.InnerException};$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes($failure.GetType().FullName+[char]0+$failure.Message))}
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes($(if($timedOut){'TIMEOUT'}else{'ERROR'})))
}catch{}
$appendLog.Invoke('EXEC id='+$requestId+' status=EXCEPTION type='+$_.Exception.GetType().FullName)
}finally{
if($null-ne$async){try{$async.AsyncWaitHandle.Close()}catch{}}
if($null-ne$pipeline){try{$pipeline.Dispose()}catch{}}
}
}

$address=if($bindName-eq'0.0.0.0'){[Net.IPAddress]::Any}elseif($bindName-eq'127.0.0.1'){[Net.IPAddress]::Loopback}else{[Net.IPAddress]::Parse($bindName)}
$listener=[Net.Sockets.TcpListener]::new($address,$port)
$listener.Server.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,[Net.Sockets.SocketOptionName]::ReuseAddress,$true)
$listener.Start(8)
$cleanListener=[Net.Sockets.TcpListener]::new($address,$cleanPort)
$cleanListener.Server.SetSocketOption([Net.Sockets.SocketOptionLevel]::Socket,[Net.Sockets.SocketOptionName]::ReuseAddress,$true)
$cleanListener.Start(8)
$appendLog.Invoke('START endpoint=AndroidSMA session='+$sessionId+' process='+$processName+' pid='+[Environment]::ProcessId+' uid='+$processUid+' bind='+$bindName+' developmentPort='+$port+' cleanPort='+$cleanPort+' auth=NONE root='+$root)

while($running){
$client=$null
$stream=$null
try{
while($running-and-not$listener.Pending()-and-not$cleanListener.Pending()){[Threading.Thread]::Sleep(20)}
if(-not$running){break}
if($listener.Pending()){$door='development';$client=$listener.AcceptTcpClient()}else{$door='clean';$client=$cleanListener.AcceptTcpClient()}
$client.NoDelay=$true
$client.ReceiveTimeout=300000
$client.SendTimeout=300000
$stream=$client.GetStream()
$hello='ASMA_REPL version=1 endpoint=AndroidSMA door='+$door+' session='+$sessionId+' process='+$processName+' pid='+[Environment]::ProcessId+' uid='+$processUid+' auth=NONE root='+$root
$writeFrame.Invoke($stream,0x8000,0,$utf8.GetBytes($hello))
$appendLog.Invoke('ATTACH session='+$sessionId+' door='+$door+' remote='+$client.Client.RemoteEndPoint)
$connected=$true
while($connected-and$running){
$frame=$readFrame.Invoke($stream)
$opcode=[uint16]$frame[0]
$requestId=[uint32]$frame[1]
$payload=[byte[]]$frame[2]
try{
if($opcode-eq1){$writeFrame.Invoke($stream,0x8001,$requestId,$payload);continue}
if($opcode-eq2){
if($payload.Length-gt1048576){throw 'COMMAND_TOO_LARGE'}
$execute.Invoke($utf8.GetString($payload),$requestId,$stream)
continue
}
if($opcode-eq3-or$opcode-eq4){
if($payload.Length-lt4){throw 'BAD_PUT_PAYLOAD'}
$pathLength=[BitConverter]::ToUInt32($payload,0)
if($pathLength-gt4096-or$pathLength+4-gt$payload.Length){throw 'BAD_PUT_PATH_LENGTH'}
$relative=$utf8.GetString($payload,4,[int]$pathLength)
$target=$resolveRemote.Invoke($relative)
$dataLength=$payload.Length-4-[int]$pathLength
$data=[byte[]]::new($dataLength)
if($dataLength-gt0){[Array]::Copy($payload,4+[int]$pathLength,$data,0,$dataLength)}
$temp=$target+'.new-'+[Guid]::NewGuid().ToString('N')
try{
if($opcode-eq3-and[IO.File]::Exists($target)){throw 'TARGET_EXISTS'}
[IO.File]::WriteAllBytes($temp,$data)
if($opcode-eq4-and[IO.File]::Exists($target)){
$backup=$target+'.bak-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
[IO.File]::Copy($target,$backup,$false)
}
[IO.File]::Move($temp,$target,$opcode-eq4)
$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data))
$writeFrame.Invoke($stream,0x8005,$requestId,$utf8.GetBytes('OK path='+$relative+' bytes='+$data.Length+' sha256='+$hash))
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('OK'))
$appendLog.Invoke('PUT id='+$requestId+' replace='+($opcode-eq4)+' path='+$relative+' bytes='+$data.Length+' sha256='+$hash)
}finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
continue
}
if($opcode-eq5){
$relative=$utf8.GetString($payload)
$target=$resolveRemote.Invoke($relative)
$data=[IO.File]::ReadAllBytes($target)
$writeFrame.Invoke($stream,0x8005,$requestId,$data)
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('OK'))
$appendLog.Invoke('GET id='+$requestId+' path='+$relative+' bytes='+$data.Length)
continue
}
if($opcode-eq6){
$relative=$utf8.GetString($payload)
$target=$resolveRemote.Invoke($relative)
$data=[IO.File]::ReadAllBytes($target)
$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($data))
$writeFrame.Invoke($stream,0x8005,$requestId,$utf8.GetBytes('path='+$relative+' bytes='+$data.Length+' sha256='+$hash))
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('OK'))
continue
}
if($opcode-eq7){
foreach($path in [IO.Directory]::EnumerateFiles($root,'*.ps1',[IO.SearchOption]::TopDirectoryOnly)){
$writeFrame.Invoke($stream,0x8005,$requestId,$utf8.GetBytes([IO.Path]::GetFileName($path)))
}
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('OK'))
continue
}
if($opcode-eq8){
$relative=$utf8.GetString($payload)
$target=$resolveRemote.Invoke($relative)
$execute.Invoke([IO.File]::ReadAllText($target,$utf8),$requestId,$stream)
continue
}
if($opcode-eq9){$writeFrame.Invoke($stream,0x8009,$requestId,$utf8.GetBytes('BYE'));$connected=$false;continue}
if($opcode-eq10){$writeFrame.Invoke($stream,0x8009,$requestId,$utf8.GetBytes('STOPPED'));$connected=$false;$running=$false;continue}
$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes('UNKNOWN_OPCODE '+$opcode))
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('ERROR'))
}catch{
$failure=$_.Exception
while($null-ne$failure.InnerException){$failure=$failure.InnerException}
$writeFrame.Invoke($stream,0x8003,$requestId,$utf8.GetBytes($failure.GetType().FullName+[char]0+$failure.Message))
$writeFrame.Invoke($stream,0x8004,$requestId,$utf8.GetBytes('ERROR'))
$appendLog.Invoke('REQUEST id='+$requestId+' opcode='+$opcode+' status=ERROR type='+$_.Exception.GetType().FullName+' message='+$_.Exception.Message)
}
}
}catch{
$appendLog.Invoke('CLIENT status=ERROR type='+$_.Exception.GetType().FullName+' message='+$_.Exception.Message)
}finally{
if($null-ne$stream){try{$stream.Dispose()}catch{}}
if($null-ne$client){try{$client.Dispose()}catch{}}
$appendLog.Invoke('DETACH session='+$sessionId)
}
}
}finally{
if($null-ne$listener){try{$listener.Stop()}catch{}}
if($null-ne$cleanListener){try{$cleanListener.Stop()}catch{}}
if($null-ne$httpCancellation){try{$httpCancellation.Cancel()}catch{}}
if($null-ne$httpAsync){try{if($httpAsync.AsyncWaitHandle.WaitOne(3000)){[void]$httpPowerShell.EndInvoke($httpAsync)}else{$httpPowerShell.Stop()}}catch{};try{$httpAsync.AsyncWaitHandle.Close()}catch{}}
if($null-ne$httpPowerShell){try{$httpPowerShell.Dispose()}catch{}}
if($null-ne$httpRunspace){try{$httpRunspace.Dispose()}catch{}}
if($null-ne$httpCancellation){try{$httpCancellation.Dispose()}catch{}}
if($null-ne$runspace){try{$runspace.Dispose()}catch{}}
$appendLog.Invoke('STOP')
$global:AndroidSmaReplActive=$false
}
return
}

$tcp=$null
$stream=$null
$requestId=[uint32]0
try{
$tcp=[Net.Sockets.TcpClient]::new()
$tcp.NoDelay=$true
$tcp.ReceiveTimeout=300000
$tcp.SendTimeout=300000
$tcp.Connect($hostName,$port)
$stream=$tcp.GetStream()
$hello=$readFrame.Invoke($stream)
if([uint16]$hello[0]-ne0x8000){throw 'HELLO_REQUIRED'}
$sessionHello=$utf8.GetString([byte[]]$hello[2])
if(-not$cleanClient){[Console]::WriteLine($sessionHello)}
$remotePrompt='PS (AndroidSMA)Home:> '

$receiveUntilDone=[Action[uint32,string]]{
param([uint32]$id,[string]$writePath)
$complete=$false
$sawError=$false
while(-not$complete){
$response=$readFrame.Invoke($stream)
$responseOpcode=[uint16]$response[0]
$responseId=[uint32]$response[1]
$responsePayload=[byte[]]$response[2]
if($responseId-ne$id){throw 'RESPONSE_ID_MISMATCH'}
if($responseOpcode-eq0x8002){[Console]::WriteLine($utf8.GetString($responsePayload));continue}
if($responseOpcode-eq0x8003){
$sawError=$true
$errorText=$utf8.GetString($responsePayload)
$separator=$errorText.IndexOf([char]0)
if($separator-ge0){$errorType=$errorText.Substring(0,$separator);$errorMessage=$errorText.Substring($separator+1);if($cleanClient){$errorText=$errorMessage}else{$errorText=$errorType+': '+$errorMessage}}
[Console]::Error.WriteLine($errorText)
continue
}
if($responseOpcode-eq0x8005){
if($writePath){[IO.File]::WriteAllBytes($writePath,$responsePayload);[Console]::WriteLine('WROTE '+$writePath+' '+$responsePayload.Length+' bytes');$writePath=$null}else{[Console]::WriteLine($utf8.GetString($responsePayload))}
continue
}
if($responseOpcode-eq0x8004){$doneText=$utf8.GetString($responsePayload);if($cleanClient){if($doneText-ne'OK'-and-not$sawError){[Console]::Error.WriteLine($doneText)}}else{[Console]::WriteLine('[request='+$id+' status='+$doneText+']')};$complete=$true;continue}
if($responseOpcode-eq0x8009){[Console]::WriteLine($utf8.GetString($responsePayload));$complete=$true;continue}
throw 'UNEXPECTED_RESPONSE_OPCODE '+$responseOpcode
}
}

$interactive=$true
while($interactive){
[Console]::Write($remotePrompt)
$line=[Console]::ReadLine()
if($null-eq$line){$line='.exit'}
$requestId++
if($line-eq'.exit'){$writeFrame.Invoke($stream,9,$requestId,[byte[]]::new(0));$receiveUntilDone.Invoke($requestId,$null);$interactive=$false;continue}
if($line-eq'.stop'){$writeFrame.Invoke($stream,10,$requestId,[byte[]]::new(0));$receiveUntilDone.Invoke($requestId,$null);$interactive=$false;continue}
if($line-eq'.session'){[Console]::WriteLine($sessionHello);continue}
if($line-eq'.ping'){$payload=$utf8.GetBytes([DateTime]::UtcNow.ToString('o'));$writeFrame.Invoke($stream,1,$requestId,$payload);$response=$readFrame.Invoke($stream);[Console]::WriteLine($utf8.GetString([byte[]]$response[2]));continue}
if($line-eq'.list'){$writeFrame.Invoke($stream,7,$requestId,[byte[]]::new(0));$receiveUntilDone.Invoke($requestId,$null);continue}
if($line.StartsWith('.hash ',[StringComparison]::Ordinal)){$writeFrame.Invoke($stream,6,$requestId,$utf8.GetBytes($line.Substring(6)));$receiveUntilDone.Invoke($requestId,$null);continue}
if($line.StartsWith('.run ',[StringComparison]::Ordinal)){$writeFrame.Invoke($stream,8,$requestId,$utf8.GetBytes($line.Substring(5)));$receiveUntilDone.Invoke($requestId,$null);continue}
if($line.StartsWith('.get ',[StringComparison]::Ordinal)){
$parts=$line.Substring(5).Split([char[]]@(' '),2,[StringSplitOptions]::RemoveEmptyEntries)
if($parts.Length-ne2){[Console]::Error.WriteLine('usage: .get remote.ps1 local.ps1');continue}
$writeFrame.Invoke($stream,5,$requestId,$utf8.GetBytes($parts[0]));$receiveUntilDone.Invoke($requestId,[IO.Path]::GetFullPath($parts[1]));continue
}
if($line.StartsWith('.putnew ',[StringComparison]::Ordinal)-or$line.StartsWith('.put ',[StringComparison]::Ordinal)){
$replace=$line.StartsWith('.put ',[StringComparison]::Ordinal)
$offset=if($replace){5}else{8}
$parts=$line.Substring($offset).Split([char[]]@(' '),2,[StringSplitOptions]::RemoveEmptyEntries)
if($parts.Length-ne2){[Console]::Error.WriteLine('usage: .putnew local.ps1 remote.ps1 | .put local.ps1 remote.ps1');continue}
$local=[IO.Path]::GetFullPath($parts[0])
$remoteBytes=$utf8.GetBytes($parts[1])
$fileBytes=[IO.File]::ReadAllBytes($local)
$payload=[byte[]]::new(4+$remoteBytes.Length+$fileBytes.Length)
[Array]::Copy([BitConverter]::GetBytes([uint32]$remoteBytes.Length),0,$payload,0,4)
[Array]::Copy($remoteBytes,0,$payload,4,$remoteBytes.Length)
[Array]::Copy($fileBytes,0,$payload,4+$remoteBytes.Length,$fileBytes.Length)
$writeFrame.Invoke($stream,($(if($replace){4}else{3})),$requestId,$payload)
$receiveUntilDone.Invoke($requestId,$null)
continue
}
if($line-eq'.begin'){
$builder=[Text.StringBuilder]::new()
while($true){[Console]::Write('....> ');$next=[Console]::ReadLine();if($null-eq$next-or$next-eq'.end'){break};[void]$builder.AppendLine($next)}
$line=$builder.ToString()
}
$commandBuilder=[Text.StringBuilder]::new($line)
while($true){
$parseTokens=$null
$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseInput($commandBuilder.ToString(),[ref]$parseTokens,[ref]$parseErrors)
$incomplete=$false
foreach($parseError in $parseErrors){if($parseError.IncompleteInput){$incomplete=$true;break}}
if(-not$incomplete){break}
[Console]::Write('>> ')
$next=[Console]::ReadLine()
if($null-eq$next){break}
[void]$commandBuilder.AppendLine()
[void]$commandBuilder.Append($next)
}
$line=$commandBuilder.ToString()
$writeFrame.Invoke($stream,2,$requestId,$utf8.GetBytes($line))
$receiveUntilDone.Invoke($requestId,$null)
}
}finally{
if($null-ne$stream){try{$stream.Dispose()}catch{}}
if($null-ne$tcp){try{$tcp.Dispose()}catch{}}
}
