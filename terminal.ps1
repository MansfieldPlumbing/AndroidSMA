using namespace System
using namespace System.Collections.Generic

param([Parameter(Mandatory)] $Event)

if ($null -eq $script:AndroidCanvas) {
    $script:AndroidCanvas = [pscustomobject]@{
        Cells = [uint32[]]::new(1); Columns = 1; Rows = 1
        FontSize = 18.0; CellWidth = 10.0; CellHeight = 20.0
        LeftInset = 0; TopInset = 0; RightInset = 0; BottomInset = 0
        LastDistance = 0.0; TouchDownAt = 0L; SelectionAnchor = $null
        TouchX = [List[int]]::new(); TouchY = [List[int]]::new(); TouchAt = [List[long]]::new()
        LastTouchCell = -1; Frame = 0L; DrawnAt = 0L
        Activity = $null; Surface = $null; Ime = $null
        ServiceCapability = $null; Actions = $null; Generation = [Guid]::Empty
    }
}

$script:TerminalPalette = [int[]]@(
    [Android.Graphics.Color]::Rgb(9,12,18).ToArgb(),
    [Android.Graphics.Color]::Rgb(205,49,49).ToArgb(),
    [Android.Graphics.Color]::Rgb(13,188,121).ToArgb(),
    [Android.Graphics.Color]::Rgb(229,229,16).ToArgb(),
    [Android.Graphics.Color]::Rgb(36,114,200).ToArgb(),
    [Android.Graphics.Color]::Rgb(188,63,188).ToArgb(),
    [Android.Graphics.Color]::Rgb(17,168,205).ToArgb(),
    [Android.Graphics.Color]::Rgb(229,229,229).ToArgb(),
    [Android.Graphics.Color]::Rgb(102,102,102).ToArgb(),
    [Android.Graphics.Color]::Rgb(241,76,76).ToArgb(),
    [Android.Graphics.Color]::Rgb(35,209,139).ToArgb(),
    [Android.Graphics.Color]::Rgb(245,245,67).ToArgb(),
    [Android.Graphics.Color]::Rgb(59,142,234).ToArgb(),
    [Android.Graphics.Color]::Rgb(214,112,214).ToArgb(),
    [Android.Graphics.Color]::Rgb(41,184,219).ToArgb(),
    [Android.Graphics.Color]::Rgb(255,255,255).ToArgb()
)

function script:Get-AndroidTerminalGeometry {
    $canvasState = $script:AndroidCanvas
    if ($null -eq $canvasState.Surface -or $canvasState.Surface.Width -le 0 -or $canvasState.Surface.Height -le 0) { return $null }
    $insets = $canvasState.Surface.RootWindowInsets
    if ($null -ne $insets) {
        [Android.Graphics.Insets] $systemBars = $insets.GetInsets(
            [Android.Views.WindowInsets+Type]::SystemBars())
        $canvasState.LeftInset = $systemBars.Left
        $canvasState.TopInset = $systemBars.Top
        $canvasState.RightInset = $systemBars.Right
        $canvasState.BottomInset = $systemBars.Bottom
        if ($null -ne $insets.DisplayCutout) {
            $canvasState.LeftInset = [Math]::Max($canvasState.LeftInset, $insets.DisplayCutout.SafeInsetLeft)
            $canvasState.TopInset = [Math]::Max($canvasState.TopInset, $insets.DisplayCutout.SafeInsetTop)
            $canvasState.RightInset = [Math]::Max($canvasState.RightInset, $insets.DisplayCutout.SafeInsetRight)
            $canvasState.BottomInset = [Math]::Max($canvasState.BottomInset, $insets.DisplayCutout.SafeInsetBottom)
        }
    }
    if ($canvasState.TopInset -le 0) {
        [int] $statusBar = $script:Activity.Resources.GetIdentifier('status_bar_height','dimen','android')
        if ($statusBar -gt 0) { $canvasState.TopInset = $script:Activity.Resources.GetDimensionPixelSize($statusBar) }
    }
    if ($canvasState.BottomInset -le 0) {
        [int] $navigationBar = $script:Activity.Resources.GetIdentifier('navigation_bar_height','dimen','android')
        if ($navigationBar -gt 0) { $canvasState.BottomInset = $script:Activity.Resources.GetDimensionPixelSize($navigationBar) }
    }
    [Android.Graphics.Paint] $measure = [Android.Graphics.Paint]::new([Android.Graphics.PaintFlags]::AntiAlias)
    try {
        [void]$measure.SetTypeface([Android.Graphics.Typeface]::Monospace)
        $measure.TextSize = [single]($canvasState.FontSize * $script:Activity.Resources.DisplayMetrics.ScaledDensity)
        $canvasState.CellWidth = [Math]::Max(2.0, [double]$measure.MeasureText('M'))
        $canvasState.CellHeight = [Math]::Max(4.0, [double]$measure.FontSpacing)
    }
    finally { $measure.Dispose() }
    [int] $width = [Math]::Max(1, $canvasState.Surface.Width - $canvasState.LeftInset - $canvasState.RightInset)
    [int] $height = [Math]::Max(1, $canvasState.Surface.Height - $canvasState.TopInset - $canvasState.BottomInset)
    [int] $columns = [Math]::Clamp([int][Math]::Floor($width / $canvasState.CellWidth), 2, 512)
    [int] $rows = [Math]::Clamp([int][Math]::Floor($height / $canvasState.CellHeight), 2, 512)
    while ($columns * $rows -gt 262144) { $rows-- }
    [pscustomobject]@{ Width=$width; Height=$height; Columns=$columns; Rows=$rows }
}

