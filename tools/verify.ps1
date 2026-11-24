<#
.SYNOPSIS
  Check the built packs against the vanilla ones in source\ (Windows PowerShell 5.1).

.DESCRIPTION
  Per language, checks that:
    - the pack still holds the same FMG set and the same entry ids
    - every entry the config merges equals top language + separator + secondary language
    - every other entry and every FMG left alone is byte-identical to vanilla

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\verify.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\verify.ps1 -Config tools\dualsub-all.config.json -PackDir _work\all
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$PackDir,
    [string]$Yabber,
    [string]$Config
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackRoot = if ((Split-Path -Leaf $ScriptDir) -ieq 'tools') { Split-Path -Parent $ScriptDir } else { $ScriptDir }
$ConfigPath = if ($Config) { (Resolve-Path -LiteralPath $Config).Path } else { Join-Path $ScriptDir 'dualsub.config.json' }

$script:NullMarkers = @('', 'null', '%null%')
$script:MultiLineFmgs = @('Conversation_.fmg', 'Movie_subtitles_.fmg', 'Event_text_.fmg')

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
    throw "Yabber not found. Extract Yabber under this package's root folder or pass -Yabber <dir>."
}

function Invoke-Yabber([string]$Tool, [string]$Path) {
    $out = & $Tool $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Yabber failed on ${Path}:`n$($out -join "`n")" }
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
    return $fmgDir.FullName
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

function Get-FitSettings($Cfg, [string]$Fmg) {
    $fit = $Cfg.fit
    if (-not $fit -or -not $fit.enabled) { return $null }
    $fmgs = @($fit.fmgs)
    if ($fmgs.Count -gt 0 -and ($fmgs -notcontains $Fmg)) { return $null }
    $max = if ($fit.max_lines) { [int]$fit.max_lines } else { 3 }
    $w = if ($fit.line_width) { [int]$fit.line_width } else { 60 }
    return [pscustomobject]@{ Max = $max; Width = $w }
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
    $flat = ((Join-Flat $a) + " / " + (Join-Flat $b))
    $flat = ($flat -replace '\s{2,}', ' ').Trim()
    if ((Get-RenderedLines $flat $Fit.Width) -le $Fit.Max) {
        return [pscustomobject]@{ Text = $flat; Inline = $true; Skip = $false }
    }
    return [pscustomobject]@{ Text = ''; Inline = $false; Skip = $true }
}

function Get-ShortLabelLimit($Cfg, [string]$Fmg) {
    $s = $Cfg.skip_short
    $units = 8
    if ($s) {
        if ($null -ne $s.units) { $units = [int]$s.units }
        elseif ($s.enabled -eq $false) { return 0 }
        $except = @($s.except)
        if ($except.Count -gt 0 -and ($except -contains $Fmg)) { return 0 }
    }
    return $units
}

function Get-FmgEntries([string]$FmgDir, [string]$Fmg) {
    $fmgPath = Join-Path $FmgDir $Fmg
    if ($script:TextCache.ContainsKey($fmgPath)) { return $script:TextCache[$fmgPath] }
    $xml = $fmgPath + '.xml'
    Invoke-Yabber $script:YabberExe $fmgPath
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($xml)
    $map = @{}
    foreach ($el in $doc.SelectNodes('/fmg/entries/text')) {
        $map[$el.GetAttribute('id')] = ConvertTo-Lf $el.InnerText
    }
    $script:TextCache[$fmgPath] = $map
    return $map
}

