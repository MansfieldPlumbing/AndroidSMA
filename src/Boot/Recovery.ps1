#requires -Version 7.0
using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces

param(
    [Parameter(Mandatory)]
    [psobject] $Event
)

# This script lives in the durable boot/recovery runspace. Android's tiny entry
# artifact invokes it with Create and ActivityResult events. PROFILE.PS1 lives
# in a separate, disposable application runspace.

$script:PickFileRequest = 1001

function ConvertTo-OneLine([AllowNull()][string] $Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '—' }
    return $Value.Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Get-PrivateRoot {
    $script:Activity.FilesDir.AbsolutePath
}

function Get-ProfilePath {
    [Path]::Combine((Get-PrivateRoot), 'PROFILE.PS1')
}

function ConvertTo-ErrorRecordText([ErrorRecord] $Record) {
    $invocation = $Record.InvocationInfo
    $source = if ([string]::IsNullOrWhiteSpace($invocation.ScriptName)) {
        Get-ProfilePath
    } else { $invocation.ScriptName }
    $line = if ($invocation.ScriptLineNumber -gt 0) { $invocation.ScriptLineNumber } else { '—' }
    $column = if ($invocation.OffsetInLine -gt 0) { $invocation.OffsetInLine } else { '—' }

    @(
        'message: ' + (ConvertTo-OneLine ($Record.Exception?.Message ?? $Record.ToString()))
        'exception: ' + ($Record.Exception?.GetType().FullName ?? '—')
        'fullyQualifiedErrorId: ' + (ConvertTo-OneLine $Record.FullyQualifiedErrorId)
        'category: ' + $Record.CategoryInfo.Category
        'categoryReason: ' + (ConvertTo-OneLine $Record.CategoryInfo.Reason)
        'targetName: ' + (ConvertTo-OneLine $Record.CategoryInfo.TargetName)
        'targetType: ' + (ConvertTo-OneLine $Record.CategoryInfo.TargetType)
        'source: ' + $source
        'line: ' + $line
        'column: ' + $column
        'sourceText: ' + (ConvertTo-OneLine $invocation.Line)
        'scriptStackTrace: ' + (ConvertTo-OneLine $Record.ScriptStackTrace)
    ) -join "`n"
}

