using namespace System
using namespace System.Collections.Generic
using namespace System.Globalization

function New-TerminalCell {
    param([string] $Text = ' ')
    [pscustomobject]@{
        Text = $Text; Width = 1; Foreground = -1; Background = -1
        Bold = $false; Underline = $false; Inverse = $false; Hyperlink = $null
    }
}

function New-TerminalRow {
    param([int] $Columns)
    [object[]] $cells = [object[]]::new($Columns)
    for ([int] $column = 0; $column -lt $Columns; $column++) { $cells[$column] = New-TerminalCell }
    [pscustomobject]@{ Cells = $cells; Wrapped = $false }
}

function Copy-TerminalRow {
    param($Row)
    [object[]] $cells = [object[]]::new($Row.Cells.Count)
    for ([int] $column = 0; $column -lt $cells.Count; $column++) {
        $source = $Row.Cells[$column]
        $cells[$column] = [pscustomobject]@{
            Text = $source.Text; Width = $source.Width; Foreground = $source.Foreground
            Background = $source.Background; Bold = $source.Bold; Underline = $source.Underline
            Inverse = $source.Inverse; Hyperlink = $source.Hyperlink
        }
    }
    [pscustomobject]@{ Cells = $cells; Wrapped = $Row.Wrapped }
}

function New-TerminalState {
    param([ValidateRange(2,1000)][int] $Columns = 80,
          [ValidateRange(2,1000)][int] $Rows = 24,
          [ValidateRange(0,100000)][int] $Scrollback = 4000)
    [List[object]] $screen = [List[object]]::new()
    for ([int] $row = 0; $row -lt $Rows; $row++) { $screen.Add((New-TerminalRow $Columns)) }
    [pscustomobject]@{
        Columns = $Columns; Rows = $Rows; ScrollbackLimit = $Scrollback
        Screen = $screen; Scrollback = [List[object]]::new()
        CursorRow = 0; CursorColumn = 0; SavedCursorRow = 0; SavedCursorColumn = 0
        ScrollTop = 0; ScrollBottom = $Rows - 1; ViewportOffset = 0
        ParserPending = ''; Title = ''; CurrentHyperlink = $null
        Foreground = -1; Background = -1; Bold = $false; Underline = $false; Inverse = $false
        Alternate = $false; MainScreen = $null; MainScrollback = $null
        DirtyRows = [HashSet[int]]::new(); Modes = [HashSet[string]]::new()
        Replies = [List[string]]::new(); SelectionStart = $null; SelectionEnd = $null
        InputText = ''; Composition = ''; CellWidth = 10.0; CellHeight = 20.0
    }
}

function Clear-TerminalRow {
    param($State, [int] $Row, [int] $Start = 0, [int] $End = -1)
    if ($End -lt 0) { $End = $State.Columns - 1 }
    for ([int] $column = [Math]::Max(0, $Start); $column -le [Math]::Min($End, $State.Columns - 1); $column++) {
        $State.Screen[$Row].Cells[$column] = New-TerminalCell
    }
    [void]$State.DirtyRows.Add($Row)
}

function Add-TerminalScrollback {
    param($State, $Row)
    $State.Scrollback.Add((Copy-TerminalRow $Row))
    while ($State.Scrollback.Count -gt $State.ScrollbackLimit) { $State.Scrollback.RemoveAt(0) }
    if ($State.ViewportOffset -gt 0) {
        $State.ViewportOffset = [Math]::Min($State.Scrollback.Count, $State.ViewportOffset + 1)
    }
}

function Move-TerminalNewLine {
    param($State)
    if ($State.CursorRow -eq $State.ScrollBottom) {
        if ($State.ScrollTop -eq 0 -and $State.ScrollBottom -eq $State.Rows - 1) {
            Add-TerminalScrollback $State $State.Screen[0]
        }
        $State.Screen.RemoveAt($State.ScrollTop)
        $State.Screen.Insert($State.ScrollBottom, (New-TerminalRow $State.Columns))
        for ([int] $row = $State.ScrollTop; $row -le $State.ScrollBottom; $row++) { [void]$State.DirtyRows.Add($row) }
    }
    else { $State.CursorRow++ }
}

