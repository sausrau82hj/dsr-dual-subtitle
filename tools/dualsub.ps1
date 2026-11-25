<#
DARK SOULS: REMASTERED dual-language text builder (Windows PowerShell 5.1, no Python).

Reads msg packs from <source>\msg\<LANG>\*.msgbnd.dcx, merges the two languages entry by
entry, and writes the repacked packs to <out>\msg\<LANG>\. Each slot keeps its own language
on top: the English client shows English over Chinese, the Chinese client the reverse.

All container work (DCX, BND3, FMG) is done by Yabber; this script only walks folders, edits
the FMG XML and calls Yabber to repack.

Usage:
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Filter menu
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Source "D:\...\DARK SOULS REMASTERED" -Out stage
#>
[CmdletBinding()]
param(
    [string]$Source,
    [Alias('Output')][string]$Out,
    [string]$Config,
    [string]$Yabber,
    [string]$Primary,
    [string]$Secondary,
    [string]$Filter,
    [string]$Game,
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$ScriptDir = $PSScriptRoot
$PackRoot = if ((Split-Path -Leaf $ScriptDir).ToLowerInvariant() -eq 'tools') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
$DefaultConfig = Join-Path $ScriptDir 'dualsub.config.json'

$YabberHelp = @"
Yabber not found.
  Extract Yabber anywhere under this package's root folder, or pass -Yabber <dir>,
  set "yabber_dir" in the config, or set the YABBER_DIR environment variable.
  The folder must hold both Yabber.exe and Yabber.DCX.exe.
  Download: https://github.com/JKAnderson/Yabber/releases
"@

$CategoryRules = @(
    @{ Name = 'Dialogue';           Patterns = @('Conversation_*') }
    @{ Name = 'Cutscene Subtitles'; Patterns = @('Movie_subtitles_*') }
    @{ Name = 'Dialogue Boxes';     Patterns = @('Dialogue_*') }
    @{ Name = 'Event Text';         Patterns = @('Event_text_*') }
    @{ Name = 'Menu Text';          Patterns = @('Menu_general_text_*', 'Menu_others_*', 'Ingame_menu_*', 'Text_display_*') }
    @{ Name = 'Key Prompts';        Patterns = @('Key_guide_*') }
    @{ Name = 'Help Text';          Patterns = @('Item_help_*', 'Single_line_help_*') }
    @{ Name = 'System Messages';    Patterns = @('System_message_*', 'System_specific_tags_*') }
    @{ Name = 'Blood Messages';     Patterns = @('Blood_writing_*') }
    @{ Name = 'Place Names';        Patterns = @('Place_name_*') }
    @{ Name = 'Item Names';         Patterns = @('*_name_*') }
    @{ Name = 'Item Descriptions';  Patterns = @('*_description_*', '*_long_desc_*') }
)

$DefaultCategories = [ordered]@{
    'Dialogue'           = $true
    'Cutscene Subtitles' = $true
    'Dialogue Boxes'     = 'off'
    'Event Text'         = 'off'
    'Menu Text'          = 'off'
    'Key Prompts'        = 'off'
    'Help Text'          = 'off'
    'System Messages'    = 'off'
    'Blood Messages'     = 'off'
    'Place Names'        = 'off'
    'Item Names'         = 'off'
    'Item Descriptions'  = 'off'
}

# Paragraph widgets keep a newline between the languages; one-line widgets take the inline
# separator; everything else follows the entry itself (a newline only where the source has one).
$MultilineFmgs = @('Conversation_*', 'Movie_subtitles_*', 'Dialogue_*', '*_long_desc_')
$OneLineFmgs = @('*_name_*', 'Place_name_*', 'NPC_name_*', 'Key_guide_*', 'Single_line_help_*',
                 'Item_help_*', '*_description_*', 'System_specific_tags_*', 'Text_display_tag_list_*')

function Write-Log { param([string]$Message) Write-Host $Message }

function Fail {
    param([string]$Message)
    Write-Host $Message
    exit 1
}

function Get-Prop {
    param($Node, [string]$Key, $Default)
    if ($null -eq $Node) { return $Default }
    if ($Node -is [System.Collections.IDictionary] -and $Node.Contains($Key)) { return $Node[$Key] }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $p = $Node.PSObject.Properties[$Key]
        if ($p) { return $p.Value }
    }
    return $Default
}

