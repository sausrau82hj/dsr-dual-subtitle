<#
.SYNOPSIS
  DARK SOULS: REMASTERED dual-language text builder (Windows PowerShell 5.1, no Python).

.DESCRIPTION
  Reads the packs from <source>\msg\<LANG>\menu.msgbnd.dcx, merges the Chinese and English
  text of the selected FMGs into one entry (Chinese on top, English underneath), writes the
  result into every language slot and repacks the packs into <out>\msg\<LANG>\. The Chinese
  dialogue font is copied into <out>\font\<secondary>, because the English slot's atlas has
  no CJK glyphs.

  All container work (DCX, BND3, FMG) is done by Yabber; this script only walks folders,
  edits the FMG XML and calls Yabber to repack.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Filter menu -KeepWork
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Out,
    [string]$Game,
    [string]$Yabber,
    [string]$Primary,
    [string]$Secondary,
    [string]$Config,
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackRoot = if ((Split-Path -Leaf $ScriptDir) -ieq 'tools') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
$ConfigPath = if ($Config) { (Resolve-Path -LiteralPath $Config).Path } else { Join-Path $ScriptDir 'dualsub.config.json' }

$script:NullMarkers = @('', 'null', '%null%')
$script:MultiLineFmgs = @('Conversation_.fmg', 'Movie_subtitles_.fmg', 'Event_text_.fmg')

function Write-Step([string]$Text) { Write-Host $Text }

function Test-Null($text) {
    if ($null -eq $text) { return $true }
    return ($script:NullMarkers -contains $text.Trim().ToLowerInvariant())
}

function Get-Norm([string]$text) {
    if ($null -eq $text) { return '' }
    return ($text -replace '\s+', '').ToLowerInvariant()
}

function Test-AlreadyMerged([string]$a, [string]$b, [string]$sep) {
    if (-not $sep) { return $false }
    if ($a.EndsWith($sep + $b) -or $b.EndsWith($sep + $a)) { return $true }
    $x = @($a.Split([string[]]@($sep), [System.StringSplitOptions]::None))
    $y = @($b.Split([string[]]@($sep), [System.StringSplitOptions]::None))
    if ($x.Count -gt 1 -and $y.Count -gt 1) {
        return ((($x | Sort-Object) -join "`0") -eq (($y | Sort-Object) -join "`0"))
    }
    return $false
}

function Find-YabberDir([string]$Hint) {
    $cands = New-Object System.Collections.Generic.List[string]
    if ($Hint) { $cands.Add($Hint) }
    $cmd = Get-Command 'Yabber.exe' -ErrorAction SilentlyContinue
    if ($cmd) { $cands.Add((Split-Path -Parent $cmd.Source)) }
    $roots = @($PackRoot, $ScriptDir, $env:YABBER_DIR, 'D:\Hermesworkplace\tools\Yabber',
               'D:\game\TOOL', 'D:\Tools', 'D:\tool', 'C:\Tools', 'C:\tool',
               (Join-Path $env:USERPROFILE 'Downloads'))
    foreach ($root in $roots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
        foreach ($pattern in @('Yabber*', '*\Yabber*', 'Yabber*\Yabber*')) {
            Get-ChildItem -Path (Join-Path $root $pattern) -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { $cands.Add($_.FullName) }
        }
    }
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'Yabber.exe')) -and
            (Test-Path -LiteralPath (Join-Path $c 'Yabber.DCX.exe'))) { return $c }
    }
    throw "Yabber not found. Extract Yabber anywhere under this package's root folder, pass -Yabber <dir>, or set `"yabber_dir`" in the config."
}

function Get-DefaultGame {
    if ($env:DSR_GAME_DIR -and (Test-Path -LiteralPath (Join-Path $env:DSR_GAME_DIR 'DarkSoulsRemastered.exe'))) {
        return $env:DSR_GAME_DIR
    }
    $roots = New-Object System.Collections.Generic.List[string]
    try {
        $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath
        if ($steam) {
            $roots.Add($steam)
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf) {
                foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $roots.Add($m.Groups[1].Value.Replace('\\', '\'))
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
        if (Test-Path -LiteralPath (Join-Path $cand 'DarkSoulsRemastered.exe')) { return $cand }
    }
    return 'D:\steam\steamapps\common\DARK SOULS REMASTERED'
}

function Invoke-Yabber([string]$Tool, [string]$Path) {
    $out = & $Tool $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Yabber failed on ${Path}:`n$($out -join "`n")"
    }
}

