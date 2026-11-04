# Generate self-contained defaults that load on EVERY WoW account.
# Offline export from last saved WTF data. The original game server does not
# need to be available. Last saved state may predate the newest capture.
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
    if (-not $source) {
        # Older accounts may not yet contain a completed ForeverCore snapshot.
        # An offline export of their installed addon preferences is still useful.
        $source = Get-ChildItem $accountRoot -Directory | Where-Object {
            Test-Path (Join-Path $_.FullName 'SavedVariables\Bartender4.lua')
        } | Sort-Object { (Get-Item (Join-Path $_.FullName 'SavedVariables\Bartender4.lua')).LastWriteTime } -Descending | Select-Object -First 1
        if ($source) {
            Write-Warning "Geen vastgelegde ForeverCore-snapshot gevonden. Probeer de laatst opgeslagen Bartender-instellingen uit account $($source.Name)."
        }
    }
    if (-not $source) { throw 'Geen WoW-account met opgeslagen Bartender-instellingen gevonden. Gebruik desnoods tools/Export-AddonSettings.ps1 alleen.' }
}

$saved = Join-Path $source.FullName 'SavedVariables'
$coreFile = Join-Path $saved 'ForeverCore.lua'
$coreText = if (Test-Path $coreFile) { Get-Content $coreFile -Raw } else { 'ForeverCoreDB = {}' }
$bartenderText = Get-Content (Join-Path $saved 'Bartender4.lua') -Raw
$core = Get-RootTable $coreText 'ForeverCoreDB'
$bartender = Get-RootTable $bartenderText 'Bartender4DB'
$coreChildren = Get-DirectTables $core
$bartenderChildren = Get-DirectTables $bartender

$layout = '{["profileName"]="FC Dien Warr Snapshot",["editModeName"]="FC Dien Layout",["sourceName"]="Offline export",["revision"]=1}'
if ($coreChildren.Contains('layoutTemplate')) {
    $layout = $coreChildren['layoutTemplate']
    $layoutChildren = Get-DirectTables $layout
    if (-not $layoutChildren.Contains('layoutData')) {
        Write-Warning 'Edit Mode-layoutdata ontbreken in laatste SavedVariables. Bartender kan wel worden geëxporteerd; Edit Mode niet volledig.'
    }
} else {
    Write-Warning 'Geen opgeslagen ForeverCore-layout gevonden. Probeer Bartender zonder Edit Mode-layout.'
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
    # No dedicated snapshot? The most recently saved AceDB profile is an
    # offline fallback. Never invent geometry or claim an exact capture.
    $profiles = if ($bartenderChildren.Contains('profiles')) { Get-DirectTables $bartenderChildren['profiles'] } else { [ordered] @{} }
    $choices = @($profiles.Keys | Where-Object { $_ -ne 'Default' })
    $sourceProfile = if ($choices.Count -eq 1) { $choices[0] }
                     elseif ($profiles.Contains('Default')) { 'Default' }
                     else { $null }
    if (-not $sourceProfile) { throw "Geen Bartender profiel 'FC Dien Warr Snapshot' en geen eenduidig fallback-profiel in de offline data." }
    $parentProfile = $profiles[$sourceProfile]
    $namespaceProfiles = [ordered] @{}
    if ($bartenderChildren.Contains('namespaces')) {
        $allNamespaces = Get-DirectTables $bartenderChildren['namespaces']
        foreach ($ns in $allNamespaces.Keys) {
            $parts = Get-DirectTables $allNamespaces[$ns]
            if (-not $parts.Contains('profiles')) { continue }
            $nProfiles = Get-DirectTables $parts['profiles']
            if ($nProfiles.Contains($sourceProfile)) { $namespaceProfiles[$ns] = $nProfiles[$sourceProfile] }
        }
    }
    Write-Warning "De exacte Bartender-snapshot ontbreekt. Fallback naar opgeslagen profiel '$sourceProfile'. Controleer de layout bij eerste login."
}

$bindings = 'nil'
if ($coreChildren.Contains('accountSetup')) {
    $setupChildren = Get-DirectTables $coreChildren['accountSetup']
    if ($setupChildren.Contains('profile')) { $bindings = $setupChildren['profile'] }
}


