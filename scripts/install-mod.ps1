<#
.SYNOPSIS
  Copies a WorldBox mod folder into the game's Mods directory.

.DESCRIPTION
  Locates the WorldBox install, verifies the source folder contains a mod.json at its
  root (NML skips folders without one), and copies the folder into <WorldBox>\Mods\.

.EXAMPLE
  .\install-mod.ps1 -ModPath "C:\work\MyMod"

.EXAMPLE
  .\install-mod.ps1 -ModPath "C:\work\MyMod" -DryRun
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $ModPath,
  [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

function Find-WorldBox {
  foreach ($c in @(
      "C:\Program Files (x86)\Steam\steamapps\common\WorldBox",
      "C:\Program Files\Steam\steamapps\common\WorldBox",
      "$env:USERPROFILE\Steam\steamapps\common\WorldBox")) {
    if (Test-Path (Join-Path $c 'worldbox_Data')) { return $c }
  }
  return $null
}

$src = [IO.Path]::GetFullPath($ModPath)
if (-not (Test-Path $src)) {
  Write-Host "Mod path not found: $src" -ForegroundColor Red
  exit 1
}
if (-not (Test-Path (Join-Path $src 'mod.json'))) {
  Write-Host "No mod.json at the mod root: $src" -ForegroundColor Red
  Write-Host "NML skips folders without mod.json." -ForegroundColor Yellow
  exit 1
}

$wb = Find-WorldBox
if (-not $wb) { Write-Host "WorldBox install not found." -ForegroundColor Red; exit 1 }

$modsDir = Join-Path $wb 'Mods'
$dest = Join-Path $modsDir (Split-Path -Leaf $src)

if ($DryRun) {
  Write-Host "Would install:" -ForegroundColor Cyan
  Write-Host "  from: $src"
  Write-Host "  to  : $dest"
  exit 0
}

New-Item -ItemType Directory -Force -Path $modsDir | Out-Null

# Mirror the source folder onto the destination. Copy-Item -Recurse would NEST a copy
# inside an existing destination, leaving the previous version's .cs files in place and
# producing duplicate type definitions (error CS0101) at compile time.
# robocopy /MIR replaces the destination contents exactly.
$robocopy = Get-Command robocopy.exe -ErrorAction SilentlyContinue
if ($robocopy) {
  & robocopy.exe $src $dest /MIR /NFL /NDL /NJH /NJS /NP | Out-Null
  $rc = $LASTEXITCODE
  if ($rc -ge 8) {
    Write-Host "robocopy failed with exit code $rc" -ForegroundColor Red
    exit 1
  }
} else {
  if (Test-Path $dest) {
    Get-ChildItem $dest -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  }
  Copy-Item -Path $src -Destination $dest -Recurse -Force
}

Write-Host "Installed to: $dest" -ForegroundColor Green
Write-Host "Launch WorldBox, then check Player.log for the mod's compile line." -ForegroundColor DarkGray
exit 0