function ConvertTo-Hashtable {
    param($Object)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        $h = [ordered]@{}
        foreach ($k in @($Object.Keys)) { $h[$k] = ConvertTo-Hashtable $Object[$k] }
        return $h
    }
    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $Object.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
        return $h
    }
    if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        $list = New-Object System.Collections.ArrayList
        foreach ($item in $Object) { [void]$list.Add((ConvertTo-Hashtable $item)) }
        return , $list.ToArray()
    }
    return $Object
}

function Get-Stem {
    param([string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    foreach ($suffix in @('.msgbnd.dcx', '.msgbnd')) {
        if ($name.ToLowerInvariant().EndsWith($suffix)) { return $name.Substring(0, $name.Length - $suffix.Length) }
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($name)
}

function Sort-Ordinal {
    param([string[]]$Items)
    $copy = [string[]]$Items.Clone()
    [Array]::Sort($copy, [System.StringComparer]::OrdinalIgnoreCase)
    return , $copy
}

function Find-Yabber {
    param([string]$Hint)
    $cands = New-Object System.Collections.Generic.List[string]
    if ($Hint) { $cands.Add($Hint) }
    if ($env:YABBER_DIR) { $cands.Add($env:YABBER_DIR) }
    $cmd = Get-Command 'Yabber.exe' -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $cands.Add((Split-Path -Parent $cmd.Source)) }
    $roots = @($PackRoot, (Join-Path $PackRoot 'tools'), 'D:\game\TOOL', 'D:\Tools', 'D:\tool',
               'C:\Tools', 'C:\tool', $env:LOCALAPPDATA, (Join-Path $HOME 'Downloads'), $HOME)
    foreach ($root in $roots) {
        if (-not $root) { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $root -Directory -Filter 'Yabber*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $cands.Add($f.FullName)
        }
        foreach ($d in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)) {
            foreach ($f in @(Get-ChildItem -LiteralPath $d.FullName -Directory -Filter 'Yabber*' -ErrorAction SilentlyContinue | Sort-Object Name)) {
                $cands.Add($f.FullName)
            }
        }
    }
    foreach ($c in $cands) {
        if (-not $c) { continue }
        if ((Test-Path -LiteralPath (Join-Path $c 'Yabber.exe') -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $c 'Yabber.DCX.exe') -PathType Leaf)) {
            return [System.IO.Path]::GetFullPath($c)
        }
    }
    Fail $YabberHelp
}

function Get-DefaultGame {
    if ($env:DSR_GAME_DIR -and (Test-Path -LiteralPath (Join-Path $env:DSR_GAME_DIR 'DarkSoulsRemastered.exe'))) {
        return $env:DSR_GAME_DIR
    }
    $roots = New-Object System.Collections.Generic.List[string]
    try {
        $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath
        if ($steam) {
            $roots.Add($steam)
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf -PathType Leaf) {
                $text = Get-Content -LiteralPath $vdf -Raw -ErrorAction SilentlyContinue
                if ($text) {
                    foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                        $roots.Add(($m.Groups[1].Value -replace '\\\\', '\'))
                    }
                }
            }
        }
    } catch { }
    foreach ($r in @('D:\steam\steamapps\common', 'E:\steam\steamapps\common',
                     'F:\steam\steamapps\common', 'C:\Program Files (x86)\Steam\steamapps\common')) {
        $roots.Add($r)
    }
    foreach ($r in $roots) {
        $cand = Join-Path $r 'DARK SOULS REMASTERED'
        if (Test-Path -LiteralPath (Join-Path $cand 'DarkSoulsRemastered.exe') -PathType Leaf) { return $cand }
    }
    return 'D:\steam\steamapps\common\DARK SOULS REMASTERED'
}

function Invoke-Yabber {
    param($Yabber, [string]$Tool, [string]$Path)
    $null = & $Tool $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Yabber failed: $Path (exit $LASTEXITCODE)" }
}

