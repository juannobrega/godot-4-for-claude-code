# Exercises install.ps1 end to end in throwaway directories. Run by the
# install-windows job in .github/workflows/validate.yml, on both Windows
# PowerShell 5.1 and PowerShell 7.
#
#   1. fresh install into a project with no .claude/
#   2. reinstall is a no-op
#   3. a project's own hooks and settings survive the merge
#   4. an invalid settings.json aborts before anything is copied
#   5. the three destination forms: no argument, -Here, explicit path
#
# Exits non-zero on the first failed check.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repo      = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Repo 'install.ps1'
$Payload   = 'skills', 'commands', 'agents', 'scripts', 'templates'
$Root      = Join-Path ([System.IO.Path]::GetTempPath()) ('godot4-install-' + [guid]::NewGuid())

function Fail([string]$Message) {
  Write-Host "::error::$Message"
  exit 1
}

function Read-Json([string]$Path) {
  return ([System.IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

function Get-GroupCount($Settings) {
  $n = 0
  foreach ($evt in $Settings.hooks.PSObject.Properties) { $n += @($evt.Value).Count }
  return $n
}

function Get-AllCommands($Settings) {
  $all = @()
  foreach ($evt in $Settings.hooks.PSObject.Properties) {
    foreach ($group in @($evt.Value)) {
      foreach ($hook in @($group.hooks)) { $all += [string]$hook.command }
    }
  }
  return $all
}

function New-Project([string]$Name) {
  $dir = Join-Path $Root $Name
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  New-Item -ItemType File -Path (Join-Path $dir 'project.godot') | Out-Null
  return $dir
}

$expected = Get-GroupCount (Read-Json (Join-Path $Repo '.claude\settings.json'))

try {
  # 1. Fresh install --------------------------------------------------------
  $fresh = New-Project 'fresh'
  & $Installer $fresh
  $settingsPath = Join-Path $fresh '.claude\settings.json'

  foreach ($dir in $Payload) {
    $src = Join-Path $Repo ".claude\$dir"
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $want = @(Get-ChildItem -LiteralPath $src -Recurse -File -Force).Count
    $got  = @(Get-ChildItem -LiteralPath (Join-Path $fresh ".claude\$dir") -Recurse -File -Force).Count
    if ($want -ne $got) { Fail "fresh install: .claude/$dir has $got file(s), expected $want" }
  }

  $groups = Get-GroupCount (Read-Json $settingsPath)
  if ($groups -ne $expected) { Fail "fresh install: $groups hook group(s), expected $expected" }

  $bytes = [System.IO.File]::ReadAllBytes($settingsPath)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Fail 'fresh install: settings.json was written with a UTF-8 BOM'
  }
  Write-Host 'ok  fresh install'

  # 2. Reinstall is a no-op -------------------------------------------------
  & $Installer $fresh
  $groups = Get-GroupCount (Read-Json $settingsPath)
  if ($groups -ne $expected) { Fail "reinstall: $groups hook group(s), expected $expected" }
  Write-Host 'ok  reinstall is a no-op'

  # 3. Existing hooks and settings survive ----------------------------------
  $merged = New-Project 'merged'
  New-Item -ItemType Directory -Force -Path (Join-Path $merged '.claude') | Out-Null
  $own = @'
{
  "permissions": { "allow": ["Bash(godot:*)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "echo mine" } ] }
    ]
  }
}
'@
  $mergedSettings = Join-Path $merged '.claude\settings.json'
  [System.IO.File]::WriteAllText($mergedSettings, $own, (New-Object System.Text.UTF8Encoding $false))
  & $Installer $merged

  $result = Read-Json $mergedSettings
  $groups = Get-GroupCount $result
  if ($groups -ne ($expected + 1)) { Fail "merge: $groups hook group(s), expected $($expected + 1)" }
  if ((Get-AllCommands $result) -notcontains 'echo mine') { Fail 'merge: the project''s own hook was dropped' }
  if (@($result.permissions.allow) -notcontains 'Bash(godot:*)') { Fail 'merge: unrelated settings were dropped' }
  Write-Host 'ok  existing hooks and settings survive'

  # 4. Invalid JSON aborts before copying -----------------------------------
  $broken = New-Project 'broken'
  New-Item -ItemType Directory -Force -Path (Join-Path $broken '.claude') | Out-Null
  $brokenSettings = Join-Path $broken '.claude\settings.json'
  [System.IO.File]::WriteAllText($brokenSettings, '{ not json', (New-Object System.Text.UTF8Encoding $false))

  $threw = $false
  try { & $Installer $broken } catch { $threw = $true }
  if (-not $threw) { Fail 'invalid JSON: the installer did not fail' }
  foreach ($dir in $Payload) {
    if (Test-Path -LiteralPath (Join-Path $broken ".claude\$dir")) {
      Fail "invalid JSON: .claude/$dir was copied before the failure"
    }
  }
  if ([System.IO.File]::ReadAllText($brokenSettings) -ne '{ not json') {
    Fail 'invalid JSON: the broken settings.json was modified'
  }
  Write-Host 'ok  invalid settings.json aborts before copying'
}
finally {
  Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
}

  # 5. Destination forms ---------------------------------------------------
  # The no-argument path is the one a shadowed parameter breaks, and it was
  # uncovered when exactly that bug shipped.
  $nested = Join-Path $Root 'walkup'
  New-Item -ItemType Directory -Force -Path (Join-Path $nested 'scenes\player') | Out-Null
  New-Item -ItemType File -Force -Path (Join-Path $nested 'project.godot') | Out-Null
  Push-Location (Join-Path $nested 'scenes\player')
  try { & $Installer } finally { Pop-Location }
  if (-not (Test-Path -LiteralPath (Join-Path $nested '.claude\settings.json') -PathType Leaf)) {
    Fail 'no argument: did not install at the project root found by walking up'
  }
  if (Test-Path -LiteralPath (Join-Path $nested 'scenes\player\.claude') -PathType Container) {
    Fail 'no argument: installed in the current directory instead of the project root'
  }
  Write-Host 'ok  no argument walks up to the project root'

  # -Here must not search, and must accept a directory with no project.godot.
  $empty = Join-Path $Root 'empty'
  New-Item -ItemType Directory -Force -Path $empty | Out-Null
  Push-Location $empty
  try { & $Installer -Here } finally { Pop-Location }
  if (-not (Test-Path -LiteralPath (Join-Path $empty '.claude\settings.json') -PathType Leaf)) {
    Fail '-Here: did not install into the current directory'
  }
  Write-Host 'ok  -Here installs into an empty directory'

  # -Here inside a project must stay put rather than walk up.
  $sub = Join-Path $nested 'scenes'
  Push-Location $sub
  try { & $Installer -Here } finally { Pop-Location }
  if (-not (Test-Path -LiteralPath (Join-Path $sub '.claude\settings.json') -PathType Leaf)) {
    Fail '-Here: walked up instead of staying in the current directory'
  }
  Write-Host 'ok  -Here does not walk up'

  # Contradictory intent must be rejected, not silently resolved.
  $threw = $false
  try { & $Installer -Here $nested 2>$null } catch { $threw = $true }
  if (-not $threw) { Fail '-Here with a target should be rejected' }
  Write-Host 'ok  -Here with a target is rejected'

Write-Host 'install.ps1: all checks passed'