function script:Set-PackedCell {
    param([uint32[]]$Cells,[int]$Columns,[int]$Rows,[int]$X,[int]$Y,
          [string]$Text,[int]$Foreground=15,[int]$Background=0)
    if ($X -lt 0 -or $X -ge $Columns -or $Y -lt 0 -or $Y -ge $Rows -or -not $Text) { return }
    $Cells[$Y*$Columns+$X] = [uint32](($Background -shl 24) -bor ($Foreground -shl 16) -bor [char]$Text[0])
}

function script:Build-AndroidTerminalCells {
    param($Geometry)
    $canvasState = $script:AndroidCanvas
    if ($Geometry.Columns -ne $canvasState.Columns -or $Geometry.Rows -ne $canvasState.Rows) {
        $canvasState.Columns = $Geometry.Columns; $canvasState.Rows = $Geometry.Rows
        $canvasState.Cells = [uint32[]]::new($Geometry.Columns * $Geometry.Rows)
        Set-TerminalSize $script:Terminal $Geometry.Columns $Geometry.Rows
        [Android.Util.Log]::Info('PowerShell', "Canvas and terminal resized to $($Geometry.Columns)x$($Geometry.Rows); insets=$($canvasState.LeftInset),$($canvasState.TopInset),$($canvasState.RightInset),$($canvasState.BottomInset)")
    }
    else { [Array]::Clear($canvasState.Cells, 0, $canvasState.Cells.Length) }

    [object[]] $rows = @(Get-TerminalViewportRows $script:Terminal)
    for ([int]$y=0; $y -lt [Math]::Min($Geometry.Rows,$rows.Count); $y++) {
        $row = $rows[$y]
        for ([int]$x=0; $x -lt [Math]::Min($Geometry.Columns,$row.Cells.Count); $x++) {
            $cell = $row.Cells[$x]
            if ($cell.Width -eq 0 -or [string]::IsNullOrEmpty($cell.Text)) { continue }
            [int]$foreground = if ($cell.Foreground -ge 0) { $cell.Foreground -band 15 } else { 15 }
            [int]$background = if ($cell.Background -ge 0) { $cell.Background -band 15 } else { 0 }
            if ($cell.Inverse) { $swap=$foreground;$foreground=$background;$background=$swap }
            Set-PackedCell $canvasState.Cells $Geometry.Columns $Geometry.Rows $x $y $cell.Text $foreground $background
        }
    }

    [int]$inputX=$script:Terminal.CursorColumn; [int]$inputY=$script:Terminal.CursorRow
    [string]$projected=[string]$script:Terminal.InputText
    if ($script:Terminal.Composition) { $projected += $script:Terminal.Composition }
    foreach($character in $projected.ToCharArray()) {
        if($inputX -ge $Geometry.Columns){$inputX=0;$inputY++}
        if($inputY -ge $Geometry.Rows){break}
        [int]$background=if($script:Terminal.Composition -and $inputX -ge ($script:Terminal.CursorColumn+$script:Terminal.InputText.Length)){6}else{0}
        Set-PackedCell $canvasState.Cells $Geometry.Columns $Geometry.Rows $inputX $inputY ([string]$character) 15 $background
        $inputX++
    }
    if(([Environment]::TickCount64 % 1000) -lt 500 -and $inputX -lt $Geometry.Columns -and $inputY -lt $Geometry.Rows){
        Set-PackedCell $canvasState.Cells $Geometry.Columns $Geometry.Rows $inputX $inputY '_' 0 15
    }

    [long]$now=[Environment]::TickCount64
    for([int]$index=$canvasState.TouchAt.Count-1;$index -ge 0;$index--){
        if($now-$canvasState.TouchAt[$index] -gt 500){$canvasState.TouchAt.RemoveAt($index);$canvasState.TouchX.RemoveAt($index);$canvasState.TouchY.RemoveAt($index)}
    }
    for([int]$index=0;$index -lt $canvasState.TouchAt.Count;$index++){
        [int]$x=$canvasState.TouchX[$index];[int]$y=$canvasState.TouchY[$index]
        if($x -ge 0 -and $x -lt $Geometry.Columns -and $y -ge 0 -and $y -lt $Geometry.Rows){Set-PackedCell $canvasState.Cells $Geometry.Columns $Geometry.Rows $x $y '·' 0 14}
    }
}

