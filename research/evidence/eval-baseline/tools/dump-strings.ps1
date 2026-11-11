<#
.SYNOPSIS
  Extract every ldstr literal from a managed assembly, with the method that uses it.

.DESCRIPTION
  Answers questions like "what stat ids exist?" or "what locale key does this
  asset use?" when the type signatures are not enough.

.EXAMPLE
  .\dump-strings.ps1 -Assembly <path> -Filter '^scale$'
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
$all = New-Object System.Collections.Generic.List[object]
function Walk($types) {
  foreach ($t in $types) {
    $script:all.Add($t)
    if ($t.HasNestedTypes) { Walk $t.NestedTypes }
  }
}
Walk $asm.MainModule.Types

$rows = New-Object System.Collections.Generic.List[string]
foreach ($t in $all) {
  foreach ($m in $t.Methods) {
    if (-not $m.HasBody) { continue }
    foreach ($ins in $m.Body.Instructions) {
      if ($ins.OpCode.Code -eq [Mono.Cecil.Cil.Code]::Ldstr) {
        $v = [string]$ins.Operand
        if ($Filter -and $v -notmatch $Filter) { continue }
        $rows.Add(("{0}::{1}  =>  {2}" -f $t.FullName, $m.Name, $v))
      }
    }
  }
}
$rows | Sort-Object -Unique
Write-Output ("---- {0} string literal(s) matched" -f $rows.Count)
