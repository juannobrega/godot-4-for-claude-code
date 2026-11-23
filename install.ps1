#Requires -Version 5.1
<#
.SYNOPSIS
  Installs the godot-4 framework into a Godot project on Windows.

.DESCRIPTION
  Windows counterpart of install.sh, with the same contract:

    .\install.ps1                      install into the Godot project you are in
    .\install.ps1 <project-dir>        install into that project
    .\install.ps1 -DryRun              show what would be written, write nothing

  Copies skills, commands, agents, scripts and templates into <target>\.claude\
  and MERGES the hooks into an existing settings.json rather than replacing it:
  a real project probably has hooks of its own.

  Runs on Windows PowerShell 5.1 and PowerShell 7+, with no Python dependency.
  Both settings files are parsed before anything is copied, so an invalid
  settings.json in the target aborts the install instead of leaving it half done.

.EXAMPLE
  .\godot-4\install.ps1 C:\games\my-godot-project
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Target,

  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Src = $PSScriptRoot

# Walk up for project.godot so the installer works from any subdirectory of the
# project. Defaulting to the current directory installed wherever the shell
# happened to be, including inside the unzipped package.
function Find-GodotProjectRoot([string]$Start) {
  $d = (Resolve-Path -LiteralPath $Start).ProviderPath
  while ($true) {
    if (Test-Path -LiteralPath (Join-Path $d 'project.godot') -PathType Leaf) { return $d }
    $parent = Split-Path -Parent $d
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $d) { return $null }
    $d = $parent
  }
}