function script:Draw-AndroidTerminal {
    $canvasState = $script:AndroidCanvas
    $surface = $canvasState.Surface
    if ($null -eq $surface) { [Android.Util.Log]::Info('PowerShell','Canvas draw deferred: no SurfaceView'); return }
    if (-not $surface.Holder.Surface.IsValid) {
        [Android.Util.Log]::Info('PowerShell',"Canvas validity=false size=$($surface.Width)x$($surface.Height) shown=$($surface.IsShown) attached=$($surface.IsAttachedToWindow)")
        if ($surface.Width -le 0 -or $surface.Height -le 0) { return }
    }
    $geometry = Get-AndroidTerminalGeometry
    if ($null -eq $geometry) { return }
    Build-AndroidTerminalCells $geometry
    [Android.Graphics.Canvas] $canvas = $null
    [Android.Graphics.Paint] $paint = [Android.Graphics.Paint]::new([Android.Graphics.PaintFlags]::AntiAlias)
    try {
        $canvas = $surface.Holder.LockHardwareCanvas()
        if ($null -eq $canvas) { return }
        $canvas.DrawColor([Android.Graphics.Color]::Rgb(9,12,18))
        [void]$paint.SetTypeface([Android.Graphics.Typeface]::Monospace)
        $paint.TextSize = [single]($canvasState.FontSize * $canvasState.Activity.Resources.DisplayMetrics.ScaledDensity)
        [single]$baseline = [single]($canvasState.TopInset - $paint.FontMetrics.Top)
        for([int]$y=0;$y -lt $geometry.Rows;$y++){
            [int]$x=0
            while($x -lt $geometry.Columns){
                [uint32]$packed=$canvasState.Cells[$y*$geometry.Columns+$x]
                [int]$codepoint=[int]($packed -band 0xffff); if($codepoint -eq 0){$x++;continue}
                [int]$foreground=[int](($packed -shr 16)-band 0xff);[int]$background=[int](($packed -shr 24)-band 0xff)
                [int]$start=$x
                [System.Text.StringBuilder]$run=[System.Text.StringBuilder]::new()
                while($x -lt $geometry.Columns){
                    $packed=$canvasState.Cells[$y*$geometry.Columns+$x]
                    $codepoint=[int]($packed -band 0xffff)
                    if($codepoint -eq 0 -or [int](($packed -shr 16)-band 0xff) -ne $foreground -or [int](($packed -shr 24)-band 0xff) -ne $background){break}
                    [void]$run.Append([char]$codepoint);$x++
                }
                [single]$left=[single]($canvasState.LeftInset+$start*$canvasState.CellWidth)
                [single]$top=[single]($canvasState.TopInset+$y*$canvasState.CellHeight)
                if($background -ne 0){$paint.Color=[Android.Graphics.Color]::new($script:TerminalPalette[$background-band 15]);$canvas.DrawRect($left,$top,[single]($left+$run.Length*$canvasState.CellWidth),[single]($top+$canvasState.CellHeight),$paint)}
                $paint.Color=[Android.Graphics.Color]::new($script:TerminalPalette[$foreground-band 15])
                $canvas.DrawText($run.ToString(),$left,[single]($baseline+$y*$canvasState.CellHeight),$paint)
            }
        }
        $canvasState.Frame++; $canvasState.DrawnAt=[Environment]::TickCount64
        $script:Terminal.DirtyRows.Clear()
    }
    catch { [Android.Util.Log]::Error('PowerShell', "Canvas draw failed: $_") }
    finally {
        if($null -ne $canvas){$surface.Holder.UnlockCanvasAndPost($canvas)}
        $paint.Dispose()
    }
}

