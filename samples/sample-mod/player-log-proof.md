# In-game verification proof — `worldbox-modder` sample mod

**Date:** 2026-10-23
**Machine:** Windows 11, WorldBox installed at
`C:\Program Files (x86)\Steam\steamapps\common\WorldBox`
**Game:** WorldBox 0.51.2 (Unity 2022.3.60f1)
**Loader:** NeoModLoader **1.2.1.1** (commit `f6017bdcb6a3cfd4855d634e41b274f013463092`)
**Sample mod:** `Mods\com_example_worldboxmoddertemplate`, GUID `com.example.worldboxmoddertemplate`
**Log:** `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`

---

## Tier 1 — offline compile check

```
=== WorldBox mod compile check: com_example_worldboxmoddertemplate ===
sources : 2 file(s) under ...\com_example_worldboxmoddertemplate\Code
refs    : 187

BUILD OK -> %USERPROFILE%\AppData\Local\Temp\com_example_worldboxmoddertemplate.check.dll
```

Exit code `0`. The reference set (187 assemblies) is identical to NML's own.

Negative control — a deliberately broken mod is rejected with a precise position:

```
worldbox-research\toolchain\badmod\Code\Main.cs(2,67): error CS0103: The name 'ThisDoesNotExist' does not exist in the current context
BUILD FAILED (1 error(s))
```

Exit code `1`.

## Tier 2 — in-game load

The mod was installed into the live `Mods\` folder and WorldBox was launched.

### The mod's own log lines

```
[NML]: [WorldBoxModderTemplate]: OnLoad
[NML]: [WorldBoxModderTemplate]: WorldBoxModderTemplate loading
[NML]: [WorldBoxModderTemplate]: WORLDBOX_MODDER_TEMPLATE_MARKER loaded
[NML]: [WorldBoxModderTemplate]: WorldBoxModderTemplate ready
[NML]: [WorldBoxModderTemplate]: Loaded
[NML]: [WorldBoxModderTemplate]: WorldBoxModderTemplate power tab created
```

`WORLDBOX_MODDER_TEMPLATE_MARKER loaded` is the unambiguous proof that the mod's
`OnLoad` body executed inside the game.

### The loader's own pipeline lines for this mod

```
004: Compile Mods And Load resources     = 1.5967
011: Load Resources From Mod WorldBoxModderTemplate = 0.0013
025: Init Mod WorldBoxModderTemplate     = 0.0000
036: Post-Init Mod WorldBoxModderTemplate = 0.0000
```

### No exception

No `Failed to compile` line and no exception stack trace appears for this mod.

---

## Incident 2 — `install-mod.ps1` nested the copy instead of replacing it

Found by the in-game run, not by any offline check.

**Symptom.** Re-installing the mod over an existing copy produced:

```
[NML]: Failed to compile mod COM_EXAMPLE_WORLDBOXMODDERTEMPLATE:
  Code\Content.cs(18,25): error CS0101: The namespace 'WorldBoxModderTemplate' already contains a definition for 'Content'
  Code\Main.cs(10,18): error CS0101: The namespace 'WorldBoxModderTemplate' already contains a definition for 'Main'
  Code\Content.cs(25,28): error CS0111: Type 'Content' already defines a member called 'Init' with the same parameter types
```

**Cause.** `Copy-Item -Path $src -Destination $dest -Recurse -Force` copies the
**source folder itself** into the destination when the destination already exists. The
result was two parallel copies of every source file:

```
Mods\com_example_worldboxmoddertemplate\
├── Code\Main.cs                     <- old
└── com_example_worldboxmoddertemplate\
    └── Code\Main.cs                 <- new
```

NML compiles every `.cs` file under the mod folder, so both copies landed in the same
namespace — hence the duplicate definitions.

**Fix.** `install-mod.ps1` now mirrors the source onto the destination with
`robocopy.exe /MIR`, which replaces the destination contents exactly and removes
anything left over from a previous version. A `Copy-Item` fallback (clear, then copy)
is kept for systems without `robocopy`.

**Re-verified.** After the fix the installed tree is clean, and a fresh game run
produced the proof lines quoted above with no compile failure.

### Compiled output on disk

```
worldbox_Data\StreamingAssets\mods\NML\CompiledMods\
  COM_EXAMPLE_WORLDBOXMODDERTEMPLATE.dll    8,704 bytes
  COM_EXAMPLE_WORLDBOXMODDERTEMPLATE.pdb   11,936 bytes