function Get-TerminalGlyphWidth {
    param([Parameter(Mandatory)][string] $Text)
    [UnicodeCategory] $category = [CharUnicodeInfo]::GetUnicodeCategory($Text, 0)
    if ($category -in [UnicodeCategory]::NonSpacingMark, [UnicodeCategory]::SpacingCombiningMark,
        [UnicodeCategory]::EnclosingMark, [UnicodeCategory]::Control, [UnicodeCategory]::Format) { return 0 }
    [int] $codepoint = [char]::ConvertToUtf32($Text, 0)
    if (($codepoint -ge 0x1100 -and $codepoint -le 0x115F) -or
        ($codepoint -ge 0x2329 -and $codepoint -le 0x232A) -or
        ($codepoint -ge 0x2E80 -and $codepoint -le 0xA4CF) -or
        ($codepoint -ge 0xAC00 -and $codepoint -le 0xD7A3) -or
        ($codepoint -ge 0xF900 -and $codepoint -le 0xFAFF) -or
        ($codepoint -ge 0xFE10 -and $codepoint -le 0xFE6F) -or
        ($codepoint -ge 0xFF00 -and $codepoint -le 0xFF60) -or
        ($codepoint -ge 0x1F300 -and $codepoint -le 0x1FAFF)) { return 2 }
    return 1
}

function Set-TerminalGlyph {
    param($State, [Parameter(Mandatory)][string] $Glyph)
    [int] $width = Get-TerminalGlyphWidth $Glyph
    if ($width -eq 0) {
        [int] $column = [Math]::Max(0, $State.CursorColumn - 1)
        $State.Screen[$State.CursorRow].Cells[$column].Text += $Glyph
        [void]$State.DirtyRows.Add($State.CursorRow)
        return
    }
    if ($State.CursorColumn -ge $State.Columns -or ($width -eq 2 -and $State.CursorColumn -eq $State.Columns - 1)) {
        $State.Screen[$State.CursorRow].Wrapped = $true
        $State.CursorColumn = 0
        Move-TerminalNewLine $State
    }
    $cell = [pscustomobject]@{
        Text = $Glyph; Width = $width; Foreground = $State.Foreground; Background = $State.Background
        Bold = $State.Bold; Underline = $State.Underline; Inverse = $State.Inverse
        Hyperlink = $State.CurrentHyperlink
    }
    $State.Screen[$State.CursorRow].Cells[$State.CursorColumn] = $cell
    if ($width -eq 2) {
        $continuation = New-TerminalCell ''
        $continuation.Width = 0
        $State.Screen[$State.CursorRow].Cells[$State.CursorColumn + 1] = $continuation
    }
    $State.CursorColumn += $width
    [void]$State.DirtyRows.Add($State.CursorRow)
}

function Set-TerminalSgr {
    param($State, [int[]] $Parameter)
    if ($Parameter.Count -eq 0) { $Parameter = @(0) }
    for ([int] $index = 0; $index -lt $Parameter.Count; $index++) {
        [int] $value = $Parameter[$index]
        switch ($value) {
            0 { $State.Foreground = -1; $State.Background = -1; $State.Bold = $false; $State.Underline = $false; $State.Inverse = $false }
            1 { $State.Bold = $true }
            4 { $State.Underline = $true }
            7 { $State.Inverse = $true }
            22 { $State.Bold = $false }
            24 { $State.Underline = $false }
            27 { $State.Inverse = $false }
            { $_ -ge 30 -and $_ -le 37 } { $State.Foreground = $value - 30 }
            { $_ -ge 40 -and $_ -le 47 } { $State.Background = $value - 40 }
            { $_ -ge 90 -and $_ -le 97 } { $State.Foreground = $value - 90 + 8 }
            { $_ -ge 100 -and $_ -le 107 } { $State.Background = $value - 100 + 8 }
            39 { $State.Foreground = -1 }
            49 { $State.Background = -1 }
            { $_ -in 38,48 -and $index + 2 -lt $Parameter.Count -and $Parameter[$index + 1] -eq 5 } {
                if ($value -eq 38) { $State.Foreground = $Parameter[$index + 2] }
                else { $State.Background = $Parameter[$index + 2] }
                $index += 2
            }
        }
    }
}