function script:Request-TerminalDraw { Draw-AndroidTerminal }

function script:Invoke-AndroidTerminalTouch {
    param($Touch)
    $canvasState=$script:AndroidCanvas
    if($Touch.PointerCount -ge 2){
        [double]$dx=$Touch.X1-$Touch.X0;[double]$dy=$Touch.Y1-$Touch.Y0
        [double]$distance=[Math]::Sqrt($dx*$dx+$dy*$dy)
        if($canvasState.LastDistance -gt 0 -and $Touch.Action -eq 2){
            $canvasState.FontSize=[Math]::Clamp($canvasState.FontSize*($distance/$canvasState.LastDistance),10.0,42.0)
        }
        $canvasState.LastDistance=$distance; Request-TerminalDraw; return
    }
    $canvasState.LastDistance=0.0
    [int]$x=[Math]::Clamp([int][Math]::Floor(($Touch.X0-$canvasState.LeftInset)/[Math]::Max(1.0,$canvasState.CellWidth)),0,$canvasState.Columns-1)
    [int]$y=[Math]::Clamp([int][Math]::Floor(($Touch.Y0-$canvasState.TopInset)/[Math]::Max(1.0,$canvasState.CellHeight)),0,$canvasState.Rows-1)
    if($Touch.Action -eq 0){$canvasState.TouchDownAt=[Environment]::TickCount64;$canvasState.SelectionAnchor=[pscustomobject]@{Row=$y;Column=$x}}
    if($Touch.Action -eq 2 -and [Environment]::TickCount64-$canvasState.TouchDownAt -ge 500 -and $null -ne $canvasState.SelectionAnchor){
        [int]$base=[Math]::Max(0,$script:Terminal.Scrollback.Count-$script:Terminal.ViewportOffset)
        Set-TerminalSelection $script:Terminal ($base+$canvasState.SelectionAnchor.Row) $canvasState.SelectionAnchor.Column ($base+$y) $x
    }
    if($Touch.Action -in 0,2){
        [int]$cell=$y*$canvasState.Columns+$x
        if($cell -ne $canvasState.LastTouchCell){$canvasState.LastTouchCell=$cell;$canvasState.TouchX.Add($x);$canvasState.TouchY.Add($y);$canvasState.TouchAt.Add([Environment]::TickCount64)}
    } else {$canvasState.LastTouchCell=-1}
    Request-TerminalDraw
}

