# Generate self-contained defaults that load on EVERY WoW account.
# Run after /fc layout capture and logout. No WTF copy per account.
param([string] $GameRoot, [string] $Account)
$ErrorActionPreference = 'Stop'
$addonRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GameRoot)) {
    $GameRoot = (Resolve-Path (Join-Path $addonRoot '..\..\..')).Path
}
$accountRoot = Join-Path $GameRoot 'WTF\Account'
if (-not (Test-Path $accountRoot)) {
    throw "WTF/Account niet gevonden: $accountRoot. Gebruik -GameRoot met de juiste WoW-clientmap."
}

function Get-LuaTableAt([string] $text, [int] $start) {
    if ($start -lt 0 -or $start -ge $text.Length -or $text[$start] -ne '{') {
        throw "Geen Lua-tabel vanaf positie $start."
    }
    $depth = 0
    $quoted = $false
    $escaped = $false
    for ($i = $start; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($quoted) {
            if ($escaped) { $escaped = $false; continue }
            if ($ch -eq '\') { $escaped = $true; continue }
            if ($ch -eq '"') { $quoted = $false }
            continue
        }
        if ($ch -eq '"') { $quoted = $true; continue }
        if ($ch -eq '{') { $depth++ }
        if ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) { return $text.Substring($start, $i - $start + 1) }
        }
    }
    throw "Onvolledige Lua-tabel vanaf positie $start."
}

function Get-LuaDepth([string] $scope, [int] $end) {
    $prefix = $scope.Substring(0, $end)
    $clean = [regex]::Replace($prefix, '"(?:\\.|[^"\\])*"', '""')
    return ([regex]::Matches($clean, '\{')).Count - ([regex]::Matches($clean, '\}')).Count
}

function Get-DirectTables([string] $table) {
    $found = [ordered] @{}
    $matches = [regex]::Matches($table, '\["([^"]+)"\]\s*=\s*\{')
    foreach ($match in $matches) {
        if ((Get-LuaDepth $table $match.Index) -ne 1) { continue }
        $name = $match.Groups[1].Value
        $brace = $match.Index + $match.Length - 1
        $found[$name] = Get-LuaTableAt $table $brace
    }
    return $found
}

function Get-RootTable([string] $content, [string] $variable) {
    $pattern = '(?m)^\s*' + [regex]::Escape($variable) + '\s*=\s*\{'
    $match = [regex]::Match($content, $pattern)
    if (-not $match.Success) { throw "Lua-variabele $variable niet gevonden." }
    return Get-LuaTableAt $content ($match.Index + $match.Length - 1)
}

$source = $null
if ($Account) {
    $candidate = Join-Path $accountRoot $Account
    if (-not (Test-Path $candidate)) { throw "Accountmap niet gevonden: $candidate" }
    $source = Get-Item $candidate
} else {
    $possible = Get-ChildItem $accountRoot -Directory | Where-Object {
        (Test-Path (Join-Path $_.FullName 'SavedVariables\ForeverCore.lua')) -and
        (Test-Path (Join-Path $_.FullName 'SavedVariables\Bartender4.lua'))
    } | Sort-Object { (Get-Item (Join-Path $_.FullName 'SavedVariables\ForeverCore.lua')).LastWriteTime } -Descending
    foreach ($candidate in $possible) {
        $fcFile = Get-Content (Join-Path $candidate.FullName 'SavedVariables\ForeverCore.lua') -Raw
        if ($fcFile.Contains('FC Dien Warr Snapshot')) {
            $source = $candidate
            break
        }
    }
    if (-not $source) { throw 'Geen bronaccount met Bartender4 + ForeverCore-snapshot gevonden.' }
}

$saved = Join-Path $source.FullName 'SavedVariables'
$coreText = Get-Content (Join-Path $saved 'ForeverCore.lua') -Raw
$bartenderText = Get-Content (Join-Path $saved 'Bartender4.lua') -Raw
$core = Get-RootTable $coreText 'ForeverCoreDB'
$bartender = Get-RootTable $bartenderText 'Bartender4DB'
$coreChildren = Get-DirectTables $core
$bartenderChildren = Get-DirectTables $bartender

if (-not $coreChildren.Contains('layoutTemplate')) {
    throw 'ForeverCore layout ontbreekt. Gebruik /fc layout capture en log uit.'
}
$layout = $coreChildren['layoutTemplate']
$layoutChildren = Get-DirectTables $layout
if (-not $layoutChildren.Contains('layoutData')) {
    throw 'Portable Edit Mode-data ontbreekt. Update ForeverCore, doe /fc layout capture opnieuw en log uit.'
}

