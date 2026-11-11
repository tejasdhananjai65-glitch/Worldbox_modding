<#
.SYNOPSIS
  Offline compile check for a WorldBox NeoModLoader (NML) mod.

.DESCRIPTION
  NML compiles a mod's Code\*.cs at game start with its own Roslyn. This script
  reproduces that compile locally against the same reference assemblies, so a mod
  can be validated in seconds without launching the game.

  Reference set (mirrors what NML hands to Roslyn):
      worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll  (game API)
      worldbox_Data\StreamingAssets\mods\NeoModLoader.dll                     (NML API)
      worldbox_Data\StreamingAssets\mods\NML\Assemblies\0Harmony.dll          (patching)
      worldbox_Data\Managed\*.dll                                            (Unity + BCL)

  The compiler binary is the Roslyn 4.9.2 (net472) csc.exe that already ships in
  the workspace toolchain at ..\..\toolchain\pkg\compilers\tasks\net472\csc.exe.
  Nothing is installed and nothing outside this directory is written.

  The emitted DLL is a compile check only - NML recompiles from Code\*.cs at
  game start, so the DLL does not need to be shipped with the mod.

.EXAMPLE
  .\compile-check.ps1 -ModPath "..\GiantVillagers"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $ModPath,
  [string] $Out,
  [switch] $NoEmit
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

# ---- compiler --------------------------------------------------------------------
$csc = Join-Path $script:ToolRoot '..\..\toolchain\pkg\compilers\tasks\net472\csc.exe'
$csc = [System.IO.Path]::GetFullPath($csc)
if (-not (Test-Path $csc)) {
  Write-Host "Roslyn csc.exe not found at $csc" -ForegroundColor Red
  exit 2
}

$wb = Find-WorldBox
if (-not $wb) { Write-Host "WorldBox install not found." -ForegroundColor Red; exit 2 }

$saMods     = Join-Path $wb 'worldbox_Data\StreamingAssets\mods'
$nmlAssem   = Join-Path $saMods 'NML\Assemblies'
$managed    = Join-Path $wb 'worldbox_Data\Managed'
$publicized = Join-Path $saMods 'NML\Assembly-CSharp-Publicized.dll'

# ---- sources ---------------------------------------------------------------------
$srcRoot = Join-Path $ModPath 'Code'
if (-not (Test-Path $srcRoot)) { $srcRoot = $ModPath }
$sources = @(Get-ChildItem -Path $srcRoot -Recurse -Filter *.cs -File | Sort-Object FullName)
if ($sources.Count -eq 0) {
  Write-Host "No .cs sources found under $srcRoot" -ForegroundColor Red
  exit 2
}

# ---- references ------------------------------------------------------------------
$refs = [System.Collections.Generic.List[string]]::new()
function Add-Ref([string] $p) {
  if ($p -and (Test-Path $p) -and -not $refs.Contains($p)) { $refs.Add($p) }
}
foreach ($b in @('mscorlib.dll','System.dll','System.Core.dll','netstandard.dll')) {
  Add-Ref (Join-Path $managed $b)
}
Add-Ref $publicized
Add-Ref (Join-Path $saMods 'NeoModLoader.dll')
Add-Ref (Join-Path $nmlAssem '0Harmony.dll')
foreach ($u in @('UnityEngine.CoreModule.dll','UnityEngine.UI.dll','UnityEngine.UIModule.dll',
                 'UnityEngine.TextRenderingModule.dll','UnityEngine.InputLegacyModule.dll',
                 'UnityEngine.ImageConversionModule.dll','UnityEngine.ParticleSystemModule.dll',
                 'UnityEngine.AnimationModule.dll','UnityEngine.AudioModule.dll',
                 'UnityEngine.JSONSerializeModule.dll','UnityEngine.TilemapModule.dll',
                 'UnityEngine.UIElementsModule.dll','UnityEngine.IMGUIModule.dll')) {
  Add-Ref (Join-Path $managed $u)
}
Add-Ref (Join-Path $managed 'Newtonsoft.Json.dll')

# ---- build the csc command ------------------------------------------------------
$asmName = (Split-Path -Leaf $ModPath) -replace '[^A-Za-z0-9_]', '_'
if (-not $Out) { $Out = Join-Path $script:ToolRoot "build\$asmName.check.dll" }
$outDir = Split-Path -Parent $Out
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

$argList = @(
  '-nologo', '-nostdlib+', '-target:library', "-out:$Out",
  '-langversion:latest', '-unsafe+', '-optimize+', '-deterministic+', '-nowarn:1701,1702'
)
foreach ($r in $refs) { $argList += "-r:`"$r`"" }
foreach ($s in $sources) { $argList += "`"$($s.FullName)`"" }

Write-Host ""
Write-Host "=== WorldBox mod compile check: $asmName ===" -ForegroundColor Cyan
Write-Host ("compiler : {0}" -f $csc)
Write-Host ("sources  : {0} file(s) under {1}" -f $sources.Count, $srcRoot)
Write-Host ("refs     : {0}" -f $refs.Count)
Write-Host ""

$output = & $csc @argList 2>&1
$code = $LASTEXITCODE

$errLines  = @($output | Where-Object { $_ -match ': error CS\d+' })
$warnLines = @($output | Where-Object { $_ -match ': warning CS\d+' })

foreach ($l in $warnLines) { Write-Host $l -ForegroundColor Yellow }
foreach ($l in $errLines)   { Write-Host $l -ForegroundColor Red }
foreach ($l in $output) {
  if ($l -notmatch ': (error|warning) CS\d+') { Write-Host $l }
}

Write-Host ("csc exit code: {0}" -f $code)

if ($code -eq 0) {
  Write-Host ("BUILD OK -> {0}" -f $Out) -ForegroundColor Green
  exit 0
} else {
  Write-Host ("BUILD FAILED ({0} error(s))" -f $errLines.Count) -ForegroundColor Red
  exit 1
}