function Get-Stem([string]$Path) {
    $name = Split-Path -Leaf $Path
    foreach ($suffix in @('.msgbnd.dcx', '.msgbnd')) {
        if ($name.ToLowerInvariant().EndsWith($suffix)) { return $name.Substring(0, $name.Length - $suffix.Length) }
    }
    return [System.IO.Path]::GetFileNameWithoutExtension($name)
}

function Expand-Pack([string]$DcxPath, [string]$WorkDir) {
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $dcx = Join-Path $WorkDir (Split-Path -Leaf $DcxPath)
    Copy-Item -LiteralPath $DcxPath -Destination $dcx -Force
    Invoke-Yabber $script:YabberDcx $dcx
    $msgbnd = $dcx.Substring(0, $dcx.Length - 4)
    Invoke-Yabber $script:YabberExe $msgbnd
    $bnd = Join-Path $WorkDir (([System.IO.Path]::GetFileNameWithoutExtension($msgbnd)) + '-msgbnd')
    $fmgDir = Get-ChildItem -Path $bnd -Recurse -Directory |
        Where-Object { Get-ChildItem -LiteralPath $_.FullName -Filter *.fmg -File -ErrorAction SilentlyContinue } |
        Select-Object -First 1
    if (-not $fmgDir) { throw "No FMG found after unpacking $DcxPath" }
    return [pscustomobject]@{ Bnd = $bnd; FmgDir = $fmgDir.FullName; Msgbnd = $msgbnd }
}