function Expand-Pack {
    param($Yabber, [string]$DcxPath, [string]$WorkDir)
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    $dcx = Join-Path $WorkDir (Split-Path -Leaf $DcxPath)
    Copy-Item -LiteralPath $DcxPath -Destination $dcx -Force
    Invoke-Yabber $Yabber $Yabber.Dcx $dcx
    $msgbnd = $dcx.Substring(0, $dcx.Length - 4)
    Invoke-Yabber $Yabber $Yabber.Exe $msgbnd
    $unpacked = Join-Path $WorkDir (([System.IO.Path]::GetFileNameWithoutExtension($msgbnd)) + '-msgbnd')
    $fmgDir = Get-ChildItem -LiteralPath $unpacked -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { Get-ChildItem -LiteralPath $_.FullName -Filter *.fmg -File -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $fmgDir) { throw "No FMG found in $unpacked" }
    return [pscustomobject]@{ Unpacked = $unpacked; FmgDir = $fmgDir.FullName; Msgbnd = $msgbnd }
}

function ConvertTo-Lf {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Get-TextMap {
    param($Yabber, [string]$FmgDir, [string]$Fmg)
    $path = Join-Path $FmgDir $Fmg
    Invoke-Yabber $Yabber $Yabber.Exe $path
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($path + '.xml')
    $map = @{}
    foreach ($el in $doc.SelectNodes('/fmg/entries/text')) {
        $map[$el.GetAttribute('id')] = ConvertTo-Lf $el.InnerText
    }
    return $map
}

function Get-Category {
    param([string]$Fmg)
    $base = [System.IO.Path]::GetFileName($Fmg)
    foreach ($rule in $CategoryRules) {
        foreach ($p in $rule.Patterns) {
            if ($base -like $p) { return $rule.Name }
        }
    }
    return 'Other'
}

function Get-ValueMode {
    param($Value)
    if ($Value -is [System.Collections.IDictionary]) {
        $mode = Get-Prop $Value 'mode' $null
        if ($mode) { return [string]$mode }
        $enabled = Get-Prop $Value 'enabled' $null
        if ($null -ne $enabled) { return $(if ($enabled) { 'append' } else { 'off' }) }
        return 'append'
    }
    if ($Value -is [string]) { return $Value.Trim() }
    if ($Value -is [bool]) { return $(if ($Value) { 'append' } else { 'off' }) }
    return $(if ($Value) { 'append' } else { 'off' })
}

function Get-Mode {
    param($Cfg, [string]$Pack, [string]$Fmg)
    $files = Get-Prop $Cfg 'files' @{}
    $packNode = Get-Prop $files (Get-Stem $Pack) $null
    if ($packNode) {
        if (-not (Get-Prop $packNode 'enabled' $true)) { return 'off' }
        $rules = Get-Prop $packNode 'fmg' @{}
        foreach ($k in @($rules.Keys)) {
            if ($Fmg -like $k) { return (Get-ValueMode $rules[$k]) }
        }
    }
    $cats = Get-Prop $Cfg 'categories' $null
    if ($cats) {
        $v = Get-Prop $cats (Get-Category $Fmg) $null
        if ($null -ne $v) { return (Get-ValueMode $v) }
    }
    return 'off'
}

function Get-InlineSep {
    param($Cfg)
    $sep = Get-Prop $Cfg 'separator' ' / '
    if ($sep -eq '\n') { return "`n" }
    if (-not $sep) { return ' / ' }
    return [string]$sep
}

function Get-SeparatorFor {
    param($Cfg, [string]$Pack, [string]$Fmg)
    $base = [System.IO.Path]::GetFileName($Fmg)
    $files = Get-Prop $Cfg 'files' @{}
    $packNode = Get-Prop $files (Get-Stem $Pack) $null
    if ($packNode) {
        $rules = Get-Prop $packNode 'fmg' @{}
        foreach ($k in @($rules.Keys)) {
            if ($Fmg -like $k) {
                $v = $rules[$k]
                if ($v -is [System.Collections.IDictionary]) {
                    $s = Get-Prop $v 'separator' $null
                    if ($null -ne $s) {
                        if ($s -eq '\n') { return "`n" }
                        return [string]$s
                    }
                }
            }
        }
    }
    foreach ($p in $MultilineFmgs) { if ($base -like $p) { return "`n" } }
    $inline = Get-InlineSep $Cfg
    foreach ($p in $OneLineFmgs) { if ($base -like $p) { return $inline } }
    return $null
}

function Test-IsNull {
    param([string]$Text)
    if ($null -eq $Text) { return $true }
    $n = $Text.Trim().ToLowerInvariant()
    return ($n -eq '' -or $n -eq 'null' -or $n -eq '%null%')
}

function Get-Norm {
    param([string]$Text)
    return ($Text -replace '\s+', '').ToLowerInvariant()
}

function Get-TextUnits {
    param([string]$Text)
    $n = 0
    foreach ($ch in $Text.ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 0x1100 -and $c -le 0x115F) -or ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0xF900 -and $c -le 0xFAFF) -or
            ($c -ge 0xFE30 -and $c -le 0xFE4F) -or ($c -ge 0xFF00 -and $c -le 0xFF60) -or
            ($c -ge 0xFFE0 -and $c -le 0xFFE6) -or ($c -ge 0x3000 -and $c -le 0x303F)) { $n += 2 }
        else { $n += 1 }
    }
    return $n
}