function Set-TerminalAlternateScreen {
    param($State, [bool] $Enable)
    if ($Enable -and -not $State.Alternate) {
        $State.MainScreen = $State.Screen
        $State.MainScrollback = $State.Scrollback
        [List[object]] $screen = [List[object]]::new()
        for ([int] $row = 0; $row -lt $State.Rows; $row++) { $screen.Add((New-TerminalRow $State.Columns)) }
        $State.Screen = $screen; $State.Scrollback = [List[object]]::new()
        $State.SavedCursorRow = $State.CursorRow; $State.SavedCursorColumn = $State.CursorColumn
        $State.CursorRow = 0; $State.CursorColumn = 0; $State.Alternate = $true
    }
    elseif (-not $Enable -and $State.Alternate) {
        $State.Screen = $State.MainScreen; $State.Scrollback = $State.MainScrollback
        $State.CursorRow = $State.SavedCursorRow; $State.CursorColumn = $State.SavedCursorColumn
        $State.MainScreen = $null; $State.MainScrollback = $null; $State.Alternate = $false
    }
    for ([int] $row = 0; $row -lt $State.Rows; $row++) { [void]$State.DirtyRows.Add($row) }
}

function Invoke-TerminalCsi {
    param($State, [string] $Body, [char] $Final)
    [bool] $private = $Body.StartsWith('?')
    if ($private) { $Body = $Body.Substring(1) }
    [List[int]] $parameterValues = [List[int]]::new()
    if ($Body.Length) {
        foreach ($item in $Body.Split(';')) { $parameterValues.Add($(if ($item -eq '') { 0 } else { [int]$item })) }
    }
    [int[]] $parameter = $parameterValues.ToArray()
    [int] $first = if ($parameter.Count -and $parameter[0] -gt 0) { $parameter[0] } else { 1 }
    switch ($Final) {
        'A' { $State.CursorRow = [Math]::Max($State.ScrollTop, $State.CursorRow - $first) }
        'B' { $State.CursorRow = [Math]::Min($State.ScrollBottom, $State.CursorRow + $first) }
        'C' { $State.CursorColumn = [Math]::Min($State.Columns - 1, $State.CursorColumn + $first) }
        'D' { $State.CursorColumn = [Math]::Max(0, $State.CursorColumn - $first) }
        { $_ -in 'H','f' } {
            [int] $row = if ($parameter.Count -gt 0 -and $parameter[0] -gt 0) { $parameter[0] } else { 1 }
            [int] $column = if ($parameter.Count -gt 1 -and $parameter[1] -gt 0) { $parameter[1] } else { 1 }
            $State.CursorRow = [Math]::Clamp($row - 1, 0, $State.Rows - 1)
            $State.CursorColumn = [Math]::Clamp($column - 1, 0, $State.Columns - 1)
        }
        'J' {
            [int] $mode = if ($parameter.Count) { $parameter[0] } else { 0 }
            if ($mode -in 2,3) { for ([int]$row=0; $row -lt $State.Rows; $row++) { Clear-TerminalRow $State $row }; $State.CursorRow=0; $State.CursorColumn=0 }
            elseif ($mode -eq 0) { Clear-TerminalRow $State $State.CursorRow $State.CursorColumn; for ([int]$row=$State.CursorRow+1;$row -lt $State.Rows;$row++){Clear-TerminalRow $State $row} }
            elseif ($mode -eq 1) { for ([int]$row=0;$row -lt $State.CursorRow;$row++){Clear-TerminalRow $State $row}; Clear-TerminalRow $State $State.CursorRow 0 $State.CursorColumn }
        }
        'K' {
            [int] $mode = if ($parameter.Count) { $parameter[0] } else { 0 }
            if ($mode -eq 0) { Clear-TerminalRow $State $State.CursorRow $State.CursorColumn }
            elseif ($mode -eq 1) { Clear-TerminalRow $State $State.CursorRow 0 $State.CursorColumn }
            else { Clear-TerminalRow $State $State.CursorRow }
        }
        'm' { Set-TerminalSgr $State $parameter }
        'r' {
            [int] $top = if ($parameter.Count -gt 0 -and $parameter[0]) { $parameter[0] - 1 } else { 0 }
            [int] $bottom = if ($parameter.Count -gt 1 -and $parameter[1]) { $parameter[1] - 1 } else { $State.Rows - 1 }
            if ($top -lt $bottom -and $bottom -lt $State.Rows) { $State.ScrollTop=$top; $State.ScrollBottom=$bottom; $State.CursorRow=$top; $State.CursorColumn=0 }
        }
        's' { $State.SavedCursorRow=$State.CursorRow; $State.SavedCursorColumn=$State.CursorColumn }
        'u' { $State.CursorRow=$State.SavedCursorRow; $State.CursorColumn=$State.SavedCursorColumn }
        'n' { if ($first -eq 6) { $State.Replies.Add("`e[$($State.CursorRow+1);$($State.CursorColumn+1)R") } }
        'h' { if ($private) { foreach($mode in $parameter){[void]$State.Modes.Add("?$mode"); if($mode -eq 1049){Set-TerminalAlternateScreen $State $true}} } }
        'l' { if ($private) { foreach($mode in $parameter){[void]$State.Modes.Remove("?$mode"); if($mode -eq 1049){Set-TerminalAlternateScreen $State $false}} } }
    }
}