function ConvertTo-Lf([string]$text) {
    if ($null -eq $text) { return '' }
    return (($text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Get-TextUnits([string]$text) {
    $n = 0
    foreach ($ch in $text.ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 0x1100 -and $c -le 0x115F) -or ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or ($c -ge 0xF900 -and $c -le 0xFAFF) -or
            ($c -ge 0xFE30 -and $c -le 0xFE4F) -or ($c -ge 0xFF00 -and $c -le 0xFF60) -or
            ($c -ge 0xFFE0 -and $c -le 0xFFE6) -or ($c -ge 0x3000 -and $c -le 0x303F)) { $n += 2 }
        else { $n += 1 }
    }
    return $n
}

function Get-RenderedLines([string]$text, [int]$width) {
    if ($width -le 0) { return 999 }
    $total = 0
    foreach ($line in $text.Split("`n")) {
        $total += [Math]::Max(1, [int][Math]::Ceiling((Get-TextUnits $line) / $width))
    }
    return $total
}

function Get-FitSettings([string]$Fmg) {
    # The NPC dialogue box holds three lines, the subtitle strip two. Everything else is
    # merged as-is: if you enable a category, its box is your problem.
    if ($Fmg -eq 'Conversation_.fmg') { return [pscustomobject]@{ Max = 3; Width = 60; Inline = $true } }
    if ($Fmg -eq 'Movie_subtitles_.fmg') { return [pscustomobject]@{ Max = 2; Width = 62; Inline = $true } }
    return $null
}

function Join-Flat([string]$text) {
    $parts = $text.Split("`n")
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

function Get-MergedText([string]$a, [string]$b, [string]$sep, $Fit) {
    $cand = $a.TrimEnd([char[]]@("`n")) + $sep + $b.TrimEnd([char[]]@("`n"))
    if (-not $Fit) { return [pscustomobject]@{ Text = $cand; Inline = $false; Skip = $false } }
    if ((Get-RenderedLines $cand $Fit.Width) -le $Fit.Max) {
        return [pscustomobject]@{ Text = $cand; Inline = $false; Skip = $false }
    }
    if (-not $Fit.Inline) { return [pscustomobject]@{ Text = ''; Inline = $false; Skip = $true } }
    $flat = ((Join-Flat $a) + " / " + (Join-Flat $b))
    $flat = ($flat -replace '\s{2,}', ' ').Trim()
    if ((Get-RenderedLines $flat $Fit.Width) -le $Fit.Max) {
        return [pscustomobject]@{ Text = $flat; Inline = $true; Skip = $false }
    }
    return [pscustomobject]@{ Text = ''; Inline = $false; Skip = $true }
}

function Get-FmgEntries([string]$FmgDir, [string]$Fmg) {
    $xml = Join-Path $FmgDir ($Fmg + '.xml')
    Invoke-Yabber $script:YabberExe (Join-Path $FmgDir $Fmg)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($xml)
    $map = @{}
    foreach ($el in $doc.SelectNodes('/fmg/entries/text')) {
        $map[$el.GetAttribute('id')] = ConvertTo-Lf $el.InnerText
    }
    return $map
}

function Save-XmlDoc([System.Xml.XmlDocument]$Doc, [string]$Path) {
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::None
    $settings.Indent = $false
    $settings.Encoding = New-Object System.Text.UTF8Encoding($true)
    $writer = [System.Xml.XmlWriter]::Create($Path, $settings)
    try { $Doc.Save($writer) } finally { $writer.Close() }
}

function Update-Fmg([string]$FmgDir, [string]$Fmg, $TopMap, $SecMap, [string]$Mode, [string]$Sep, $Fit) {
    $xml = Join-Path $FmgDir ($Fmg + '.xml')
    Invoke-Yabber $script:YabberExe (Join-Path $FmgDir $Fmg)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($xml)
    $changed = 0
    $inline = 0
    $skipped = 0
    foreach ($el in $doc.SelectNodes('/fmg/entries/text')) {
        $id = $el.GetAttribute('id')
        $a = if ($TopMap.ContainsKey($id)) { [string]$TopMap[$id] } else { '' }
        $b = if ($SecMap.ContainsKey($id)) { [string]$SecMap[$id] } else { '' }
        if ((Test-Null $a) -or (Test-Null $b)) { continue }
        if ((Get-Norm $a) -eq (Get-Norm $b)) { continue }
        if ($Mode -eq 'sec_only') {
            if ((ConvertTo-Lf $el.InnerText) -cne $b) { $el.InnerText = $b; $changed++ }
            continue
        }
        if (Test-AlreadyMerged $a $b $Sep) { continue }
        $merged = Get-MergedText $a $b $Sep $Fit
        if ($merged.Skip) { $skipped++; continue }
        $el.InnerText = $merged.Text
        if ($merged.Inline) { $inline++ }
        $changed++
    }
    if ($changed -gt 0) {
        Save-XmlDoc $doc $xml
        Invoke-Yabber $script:YabberExe $xml
    }
    Remove-Item -LiteralPath $xml -Force
    return [pscustomobject]@{ Changed = $changed; Inline = $inline; Skipped = $skipped }
}

function Get-ModeValue($Value) {
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $m = $Value.PSObject.Properties['mode']
        if ($m -and $m.Value) { return [string]$m.Value }
        $e = $Value.PSObject.Properties['enabled']
        if ($e) { return $(if ($e.Value) { 'append' } else { 'off' }) }
    }
    if ($Value -is [string]) { return $Value.Trim() }
    return $(if ($Value) { 'append' } else { 'off' })
}

function Get-Category([string]$Fmg) {
    switch ($Fmg) {
        'Conversation_.fmg'        { return 'Dialogue' }
        'Movie_subtitles_.fmg'     { return 'Cutscene Subtitles' }
        'Dialogue_.fmg'            { return 'Dialogue Boxes' }
        'Event_text_.fmg'          { return 'Event Text' }
        'Menu_general_text_.fmg'   { return 'Menu Text' }
        'Menu_others_.fmg'         { return 'Menu Text' }
        'Ingame_menu_.fmg'         { return 'Menu Text' }
        'Key_guide_.fmg'           { return 'Key Prompts' }
        'Item_help_.fmg'           { return 'Help Text' }
        'Single_line_help_.fmg'    { return 'Help Text' }
        'System_message_win32_.fmg'        { return 'System Messages' }
        'System_specific_tags_win32_.fmg'  { return 'System Messages' }
        'Blood_writing_.fmg'       { return 'Blood Messages' }
        default {
            if ($Fmg -like '*_name_.fmg') { return 'Item Names' }
            if ($Fmg -like '*_description_.fmg' -or $Fmg -like '*_long_desc_.fmg') { return 'Item Descriptions' }
            return 'Other'
        }
    }
}

function Get-Mode($Cfg, [string]$Pack, [string]$Fmg) {
    $stem = Get-Stem $Pack
    $files = $Cfg.files
    if ($files) {
        $packNode = $files.PSObject.Properties[$stem]
        if ($packNode -and $packNode.Value.fmg) {
            foreach ($p in $packNode.Value.fmg.PSObject.Properties) {
                if ($Fmg -like $p.Name) { return (Get-ModeValue $p.Value) }
            }
        }
    }
    if ($Cfg.categories) {
        $cat = Get-Category $Fmg
        $node = $Cfg.categories.PSObject.Properties[$cat]
        if ($node) { return (Get-ModeValue $node.Value) }
    }
    return 'off'
}

function Get-Separator($Cfg, [string]$Pack, [string]$Fmg) {
    $stem = Get-Stem $Pack
    $files = $Cfg.files
    if ($files) {
        $packNode = $files.PSObject.Properties[$stem]
        if ($packNode -and $packNode.Value.fmg) {
            foreach ($p in $packNode.Value.fmg.PSObject.Properties) {
                if ($Fmg -like $p.Name -and $p.Value -is [System.Management.Automation.PSCustomObject]) {
                    $sepNode = $p.Value.PSObject.Properties['separator']
                    if ($sepNode) {
                        return $(if ($sepNode.Value -eq '\n') { "`n" } else { [string]$sepNode.Value })
                    }
                }
            }
        }
    }
    if ($script:MultiLineFmgs -contains $Fmg) { return "`n" }
    $sep = [string]$Cfg.separator
    if ($sep -eq '\n' -or $sep -eq '') { return "`n" }
    return $sep
}

# ---- main -------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Config not found: $ConfigPath" }
$cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$primary = if ($Primary) { $Primary } elseif ($cfg.primary) { [string]$cfg.primary } else { 'SCHINESE' }
$secondary = if ($Secondary) { $Secondary } elseif ($cfg.secondary) { [string]$cfg.secondary } else { 'ENGLISH' }
$gameDir = if ($Game) { $Game } else { Get-DefaultGame }

$srcDir = if ($Source) { $Source } else { Join-Path $PackRoot 'source' }
if (-not (Test-Path -LiteralPath (Join-Path $srcDir 'msg'))) {
    throw "Text packs not found: $(Join-Path $srcDir 'msg') — the package ships them in source\, or pass -Source <game folder>."
}
$outDir = if ($Out) { $Out } else { $PackRoot }

$yabberDir = if ($Yabber) { $Yabber } else { Find-YabberDir '' }
$script:YabberExe = Join-Path $yabberDir 'Yabber.exe'
$script:YabberDcx = Join-Path $yabberDir 'Yabber.DCX.exe'

# Every language slot gets $primary on top and $secondary underneath.
$languages = @($secondary, $primary)
$packs = @('menu.msgbnd.dcx', 'item.msgbnd.dcx')

$started = Get-Date
Write-Step "Source: $srcDir"
Write-Step "Output: $outDir"
Write-Step "Text: $primary + $secondary -> $($languages -join ', ')"
Write-Step ''

$totalFmg = 0
$totalEntries = 0
$totalInline = 0
$totalSkipped = 0

foreach ($pack in $packs) {
    $stem = Get-Stem $pack
    $workRoot = Join-Path $outDir "_work\$stem"
    if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }

    $packDirs = @{}
    $packTexts = @{}
    foreach ($lang in $languages) {
        $dirs = Expand-Pack (Join-Path $srcDir "msg\$lang\$pack") (Join-Path $workRoot $lang)
        $packDirs[$lang] = $dirs
        $texts = @{}
        foreach ($fmg in (Get-ChildItem -LiteralPath $dirs.FmgDir -Filter *.fmg -File | Sort-Object Name | ForEach-Object Name)) {
            $texts[$fmg] = Get-FmgEntries $dirs.FmgDir $fmg
        }
        $packTexts[$lang] = $texts
    }

    Write-Step "[$pack]"
    foreach ($lang in $languages) {
        # the slot's own language goes on top, the other one underneath
        $topLang = if ($lang -eq $primary -or $lang -eq $secondary) { $lang } else { $primary }
        $bottomLang = if ($topLang -eq $primary) { $secondary } else { $primary }

        $tgt = $packDirs[$lang]
        $topDir = $packDirs[$topLang].FmgDir
        $bottomDir = $packDirs[$bottomLang].FmgDir

        $changedTotal = 0
        foreach ($fmg in (Get-ChildItem -LiteralPath $tgt.FmgDir -Filter *.fmg -File | Sort-Object Name | ForEach-Object Name)) {
            $mode = Get-Mode $cfg $pack $fmg
            if ($mode -eq 'off') { continue }
            $top = $packTexts[$topLang][$fmg]
            $bottom = $packTexts[$bottomLang][$fmg]
            $sep = Get-Separator $cfg $pack $fmg
            $fit = Get-FitSettings $fmg
            $res = Update-Fmg $tgt.FmgDir $fmg $top $bottom $mode $sep $fit
            $n = $res.Changed
            if ($res.Skipped -gt 0) { $totalSkipped += $res.Skipped }
            if ($res.Inline -gt 0) { $totalInline += $res.Inline }
            if ($n -gt 0) {
                $changedTotal += $n
                $totalFmg++
                $totalEntries += $n
                $note = ''
                if ($res.Inline -gt 0) { $note += ", $($res.Inline) inline" }
                if ($res.Skipped -gt 0) { $note += ", $($res.Skipped) left as-is" }
                Write-Step "  + $lang/$fmg`: $n entries$note"
            }
        }

        if ($changedTotal -eq 0) { Write-Step "  = $lang`: nothing to merge, pack skipped"; continue }
        Invoke-Yabber $script:YabberExe $tgt.Bnd
        Invoke-Yabber $script:YabberDcx $tgt.Msgbnd
        $dst = Join-Path $outDir "msg\$lang\$pack"
        $dstDir = Split-Path -Parent $dst
        New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
        Copy-Item -LiteralPath ($tgt.Msgbnd + '.dcx') -Destination $dst -Force
        Write-Step "  -> $dst"
    }

    if (-not $KeepWork) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Step ''
}

