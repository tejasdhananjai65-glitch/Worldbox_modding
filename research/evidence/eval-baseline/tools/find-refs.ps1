<#
.SYNOPSIS
  Find call sites of a method across an assembly.

.DESCRIPTION
  Answers "who calls Actor::finishScale()" style questions.

.EXAMPLE
  .\find-refs.ps1 -Assembly <path> -MethodName 'finishScale'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $Assembly,
  [string] $MethodName,
  [string] $FieldName,
  [string] $InvokeType
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

foreach ($t in $all) {
  foreach ($m in $t.Methods) {
    if (-not $m.HasBody) { continue }
    foreach ($ins in $m.Body.Instructions) {
      if ($ins.Operand -is [Mono.Cecil.MethodReference]) {
        $mr = $ins.Operand
        if ($mr.Name -eq $MethodName) {
          Write-Output ("{0}::{1}  ->  {2}" -f $t.FullName, $m.Name, $mr.FullName)
        }
      }
      if ($ins.Operand -is [Mono.Cecil.FieldReference]) {
        $fr = $ins.Operand
        if ($fr.Name -eq $FieldName) {
          Write-Output ("FIELD {0}::{1}  ->  {2}" -f $t.FullName, $m.Name, $fr.FullName)
        }
      }
      if ($ins.Operand -is [Mono.Cecil.MethodReference]) {
        $mr2 = $ins.Operand
        if ($mr2.DeclaringType.FullName -eq $InvokeType) {
          Write-Output ("INVOKE {0}::{1}  ->  {2}" -f $t.FullName, $m.Name, $mr2.FullName)
        }
      }
    }
  }
}