function Invoke-TerminalOsc {
    param($State, [string] $Body)
    [string[]] $part = $Body.Split(';', 3)
    if ($part[0] -in '0','2' -and $part.Count -gt 1) { $State.Title = $part[1] }
    elseif ($part[0] -eq '8') { $State.CurrentHyperlink = if ($part.Count -gt 2 -and $part[2]) { $part[2] } else { $null } }
}

function Add-TerminalText {
    param($State, [AllowEmptyString()][string] $Text)
    [string] $data = $State.ParserPending + $Text
    $State.ParserPending = ''
    for ([int] $index = 0; $index -lt $data.Length;) {
        [char] $character = $data[$index]
        if ($character -eq "`e") {
            if ($index + 1 -ge $data.Length) { $State.ParserPending = $data.Substring($index); break }
            if ($data[$index + 1] -eq '[') {
                [int] $final = $index + 2
                while ($final -lt $data.Length -and ([int][char]$data[$final] -lt 0x40 -or [int][char]$data[$final] -gt 0x7e)) { $final++ }
                if ($final -ge $data.Length) { $State.ParserPending = $data.Substring($index); break }
                Invoke-TerminalCsi $State $data.Substring($index + 2, $final - $index - 2) $data[$final]
                $index = $final + 1; continue
            }
            if ($data[$index + 1] -eq ']') {
                [int] $end = $data.IndexOf("`a", $index + 2)
                [int] $st = $data.IndexOf("`e\", $index + 2, [StringComparison]::Ordinal)
                if ($end -lt 0 -or ($st -ge 0 -and $st -lt $end)) { $end = $st }
                if ($end -lt 0) { $State.ParserPending = $data.Substring($index); break }
                Invoke-TerminalOsc $State $data.Substring($index + 2, $end - $index - 2)
                $index = if ($end -eq $st) { $end + 2 } else { $end + 1 }; continue
            }
            $index += 2; continue
        }
        switch ([int]$character) {
            7 { $index++; continue }
            8 { $State.CursorColumn=[Math]::Max(0,$State.CursorColumn-1); $index++; continue }
            9 { $State.CursorColumn=[Math]::Min($State.Columns-1,([Math]::Floor($State.CursorColumn/8)+1)*8); $index++; continue }
            10 { Move-TerminalNewLine $State; $index++; continue }
            13 { $State.CursorColumn=0; $index++; continue }
        }
        if ([char]::IsControl($character)) { $index++; continue }
        [int] $length = if ([char]::IsHighSurrogate($character) -and $index + 1 -lt $data.Length -and [char]::IsLowSurrogate($data[$index+1])) { 2 } else { 1 }
        [string] $glyph = $data.Substring($index, $length)
        $index += $length
        while ($index -lt $data.Length -and [CharUnicodeInfo]::GetUnicodeCategory($data, $index) -in
            [UnicodeCategory]::NonSpacingMark,[UnicodeCategory]::SpacingCombiningMark,[UnicodeCategory]::EnclosingMark) {
            $glyph += $data[$index]; $index++
        }
        Set-TerminalGlyph $State $glyph
    }
}

function Get-TerminalRowText {
    param($Row, [switch] $TrimEnd)
    [string] $text = ''
    foreach ($cell in $Row.Cells) { if ($cell.Width -ne 0) { $text += $cell.Text } }
    if ($TrimEnd) { return $text.TrimEnd() }
    return $text
}

function Set-TerminalSize {
    param($State, [ValidateRange(2,1000)][int] $Columns, [ValidateRange(2,1000)][int] $Rows)
    if ($Columns -eq $State.Columns -and $Rows -eq $State.Rows) { return }
    [List[string]] $logical = [List[string]]::new()
    [string] $current = ''
    foreach ($row in @($State.Scrollback) + @($State.Screen)) {
        $current += Get-TerminalRowText $row -TrimEnd:(!$row.Wrapped)
        if (-not $row.Wrapped) { $logical.Add($current); $current = '' }
    }
    if ($current.Length) { $logical.Add($current) }
    $State.Columns = $Columns; $State.Rows = $Rows; $State.ScrollTop=0; $State.ScrollBottom=$Rows-1
    $State.Scrollback = [List[object]]::new(); $State.Screen = [List[object]]::new()
    for ([int]$row=0;$row -lt $Rows;$row++){$State.Screen.Add((New-TerminalRow $Columns))}
    $State.CursorRow=0; $State.CursorColumn=0
    foreach ($line in $logical) { Add-TerminalText $State ($line + "`r`n") }
    if ($State.CursorRow -gt 0 -and $State.CursorColumn -eq 0) { $State.CursorRow-- }
    for ([int]$row=0;$row -lt $Rows;$row++){[void]$State.DirtyRows.Add($row)}
}

function Set-TerminalSelection {
    param($State, [int]$StartRow, [int]$StartColumn, [int]$EndRow, [int]$EndColumn)
    $State.SelectionStart = [pscustomobject]@{Row=$StartRow;Column=$StartColumn}
    $State.SelectionEnd = [pscustomobject]@{Row=$EndRow;Column=$EndColumn}
}

function Get-TerminalSelectionText {
    param($State)
    if ($null -eq $State.SelectionStart -or $null -eq $State.SelectionEnd) { return '' }
    $all = @($State.Scrollback) + @($State.Screen)
    [int]$startRow=[Math]::Min($State.SelectionStart.Row,$State.SelectionEnd.Row)
    [int]$endRow=[Math]::Max($State.SelectionStart.Row,$State.SelectionEnd.Row)
    [List[string]]$text=[List[string]]::new()
    for([int]$row=$startRow;$row -le $endRow -and $row -lt $all.Count;$row++){
        [int]$left=if($row -eq $State.SelectionStart.Row){$State.SelectionStart.Column}else{0}
        [int]$right=if($row -eq $State.SelectionEnd.Row){$State.SelectionEnd.Column}else{$State.Columns-1}
        if($left -gt $right){$swap=$left;$left=$right;$right=$swap}
        [string]$line=''; for([int]$column=$left;$column -le $right -and $column -lt $all[$row].Cells.Count;$column++){if($all[$row].Cells[$column].Width -ne 0){$line+=$all[$row].Cells[$column].Text}}
        $text.Add($line.TrimEnd())
    }
    return ($text -join "`n")
}

function Set-TerminalComposition {
    param($State, [string]$Text, [string]$Composition)
    $State.InputText=$Text; $State.Composition=$Composition
    [void]$State.DirtyRows.Add($State.Rows-1)
}

function Get-TerminalViewportRows {
    param($State)
    $all=@($State.Scrollback)+@($State.Screen)
    [int]$end=[Math]::Max(0,$all.Count-$State.ViewportOffset)
    [int]$start=[Math]::Max(0,$end-$State.Rows)
    return @($all[$start..([Math]::Max($start,$end-1))])
}