function script:Receive-AndroidIme {
    param($ImeEvent)
    Set-TerminalComposition $script:Terminal ([string]$ImeEvent.Text) ([string]$ImeEvent.Composition)
    Request-TerminalDraw
}

function script:Submit-AndroidTerminalInput {
    param([string]$Text)
    if([string]::IsNullOrWhiteSpace($Text)){return}
    Set-TerminalComposition $script:Terminal '' ''
    Add-TerminalText $script:Terminal ($Text+"`r`n")
    Request-TerminalDraw
    [void](Start-CommandSubmission $Text)
}

$activity=$Event.Activity
[object]$service=$PSAndroid.Service
[object]$canvasState=$script:AndroidCanvas
[Guid]$generation=[Guid]::NewGuid()
[void]$canvasState.PSObject.Properties.Remove('Generation')
$canvasState.PSObject.Properties.Add(
    [System.Management.Automation.PSNoteProperty]::new('Generation',$generation))
[scriptblock]$touchWork={param($data)Invoke-AndroidTerminalTouch $data}.GetNewClosure()
[scriptblock]$imeWork={param($data)Receive-AndroidIme $data}.GetNewClosure()
[scriptblock]$submitWork={param($data)Submit-AndroidTerminalInput ([string]$data)}.GetNewClosure()
[scriptblock]$drawWork={Request-TerminalDraw}.GetNewClosure()
[void]$canvasState.PSObject.Properties.Remove('ServiceCapability')
$canvasState.PSObject.Properties.Add(
    [System.Management.Automation.PSNoteProperty]::new('ServiceCapability',$service))
[void]$canvasState.PSObject.Properties.Remove('Actions')
$canvasState.PSObject.Properties.Add(
    [System.Management.Automation.PSNoteProperty]::new('Actions',[pscustomobject]@{
        Touch=$touchWork;Ime=$imeWork;Submit=$submitWork;Draw=$drawWork;Blink=$null
    }))
[Android.Util.Log]::Info('PowerShell', "Capabilities: service=$($null -ne $canvasState.ServiceCapability) submit=$($null -ne $canvasState.Actions.Submit) draw=$($null -ne $canvasState.Actions.Draw)")
[scriptblock]$touchHandler={
    param($sender,$eventArgs)
    try {
        $motion=$eventArgs.Event
        $data=[pscustomobject]@{Action=[int]$motion.ActionMasked;PointerCount=$motion.PointerCount;X0=[single]$motion.GetX(0);Y0=[single]$motion.GetY(0);X1=0.0;Y1=0.0}
        if($motion.PointerCount -gt 1){$data.X1=[single]$motion.GetX(1);$data.Y1=[single]$motion.GetY(1)}
        [void]$canvasState.ServiceCapability.Post($canvasState.Actions.Touch,$data)
        if($motion.ActionMasked -eq [Android.Views.MotionEventActions]::Down){
            [void]$canvasState.Ime.RequestFocus()
            $input=[Android.Views.InputMethods.InputMethodManager]$canvasState.Activity.GetSystemService([Android.Content.Context]::InputMethodService)
            [void]$input.ShowSoftInput($canvasState.Ime,[Android.Views.InputMethods.ShowFlags]::Implicit)
        }
        $eventArgs.Handled=$true
    }
    catch { [Android.Util.Log]::Error('PowerShell',"Touch callback line $($_.InvocationInfo.ScriptLineNumber): $_");if($null -ne $eventArgs){$eventArgs.Handled=$true} }
}.GetNewClosure()
[scriptblock]$textHandler={
    try {
        $editable=$canvasState.Ime.EditableText
        [int]$start=[Android.Views.InputMethods.BaseInputConnection]::GetComposingSpanStart($editable)
        [int]$end=[Android.Views.InputMethods.BaseInputConnection]::GetComposingSpanEnd($editable)
        [string]$all=[string]$canvasState.Ime.Text;[string]$composition=''
        if($start -ge 0 -and $end -gt $start -and $end -le $all.Length){$composition=$all.Substring($start,$end-$start);$all=$all.Remove($start,$end-$start)}
        [void]$canvasState.ServiceCapability.Post($canvasState.Actions.Ime,[pscustomobject]@{Text=$all;Composition=$composition})
    }
    catch { [Android.Util.Log]::Error('PowerShell',"IME callback failed: $_") }
}.GetNewClosure()
[scriptblock]$editorHandler={
    param($sender,$eventArgs)
    try {
        if($eventArgs.ActionId -eq [Android.Views.InputMethods.ImeAction]::Send){
            [string]$text=$canvasState.Ime.Text
            [void]$canvasState.ServiceCapability.Post($canvasState.Actions.Submit,$text)
            $eventArgs.Handled=$true
        }
    }
    catch { [Android.Util.Log]::Error('PowerShell',"Editor callback line $($_.InvocationInfo.ScriptLineNumber): $_");if($null -ne $eventArgs){$eventArgs.Handled=$true} }
}.GetNewClosure()
[scriptblock]$layoutHandler={try{[void]$canvasState.ServiceCapability.Post($canvasState.Actions.Draw,$null)}catch{[Android.Util.Log]::Error('PowerShell',"Layout callback failed: $_")}}.GetNewClosure()
[Action]$delayedDraw=[Action]{try{[void]$canvasState.ServiceCapability.Post($canvasState.Actions.Draw,$null)}catch{[Android.Util.Log]::Error('PowerShell',"Delayed draw failed: $_")}}.GetNewClosure()
[Action]$blink=[Action]{
    try {
        if($canvasState.Generation -eq $generation -and $null -ne $canvasState.Surface -and $canvasState.Surface.IsAttachedToWindow){
            [void]$canvasState.ServiceCapability.Post($canvasState.Actions.Draw,$null)
            [void]$canvasState.Surface.PostDelayed($canvasState.Actions.Blink,500)
        }
    }
    catch { [Android.Util.Log]::Error('PowerShell',"Cursor callback failed: $_") }
}.GetNewClosure()
$canvasState.Actions.Blink=$blink