function Get-RenderedLines {
    param([string]$Text, [int]$Width)
    $total = 0
    foreach ($line in $Text.Split("`n")) {
        $total += [Math]::Max(1, [int][Math]::Ceiling((Get-TextUnits $line) / $Width))
    }
    return $total
}

function Join-Flat {
    param([string]$Text)
    $parts = $Text.Split("`n")
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $p = $parts[$i].Trim()
        if ($i -eq 0) { [void]$sb.Append($p); continue }
        $prevLine = $parts[$i - 1].TrimEnd()
        $prev = if ($prevLine.Length -gt 0) { $prevLine.Substring($prevLine.Length - 1) } else { '' }
        if ($prev -and (Get-TextUnits $prev) -eq 2) { [void]$sb.Append($p) }
        else { [void]$sb.Append(' ').Append($p) }
    }
    return $sb.ToString()
}

# The NPC dialogue box holds three lines, the cutscene subtitle strip two, the item detail panel
# about seventeen. Only these fit their box; every other widget is merged as-is.
function Get-FitSpec {
    param([string]$Fmg)
    if ($Fmg -eq 'Conversation_.fmg') { return @{ Max = 3; Width = 60; Preview = $false } }
    if ($Fmg -eq 'Movie_subtitles_.fmg') { return @{ Max = 2; Width = 62; Preview = $false } }
    if ($Fmg -like '*_long_desc_*') { return @{ Max = 18; Width = 60; Preview = $true } }
    return $null
}

function Get-PreviewText {
    param([string]$Text, [int]$Width, [int]$MaxLines)
    $out = New-Object System.Collections.Generic.List[string]
    $used = 0
    foreach ($line in ($Text -split "`n")) {
        $trim = $line.TrimEnd()
        if ($trim.Trim() -eq '') {
            if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne '') { $out.Add(''); $used++ }
            continue
        }
        $need = [Math]::Max(1, [int][Math]::Ceiling((Get-TextUnits $trim) / $Width))
        if ($used + $need -gt $MaxLines) {
            if ($out.Count -gt 0) { $out[$out.Count - 1] = $out[$out.Count - 1].TrimEnd() + '...' }
            break
        }
        $out.Add($trim)
        $used += $need
    }
    return ($out -join "`n")
}

function Get-MergedText {
    param([string]$Top, [string]$Bottom, [string]$Inline, $Fit)
    if (-not $Fit) { return $null }
    $stacked = $Top + "`n" + $Bottom
    if ((Get-RenderedLines $stacked $Fit.Width) -le $Fit.Max) { return $stacked }
    if (-not $Fit.Preview) {
        $flat = (($(Join-Flat $Top) + $Inline + $(Join-Flat $Bottom)) -replace '\s{2,}', ' ').Trim()
        if ((Get-RenderedLines $flat $Fit.Width) -le $Fit.Max) { return $flat }
        if ((Get-RenderedLines $flat $Fit.Width) -le (Get-RenderedLines $stacked $Fit.Width)) { return $flat }
        return $stacked
    }
    # Long descriptions: the primary language in full, the secondary cut where the panel ends,
    # keeping its own line breaks and a trailing ellipsis.
    $topLines = Get-RenderedLines $Top $Fit.Width
    $budget = $Fit.Max - $topLines
    if ($budget -lt 2) { $budget = 2 }
    $preview = Get-PreviewText $Bottom $Fit.Width $budget
    if (-not $preview) { return $Top }
    return ($Top + "`n" + $preview)
}

