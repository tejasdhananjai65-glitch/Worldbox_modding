<#
.SYNOPSIS
  Offline compile-check for WorldBox NML mods.

.DESCRIPTION
  NeoModLoader compiles a mod's .cs files at game startup using its embedded
  Roslyn 4.9.2, referencing every DLL in the game's Managed folder, every DLL in
  NML\Assemblies, NeoModLoader.dll, and Assembly-CSharp-Publicized.dll.

  This script reproduces that compile locally so a mod author gets errors in about
  two seconds instead of launching the game. Exit code 0 means the game will
  accept the code too.

  The emitted DLL is a COMPILE CHECK ONLY. NML recompiles from source at game
  start, so you never need to ship a built DLL.

.EXAMPLE
  .\compile-mod.ps1 -ModPath "C:\...\WorldBox\Mods\MyMod"

.EXAMPLE
  .\compile-mod.ps1 -ModPath "C:\work\MyMod" -Out "C:\work\out\MyMod.dll"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $ModPath,
  [string] $Out,
  [string] $SourceRoot,
  [string[]] $ExtraReference,
  [switch] $NoEmit,
  [switch] $Quiet
)

$ErrorActionPreference = 'Stop'
$script:ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-WorldBox {
  foreach ($c in @(
      "C:\Program Files (x86)\Steam\steamapps\common\WorldBox",
      "C:\Program Files\Steam\steamapps\common\WorldBox",
      "$env:USERPROFILE\Steam\steamapps\common\WorldBox")) {
    if (Test-Path (Join-Path $c 'worldbox_Data')) { return $c }
  }
  return $null
}

$csc = Join-Path $script:ToolRoot 'toolchain\pkg\compilers\tasks\net472\csc.exe'
if (-not (Test-Path $csc)) {
  Write-Host "Roslyn compiler missing at $csc" -ForegroundColor Red
  Write-Host "Restore it with:  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-toolchain.ps1" -ForegroundColor Yellow
  exit 2
}

$wb = Find-WorldBox
if (-not $wb) { Write-Host "WorldBox install not found." -ForegroundColor Red; exit 2 }

$saMods     = Join-Path $wb 'worldbox_Data\StreamingAssets\mods'
$nmlAssem   = Join-Path $saMods 'NML\Assemblies'
$managed    = Join-Path $wb 'worldbox_Data\Managed'
$publicized = Join-Path $saMods 'NML\Assembly-CSharp-Publicized.dll'

if ($SourceRoot) { $srcRoot = $SourceRoot }
else {
  $srcRoot = Join-Path $ModPath 'Code'
  if (-not (Test-Path $srcRoot)) { $srcRoot = $ModPath }
}

# NML ignores dot-files and these directories when collecting sources.
$ignoredDirs = @('bin', 'obj', 'Properties', 'packages')
$sources = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.cs -File |
              Where-Object {
                $_.Name -notlike '.*' -and
                -not (@($_.Directory.FullName -split '[\\/]') | Where-Object { $ignoredDirs -contains $_ })
              } | Sort-Object FullName)
if ($sources.Count -eq 0) {
  Write-Host "No .cs sources found under $srcRoot" -ForegroundColor Red
  exit 2
}

# Reference set: mirrors ModCompileLoadService.prepareCompile exactly.
$refs = [System.Collections.Generic.List[string]]::new()
function Add-Ref([string] $p) {
  if ($p -and (Test-Path $p) -and -not $refs.Contains($p)) { $refs.Add($p) }
}
Get-ChildItem $managed   -Filter *.dll -File | ForEach-Object { Add-Ref $_.FullName }
Get-ChildItem $nmlAssem -Filter *.dll -File | ForEach-Object { Add-Ref $_.FullName }
Add-Ref (Join-Path $saMods 'NeoModLoader.dll')
Add-Ref $publicized
if ($ExtraReference) { foreach ($r in $ExtraReference) { Add-Ref $r } }

$asmName = (Split-Path -Leaf $ModPath) -replace '[^A-Za-z0-9_]', '_'
if (-not $Out) { $Out = Join-Path $env:TEMP "$asmName.check.dll" }

$argList = @(
  '-nologo', '-nostdlib+', '-target:library', "-out:$Out",
  '-langversion:latest', '-unsafe+', '-optimize+', '-deterministic+',
  '-nowarn:1701,1702,0436'
)
foreach ($r in $refs) { $argList += "-r:`"$r`"" }
foreach ($s in $sources) { $argList += "`"$($s.FullName)`"" }

if (-not $Quiet) {
  Write-Host ""
  Write-Host "=== WorldBox mod compile check: $asmName ===" -ForegroundColor Cyan
  Write-Host ("sources : {0} file(s) under {1}" -f $sources.Count, $srcRoot)
  Write-Host ("refs    : {0}" -f $refs.Count)
  Write-Host ""
}

$output = & $csc @argList 2>&1
$code = $LASTEXITCODE

$errLines  = @($output | Where-Object { $_ -match ': error CS\d+' })
$warnLines = @($output | Where-Object { $_ -match ': warning CS\d+' })

foreach ($l in $warnLines) { Write-Host $l -ForegroundColor Yellow }
foreach ($l in $errLines)   { Write-Host $l -ForegroundColor Red }
foreach ($l in $output) {
  if ($l -notmatch ': (error|warning) CS\d+') { Write-Host $l }
}

if ($code -eq 0) {
  if (-not $Quiet) {
    Write-Host ("BUILD OK -> {0}" -f $Out) -ForegroundColor Green
    if (-not $NoEmit) {
      Write-Host "compile-check only; NML recompiles from Code\*.cs at game start" -ForegroundColor DarkGray
    }
  }
  exit 0
} else {
  if (-not $Quiet) { Write-Host "BUILD FAILED ($($errLines.Count) error(s))" -ForegroundColor Red }
  exit 1
}
