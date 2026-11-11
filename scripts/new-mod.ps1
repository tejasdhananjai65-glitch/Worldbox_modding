<#
.SYNOPSIS
  Scaffolds a new WorldBox NML mod from the worldbox-modder template.

.DESCRIPTION
  Copies templates\minimal-mod to <Destination>\<sanitised ModId>, rewrites mod.json
  (GUID, name, author, description) and renames the placeholder namespace and asset
  ids so the new mod does not collide with the template.

.EXAMPLE
  .\new-mod.ps1 -ModId com.example.giantpower -Namespace GiantPower -Author example

.EXAMPLE
  .\new-mod.ps1 -ModId com.example.giantpower -Destination C:\work\mods
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $ModId,
  [string] $Namespace = 'MyMod',
  [string] $Author = 'author',
  [string] $Description = 'A WorldBox mod.',
  [string] $Destination = "$PWD"
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object Text.UTF8Encoding $false

$template = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\templates\minimal-mod'))
if (-not (Test-Path $template)) {
  Write-Host "Template not found: $template" -ForegroundColor Red
  exit 1
}

$folderName = $ModId -replace '[^A-Za-z0-9_]', '_'
$target = Join-Path ([IO.Path]::GetFullPath($Destination)) $folderName
if (Test-Path $target) {
  Write-Host "Target already exists: $target" -ForegroundColor Red
  exit 1
}

Copy-Item -Path $template -Destination $target -Recurse

# --- mod.json -------------------------------------------------------------------
$jsonPath = Join-Path $target 'mod.json'
$json = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$json.name    = $Namespace
$json.GUID    = $ModId
$json.author  = $Author
$json.description = $Description
$json | ConvertTo-Json -Depth 5 | ForEach-Object { [IO.File]::WriteAllText($jsonPath, $_, $utf8NoBom) }

# --- C# sources -----------------------------------------------------------------
$prefix = ($Namespace -replace '[^A-Za-z0-9_]', '_').ToLower()
$map = [ordered]@{
  'MyMod'                 = $Namespace
  'my_mod_group'          = "${prefix}_group"
  'my_trait'              = "${prefix}_trait"
  'my_power'              = "${prefix}_power"
  'my_effect'             = "${prefix}_effect"
  'my_mod_tab'            = "${prefix}_tab"
  'iconModderDemo'        = "icon${prefix}"
}
Get-ChildItem $target -Recurse -Filter *.cs -File | ForEach-Object {
  $text = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  foreach ($k in $map.Keys) { $text = $text.Replace($k, $map[$k]) }
  [IO.File]::WriteAllText($_.FullName, $text, $utf8NoBom)
}

# --- localisation ---------------------------------------------------------------
$localePath = Join-Path $target 'Locales\en.json'
if (Test-Path $localePath) {
  $locale = [IO.File]::ReadAllText($localePath, [Text.Encoding]::UTF8)
  foreach ($k in $map.Keys) { $locale = $locale.Replace($k, $map[$k]) }
  [IO.File]::WriteAllText($localePath, $locale, $utf8NoBom)
}

# --- sprite ---------------------------------------------------------------------
$spriteDir = Join-Path $target "GameResources\ui\icons"
if (Test-Path $spriteDir) {
  Get-ChildItem $spriteDir -Filter *.png -File | ForEach-Object {
    Rename-Item $_.FullName ("icon$prefix.png") -Force
  }
}

Write-Host "Created mod at: $target" -ForegroundColor Green
Write-Host "Next: compile-check it with scripts\compile-mod.ps1 -ModPath `"$target`"" -ForegroundColor DarkGray
exit 0
