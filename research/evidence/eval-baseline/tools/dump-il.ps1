<#
.SYNOPSIS
  Print the IL of a method (or all methods of a type) from a managed assembly.

.DESCRIPTION
  Mono.Cecil-based. Useful when the type/member signature alone does not tell
  you the semantics (e.g. whether a stat value is additive or a multiplier).

.EXAMPLE
  .\dump-il.ps1 -Assembly <path> -Type 'BaseStats' -Method 'set'
.EXAMPLE
  .\dump-il.ps1 -Assembly <path> -Type 'GodPower' -Method 'getLocaleID'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $Assembly,
  [Parameter(Mandatory = $true)][string] $Type,
  [string] $Method = '',
  [switch] $AllMembers,
  [switch] $ExactType
)

$ErrorActionPreference = 'Stop'
$wb = 'C:\Program Files (x86)\Steam\steamapps\common\WorldBox'
$cecil = Join-Path $wb 'worldbox_Data\StreamingAssets\mods\NML\Assemblies\Mono.Cecil.dll'
if (-not ('Mono.Cecil.AssemblyDefinition' -as [type])) { Add-Type -Path $cecil }

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Assembly)
$all = New-Object System.Collections.Generic.List[object]
function Walk($types) {
  foreach ($t in $types) {
    $script:all.Add($t)
    if ($t.HasNestedTypes) { Walk $t.NestedTypes }
  }
}
Walk $asm.MainModule.Types

$targets = $all | Where-Object {
  if ($ExactType) { $_.FullName -eq $Type } else { $_.FullName -eq $Type -or $_.FullName -like "$Type*" }
}

foreach ($t in $targets) {
  Write-Output ("######## TYPE {0} : {1}" -f $t.FullName, $(if ($t.BaseType) { $t.BaseType.FullName } else { '-' }))
  foreach ($m in $t.Methods) {
    if ($Method -and $m.Name -notlike "*$Method*") { continue }
    if (-not $AllMembers -and -not ($m.IsPublic -or $m.IsFamily)) { continue }
    $ps = ($m.Parameters | ForEach-Object { $_.ParameterType.FullName + ' ' + $_.Name }) -join ', '
    Write-Output ("---- {0} {1}({2})" -f $m.ReturnType.FullName, $m.Name, $ps)
    if ($m.HasBody) {
      foreach ($ins in $m.Body.Instructions) {
        Write-Output ("     {0} {1}" -f $ins.Offset.ToString('x4'), $ins.ToString())
      }
    }
    Write-Output ""
  }
}