[scriptblock]$attachUi={
    [Android.Widget.FrameLayout]$root=[Android.Widget.FrameLayout]::new($activity)
    $root.SetBackgroundColor([Android.Graphics.Color]::Rgb(9,12,18))
    [Android.Views.SurfaceView]$surface=[Android.Views.SurfaceView]::new($activity)
    $surface.Focusable=$true;$surface.FocusableInTouchMode=$true
    $root.AddView($surface,[Android.Widget.FrameLayout+LayoutParams]::new(-1,-1))
    [Android.Widget.EditText]$ime=[Android.Widget.EditText]::new($activity)
    $ime.SetBackgroundColor([Android.Graphics.Color]::Transparent)
    $ime.SetTextColor([Android.Graphics.Color]::Transparent)
    $ime.SetHintTextColor([Android.Graphics.Color]::Transparent)
    $ime.SetCursorVisible($false);$ime.Alpha=0.01
    $ime.InputType=[Android.Text.InputTypes]::ClassText -bor [Android.Text.InputTypes]::TextFlagNoSuggestions
    $ime.ImeOptions=[Android.Views.InputMethods.ImeAction]::Send
    [Android.Widget.FrameLayout+LayoutParams]$imeLayout=[Android.Widget.FrameLayout+LayoutParams]::new(2,2)
    $imeLayout.Gravity=[Android.Views.GravityFlags]::Bottom -bor [Android.Views.GravityFlags]::Left
    $root.AddView($ime,$imeLayout)
    $canvasState.Activity=$activity;$canvasState.Surface=$surface;$canvasState.Ime=$ime

    $surface.add_Touch($touchHandler)
    $ime.add_TextChanged($textHandler)
    $ime.add_EditorAction($editorHandler)
    $activity.SetContentView($root)
    $root.add_LayoutChange($layoutHandler)
    [void]$root.PostDelayed($delayedDraw,250)
    [void]$root.PostDelayed($delayedDraw,1000)
    [void]$root.PostDelayed($blink,500)
}.GetNewClosure()
$service.RunOnMainThread($activity,[Action]$attachUi)
