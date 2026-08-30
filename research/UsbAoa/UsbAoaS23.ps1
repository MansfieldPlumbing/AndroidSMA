$ErrorActionPreference='Stop'
$receipt='/data/user/0/dev.mansfieldplumbing.androidsma/files/UsbAoaS23-Gate0.log'
$utf8=[Text.UTF8Encoding]::new($false)
$lines=[Collections.Generic.List[string]]::new()
$lines.Add('UTC='+[DateTime]::UtcNow.ToString('o'))
$lines.Add('GATE=0')
$lines.Add('BUILD=NO')
$lines.Add('JNI=NO')
$lines.Add('BINDER_SERVICE=usb')
[IO.File]::WriteAllText($receipt,"UTC=$([DateTime]::UtcNow.ToString('o'))`nGATE=0`nSTAGE=SCRIPT_ENTERED`n",$utf8)
$binder=[IntPtr]::Zero
$parcelIn=[IntPtr]::Zero
$parcelOut=[IntPtr]::Zero
$statusHeader=[IntPtr]::Zero
$permissionIn=[IntPtr]::Zero
$permissionOut=[IntPtr]::Zero
$permissionStatusHeader=[IntPtr]::Zero

try{
$suffix=[Guid]::NewGuid().ToString('N')
$assembly=[Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly([Reflection.AssemblyName]::new('UsbAoaS23.'+$suffix),[Reflection.Emit.AssemblyBuilderAccess]::Run)
$module=$assembly.DefineDynamicModule('UsbAoaS23.'+$suffix)
$type=$module.DefineType('UsbAoaS23.Native.'+$suffix,[Reflection.TypeAttributes]'Public,Abstract,Sealed')
$flags=[Reflection.MethodAttributes]'Public,Static,PinvokeImpl'
$calling=[Runtime.InteropServices.CallingConvention]::Cdecl
$standard=[Reflection.CallingConventions]::Standard
$none=[Runtime.InteropServices.CharSet]::None
$ansi=[Runtime.InteropServices.CharSet]::Ansi

$method=$type.DefinePInvokeMethod('AServiceManager_getService','libbinder_ndk.so','AServiceManager_getService',$flags,$standard,[IntPtr],[Type[]]@([string]),$calling,$ansi)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AIBinder_Class_define','libbinder_ndk.so','AIBinder_Class_define',$flags,$standard,[IntPtr],[Type[]]@([string],[IntPtr],[IntPtr],[IntPtr]),$calling,$ansi)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AIBinder_associateClass','libbinder_ndk.so','AIBinder_associateClass',$flags,$standard,[byte],[Type[]]@([IntPtr],[IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AIBinder_prepareTransaction','libbinder_ndk.so','AIBinder_prepareTransaction',$flags,$standard,[int32],[Type[]]@([IntPtr],[IntPtr].MakeByRefType()),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AIBinder_transact','libbinder_ndk.so','AIBinder_transact',$flags,$standard,[int32],[Type[]]@([IntPtr],[uint32],[IntPtr].MakeByRefType(),[IntPtr].MakeByRefType(),[uint32]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_readStatusHeader','libbinder_ndk.so','AParcel_readStatusHeader',$flags,$standard,[int32],[Type[]]@([IntPtr],[IntPtr].MakeByRefType()),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AStatus_getExceptionCode','libbinder_ndk.so','AStatus_getExceptionCode',$flags,$standard,[int32],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_readInt32','libbinder_ndk.so','AParcel_readInt32',$flags,$standard,[int32],[Type[]]@([IntPtr],[int32].MakeByRefType()),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_getDataPosition','libbinder_ndk.so','AParcel_getDataPosition',$flags,$standard,[int32],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_getDataSize','libbinder_ndk.so','AParcel_getDataSize',$flags,$standard,[int32],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_appendFrom','libbinder_ndk.so','AParcel_appendFrom',$flags,$standard,[int32],[Type[]]@([IntPtr],[IntPtr],[int32],[int32]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AStatus_delete','libbinder_ndk.so','AStatus_delete',$flags,$standard,[void],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AParcel_delete','libbinder_ndk.so','AParcel_delete',$flags,$standard,[void],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$method=$type.DefinePInvokeMethod('AIBinder_decStrong','libbinder_ndk.so','AIBinder_decStrong',$flags,$standard,[void],[Type[]]@([IntPtr]),$calling,$none)
$method.SetImplementationFlags([Reflection.MethodImplAttributes]::PreserveSig)
$native=$type.CreateType()
[IO.File]::AppendAllText($receipt,"STAGE=NATIVE_TYPE_CREATED`n",$utf8)

$attributeConstructor=[Runtime.InteropServices.UnmanagedFunctionPointerAttribute].GetConstructor([Type[]]@([Runtime.InteropServices.CallingConvention]))
$attribute=[Reflection.Emit.CustomAttributeBuilder]::new($attributeConstructor,[object[]]@([Runtime.InteropServices.CallingConvention]::Cdecl))

$createBuilder=$module.DefineType('UsbAoaS23.Create.'+$suffix,[Reflection.TypeAttributes]'Class,Public,Sealed',[MulticastDelegate])
$createBuilder.SetCustomAttribute($attribute)
$constructor=$createBuilder.DefineConstructor([Reflection.MethodAttributes]'Public,HideBySig,RTSpecialName',[Reflection.CallingConventions]::Standard,[Type[]]@([object],[IntPtr]))
$constructor.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$invoke=$createBuilder.DefineMethod('Invoke',[Reflection.MethodAttributes]'Public,HideBySig,NewSlot,Virtual',[IntPtr],[Type[]]@([IntPtr]))
$invoke.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$createDelegateType=$createBuilder.CreateType()

$destroyBuilder=$module.DefineType('UsbAoaS23.Destroy.'+$suffix,[Reflection.TypeAttributes]'Class,Public,Sealed',[MulticastDelegate])
$destroyBuilder.SetCustomAttribute($attribute)
$constructor=$destroyBuilder.DefineConstructor([Reflection.MethodAttributes]'Public,HideBySig,RTSpecialName',[Reflection.CallingConventions]::Standard,[Type[]]@([object],[IntPtr]))
$constructor.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$invoke=$destroyBuilder.DefineMethod('Invoke',[Reflection.MethodAttributes]'Public,HideBySig,NewSlot,Virtual',[void],[Type[]]@([IntPtr]))
$invoke.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$destroyDelegateType=$destroyBuilder.CreateType()

$transactBuilder=$module.DefineType('UsbAoaS23.Transact.'+$suffix,[Reflection.TypeAttributes]'Class,Public,Sealed',[MulticastDelegate])
$transactBuilder.SetCustomAttribute($attribute)
$constructor=$transactBuilder.DefineConstructor([Reflection.MethodAttributes]'Public,HideBySig,RTSpecialName',[Reflection.CallingConventions]::Standard,[Type[]]@([object],[IntPtr]))
$constructor.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$invoke=$transactBuilder.DefineMethod('Invoke',[Reflection.MethodAttributes]'Public,HideBySig,NewSlot,Virtual',[int32],[Type[]]@([IntPtr],[uint32],[IntPtr],[IntPtr]))
$invoke.SetImplementationFlags([Reflection.MethodImplAttributes]'Runtime,Managed')
$transactDelegateType=$transactBuilder.CreateType()

$onCreate=[Management.Automation.LanguagePrimitives]::ConvertTo({param([IntPtr]$args)[IntPtr]::Zero},$createDelegateType)
$onDestroy=[Management.Automation.LanguagePrimitives]::ConvertTo({param([IntPtr]$data)},$destroyDelegateType)
$onTransact=[Management.Automation.LanguagePrimitives]::ConvertTo({param([IntPtr]$binder,[uint32]$code,[IntPtr]$input,[IntPtr]$output)-32},$transactDelegateType)
$onCreatePointer=[Runtime.InteropServices.Marshal]::GetFunctionPointerForDelegate($onCreate)
$onDestroyPointer=[Runtime.InteropServices.Marshal]::GetFunctionPointerForDelegate($onDestroy)
$onTransactPointer=[Runtime.InteropServices.Marshal]::GetFunctionPointerForDelegate($onTransact)

$class=$native::AIBinder_Class_define('android.hardware.usb.IUsbManager',$onCreatePointer,$onDestroyPointer,$onTransactPointer)
[IO.File]::AppendAllText($receipt,"STAGE=CLASS_DEFINE_RETURNED`n",$utf8)
$lines.Add('CLASS_DEFINED='+($class-ne[IntPtr]::Zero))
if($class-eq[IntPtr]::Zero){throw 'AIBinder_Class_define returned null'}

$binder=$native::AServiceManager_getService('usb')
[IO.File]::AppendAllText($receipt,"STAGE=GET_SERVICE_RETURNED`n",$utf8)
$lines.Add('SERVICE_ACQUIRED='+($binder-ne[IntPtr]::Zero))
if($binder-eq[IntPtr]::Zero){throw 'AServiceManager_getService returned null'}

$associated=$native::AIBinder_associateClass($binder,$class)
[IO.File]::AppendAllText($receipt,"STAGE=ASSOCIATE_RETURNED`n",$utf8)
$lines.Add('CLASS_ASSOCIATED='+$associated)
if($associated-eq0){throw 'AIBinder_associateClass returned false'}

$prepare=$native::AIBinder_prepareTransaction($binder,[ref]$parcelIn)
[IO.File]::AppendAllText($receipt,"STAGE=PREPARE_RETURNED STATUS=$prepare`n",$utf8)
$lines.Add('PREPARE_STATUS='+$prepare)
if($prepare-ne0){throw 'AIBinder_prepareTransaction failed: '+$prepare}

$transactionCode=3
$transaction=$native::AIBinder_transact($binder,$transactionCode,[ref]$parcelIn,[ref]$parcelOut,0)
[IO.File]::AppendAllText($receipt,"STAGE=TRANSACT_RETURNED STATUS=$transaction`n",$utf8)
$lines.Add('TRANSACTION_CODE='+$transactionCode)
$lines.Add('TRANSACTION_STATUS='+$transaction)
if($transaction-ne0){throw 'AIBinder_transact failed: '+$transaction}

$readStatus=$native::AParcel_readStatusHeader($parcelOut,[ref]$statusHeader)
[IO.File]::AppendAllText($receipt,"STAGE=STATUS_HEADER_RETURNED STATUS=$readStatus`n",$utf8)
$lines.Add('STATUS_HEADER_READ='+$readStatus)
if($readStatus-ne0){throw 'AParcel_readStatusHeader failed: '+$readStatus}
$exception=$native::AStatus_getExceptionCode($statusHeader)
$lines.Add('BINDER_EXCEPTION='+$exception)
if($exception-ne0){throw 'Binder exception: '+$exception}

$accessoryStart=$native::AParcel_getDataPosition($parcelOut)
$present=0
$readPresent=$native::AParcel_readInt32($parcelOut,[ref]$present)
$lines.Add('PRESENCE_READ_STATUS='+$readPresent)
$lines.Add('ACCESSORY_PRESENT_MARKER='+$present)
if($readPresent-ne0){throw 'AParcel_readInt32 failed: '+$readPresent}
if($present-ne1){throw 'No current accessory'}

$accessoryEnd=$native::AParcel_getDataSize($parcelOut)
$accessorySize=$accessoryEnd-$accessoryStart
$lines.Add('ACCESSORY_PARCEL_START='+$accessoryStart)
$lines.Add('ACCESSORY_PARCEL_SIZE='+$accessorySize)
if($accessorySize-le4){throw 'Accessory parcel payload is too small'}

$permissionPrepare=$native::AIBinder_prepareTransaction($binder,[ref]$permissionIn)
$lines.Add('PERMISSION_PREPARE_STATUS='+$permissionPrepare)
if($permissionPrepare-ne0){throw 'Permission AIBinder_prepareTransaction failed: '+$permissionPrepare}

$append=$native::AParcel_appendFrom($parcelOut,$permissionIn,$accessoryStart,$accessorySize)
$lines.Add('ACCESSORY_APPEND_STATUS='+$append)
if($append-ne0){throw 'AParcel_appendFrom failed: '+$append}

$permissionTransactionCode=19
$permissionTransaction=$native::AIBinder_transact($binder,$permissionTransactionCode,[ref]$permissionIn,[ref]$permissionOut,0)
$lines.Add('PERMISSION_TRANSACTION_CODE='+$permissionTransactionCode)
$lines.Add('PERMISSION_TRANSACTION_STATUS='+$permissionTransaction)
if($permissionTransaction-ne0){throw 'Permission AIBinder_transact failed: '+$permissionTransaction}

$permissionReadStatus=$native::AParcel_readStatusHeader($permissionOut,[ref]$permissionStatusHeader)
$lines.Add('PERMISSION_STATUS_HEADER_READ='+$permissionReadStatus)
if($permissionReadStatus-ne0){throw 'Permission AParcel_readStatusHeader failed: '+$permissionReadStatus}
$permissionException=$native::AStatus_getExceptionCode($permissionStatusHeader)
$lines.Add('PERMISSION_BINDER_EXCEPTION='+$permissionException)
if($permissionException-ne0){throw 'Permission Binder exception: '+$permissionException}

$permission=0
$permissionRead=$native::AParcel_readInt32($permissionOut,[ref]$permission)
$lines.Add('PERMISSION_READ_STATUS='+$permissionRead)
$lines.Add('HAS_ACCESSORY_PERMISSION='+$permission)
if($permissionRead-ne0){throw 'Permission AParcel_readInt32 failed: '+$permissionRead}

$lines.Add('RESULT=OBSERVED_ACCESSORY_AND_PERMISSION_REPLIES')
$lines.Add('STOP=REQUEST_ACCESSORY_PERMISSION_RESULT_TOKEN_NOT_IMPLEMENTED')
}catch{
$lines.Add('RESULT=FAIL')
$lines.Add('ERROR_TYPE='+$_.Exception.GetType().FullName)
$lines.Add('ERROR='+$_.Exception.Message)
}finally{
if($statusHeader-ne[IntPtr]::Zero){$native::AStatus_delete($statusHeader)}
if($permissionStatusHeader-ne[IntPtr]::Zero){$native::AStatus_delete($permissionStatusHeader)}
if($permissionOut-ne[IntPtr]::Zero){$native::AParcel_delete($permissionOut)}
if($permissionIn-ne[IntPtr]::Zero){$native::AParcel_delete($permissionIn)}
if($parcelOut-ne[IntPtr]::Zero){$native::AParcel_delete($parcelOut)}
if($parcelIn-ne[IntPtr]::Zero){$native::AParcel_delete($parcelIn)}
if($binder-ne[IntPtr]::Zero){$native::AIBinder_decStrong($binder)}
$lines.Add('UTC_END='+[DateTime]::UtcNow.ToString('o'))
[IO.File]::WriteAllLines($receipt,$lines,$utf8)
}