function Test-NarrowLabel {
    param([string]$Fmg, [string]$Top, [string]$Bottom, [string]$Inline)
    # Interaction prompts and menu labels sit in fields one short label wide: the merged line
    # would run past the field, so those keep the game's own language only.
    if ($Fmg -notlike 'Event_text_*') { return $false }
    $width = [Math]::Min((Get-TextUnits $Top), (Get-TextUnits $Bottom))
    if ($width -gt 12) { return $false }
    return ((Get-TextUnits ($Top + $Inline + $Bottom)) -gt 24)
}

function Test-AlreadyMerged {
    param([string]$T1, [string]$T2, [string]$Sep)
    if (-not $Sep) { return $false }
    if ($T1.EndsWith($Sep + $T2) -or $T2.EndsWith($Sep + $T1)) { return $true }
    $pattern = [regex]::Escape($Sep)
    $a = [string[]]@($T1 -split $pattern)
    $b = [string[]]@($T2 -split $pattern)
    if ($a.Count -le 1 -or $b.Count -le 1 -or $a.Count -ne $b.Count) { return $false }
    $sa = [string[]]$a.Clone()
    $sb = [string[]]$b.Clone()
    [Array]::Sort($sa, [System.StringComparer]::Ordinal)
    [Array]::Sort($sb, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $sa.Count; $i++) { if ($sa[$i] -ne $sb[$i]) { return $false } }
    return $true
}

function Write-Fmg {
    param([System.Xml.XmlDocument]$Doc, [string]$Path)
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::None
    $settings.Indent = $false
    $settings.Encoding = New-Object System.Text.UTF8Encoding($true)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $Doc.Save($writer) } finally { $writer.Close() }
}

function Update-Fmg {
    param($Yabber, [string]$FmgDir, [string]$Fmg, $TopMap, $BottomMap, [string]$Mode, $Sep, [string]$Inline)
    $path = Join-Path $FmgDir $Fmg
    $xml = $path + '.xml'
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($xml)
    $changed = 0
    $fit = Get-FitSpec $Fmg
    foreach ($el in $doc.SelectNodes('/fmg/entries/text')) {
        $id = $el.GetAttribute('id')
        $top = if ($TopMap.ContainsKey($id)) { [string]$TopMap[$id] } else { '' }
        $bottom = if ($BottomMap.ContainsKey($id)) { [string]$BottomMap[$id] } else { '' }
        if (Test-IsNull $bottom) { continue }
        if ($Mode -eq 'sec_only') {
            if ($top -ceq $bottom) { continue }
            $el.InnerText = $bottom
            $changed++
            continue
        }
        if (Test-IsNull $top) { continue }
        if ((Get-Norm $top) -eq (Get-Norm $bottom)) { continue }
        $useSep = $Sep
        if ($null -eq $useSep) {
            if ($top.Contains("`n") -or $bottom.Contains("`n")) { $useSep = "`n" } else { $useSep = $Inline }
        }
        if (Test-AlreadyMerged $top $bottom $useSep) { continue }
        if (Test-NarrowLabel $Fmg $top $bottom $Inline) { continue }
        $text = $null
        if ($fit) { $text = Get-MergedText $top $bottom $Inline $fit }
        if (-not $text) { $text = $top + $useSep + $bottom }
        $el.InnerText = $text
        $changed++
    }
    if ($changed -gt 0) {
        Write-Fmg $doc $xml
        Invoke-Yabber $Yabber $Yabber.Exe $xml
    }
    return $changed
}