# WoW keeps account/character keybinds in bindings-cache.wtf, independent of
# ForeverCore's SavedVariables. Offline import works without a game login.
function Escape-LuaString([string] $value) {
    return '"' + $value.Replace('\', '\\').Replace('"', '\"') + '"'
}
function Read-BindingCache([string] $path) {
    $found = [ordered] @{}
    foreach ($line in (Get-Content -LiteralPath $path -ErrorAction Stop)) {
        $m = [regex]::Match($line,
            '^\s*bind\s+(?:"(?<quotedKey>[^"]+)"|(?<bareKey>\S+))\s+(?:"(?<quotedCommand>[^"]+)"|(?<bareCommand>.+?))\s*
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
[void] $builder.AppendLine('    clientCVars = {')
foreach ($line in $luaCvars) { [void] $builder.AppendLine($line) }
[void] $builder.AppendLine('    },')
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
Write-Host "Clientinstellingen vastgelegd: $($clientValues.Count)"
Write-Host "Na latere layoutwijzigingen: /fc layout capture, uitloggen en script opnieuw draaien."

# Discover other installed UI addons and bundle safe account-wide preferences.
# This is a one-time export on the source PC; no WTF copy per target account.
$extraExporter = Join-Path $PSScriptRoot 'Export-AddonSettings.ps1'
if (-not (Test-Path -LiteralPath $extraExporter)) {
    throw "Export-AddonSettings.ps1 ontbreekt. Update eerst ForeverCore volledig."
}
& $extraExporter -GameRoot $GameRoot -Account $source.Name -AddonRoot $addonRoot

,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $m.Success) { continue }
        $key = if ($m.Groups['quotedKey'].Success) { $m.Groups['quotedKey'].Value } else { $m.Groups['bareKey'].Value }
        $command = if ($m.Groups['quotedCommand'].Success) { $m.Groups['quotedCommand'].Value } else { $m.Groups['bareCommand'].Value.Trim() }
        if ($key -and $command) { $found[$key.ToUpperInvariant()] = $command }
    }
    return $found
}

$sourceNameMatch = [regex]::Match($layout, '\["sourceName"\]\s*=\s*"([^"]+)"')
$sourceCharacter = if ($sourceNameMatch.Success) { $sourceNameMatch.Groups[1].Value } else { $null }
$allBindingFiles = @(Get-ChildItem -LiteralPath $source.FullName -Filter 'bindings-cache.wtf' -Recurse -File -ErrorAction SilentlyContinue)
$selectedBindings = $null
if ($sourceCharacter) {
    $selectedBindings = $allBindingFiles | Where-Object {
        (Split-Path (Split-Path $_.FullName -Parent) -Leaf) -eq $sourceCharacter
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
if (-not $selectedBindings) {
    $accountBindingsPath = Join-Path $source.FullName 'bindings-cache.wtf'
    if (Test-Path -LiteralPath $accountBindingsPath) {
        $selectedBindings = Get-Item -LiteralPath $accountBindingsPath
    }
}
if (-not $selectedBindings -and $allBindingFiles.Count -eq 1) {
    $selectedBindings = $allBindingFiles[0]
}
if ($selectedBindings) {
    $foundBindings = Read-BindingCache $selectedBindings.FullName
    if ($foundBindings.Count -ge 5) {
        $luaEntries = [System.Collections.Generic.List[string]]::new()
        foreach ($key in ($foundBindings.Keys | Sort-Object)) {
            $luaEntries.Add('{' + (Escape-LuaString $key) + ', ' + (Escape-LuaString $foundBindings[$key]) + '}')
        }
        # Other classes receive all non-class-specific keys including camera,
        # action bars and UI commands; original Warrior spell keys are ignored.
        $bindings = '{revision=2026110401, class="WARRIOR", keys={' + ($luaEntries -join ',') + '}}'
        Write-Host ("Bindings uit " + $selectedBindings.FullName + ": " + $foundBindings.Count + " toetsen") -ForegroundColor Green
    } else {
        Write-Warning ("Bindings-cache bevat te weinig bruikbare toetsen: " + $selectedBindings.FullName)
    }
} else {
    Write-Warning "Geen bindings-cache.wtf gevonden. Alleen eventueel eerder vastgelegde /fc setup capture wordt meegenomen."
}

# Status text, camera zoom and player highlight are Blizzard CVars, not
# Bartender profile settings. Capture relevant source options offline.
$clientValues = [ordered] @{
    'statusText' = '1'
    'statusTextDisplay' = 'BOTH'
    'cameraDistanceMaxZoomFactor' = '4'
    'findYourselfAnywhere' = '1'
    'findYourselfMode' = '1'
    'findYourselfModeCircle' = '1'
    'findYourselfModeOutline' = '1'
}
$sourceCvars = @(
    (Join-Path $GameRoot 'WTF\Config.wtf'),
    (Join-Path $GameRoot 'WTF\config-cache.wtf'),
    (Join-Path $source.FullName 'config-cache.wtf')
)
if ($selectedBindings) {
    $characterCvars = Join-Path (Split-Path $selectedBindings.FullName -Parent) 'config-cache.wtf'
    $sourceCvars += $characterCvars
}
foreach ($cfg in $sourceCvars) {
    if (-not (Test-Path -LiteralPath $cfg)) { continue }
    foreach ($line in (Get-Content -LiteralPath $cfg)) {
        $m = [regex]::Match($line, '^\s*SET\s+(\S+)\s+"?([^"]+?)"?\s*
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

,
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $m.Success) { continue }
        $name, $value = $m.Groups[1].Value, $m.Groups[2].Value
        if ($name -eq 'cameraDistanceMaxZoomFactor' -and $value -match '^\d+(\.\d+)?
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

) {
            $clientValues['cameraDistanceMaxZoomFactor'] = $value
        } elseif ($name -eq 'cameraDistanceRateMult' -and $value -match '^\d+(\.\d+)?
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

) {
            $clientValues['cameraDistanceRateMult'] = $value
        }
    }
}
$luaCvars = [System.Collections.Generic.List[string]]::new()
foreach ($name in $clientValues.Keys) {
    $luaCvars.Add('        [' + (Escape-LuaString $name) + '] = ' + (Escape-LuaString $clientValues[$name]) + ',')
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