$profileName = 'FC Dien Warr Snapshot'
$parentProfile = '{}'
if ($bartenderChildren.Contains('profiles')) {
    $profiles = Get-DirectTables $bartenderChildren['profiles']
    if ($profiles.Contains($profileName)) { $parentProfile = $profiles[$profileName] }
}
$namespaceProfiles = [ordered] @{}
if ($bartenderChildren.Contains('namespaces')) {
    $namespaces = Get-DirectTables $bartenderChildren['namespaces']
    foreach ($ns in $namespaces.Keys) {
        $parts = Get-DirectTables $namespaces[$ns]
        if (-not $parts.Contains('profiles')) { continue }
        $profiles = Get-DirectTables $parts['profiles']
        if ($profiles.Contains($profileName)) {
            $namespaceProfiles[$ns] = $profiles[$profileName]
        }
    }
}
if ($parentProfile -eq '{}' -and $namespaceProfiles.Count -eq 0) {
    throw "Bartender-profiel '$profileName' ontbreekt. Gebruik /fc layout capture opnieuw."
}

$bindings = 'nil'
if ($coreChildren.Contains('accountSetup')) {
    $setupChildren = Get-DirectTables $coreChildren['accountSetup']
    if ($setupChildren.Contains('profile')) { $bindings = $setupChildren['profile'] }
}

# Optional addons: extract only the saved named UI profile, never quest history
# or Details! combat data. Missing addons do not block Bartender portability.
$questieProfile = 'nil'
$questieFile = Join-Path $saved 'QuestieConfig.lua'
if (Test-Path $questieFile) {
    $q = Get-RootTable (Get-Content $questieFile -Raw) 'QuestieConfig'
    $qParts = Get-DirectTables $q
    if ($qParts.Contains('profiles')) {
        $qProfiles = Get-DirectTables $qParts['profiles']
        if ($qProfiles.Contains('FC Dien Warr Questie')) {
            $questieProfile = $qProfiles['FC Dien Warr Questie']
        }
    }
}
$detailsProfile = 'nil'
$detailsFile = Join-Path $saved 'Details.lua'
if (Test-Path $detailsFile) {
    $d = Get-RootTable (Get-Content $detailsFile -Raw) '_detalhes_global'
    $dParts = Get-DirectTables $d
    if ($dParts.Contains('__profiles')) {
        $dProfiles = Get-DirectTables $dParts['__profiles']
        if ($dProfiles.Contains('FC Dien Warr Details')) {
            $detailsProfile = $dProfiles['FC Dien Warr Details']
        }
    }
}

$builder = [System.Text.StringBuilder]::new()
[void] $builder.AppendLine('-- AUTO-GENERATED by tools/Export-PortableSnapshot.ps1')
[void] $builder.AppendLine('-- Contains only UI snapshot and optional captured keybinds.')
[void] $builder.AppendLine('_G.ForeverCoreBundledDefaults = {')
[void] $builder.AppendLine('    bartender = {')
[void] $builder.AppendLine('        profileName = "FC Dien Warr Snapshot",')
[void] $builder.AppendLine("        profile = $parentProfile,")
[void] $builder.AppendLine('        namespaces = {')
foreach ($ns in $namespaceProfiles.Keys) {
    $escapedName = $ns.Replace('\', '\\').Replace('"', '\"')
    [void] $builder.AppendLine('            ["' + $escapedName + '"] = ' + $namespaceProfiles[$ns] + ',')
}
[void] $builder.AppendLine('        },')
[void] $builder.AppendLine('    },')
[void] $builder.AppendLine("    layout = $layout,")
[void] $builder.AppendLine("    bindingProfile = $bindings,")
if ($questieProfile -ne 'nil') {
    [void] $builder.AppendLine('    questie = {profileName = "FC Dien Warr Questie", profile = ' + $questieProfile + '},')
}
if ($detailsProfile -ne 'nil') {
    [void] $builder.AppendLine('    details = {profileName = "FC Dien Warr Details", profile = ' + $detailsProfile + '},')
}
[void] $builder.AppendLine('}')
$destination = Join-Path $addonRoot 'PortableSnapshot.lua'
[System.IO.File]::WriteAllText($destination, $builder.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "Portable UI-snapshot gemaakt: $destination" -ForegroundColor Green
Write-Host "Bronaccount: $($source.Name); Bartender modules: $($namespaceProfiles.Count)"
Write-Host "Nieuwe characters op ELK account krijgen deze interface automatisch."
Write-Host "Na latere layoutwijzigingen: /fc layout capture, uitloggen en script opnieuw draaien."

# Discover other installed UI addons and bundle safe account-wide preferences.
# This is a one-time export on the source PC; no WTF copy per target account.
$extraExporter = Join-Path $PSScriptRoot 'Export-AddonSettings.ps1'
if (-not (Test-Path -LiteralPath $extraExporter)) {
    throw "Export-AddonSettings.ps1 ontbreekt. Update eerst ForeverCore volledig."
}
& $extraExporter -GameRoot $GameRoot -Account $source.Name -AddonRoot $addonRoot