function Get-PackNames {
    param([string]$Root, [string]$LangA, [string]$LangB)
    $a = Join-Path $Root "msg\$LangA"
    $b = Join-Path $Root "msg\$LangB"
    $names = @{}
    foreach ($f in Get-ChildItem -LiteralPath $a -File -ErrorAction SilentlyContinue) {
        if ($f.Name.ToLowerInvariant().EndsWith('.msgbnd.dcx')) { $names[$f.Name.ToLowerInvariant()] = $f.Name }
    }
    $have = @{}
    foreach ($f in Get-ChildItem -LiteralPath $b -File -ErrorAction SilentlyContinue) { $have[$f.Name.ToLowerInvariant()] = $true }
    $res = New-Object System.Collections.Generic.List[string]
    foreach ($k in @($names.Keys)) { if ($have.ContainsKey($k)) { $res.Add($names[$k]) } }
    return (Sort-Ordinal $res.ToArray())
}

# ---- main ----

$interactive = ($PSBoundParameters.Count -eq 0)
$cfgPath = if ($Config) { $Config } else { $DefaultConfig }
if (-not (Test-Path -LiteralPath $cfgPath -PathType Leaf)) { Fail "Config not found: $cfgPath" }
$fromFile = ConvertTo-Hashtable (Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json)
$cfg = [ordered]@{}
$cfg['categories'] = [ordered]@{}
foreach ($k in $DefaultCategories.Keys) { $cfg['categories'][$k] = $DefaultCategories[$k] }
foreach ($k in @($fromFile.Keys)) {
    if ($k -eq 'categories') {
        foreach ($c in @($fromFile['categories'].Keys)) { $cfg['categories'][$c] = $fromFile['categories'][$c] }
    } else {
        $cfg[$k] = $fromFile[$k]
    }
}
if ($Primary) { $cfg['primary'] = $Primary }
if ($Secondary) { $cfg['secondary'] = $Secondary }
$primaryLang = if ($cfg['primary']) { [string]$cfg['primary'] } else { 'SCHINESE' }
$secondaryLang = if ($cfg['secondary']) { [string]$cfg['secondary'] } else { 'ENGLISH' }

$srcDir = if ($Source) { $Source } elseif (Test-Path -LiteralPath (Join-Path $PackRoot 'source') -PathType Container) { Join-Path $PackRoot 'source' } else { $null }
if (-not $srcDir) { Fail 'No source folder: the package holds source\, or pass -Source <game folder>.' }
if (-not (Test-Path -LiteralPath (Join-Path $srcDir 'msg') -PathType Container)) { Fail "Text packs not found: $(Join-Path $srcDir 'msg')" }
$outDir = if ($Out) { $Out } else { $PackRoot }
$gameDir = if ($Game) { $Game } else { Get-DefaultGame }

$yabberDir = if ($Yabber) { $Yabber } elseif ($cfg['yabber_dir']) { [string]$cfg['yabber_dir'] } else { Find-Yabber '' }
$y = @{ Exe = (Join-Path $yabberDir 'Yabber.exe'); Dcx = (Join-Path $yabberDir 'Yabber.DCX.exe'); Dir = $yabberDir }
if (-not (Test-Path -LiteralPath $y.Exe) -or -not (Test-Path -LiteralPath $y.Dcx)) { Fail "Yabber not found in: $yabberDir`n$YabberHelp" }

$langs = @($secondaryLang, $primaryLang)
$packs = Get-PackNames $srcDir $primaryLang $secondaryLang
if ($Filter) { $packs = @($packs | Where-Object { (Get-Stem $_) -like $Filter }) }
if (-not $packs -or $packs.Count -eq 0) { Fail 'No text packs to process' }

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Log "Source: $srcDir"
Write-Log "Output: $outDir"
Write-Log "Text: $primaryLang + $secondaryLang, slots $($langs -join ', '), $($packs.Count) packs"
Write-Log ''

$totalFmg = 0
$totalEntries = 0