if (-not [string]::IsNullOrWhiteSpace($Target)) {
  if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    throw "not a directory: $Target"
  }
  $Dest = (Resolve-Path -LiteralPath $Target).ProviderPath
  if (-not (Test-Path -LiteralPath (Join-Path $Dest 'project.godot') -PathType Leaf)) {
    Write-Warning "$Dest has no project.godot."
    Write-Warning 'The framework installs, but every hook stays inert until it does.'
  }
} else {
  $Dest = Find-GodotProjectRoot (Get-Location).Path
  if (-not $Dest) {
    throw ("no project.godot in {0} or any directory above it. Run this from " +
           "inside your Godot project, or name it: .\install.ps1 C:\path\to\project" `
           -f (Get-Location).Path)
  }
}

# The package is never its own target: unzip drops it into the current folder,
# so one stray cd puts .claude where Claude Code never looks.
$srcNorm  = $Src.TrimEnd('\', '/')
$destNorm = $Dest.TrimEnd('\', '/')
if ($destNorm -eq $srcNorm -or
    $destNorm.StartsWith($srcNorm + [System.IO.Path]::DirectorySeparatorChar,
                         [System.StringComparison]::OrdinalIgnoreCase)) {
  throw ("$Dest is inside the godot-4 package, not a Godot project. Installing " +
         "there would put .claude next to the installer. Run the installer from " +
         "your project instead: cd C:\path\to\project; $Src\install.ps1")
}

$SrcClaude    = Join-Path $Src '.claude'
$DestClaude   = Join-Path $Dest '.claude'
$SrcSettings  = Join-Path $SrcClaude 'settings.json'
$DestSettings = Join-Path $DestClaude 'settings.json'

# ReadAllText detects a BOM and defaults to UTF-8. Get-Content on Windows
# PowerShell 5.1 would read a BOM-less file as the ANSI code page.
function Read-JsonFile([string]$Path) {
  $text = [System.IO.File]::ReadAllText($Path)
  if ([string]::IsNullOrWhiteSpace($text)) { return [PSCustomObject]@{} }
  return ($text | ConvertFrom-Json)
}

# The scripts a hook group runs. A group is identified by them, so
# re-installing is a no-op and a hand-edited matcher is not silently reverted.
function Get-GroupCommands($Group) {
  if ($null -eq $Group -or $Group -isnot [System.Management.Automation.PSCustomObject]) { return @() }
  $inner = $Group.PSObject.Properties['hooks']
  if ($null -eq $inner -or $null -eq $inner.Value) { return @() }
  $commands = @()
  foreach ($hook in @($inner.Value)) {
    if ($hook -isnot [System.Management.Automation.PSCustomObject]) { continue }
    $command = $hook.PSObject.Properties['command']
    if ($null -ne $command) { $commands += [string]$command.Value }
  }
  return $commands
}

# --- 1. Parse both settings files before touching the target -----------------

$incomingProp = (Read-JsonFile $SrcSettings).PSObject.Properties['hooks']
if ($null -eq $incomingProp) { throw "$SrcSettings has no hooks object" }
$incoming = $incomingProp.Value

if (Test-Path -LiteralPath $DestSettings -PathType Leaf) {
  try {
    $existing = Read-JsonFile $DestSettings
  } catch {
    throw "$DestSettings is not valid JSON ($($_.Exception.Message)). Nothing was installed; fix the file and run the installer again."
  }
  if ($existing -isnot [System.Management.Automation.PSCustomObject]) {
    throw "$DestSettings must contain a JSON object. Nothing was installed."
  }
  $hooksProp = $existing.PSObject.Properties['hooks']
  if ($null -ne $hooksProp -and $hooksProp.Value -isnot [System.Management.Automation.PSCustomObject]) {
    throw "$DestSettings has a 'hooks' entry that is not an object. Nothing was installed."
  }
} else {
  $existing = [PSCustomObject]@{}
}

# --- 2. Copy the payload -----------------------------------------------------

if ($DryRun) {
  Write-Host "would install into $DestClaude\"
  foreach ($dir in 'skills', 'commands', 'agents', 'scripts', 'templates') {
    $from = Join-Path $SrcClaude $dir
    if (-not (Test-Path -LiteralPath $from -PathType Container)) { continue }
    $n = (Get-ChildItem -LiteralPath $from -Recurse -File -Force |
          Where-Object { $_.Extension -ne '.pyc' }).Count
    Write-Host ("  {0}/ ({1} files)" -f $dir, $n)
  }
  Write-Host '  settings.json (hooks merged, existing entries kept)'
  exit 0
}

Write-Host "installing into $DestClaude\"
New-Item -ItemType Directory -Force -Path $DestClaude | Out-Null
foreach ($dir in 'skills', 'commands', 'agents', 'scripts', 'templates') {
  $from = Join-Path $SrcClaude $dir
  if (-not (Test-Path -LiteralPath $from -PathType Container)) { continue }
  $from = (Resolve-Path -LiteralPath $from).ProviderPath
  $to = Join-Path $DestClaude $dir

  # File by file, so an existing directory is merged into rather than nested.
  Get-ChildItem -LiteralPath $from -Recurse -File -Force |
    Where-Object { $_.Extension -ne '.pyc' -and $_.DirectoryName -notlike '*__pycache__*' } |
    ForEach-Object {
    $relative = $_.FullName.Substring($from.Length).TrimStart('\', '/')
    $out = Join-Path $to $relative
    $parent = Split-Path -Parent $out
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
      New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $_.FullName -Destination $out -Force
  }
  Write-Host "installed .claude/$dir"
}

# --- 3. Merge the hooks --------------------------------------------------------

if ($null -eq $existing.PSObject.Properties['hooks']) {
  $existing | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([PSCustomObject]@{})
}
$hooks = $existing.hooks

$added = 0
foreach ($evt in $incoming.PSObject.Properties) {
  $slot = $hooks.PSObject.Properties[$evt.Name]
  $current = @()
  if ($null -ne $slot -and $null -ne $slot.Value) { $current = @($slot.Value) }

  foreach ($group in @($evt.Value)) {
    $commands = Get-GroupCommands $group
    $present = $false
    foreach ($other in $current) {
      foreach ($command in (Get-GroupCommands $other)) {
        if ($commands -contains $command) { $present = $true; break }
      }
      if ($present) { break }
    }
    if ($present) { continue }
    $current += $group
    $added++
  }

  if ($null -ne $slot) {
    $slot.Value = $current
  } else {
    $hooks | Add-Member -NotePropertyName $evt.Name -NotePropertyValue $current
  }
}

# Written as UTF-8 without a BOM: Set-Content -Encoding UTF8 on 5.1 adds one,
# and a BOM in front of the JSON breaks parsers that do not expect it.
$json = $existing | ConvertTo-Json -Depth 100
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($DestSettings, $json + "`n", $utf8)
Write-Host "merged $added hook group(s) into .claude/settings.json"

# --- 4. Runtime the hooks need ------------------------------------------------

# The hooks are bash and Python scripts. Missing tools do not block the
# install, but the user should hear about it now rather than at the first hook.
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
  Write-Warning 'bash was not found on PATH. The hooks are bash scripts; install Git for Windows (Git Bash) so Claude Code can run them.'
}
if (-not (Get-Command python3 -ErrorAction SilentlyContinue)) {
  Write-Warning 'python3 was not found on PATH. guard_scene.py runs as python3; without it the scene guard hook fails.'
}

Write-Host @'

Done. Next:

  /godot-4:init     detect the engine and propose a constitution

The hooks are active from the next session in this project. Everything stays
inert in a directory with no project.godot.
'@