function Get-FmgNames([string]$FmgDir) {
    return @(Get-ChildItem -LiteralPath $FmgDir -Filter *.fmg -File | Sort-Object Name | ForEach-Object Name)
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
        default                    { return 'Other' }
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
        $node = $Cfg.categories.PSObject.Properties[(Get-Category $Fmg)]
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
                    if ($sepNode) { return $(if ($sepNode.Value -eq '\n') { "`n" } else { [string]$sepNode.Value }) }
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
$packDirResolved = if ($PackDir) { (Resolve-Path -LiteralPath $PackDir).Path } else { $PackRoot }
$srcDir = if ($Source) { (Resolve-Path -LiteralPath $Source).Path } else { Join-Path $PackRoot 'source' }

$yabberDir = if ($Yabber) { $Yabber } elseif ($cfg.yabber_dir) { $cfg.yabber_dir } else { Find-YabberDir '' }
$script:YabberExe = Join-Path $yabberDir 'Yabber.exe'
$script:YabberDcx = Join-Path $yabberDir 'Yabber.DCX.exe'
$script:TextCache = @{}

$secondary = [string]$cfg.secondary
$languages = @($cfg.languages)
if ($languages.Count -eq 0) { $languages = @($cfg.primary, $secondary) }
$packs = @($cfg.packs)
if ($packs.Count -eq 0) { $packs = @('menu.msgbnd.dcx') }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('dsr-verify-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$counter = 0
$errors = New-Object System.Collections.Generic.List[string]
$mergedTotal = 0

try {
    foreach ($pack in $packs) {
        $van = @{}
        $built = @{}
        foreach ($lang in $languages) {
            $counter++; $van[$lang] = Expand-Pack (Join-Path $srcDir "msg\$lang\$pack") (Join-Path $work "v$counter")
            $counter++; $built[$lang] = Expand-Pack (Join-Path $packDirResolved "msg\$lang\$pack") (Join-Path $work "b$counter")
        }
        $secTexts = @{}
        foreach ($fmg in (Get-FmgNames $van[$secondary])) { $secTexts[$fmg] = Get-FmgEntries $van[$secondary] $fmg }

        foreach ($lang in $languages) {
            $topLang = $lang
            if ($cfg.chinese_source) {
                $node = $cfg.chinese_source.PSObject.Properties[$lang]
                if ($node -and $node.Value) { $topLang = [string]$node.Value }
            } elseif ($lang -eq $secondary) { $topLang = [string]$cfg.primary }
            Write-Host "[$lang] top=$topLang"

            $bNames = Get-FmgNames $built[$lang]
            $vNames = Get-FmgNames $van[$lang]
            $missing = @($bNames | Where-Object { $vNames -notcontains $_ })
            $extra = @($vNames | Where-Object { $bNames -notcontains $_ })
            if ($missing.Count -or $extra.Count) {
                $errors.Add("${lang}: FMG set differs: " + (($missing + $extra) -join ', '))
            }

            foreach ($fmg in @($bNames | Where-Object { $vNames -contains $_ })) {
                $mode = Get-Mode $cfg $pack $fmg
                if ($mode -eq 'off') {
                    $bBytes = [System.IO.File]::ReadAllBytes((Join-Path $built[$lang] $fmg))
                    $vBytes = [System.IO.File]::ReadAllBytes((Join-Path $van[$lang] $fmg))
                    if ([Convert]::ToBase64String($bBytes) -ne [Convert]::ToBase64String($vBytes)) {
                        $errors.Add("${lang}/${fmg}: untouched FMG changed")
                    }
                    continue
                }
                $bt = Get-FmgEntries $built[$lang] $fmg
                $vt = Get-FmgEntries $van[$lang] $fmg
                $bk = (@($bt.Keys) | Sort-Object) -join ','
                $vk = (@($vt.Keys) | Sort-Object) -join ','
                if ($bk -ne $vk) { $errors.Add("${lang}/${fmg}: entry ids differ"); continue }
                $top = Get-FmgEntries $van[$topLang] $fmg
                $sep = Get-Separator $cfg $pack $fmg
                $fit = Get-FitSettings $cfg $fmg
                $shortLimit = Get-ShortLabelLimit $cfg $fmg
                $n = 0
                foreach ($key in $vt.Keys) {
                    $original = [string]$vt[$key]
                    $a = if ($top.ContainsKey($key)) { [string]$top[$key] } else { '' }
                    $b = if ($secTexts[$fmg].ContainsKey($key)) { [string]$secTexts[$fmg][$key] } else { '' }
                    if ((Test-Null $a) -or (Test-Null $b) -or ((Get-Norm $a) -eq (Get-Norm $b))) {
                        $expected = $original
                    } elseif ($a.Contains('<?') -or $b.Contains('<?')) {
                        # tagged entries stay vanilla so engine glyphs are not duplicated
                        $expected = $original
                    } elseif ($shortLimit -gt 0 -and (Get-TextUnits ($original.Trim())) -le $shortLimit) {
                        # short UI labels stay vanilla, their box is only as wide as the label
                        $expected = $original
                    } elseif ($mode -eq 'sec_only') {
                        $expected = $b
                    } else {
                        $merged = Get-MergedText $a $b $sep $fit
                        $expected = if ($merged.Skip) { $original } else { $merged.Text }
                    }
                    $got = [string]$bt[$key]
                    if ($got -cne $expected) {
                        # Yabber drops whitespace-only text nodes when it repacks an FMG
                        if ($expected.Trim() -eq '' -and $got.Trim() -eq '') {
                            if ($expected -cne $original) { $n++ }
                            continue
                        }
                        $errors.Add("${lang}/${fmg}: entry $key mismatch`n    got      '$got'`n    expected '$expected'")
                        break
                    }
                    if ($expected -cne $original) { $n++ }
                }
                $mergedTotal += $n
                Write-Host ("  {0}: {1} merged of {2} entries" -f $fmg, $n, $vt.Count)
            }
            Write-Host ("  {0}: {1} FMGs ok" -f $pack, $bNames.Count)
        }
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($errors.Count -gt 0) {
    Write-Host ("FAILED ({0}):" -f $errors.Count)
    foreach ($e in ($errors | Select-Object -First 20)) { Write-Host " - $e" }
    exit 1
}
Write-Host ("ALL OK - {0} merged entries across {1} languages" -f $mergedTotal, $languages.Count)
exit 0