# A pack whose categories are all off ships untouched, so replacing the whole msg
# folder leaves no gap.
foreach ($pack in $packs) {
    foreach ($lang in $languages) {
        $src = Join-Path $srcDir "msg\$lang\$pack"
        $dst = Join-Path $outDir "msg\$lang\$pack"
        if (-not (Test-Path -LiteralPath $src) -or (Test-Path -LiteralPath $dst)) { continue }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Step "  -> $dst (unchanged)"
    }
}

# The primary language's dialogue font carries the CJK glyphs the other slots lack.
$fontSrcDir = Join-Path $gameDir ("font\" + $primary.ToLowerInvariant())
$fontFiles = @('TalkFont24.ccm.dcx', 'TalkFont24.tpf.dcx')
# Menus, items and the rest draw with DSFont24, so bilingual UI text needs that atlas too.
$uiOn = $false
if ($cfg.categories) {
    foreach ($name in $cfg.categories.PSObject.Properties.Name) {
        if ($name -in @('Dialogue', 'Cutscene Subtitles')) { continue }
        if ([string](Get-ModeValue $cfg.categories.$name) -ne 'off') { $uiOn = $true }
    }
}
if ($uiOn) { $fontFiles += @('DSFont24.ccm.dcx', 'DSFont24.tpf.dcx') }

if (Test-Path -LiteralPath $fontSrcDir) {
    foreach ($lang in $languages) {
        if ($lang -eq $primary) { continue }
        $fontDst = Join-Path $outDir ("font\" + $lang)
        New-Item -ItemType Directory -Force -Path $fontDst | Out-Null
        foreach ($f in $fontFiles) {
            $src = Join-Path $fontSrcDir $f
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $fontDst $f) -Force }
        }
        Write-Step "  -> $fontDst"
    }
}

$elapsed = (Get-Date) - $started
Write-Step ("Done: {0} pack(s), {1} FMGs, {2} entries, in {3:N1}s" -f $packs.Count, $totalFmg, $totalEntries, $elapsed.TotalSeconds)
if ($totalInline -gt 0 -or $totalSkipped -gt 0) {
    Write-Step ("Fitted to the box: {0} inline, {1} left as they were" -f $totalInline, $totalSkipped)
}
Write-Step "Mod files in: $outDir"
