<#
.SYNOPSIS
  Restores the offline WorldBox mod compile toolchain (Roslyn 4.9.2 net472).

.DESCRIPTION
  Downloads Microsoft.Net.Compilers.Toolset 4.9.2 from nuget.org - the exact Roslyn
  version NeoModLoader embeds - and extracts the net472 compiler used by compile-mod.ps1.

  Only needed once. Requires internet access.

  If the toolchain is already present this exits 0 immediately.
#>
[CmdletBinding()]
param([switch] $Force)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pkg  = Join-Path $root 'toolchain\pkg'
$csc  = Join-Path $pkg 'compilers\tasks\net472\csc.exe'

if ((Test-Path $csc) -and -not $Force) {
  Write-Host "Toolchain already present: $csc" -ForegroundColor Green
  exit 0
}

New-Item -ItemType Directory -Force -Path $pkg | Out-Null
$url = 'https://www.nuget.org/api/v2/package/Microsoft.Net.Compilers.Toolset/4.9.2'
$zip = Join-Path $pkg 'compilers.4.9.2.zip'

Write-Host "Downloading Roslyn 4.9.2 toolset..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 300

$ext = Join-Path $pkg 'compilers'
if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $ext -Force

if (-not (Test-Path $csc)) {
  Write-Host "Extraction failed: $csc missing" -ForegroundColor Red
  exit 1
}
Write-Host "Toolchain ready: $csc" -ForegroundColor Green
exit 0