foreach ($pack in $packs) {
    $stem = Get-Stem $pack
    Write-Log "[$stem]"
    $workRoot = Join-Path $outDir "_work\$stem"
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }

    $dirs = @{}
    $texts = @{}
    foreach ($lang in $langs) {
        $src = Join-Path $srcDir "msg\$lang\$pack"
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
        $dir = Expand-Pack $y $src (Join-Path $workRoot $lang)
        $dirs[$lang] = $dir
        $maps = @{}
        foreach ($fmg in (Get-ChildItem -LiteralPath $dir.FmgDir -Filter *.fmg -File | Sort-Object Name | ForEach-Object Name)) {
            $maps[$fmg] = Get-TextMap $y $dir.FmgDir $fmg
        }
        $texts[$lang] = $maps
    }

    $packEntries = 0
    foreach ($lang in $langs) {
        if (-not $dirs.ContainsKey($lang)) { continue }
        $other = if ($lang -eq $primaryLang) { $secondaryLang } else { $primaryLang }
        if (-not $dirs.ContainsKey($other)) { continue }
        $changed = 0
        foreach ($fmg in (Get-ChildItem -LiteralPath $dirs[$lang].FmgDir -Filter *.fmg -File | Sort-Object Name | ForEach-Object Name)) {
            if (-not $texts[$other].ContainsKey($fmg)) { continue }
            $mode = Get-Mode $cfg $pack $fmg
            if ($mode -eq 'off') { continue }
            $sep = Get-SeparatorFor $cfg $pack $fmg
            $n = Update-Fmg $y $dirs[$lang].FmgDir $fmg $texts[$lang][$fmg] $texts[$other][$fmg] $mode $sep (Get-InlineSep $cfg)
            if ($n -gt 0) {
                $changed += $n
                $totalFmg++
                Write-Log "  + $lang/$fmg`: $n entries"
            }
        }
        if ($changed -eq 0) { Write-Log "  = $lang`: nothing to merge"; continue }
        $packEntries += $changed
        Invoke-Yabber $y $y.Exe $dirs[$lang].Unpacked
        Invoke-Yabber $y $y.Dcx $dirs[$lang].Msgbnd
        $dst = Join-Path $outDir "msg\$lang\$pack"
        New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
        Copy-Item -LiteralPath ($dirs[$lang].Msgbnd + '.dcx') -Destination $dst -Force
        Write-Log "  -> $dst"
    }
    $totalEntries += $packEntries
    if ($packEntries -eq 0) { Write-Log "  = $stem stays vanilla, not installed" }
    if (-not $KeepWork) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Log ''
}

$fontFiles = @('TalkFont24.ccm.dcx', 'TalkFont24.tpf.dcx')
$uiOn = $false
foreach ($name in $cfg['categories'].Keys) {
    if ($name -in @('Dialogue', 'Cutscene Subtitles')) { continue }
    if ((Get-ValueMode $cfg['categories'][$name]) -ne 'off') { $uiOn = $true }
}
if ($uiOn) { $fontFiles += @('DSFont24.ccm.dcx', 'DSFont24.tpf.dcx') }
# Every slot shows Chinese somewhere, so every non-Chinese slot needs the Chinese atlas; the
# Chinese slot already has it.
$cjkLang = 'SCHINESE'
$fontSrcDir = Join-Path $gameDir ("font\" + $cjkLang.ToLowerInvariant())
foreach ($lang in $langs) {
    if ($lang -eq $cjkLang) { continue }
    $fontDst = Join-Path $outDir ("font\" + $lang)
    New-Item -ItemType Directory -Path $fontDst -Force | Out-Null
    foreach ($f in $fontFiles) {
        $src = Join-Path $fontSrcDir $f
        if (Test-Path -LiteralPath $src -PathType Leaf) {
            Copy-Item -LiteralPath $src -Destination (Join-Path $fontDst $f) -Force
        } elseif (-not (Test-Path -LiteralPath (Join-Path $fontDst $f) -PathType Leaf)) {
            Write-Log "  ! font missing: $src"
        }
    }
    Write-Log "  -> $fontDst"
}

Write-Log ("Done: {0} FMGs, {1} entries, {2:N1}s" -f $totalFmg, $totalEntries, $stopwatch.Elapsed.TotalSeconds)
Write-Log "Mod files in: $outDir"

if ($interactive) { $null = Read-Host "`nPress Enter to close" }
exit 0