```

The UID is upper-cased and sanitised to `[A-Za-z0-9_]`.

### Compile record

```json
"COM_EXAMPLE_WORLDBOXMODDERTEMPLATE": {
  "dependencies": [],
  "disabled": false,
  "mod_id": "COM_EXAMPLE_WORLDBOXMODDERTEMPLATE",
  "optional_dependencies": [],
  "compile_environment": "NML_WINDOWS;NML_GAME_VERSION_0_51_2;NML_GAME_VERSION_0_51",
  "timestamp": 639283431046720076,
  "compile_timestamp": 639283431522216429
}
```

`compile_environment` is the set of preprocessor symbols NML defines for the mod —
here the platform and the game version.

---

## What the mod actually exercised

| Feature | Verified by |
|---|---|
| `mod.json` discovery and parsing | the mod was found and compiled |
| Roslyn compile of `Code\*.cs` | `Compile Mods And Load resources` |
| `BasicMod<T>` entry class discovery | `OnLoad` + `Loaded` |
| Trait group registration | trait group registered, no exception |
| Trait registration + `unlock(true)` | trait registered, no exception |
| Status effect registration | status registered, no exception |
| God power registration | power registered, no exception |
| Custom sprite via `GameResources\` | `Load Resources From Mod WorldBoxModderTemplate` |
| `Locales\en.json` auto-loading | `BasicMod<T>` implements `ILocalizable`; no `missing text:` for this mod |
| Power tab creation from `Update()` | `WorldBoxModderTemplate power tab created` |
| Locale keys `trait_<id>` / `<id>_description` | no `missing text:` entries for this mod |

---

## Incident during this verification — NML AutoUpdate destroyed the loader

This is recorded because it is a real, reproducible hazard.

**What happened.** On the very first launch of the game, NML's bundled
`NeoModLoader.AutoUpdate` module ran, found that a newer release (1.2.1.1) existed,
and tried to download it. The in-game download failed — the log shows
`Curl error 35: Handshake failed. UnityTls error code: 7` and
`Unable to complete SSL connection` — but the updater had already **deleted** the
installed loader.

**Why it was unrecoverable.** Decompiling `NeoModLoader.AutoUpdate_memload.dll`
(`NeoModLoader.AutoUpdate.UpdateHelper`) shows the exact sequence:

- `BackupFile(path)` — reads the file into an **in-memory** dictionary
  (`file_bak`) and then **deletes** it from disk.
- `TryReplaceFile(old, new)` — deletes `old` if present, then
  `File.Copy(new, old, true)`.

The backup exists only in the process's memory. When the download produced a 0-byte
file, the copy wrote a broken loader, and when the process exited the in-memory
backup was gone for good.

**How it presented.** With the loader missing, the game still started, but every mod
silently failed to compile:

```
[NML]: Error when load default reference ...\StreamingAssets\mods\NeoModLoader.dll:
       Could not find file "..."
004: Compile Mods And Load resources     = 0.0006
System.ArgumentNullException: Value cannot be null.
Parameter name: references[185]
  at Microsoft.CodeAnalysis.Compilation.ValidateReferences[T] ...
  at NeoModLoader.services.ModCompileLoadService.compileMod (...) ModCompileLoadService.cs:170
```

The clue is `references[185]` — NML adds **its own DLL** as a compile reference, so
when the loader is missing the reference list contains a null and Roslyn refuses to
compile anything.

**How it was fixed.** `NeoModLoader.dll` and `NeoModLoader.pdb` for release **1.2.1.1**
were downloaded from the official GitHub release and installed to
`worldbox_Data\StreamingAssets\mods\`, and `NML\commit` was set to that release's
commit `f6017bdcb6a3cfd4855d634e41b274f013463092`.

Installing the version the updater wants makes the updater a no-op: `GetDLLVersion`
reads `AssemblyName.GetAssemblyName(path).Version`, so an installed `1.2.1.1` is
already at the latest version and nothing is downloaded or deleted.

**Install state left behind**

```
worldbox_Data\StreamingAssets\mods\
  NeoModLoader.AutoUpdate_memload.dll    26,112 bytes   (game-shipped)
  NeoModLoader.dll                    22,753,792 bytes   1.2.1.1
  NeoModLoader.pdb                       223,952 bytes
NML\commit  ->  f6017bdcb6a3cfd4855d634e41b274f013463092
```

The 0-byte staged files in `%TEMP%\NeoModLoader_1-2-1-1.dll` and `.pdb` were removed
so a later launch cannot repeat the broken replace.

**Note for the user.** The loader that was installed before this session was
22,417,408 bytes — a build newer than the public `1.2.0.1` release and newer than
upstream `master` at the time. It was deleted by the failed auto-update and could
not be recovered, so the install now carries the official `1.2.1.1` release instead.
Copies of both public releases are preserved at
`<repo-root>\_tools\nml-restore\`.
