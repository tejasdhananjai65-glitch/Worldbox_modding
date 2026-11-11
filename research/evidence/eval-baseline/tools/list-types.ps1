<#
.SYNOPSIS
  List every type name in a managed assembly (optionally filtered by regex).

.EXAMPLE
  .\list-types.ps1 -Assembly <path> -Filter 'Trait'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $Assembly,
  [string] $Filter = ''
)

$ErrorActionPreference = 'Stop'
$wb = 'C:\Program Files (x86)\Steam\steamapps\common\WorldBox'
$cecil = Join-Path $wb 'worldbox_Data\StreamingAssets\mods\NML\Assemblies\Mono.Cecil.dll'
if (-not ('Mono.Cecil.AssemblyDefinition' -as [type])) { Add-Type -Path $cecil }

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Assembly)
$all = New-Object System.Collections.Generic.List[string]
function Walk($types) {
  foreach ($t in $types) {
    $script:all.Add($t.FullName)
    if ($t.HasNestedTypes) { Walk $t.NestedTypes }
  }
}
Walk $asm.MainModule.Types

Write-Output "TOTAL TYPES: $($all.Count)"
if ($Filter) {
  $all | Where-Object { $_ -match $Filter } | Sort-Object
} else {
  $all | Sort-Object
}
