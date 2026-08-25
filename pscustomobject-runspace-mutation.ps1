using namespace System
using namespace System.Collections.Concurrent
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Runtime.CompilerServices
using namespace System.Threading

function Invoke-PSCustomObjectRunspaceMutationReceipt {
    param(
        [Parameter(Mandatory)][Android.Views.SurfaceView] $SurfaceView,
        [Parameter(Mandatory)][Android.OS.IBinder] $ReplacementAndroidObject
    )

    [object] $sentinelA1 = [object]::new()
    [object] $sentinelB2 = [object]::new()
    [object] $sentinelA3 = [object]::new()
    [object] $sentinelFromB = [object]::new()
    [object] $sentinelFromA = [object]::new()
    [object] $sentinelListA1 = [object]::new()
    [object] $sentinelListB2 = [object]::new()
    [object] $sentinelListA3 = [object]::new()

    [List[object]] $sharedList = [List[object]]::new()
    $shared = [pscustomobject]@{
        Version = 0
        Value = $null
        Child = $SurfaceView
        List = $sharedList
    }

    [ConcurrentDictionary[string,object]] $observations =
        [ConcurrentDictionary[string,object]]::new()
    [ManualResetEventSlim] $ownerStepOneComplete = [ManualResetEventSlim]::new($false)
    [ManualResetEventSlim] $childStepTwoComplete = [ManualResetEventSlim]::new($false)
    [ManualResetEventSlim] $ownerStepThreeComplete = [ManualResetEventSlim]::new($false)

    [InitialSessionState] $initial = [InitialSessionState]::Create()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::ReuseThread
    [Runspace] $childRunspace = [RunspaceFactory]::CreateRunspace($initial)
    $childRunspace.Open()

    $variables = [ordered]@{
        Shared = $shared
        SharedList = $sharedList
        SurfaceView = $SurfaceView
        ReplacementAndroidObject = $ReplacementAndroidObject
        SentinelA1 = $sentinelA1
        SentinelB2 = $sentinelB2
        SentinelA3 = $sentinelA3
        SentinelFromB = $sentinelFromB
        SentinelFromA = $sentinelFromA
        SentinelListA1 = $sentinelListA1
        SentinelListB2 = $sentinelListB2
        SentinelListA3 = $sentinelListA3
        Observations = $observations
        OwnerStepOneComplete = $ownerStepOneComplete
        ChildStepTwoComplete = $childStepTwoComplete
        OwnerStepThreeComplete = $ownerStepThreeComplete
    }
    foreach ($entry in $variables.GetEnumerator()) {
        $childRunspace.SessionStateProxy.SetVariable($entry.Key, $entry.Value)
    }

    [string] $childSource = @'
using namespace System
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Runtime.CompilerServices

function Set-ChildWrapperObservation {
    param([Parameter(Mandatory)][string] $Prefix)
    [PSObject] $wrapper = [PSObject]::AsPSObject($Shared)
    [object] $baseObject = $wrapper.BaseObject
    $Observations["${Prefix}ThreadId"] = [Android.OS.Process]::MyTid()
    $Observations["${Prefix}RunspaceIdentity"] = [RuntimeHelpers]::GetHashCode([Runspace]::DefaultRunspace)
    $Observations["${Prefix}WrapperIdentity"] = [RuntimeHelpers]::GetHashCode($wrapper)
    if ($Prefix -eq 'ChildStepOne') {
        $Observations['ChildStepOneWrapperReference'] = $wrapper
        $Observations['ChildStepOneSharedReference'] = $Shared
    }
    $Observations["${Prefix}BaseObjectPresent"] = $null -ne $baseObject
    $Observations["${Prefix}BaseObjectType"] = if ($null -eq $baseObject) { '<null>' } else { $baseObject.GetType().FullName }
    $Observations["${Prefix}BaseObjectIdentity"] = if ($null -eq $baseObject) { 0 } else { [RuntimeHelpers]::GetHashCode($baseObject) }
    [string[]] $propertyNames = @($Shared.PSObject.Properties.Name)
    [Array]::Sort($propertyNames)
    $Observations["${Prefix}PropertyNames"] = [string]::Join(',', $propertyNames)
}

try {
    $Observations['ChildWaitedForOwnerStepOne'] = $OwnerStepOneComplete.Wait(10000)
    Set-ChildWrapperObservation -Prefix 'ChildStepOne'
    $Observations['ChildStepOneVersion'] = $Shared.Version
    $Observations['ChildStepOneValueReferenceEqual'] = [object]::ReferenceEquals($Shared.Value, $SentinelA1)
    $Observations['ChildStepOneChildReferenceEqual'] = [object]::ReferenceEquals($Shared.Child, $SurfaceView)
    $Observations['ChildStepOneListReferenceEqual'] = [object]::ReferenceEquals($Shared.List, $SharedList)
    $Observations['ChildStepOneListContainsOwnerSentinel'] = $Shared.List.Contains($SentinelListA1)

    $Shared.Version = 2
    $Shared.Value = $SentinelB2
    $Shared.Child = $ReplacementAndroidObject
    $Shared.List.Add($SentinelListB2)
    $Shared.PSObject.Properties.Add([PSNoteProperty]::new('FromB', $SentinelFromB))
    Set-ChildWrapperObservation -Prefix 'ChildStepTwo'
    $ChildStepTwoComplete.Set()

    $Observations['ChildWaitedForOwnerStepThree'] = $OwnerStepThreeComplete.Wait(10000)
    Set-ChildWrapperObservation -Prefix 'ChildStepThree'
    $Observations['ChildStepThreeVersion'] = $Shared.Version
    $Observations['ChildStepThreeValueReferenceEqual'] = [object]::ReferenceEquals($Shared.Value, $SentinelA3)
    $Observations['ChildStepThreeFromBPresent'] = $null -ne $Shared.PSObject.Properties['FromB']
    $Observations['ChildStepThreeFromAPresent'] = $null -ne $Shared.PSObject.Properties['FromA']
    $Observations['ChildStepThreeFromAReferenceEqual'] =
        $null -ne $Shared.PSObject.Properties['FromA'] -and
        [object]::ReferenceEquals($Shared.FromA, $SentinelFromA)
    $Observations['ChildStepThreeChildReferenceEqual'] = [object]::ReferenceEquals($Shared.Child, $SurfaceView)
    $Observations['ChildStepThreeListReferenceEqual'] = [object]::ReferenceEquals($Shared.List, $SharedList)
    $Observations['ChildStepThreeListContainsOwnerOne'] = $Shared.List.Contains($SentinelListA1)
    $Observations['ChildStepThreeListContainsChildTwo'] = $Shared.List.Contains($SentinelListB2)
    $Observations['ChildStepThreeListContainsOwnerThree'] = $Shared.List.Contains($SentinelListA3)
}
catch {
    $Observations['ChildFailureType'] = $_.Exception.GetType().FullName
    $Observations['ChildFailureMessage'] = $_.Exception.Message
    $ChildStepTwoComplete.Set()
}
'@

    [PowerShell] $childPowerShell = [PowerShell]::Create()
    $childPowerShell.Runspace = $childRunspace
    [void]$childPowerShell.AddScript($childSource, $false)
    [IAsyncResult] $childAsync = $childPowerShell.BeginInvoke()

    try {
        [PSObject] $ownerWrapperStepOne = [PSObject]::AsPSObject($shared)
        $observations['OwnerRunspaceIdentity'] = [RuntimeHelpers]::GetHashCode([Runspace]::DefaultRunspace)
        $observations['ChildRunspaceIdentity'] = [RuntimeHelpers]::GetHashCode($childRunspace)
        $observations['OwnerStepOneThreadId'] = [Android.OS.Process]::MyTid()
        $observations['OwnerStepOneWrapperIdentity'] = [RuntimeHelpers]::GetHashCode($ownerWrapperStepOne)
        $observations['OwnerStepOneBaseObjectIdentity'] = [RuntimeHelpers]::GetHashCode($ownerWrapperStepOne.BaseObject)
        [Java.Interop.IJavaPeerable] $surfacePeer = $SurfaceView
        [Java.Interop.IJavaPeerable] $replacementPeer = $ReplacementAndroidObject
        $observations['SurfaceViewManagedIdentity'] = [RuntimeHelpers]::GetHashCode($SurfaceView)
        $observations['SurfaceViewJniIdentity'] = $surfacePeer.JniIdentityHashCode
        $observations['SurfaceViewPeerHandle'] = $surfacePeer.PeerReference.Handle.ToInt64()
        $observations['ReplacementAndroidObjectType'] = $ReplacementAndroidObject.GetType().FullName
        $observations['ReplacementAndroidObjectManagedIdentity'] = [RuntimeHelpers]::GetHashCode($ReplacementAndroidObject)
        $observations['ReplacementAndroidObjectJniIdentity'] = $replacementPeer.JniIdentityHashCode
        $observations['ReplacementAndroidObjectPeerHandle'] = $replacementPeer.PeerReference.Handle.ToInt64()
        $shared.Version = 1
        $shared.Value = $sentinelA1
        $shared.List.Add($sentinelListA1)
        [string[]] $ownerStepOnePropertyNames = @($shared.PSObject.Properties.Name)
        [Array]::Sort($ownerStepOnePropertyNames)
        $observations['OwnerStepOnePropertyNames'] = [string]::Join(',', $ownerStepOnePropertyNames)
        $ownerStepOneComplete.Set()

        $observations['OwnerWaitedForChildStepTwo'] = $childStepTwoComplete.Wait(10000)
        [PSObject] $ownerWrapperStepTwo = [PSObject]::AsPSObject($shared)
        $observations['OwnerStepTwoThreadId'] = [Android.OS.Process]::MyTid()
        $observations['OwnerStepTwoWrapperIdentity'] = [RuntimeHelpers]::GetHashCode($ownerWrapperStepTwo)
        $observations['OwnerStepTwoBaseObjectIdentity'] = [RuntimeHelpers]::GetHashCode($ownerWrapperStepTwo.BaseObject)
        $observations['OwnerChildWrapperReferenceEqual'] =
            [object]::ReferenceEquals($ownerWrapperStepOne, $observations['ChildStepOneWrapperReference'])
        $observations['OwnerChildSharedReferenceEqual'] =
            [object]::ReferenceEquals($shared, $observations['ChildStepOneSharedReference'])
        [string[]] $ownerStepTwoPropertyNames = @($shared.PSObject.Properties.Name)
        [Array]::Sort($ownerStepTwoPropertyNames)
        $observations['OwnerStepTwoPropertyNames'] = [string]::Join(',', $ownerStepTwoPropertyNames)
        $observations['OwnerStepTwoVersion'] = $shared.Version
        $observations['OwnerStepTwoValueReferenceEqual'] = [object]::ReferenceEquals($shared.Value, $sentinelB2)
        $observations['OwnerStepTwoFromBPresent'] = $null -ne $shared.PSObject.Properties['FromB']
        $observations['OwnerStepTwoFromBReferenceEqual'] =
            $null -ne $shared.PSObject.Properties['FromB'] -and
            [object]::ReferenceEquals($shared.FromB, $sentinelFromB)
        $observations['OwnerStepTwoChildReferenceEqual'] = [object]::ReferenceEquals($shared.Child, $ReplacementAndroidObject)
        $observations['OwnerStepTwoListReferenceEqual'] = [object]::ReferenceEquals($shared.List, $sharedList)
        $observations['OwnerStepTwoListContainsOwnerOne'] = $shared.List.Contains($sentinelListA1)
        $observations['OwnerStepTwoListContainsChildTwo'] = $shared.List.Contains($sentinelListB2)

        $shared.PSObject.Properties.Remove('FromB')
        $shared.PSObject.Properties.Add([PSNoteProperty]::new('FromA', $sentinelFromA))
        $shared.Version = 3
        $shared.Value = $sentinelA3
        $shared.Child = $SurfaceView
        $shared.List.Add($sentinelListA3)
        [string[]] $ownerStepThreePropertyNames = @($shared.PSObject.Properties.Name)
        [Array]::Sort($ownerStepThreePropertyNames)
        $observations['OwnerStepThreePropertyNames'] = [string]::Join(',', $ownerStepThreePropertyNames)
        $ownerStepThreeComplete.Set()

        if (-not $childAsync.AsyncWaitHandle.WaitOne(10000)) {
            $observations['ChildCompletionTimedOut'] = $true
            $childPowerShell.Stop()
        }
        else {
            [void]$childPowerShell.EndInvoke($childAsync)
            $observations['ChildCompletionTimedOut'] = $false
        }
        if ($childPowerShell.HadErrors) {
            $observations['ChildPowerShellError'] = [string]$childPowerShell.Streams.Error[0]
        }

        [bool] $scalarMutationPassed =
            $observations['ChildStepOneVersion'] -eq 1 -and
            $observations['ChildStepOneValueReferenceEqual'] -eq $true -and
            $observations['OwnerStepTwoVersion'] -eq 2 -and
            $observations['OwnerStepTwoValueReferenceEqual'] -eq $true -and
            $observations['ChildStepThreeVersion'] -eq 3 -and
            $observations['ChildStepThreeValueReferenceEqual'] -eq $true
        [bool] $propertyStructurePassed =
            $observations['OwnerStepTwoFromBPresent'] -eq $true -and
            $observations['OwnerStepTwoFromBReferenceEqual'] -eq $true -and
            $observations['ChildStepThreeFromBPresent'] -eq $false -and
            $observations['ChildStepThreeFromAPresent'] -eq $true -and
            $observations['ChildStepThreeFromAReferenceEqual'] -eq $true
        [bool] $nestedAndroidReplacementPassed =
            $observations['ChildStepOneChildReferenceEqual'] -eq $true -and
            $observations['OwnerStepTwoChildReferenceEqual'] -eq $true -and
            $observations['ChildStepThreeChildReferenceEqual'] -eq $true
        [bool] $nestedClrListPassed =
            $observations['ChildStepOneListReferenceEqual'] -eq $true -and
            $observations['ChildStepOneListContainsOwnerSentinel'] -eq $true -and
            $observations['OwnerStepTwoListReferenceEqual'] -eq $true -and
            $observations['OwnerStepTwoListContainsOwnerOne'] -eq $true -and
            $observations['OwnerStepTwoListContainsChildTwo'] -eq $true -and
            $observations['ChildStepThreeListReferenceEqual'] -eq $true -and
            $observations['ChildStepThreeListContainsOwnerOne'] -eq $true -and
            $observations['ChildStepThreeListContainsChildTwo'] -eq $true -and
            $observations['ChildStepThreeListContainsOwnerThree'] -eq $true

        $receipt = [pscustomobject]@{
            CompletedAt = [DateTimeOffset]::UtcNow
            OwnerPid = [Android.OS.Process]::MyPid()
            OwnerTid = [Android.OS.Process]::MyTid()
            OwnerRunspace = [Runspace]::DefaultRunspace
            ChildRunspace = $childRunspace
            Shared = $shared
            SharedList = $sharedList
            SurfaceView = $SurfaceView
            ReplacementAndroidObject = $ReplacementAndroidObject
            Observations = $observations
            ScalarMutationPassed = $scalarMutationPassed
            PropertyStructureMutationPassed = $propertyStructurePassed
            NestedAndroidReferenceReplacementPassed = $nestedAndroidReplacementPassed
            NestedClrListMutationPassed = $nestedClrListPassed
            AllTestedMutationsPassed =
                $scalarMutationPassed -and $propertyStructurePassed -and
                $nestedAndroidReplacementPassed -and $nestedClrListPassed
        }

        [Android.Util.Log]::Info('PowerShell',
            "PSCUSTOMOBJECT_RUNSPACE_MUTATION scalar=$scalarMutationPassed propertyStructure=$propertyStructurePassed nestedAndroid=$nestedAndroidReplacementPassed nestedClrList=$nestedClrListPassed all=$($receipt.AllTestedMutationsPassed) ownerPid=$($receipt.OwnerPid) ownerTid=$($receipt.OwnerTid) ownerRunspace=$($observations['OwnerRunspaceIdentity']) childRunspace=$($observations['ChildRunspaceIdentity']) ownerWrapper=$($observations['OwnerStepOneWrapperIdentity']) childWrapper=$($observations['ChildStepOneWrapperIdentity']) ownerBase=$($observations['OwnerStepOneBaseObjectIdentity']) childBase=$($observations['ChildStepOneBaseObjectIdentity']) childFailureType=$($observations['ChildFailureType']) childFailureMessage=$($observations['ChildFailureMessage'])")
        [Android.Util.Log]::Info('PowerShell',
            "PSCUSTOMOBJECT_RUNSPACE_MUTATION_DETAILS B1version=$($observations['ChildStepOneVersion']) B1valueRef=$($observations['ChildStepOneValueReferenceEqual']) A2version=$($observations['OwnerStepTwoVersion']) A2valueRef=$($observations['OwnerStepTwoValueReferenceEqual']) A2fromB=$($observations['OwnerStepTwoFromBPresent']) A2fromBRef=$($observations['OwnerStepTwoFromBReferenceEqual']) A2childRef=$($observations['OwnerStepTwoChildReferenceEqual']) B3version=$($observations['ChildStepThreeVersion']) B3valueRef=$($observations['ChildStepThreeValueReferenceEqual']) B3fromB=$($observations['ChildStepThreeFromBPresent']) B3fromA=$($observations['ChildStepThreeFromAPresent']) B3fromARef=$($observations['ChildStepThreeFromAReferenceEqual']) B3childRef=$($observations['ChildStepThreeChildReferenceEqual'])")
        [Android.Util.Log]::Info('PowerShell',
            "PSCUSTOMOBJECT_RUNSPACE_MUTATION_STRUCTURE A1properties=$($observations['OwnerStepOnePropertyNames']) B1properties=$($observations['ChildStepOnePropertyNames']) B2properties=$($observations['ChildStepTwoPropertyNames']) A2properties=$($observations['OwnerStepTwoPropertyNames']) A3properties=$($observations['OwnerStepThreePropertyNames']) B3properties=$($observations['ChildStepThreePropertyNames']) ownerChildWrapperRef=$($observations['OwnerChildWrapperReferenceEqual']) ownerChildSharedRef=$($observations['OwnerChildSharedReferenceEqual']) ownerBasePresent=$($observations['OwnerStepOneBaseObjectIdentity'] -ne 0) childBasePresent=$($observations['ChildStepOneBaseObjectPresent'])")
        [Android.Util.Log]::Info('PowerShell',
            "PSCUSTOMOBJECT_RUNSPACE_MUTATION_CONTROLS barrierA1=$($observations['ChildWaitedForOwnerStepOne']) barrierB2=$($observations['OwnerWaitedForChildStepTwo']) barrierA3=$($observations['ChildWaitedForOwnerStepThree']) listB1ref=$($observations['ChildStepOneListReferenceEqual']) listB1hasA=$($observations['ChildStepOneListContainsOwnerSentinel']) listA2ref=$($observations['OwnerStepTwoListReferenceEqual']) listA2hasA=$($observations['OwnerStepTwoListContainsOwnerOne']) listA2hasB=$($observations['OwnerStepTwoListContainsChildTwo']) listB3ref=$($observations['ChildStepThreeListReferenceEqual']) listB3hasA1=$($observations['ChildStepThreeListContainsOwnerOne']) listB3hasB2=$($observations['ChildStepThreeListContainsChildTwo']) listB3hasA3=$($observations['ChildStepThreeListContainsOwnerThree'])")
        [Android.Util.Log]::Info('PowerShell',
            "PSCUSTOMOBJECT_RUNSPACE_MUTATION_ANDROID surfaceManaged=$($observations['SurfaceViewManagedIdentity']) surfaceJni=$($observations['SurfaceViewJniIdentity']) surfacePeer=$($observations['SurfaceViewPeerHandle']) replacementType=$($observations['ReplacementAndroidObjectType']) replacementManaged=$($observations['ReplacementAndroidObjectManagedIdentity']) replacementJni=$($observations['ReplacementAndroidObjectJniIdentity']) replacementPeer=$($observations['ReplacementAndroidObjectPeerHandle'])")
        return $receipt
    }
    finally {
        $ownerStepOneComplete.Set()
        $childStepTwoComplete.Set()
        $ownerStepThreeComplete.Set()
        $childPowerShell.Dispose()
        $childRunspace.Dispose()
        $ownerStepOneComplete.Dispose()
        $childStepTwoComplete.Dispose()
        $ownerStepThreeComplete.Dispose()
    }
}