function Add-RecoveryContext([string] $FailureText) {
    $runspaceId = if ($script:ApplicationRunspace) {
        $script:ApplicationRunspace.InstanceId
    } else { '—' }
    $abis = [Android.OS.Build]::SupportedAbis

    $FailureText + "`n`n" + (@(
        'timestamp: ' + [DateTimeOffset]::UtcNow.ToString('O')
        'pid: ' + [Environment]::ProcessId
        'tid: ' + [Android.OS.Process]::MyTid()
        'package: ' + $script:Activity.PackageName
        'device: ' + (ConvertTo-OneLine ("{0} {1}" -f [Android.OS.Build]::Manufacturer, [Android.OS.Build]::Model))
        'android: ' + [Android.OS.Build+VERSION]::Release
        'api: ' + [int][Android.OS.Build+VERSION]::SdkInt
        'abi: ' + ($abis -join ',')
        'dotnet: ' + [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        'runspace: ' + $runspaceId
    ) -join "`n")
}

function ConvertTo-ParseFailureText([System.Management.Automation.Language.ParseError[]] $ParseErrors) {
    $profilePath = Get-ProfilePath
    $sourceLines = [File]::ReadAllLines($profilePath)
    $items = [List[string]]::new()

    foreach ($parseError in $ParseErrors) {
        $line = $parseError.Extent.StartLineNumber
        $column = $parseError.Extent.StartColumnNumber
        $sourceText = if ($line -gt 0 -and $line -le $sourceLines.Length) {
            $sourceLines[$line - 1]
        } else { $parseError.Extent.Text }

        $items.Add((@(
            'message: ' + (ConvertTo-OneLine $parseError.Message)
            'exception: System.Management.Automation.ParseException'
            'fullyQualifiedErrorId: ' + (ConvertTo-OneLine $parseError.ErrorId)
            'category: ParserError'
            'categoryReason: ParseException'
            'targetName: ' + $profilePath
            'targetType: System.String'
            'source: ' + $profilePath
            'line: ' + $line
            'column: ' + $column
            'sourceText: ' + (ConvertTo-OneLine $sourceText)
            'scriptStackTrace: —'
        ) -join "`n"))
    }

    Add-RecoveryContext ($items -join "`n`n")
}

function ConvertTo-FailureText {
    param(
        [Parameter(Mandatory)] $Failure,
        [ErrorRecord[]] $ErrorRecords
    )

    $profilePath = Get-ProfilePath
    $failureText = if ($ErrorRecords.Count) {
        $recordText = [List[string]]::new()
        foreach ($record in $ErrorRecords) {
            $recordText.Add((ConvertTo-ErrorRecordText $record))
        }
        $recordText -join "`n`n"
    } elseif ($Failure -is [ErrorRecord]) {
        ConvertTo-ErrorRecordText $Failure
    } else {
        @(
            'message: ' + (ConvertTo-OneLine $Failure.Message)
            'exception: ' + $Failure.GetType().FullName
            'source: ' + $profilePath
            'line: —'
            'column: —'
        ) -join "`n"
    }

    Add-RecoveryContext $failureText
}

function Copy-RecoveryText([string] $Label, [string] $Text) {
    $clipboard = $script:Activity.GetSystemService([Android.Content.Context]::ClipboardService)
    $clipboard.PrimaryClip = [Android.Content.ClipData]::NewPlainText($Label, $Text)
}

function Get-FailureClipboardPayload([string] $Details) {
    $profile = Get-ProfilePath
    if (-not [File]::Exists($profile)) {
        return "ANDROIDSMA STARTUP FAILURE`n`n$Details`n`nPROFILE.PS1: unavailable"
    }

    $text = [File]::ReadAllText($profile)
    "ANDROIDSMA STARTUP FAILURE`n`n$Details" +
        "`n`n--- PROFILE.PS1 BEGIN ---`n`n$text" +
        "`n`n--- PROFILE.PS1 END ---"
}

function Add-RecoveryButton($Parent, [string] $Text, [scriptblock] $Action) {
    $button = [Android.Widget.Button]::new($script:Activity)
    $button.Text = $Text
    $handler = { & $Action }.GetNewClosure()
    $button.add_Click($handler)

    $parameters = [Android.Widget.LinearLayout+LayoutParams]::new(
        [Android.Views.ViewGroup+LayoutParams]::MatchParent,
        [Android.Views.ViewGroup+LayoutParams]::WrapContent)
    $parameters.TopMargin = ConvertTo-Dp 8
    $Parent.AddView($button, $parameters)
}

function ConvertTo-Dp([int] $Value) {
    [int][Android.Util.TypedValue]::ApplyDimension(
        [Android.Util.ComplexUnitType]::Dip,
        $Value,
        $script:Activity.Resources.DisplayMetrics)
}

function Show-Recovery([string] $Title, [string] $Details) {
    $script:RecoveryTitle = $Title
    $script:RecoveryDetails = $Details

    $layout = [Android.Widget.LinearLayout]::new($script:Activity)
    $layout.Orientation = [Android.Widget.Orientation]::Vertical
    $layout.SetBackgroundColor([Android.Graphics.Color]::Rgb(11, 61, 46))
    $padding = ConvertTo-Dp 24
    $layout.SetPadding($padding, $padding, $padding, $padding)

    $heading = [Android.Widget.TextView]::new($script:Activity)
    $heading.Text = $Title
    $heading.SetTextColor([Android.Graphics.Color]::White)
    $heading.SetTextSize([Android.Util.ComplexUnitType]::Sp, 64)
    $layout.AddView($heading)

    $message = [Android.Widget.TextView]::new($script:Activity)
    $message.Text = $Details
    $message.SetTextIsSelectable($true)
    $message.SetTextColor([Android.Graphics.Color]::White)
    $message.SetTextSize([Android.Util.ComplexUnitType]::Sp, 15)

    $messageLayout = [Android.Widget.LinearLayout+LayoutParams]::new(
        [Android.Views.ViewGroup+LayoutParams]::MatchParent, 0, 1.0)
    $messageLayout.TopMargin = ConvertTo-Dp 16
    $messageLayout.BottomMargin = ConvertTo-Dp 16
    $scroll = [Android.Widget.ScrollView]::new($script:Activity)
    $scroll.AddView($message)
    $layout.AddView($scroll, $messageLayout)

    if ($Title -eq ':(') {
        Add-RecoveryButton $layout 'COPY TO CLIPBOARD' {
            Copy-RecoveryText 'AndroidSMA startup failure' (Get-FailureClipboardPayload $Details)
        }
    }

    Add-RecoveryButton $layout 'HELP' {
        $helpText = @"
1. Select IMPORT FILE.

2. Select any document. AndroidSMA copies it to private app storage using its display name.

3. A file named PROFILE.PS1 starts automatically. Import an application entry script under that name to boot it.

4. Other imported files are available to PROFILE.PS1 under `$PSScriptRoot.

5. RETRY disposes the failed runspace and invokes PROFILE.PS1 again.

6. Android Settings > Apps > AndroidSMA > Storage > Clear storage removes all imported files.

CURRENT DETAILS

$Details
"@
        $dialog = [Android.App.AlertDialog+Builder]::new($script:Activity)
        $dialog.SetTitle('HELP')
        $dialog.SetMessage($helpText)
        $copyHelp = { Copy-RecoveryText 'AndroidSMA help' $helpText }.GetNewClosure()
        $dialog.SetNeutralButton('COPY TO CLIPBOARD', $copyHelp)
        $dialog.SetPositiveButton('OK', {})
        $dialog.Show()
    }

    Add-RecoveryButton $layout 'IMPORT FILE' { Open-DocumentPicker }
    Add-RecoveryButton $layout 'PRIVATE HOME' { Show-PrivateHome (Get-PrivateRoot) }
    Add-RecoveryButton $layout 'RETRY' { Restart-AndroidSmaApplication }
    $script:Activity.SetContentView($layout)
}

function Test-PrivateHomePath([string] $Path) {
    $root = [Path]::GetFullPath((Get-PrivateRoot)).TrimEnd([Path]::DirectorySeparatorChar)
    $candidate = [Path]::GetFullPath($Path).TrimEnd([Path]::DirectorySeparatorChar)
    $candidate.Equals($root, [StringComparison]::Ordinal) -or
        $candidate.StartsWith($root + [Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)
}

function Show-PrivateFile($Item) {
    $details = @(
        'name: ' + $Item.Name
        'path: ' + $Item.FullName
        'bytes: ' + $Item.Length
        'modified: ' + $Item.LastWriteTimeUtc.ToString('O')
    ) -join "`n"

    $filePath = $Item.FullName
    $dialog = [Android.App.AlertDialog+Builder]::new($script:Activity)
    $dialog.SetTitle($Item.Name)
    $dialog.SetMessage($details)
    $copyPath = { Copy-RecoveryText 'AndroidSMA private path' $filePath }.GetNewClosure()
    $dialog.SetNeutralButton('COPY PATH', $copyPath)
    $dialog.SetPositiveButton('OK', {})
    $dialog.Show()
}

function Show-PrivateHome([string] $Path) {
    if (-not (Test-PrivateHomePath $Path)) {
        throw [UnauthorizedAccessException]::new('Private-home navigation cannot leave app storage.')
    }

    $root = [Path]::GetFullPath((Get-PrivateRoot)).TrimEnd([Path]::DirectorySeparatorChar)
    $current = [Path]::GetFullPath($Path).TrimEnd([Path]::DirectorySeparatorChar)

    $layout = [Android.Widget.LinearLayout]::new($script:Activity)
    $layout.Orientation = [Android.Widget.Orientation]::Vertical
    $layout.SetBackgroundColor([Android.Graphics.Color]::Rgb(11, 61, 46))
    $padding = ConvertTo-Dp 24
    $layout.SetPadding($padding, $padding, $padding, $padding)

    $heading = [Android.Widget.TextView]::new($script:Activity)
    $heading.Text = 'HOME'
    $heading.SetTextColor([Android.Graphics.Color]::White)
    $heading.SetTextSize([Android.Util.ComplexUnitType]::Sp, 40)
    $layout.AddView($heading)

    $location = [Android.Widget.TextView]::new($script:Activity)
    $location.Text = if ($current -eq $root) { '/' } else { $current.Substring($root.Length) }
    $location.SetTextIsSelectable($true)
    $location.SetTextColor([Android.Graphics.Color]::White)
    $location.SetTextSize([Android.Util.ComplexUnitType]::Sp, 14)
    $layout.AddView($location)

    $rows = [Android.Widget.LinearLayout]::new($script:Activity)
    $rows.Orientation = [Android.Widget.Orientation]::Vertical

    if ($current -ne $root) {
        $parent = [Directory]::GetParent($current).FullName
        $openParent = { Show-PrivateHome $parent }.GetNewClosure()
        Add-RecoveryButton $rows '[..]  PARENT' $openParent
    }

    $items = [List[FileSystemInfo]]::new([DirectoryInfo]::new($current).GetFileSystemInfos())
    $items.Sort([Comparison[FileSystemInfo]] {
        param($left, $right)
        $leftDirectory = $left -is [DirectoryInfo]
        $rightDirectory = $right -is [DirectoryInfo]
        if ($leftDirectory -ne $rightDirectory) {
            if ($leftDirectory) { return -1 }
            return 1
        }
        [string]::Compare($left.Name, $right.Name, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($items.Count -eq 0) {
        $empty = [Android.Widget.TextView]::new($script:Activity)
        $empty.Text = '(empty)'
        $empty.SetTextColor([Android.Graphics.Color]::White)
        $empty.SetTextSize([Android.Util.ComplexUnitType]::Sp, 15)
        $rows.AddView($empty)
    }

    foreach ($item in $items) {
        $selected = $item
        if ($selected -is [DirectoryInfo]) {
            $directoryPath = $selected.FullName
            $openDirectory = { Show-PrivateHome $directoryPath }.GetNewClosure()
            Add-RecoveryButton $rows ('[DIR]  ' + $selected.Name) $openDirectory
        } else {
            $file = $selected
            $openFile = { Show-PrivateFile $file }.GetNewClosure()
            Add-RecoveryButton $rows ('[FILE] ' + $selected.Name + '  (' + $selected.Length + ')') $openFile
        }
    }

    $scroll = [Android.Widget.ScrollView]::new($script:Activity)
    $scroll.AddView($rows)
    $scrollLayout = [Android.Widget.LinearLayout+LayoutParams]::new(
        [Android.Views.ViewGroup+LayoutParams]::MatchParent, 0, 1.0)
    $scrollLayout.TopMargin = ConvertTo-Dp 16
    $scrollLayout.BottomMargin = ConvertTo-Dp 16
    $layout.AddView($scroll, $scrollLayout)

    Add-RecoveryButton $layout 'BACK TO RECOVERY' {
        Show-Recovery $script:RecoveryTitle $script:RecoveryDetails
    }
    $script:Activity.SetContentView($layout)
}

function Open-DocumentPicker {
    $picker = [Android.Content.Intent]::new([Android.Content.Intent]::ActionOpenDocument)
    $picker.AddCategory([Android.Content.Intent]::CategoryOpenable)
    $picker.SetType('*/*')
    $script:Activity.StartActivityForResult($picker, $script:PickFileRequest)
}

function Get-DocumentDisplayName($Uri) {
    $cursor = $script:Activity.ContentResolver.Query(
        $Uri, [string[]]@([Android.Provider.IOpenableColumns]::DisplayName), $null, $null, $null)
    try {
        if ($null -eq $cursor -or -not $cursor.MoveToFirst()) {
            throw [IOException]::new('The selected document has no display name.')
        }
        $column = $cursor.GetColumnIndex([Android.Provider.IOpenableColumns]::DisplayName)
        $name = if ($column -ge 0) { $cursor.GetString($column) } else { $null }
        if ([string]::IsNullOrEmpty($name)) {
            throw [IOException]::new('The selected document has no display name.')
        }
        $name
    } finally {
        if ($cursor) { $cursor.Dispose() }
    }
}

function Import-Document($Uri) {
    $name = Get-DocumentDisplayName $Uri
    if ([string]::IsNullOrWhiteSpace($name) -or $name -in '.', '..' -or
        $name.Contains('/') -or $name.Contains('\')) {
        throw [IOException]::new('The selected document name is invalid.')
    }
    if ($name.Equals('PROFILE.PS1', [StringComparison]::OrdinalIgnoreCase)) {
        $name = 'PROFILE.PS1'
    }

    $destination = [Path]::Combine((Get-PrivateRoot), $name)
    $incoming = "$destination.incoming"
    try {
        $source = $script:Activity.ContentResolver.OpenInputStream($Uri)
        if ($null -eq $source) {
            throw [IOException]::new('The selected document could not be opened.')
        }
        try {
            $target = [FileStream]::new($incoming, [FileMode]::Create, [FileAccess]::Write, [FileShare]::None)
            try {
                $source.CopyTo($target)
                $target.Flush($true)
            } finally { $target.Dispose() }
        } finally { $source.Dispose() }

        [File]::Move($incoming, $destination, $true)
        [Android.Util.Log]::Info('AndroidSMA', "IMPORTED $name")
    } catch {
        if ([File]::Exists($incoming)) { [File]::Delete($incoming) }
        throw
    }

    [pscustomobject]@{ Name = $name; Path = $destination }
}

function Stop-AndroidSmaApplication {
    if ($script:ApplicationRunspace) {
        $script:ApplicationRunspace.Dispose()
        $script:ApplicationRunspace = $null
    }
    [Runspace]::DefaultRunspace = $script:BootRunspace
}

function Add-AndroidSmaCommands($InitialSessionState, [Reflection.Assembly] $Assembly) {
    foreach ($type in $Assembly.GetTypes()) {
        $cmdlets = $type.GetCustomAttributes([CmdletAttribute], $false)
        if ($cmdlets.Count) {
            $cmdlet = $cmdlets[0]
            $InitialSessionState.Commands.Add(
                [SessionStateCmdletEntry]::new(
                    "$($cmdlet.VerbName)-$($cmdlet.NounName)", $type, $null))
        }

        $providers = $type.GetCustomAttributes(
            [System.Management.Automation.Provider.CmdletProviderAttribute], $false)
        if ($providers.Count) {
            $provider = $providers[0]
            $InitialSessionState.Providers.Add(
                [SessionStateProviderEntry]::new($provider.ProviderName, $type, $null))
        }
    }
}

function New-AndroidSmaApplicationRunspace {
    # CreateDefault2 is the behavior oracle for cmdlets/providers. It will be
    # replaced by the explicit keep-manifest after the assembly wall is proven.
    $initial = [InitialSessionState]::CreateDefault2()
    $initial.LanguageMode = [PSLanguageMode]::FullLanguage
    $initial.ThreadOptions = [PSThreadOptions]::UseCurrentThread
    Add-AndroidSmaCommands $initial ([PSObject].Assembly)
    Add-AndroidSmaCommands $initial ([Reflection.Assembly]::Load('Microsoft.PowerShell.Commands.Utility'))
    Add-AndroidSmaCommands $initial ([Reflection.Assembly]::Load('Microsoft.PowerShell.Commands.Management'))
    $runspace = [RunspaceFactory]::CreateRunspace($initial)
    $runspace.Open()
    $runspace
}

function Start-AndroidSmaApplication {
    $profile = Get-ProfilePath
    if (-not [File]::Exists($profile)) {
        $missing = [FileNotFoundException]::new('PROFILE.PS1 is missing.', $profile)
        Show-Recovery ':(' (ConvertTo-FailureText $missing)
        return
    }

    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $profile, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) {
        $details = ConvertTo-ParseFailureText $parseErrors
        [Android.Util.Log]::Error('AndroidSMA', "PROFILE_PARSE_FAILED $details")
        Show-Recovery ':(' $details
        return
    }

    try {
        $script:ApplicationRunspace = New-AndroidSmaApplicationRunspace
        $script:ApplicationRunspace.SessionStateProxy.SetVariable('Activity', $script:Activity)

        $shell = [PowerShell]::Create()
        $records = @()
        try {
            $shell.Runspace = $script:ApplicationRunspace
            [Runspace]::DefaultRunspace = $script:ApplicationRunspace
            $null = $shell.AddCommand($profile).Invoke()
            $records = [ErrorRecord[]]$shell.Streams.Error
            if ($shell.HadErrors) {
                throw [RuntimeException]::new('PROFILE.PS1 reported one or more errors.')
            }
        } catch {
            $records = [ErrorRecord[]]$shell.Streams.Error
            if (-not $records.Count) {
                $exception = $_.Exception
                while ($exception) {
                    $record = $exception.ErrorRecord
                    if ($record -and
                        -not [string]::IsNullOrWhiteSpace($record.InvocationInfo.ScriptName)) {
                        $records = [ErrorRecord[]]@($record)
                        break
                    }
                    $exception = $exception.InnerException
                }
            }
            throw
        } finally {
            [Runspace]::DefaultRunspace = $script:BootRunspace
            $shell.Dispose()
        }

        [Android.Util.Log]::Info('AndroidSMA', "PROFILE_OK runspace=$($script:ApplicationRunspace.InstanceId)")
    } catch {
        $details = ConvertTo-FailureText $_.Exception $records
        Stop-AndroidSmaApplication
        [Android.Util.Log]::Error('AndroidSMA', "PROFILE_FAILED $details")
        Show-Recovery ':(' $details
    }
}

function Restart-AndroidSmaApplication {
    Stop-AndroidSmaApplication
    Start-AndroidSmaApplication
}

function Receive-ActivityResult($ResultEvent) {
    if ($ResultEvent.RequestCode -ne $script:PickFileRequest -or
        $ResultEvent.ResultCode -ne [Android.App.Result]::Ok -or
        $null -eq $ResultEvent.Data?.Data) { return }

    try {
        $import = Import-Document $ResultEvent.Data.Data
        if ($import.Name -ceq 'PROFILE.PS1') {
            Restart-AndroidSmaApplication
        } else {
            Show-Recovery "IMPORTED: $($import.Name)" (
                "source: $($import.Path)`nline: —`ncolumn: —`nmessage: Select RETRY.")
        }
    } catch {
        Show-Recovery ':(' (ConvertTo-FailureText $_)
    }
}

switch ($Event.Kind) {
    'Create' {
        $script:Activity = $Event.Activity
        $script:BootRunspace = [Runspace]::DefaultRunspace
        Start-AndroidSmaApplication
    }
    'ActivityResult' {
        if ($Event.Activity) { $script:Activity = $Event.Activity }
        Receive-ActivityResult $Event
    }
    default { throw "Unknown AndroidSMA boot event: $($Event.Kind)" }
}
