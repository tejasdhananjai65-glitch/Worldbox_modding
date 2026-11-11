<#
.SYNOPSIS
  Cecil-based type inspector for WorldBox modding work.

.DESCRIPTION
  Reads a managed assembly with Mono.Cecil and prints the public surface of
  every type whose FullName matches the given pattern. Read-only: the target
  assembly is never modified.

  The WorldBox install ships Mono.Cecil inside the NeoModLoader Assemblies
  folder, so no extra download is needed.

.EXAMPLE
  .\dump-types.ps1 -Assembly <path> -Pattern 'GodPower'
.EXAMPLE
  .\dump-types.ps1 -Assembly <path> -Pattern '^GodPower$' -Exact
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $Assembly,
  [Parameter(Mandatory = $true)][string] $Pattern,
  [switch] $Exact,
  [switch] $AllMembers
)

$ErrorActionPreference = 'Stop'

$wb = 'C:\Program Files (x86)\Steam\steamapps\common\WorldBox'
$cecil = Join-Path $wb 'worldbox_Data\StreamingAssets\mods\NML\Assemblies\Mono.Cecil.dll'

if (-not (Test-Path $cecil)) { throw "Mono.Cecil.dll not found at $cecil" }
if (-not (Test-Path $Assembly)) { throw "Assembly not found: $Assembly" }

if (-not ('Mono.Cecil.AssemblyDefinition' -as [type])) { Add-Type -Path $cecil }

$asm = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($Assembly)

# collect every type, including nested ones
$all = New-Object System.Collections.Generic.List[object]
function Walk($types) {
  foreach ($t in $types) {
    $script:all.Add($t)
    if ($t.HasNestedTypes) { Walk $t.NestedTypes }
  }
}
Walk $asm.MainModule.Types

$hits = $all | Where-Object {
  if ($Exact) { $_.FullName -eq $Pattern } else { $_.FullName -like $Pattern }
}

if ($hits.Count -eq 0) {
  Write-Output "NO MATCH for pattern: $Pattern"
  exit 1
}

foreach ($t in $hits) {
  $bt = if ($t.BaseType) { $t.BaseType.FullName } else { '-' }
  Write-Output ("=== TYPE {0} : {1}" -f $t.FullName, $bt)

  foreach ($f in $t.Fields) {
    if ($f.IsPublic -or $AllMembers) {
      Write-Output ("    FIELD {0} {1}{2}" -f $f.FieldType.FullName, $f.Name, $(if ($f.IsStatic) { ' [static]' } else { '' }))
    }
  }
  foreach ($p in $t.Properties) {
    $acc = $p.GetMethod; if ($null -eq $acc) { $acc = $p.SetMethod }
    if ($acc -and ($acc.IsPublic -or $acc.IsFamily -or $AllMembers)) {
      $g = if ($p.GetMethod) { 'get;' } else { '' }
      $s = if ($p.SetMethod) { 'set;' } else { '' }
      Write-Output ("    PROP {0} {1} {{ {2} {3} }}" -f $p.PropertyType.FullName, $p.Name, $g, $s)
    }
  }
  foreach ($m in $t.Methods) {
    if ($m.IsPublic -or $m.IsFamily -or $AllMembers) {
      $ps = ($m.Parameters | ForEach-Object { $_.ParameterType.FullName + ' ' + $_.Name }) -join ', '
      Write-Output ("    METHOD {0} {1}({2}){3}" -f $m.ReturnType.FullName, $m.Name, $ps, $(if ($m.IsStatic) { ' [static]' } else { '' }))
    }
  }
  Write-Output ""
}
exit 0
