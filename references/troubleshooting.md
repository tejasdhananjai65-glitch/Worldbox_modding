# Troubleshooting WorldBox Mods

Diagnosis order, from the community docs and confirmed against real `Player.log` traces:

1. Did NeoModLoader see, compile and load the mod?
2. What exact error or warning signature appears?
3. Which subsystem should I look at next?

**Search for your own log marker first.** That single search separates "my mod never ran"
from "my feature ran and then failed". Then take the highest-severity signature and fix
that — do not change unrelated code because a scary-looking line is nearby.

---

## 1. Log locations

| File | Location | What |
|---|---|---|
| `Player.log` | `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\` | the current run |
| `Player-prev.log` | same folder | the previous run — the one that crashed (the game overwrites `Player.log` on the next start) |
| `logs\error_*.log` | same folder, `logs\` subfolder | one file per error the game caught |
| `mods_config\<GUID>.config` | same folder | the player's saved settings for your mod |
| `NML\mod_compile_records.json` | `worldbox_Data\StreamingAssets\mods\NML\` | NML's compile cache |
| `NML\CompiledMods\<uid>.dll` | same folder | the compiled output |

---

## 2. Symptom → cause → fix

### The mod does not appear at all

| Cause | Evidence | Fix |
|---|---|---|
| `mod.json` missing or not at the mod root | `[NML]: No mod.json file for folder ...\Mods\<name> in Mods` | put `mod.json` directly inside the mod folder |
| The folder is nested one level too deep | same line | the mod folder must sit **directly** inside `Mods\` |
| The game is not in experimental mode | the mod list is empty and no `Compile Mod` line appears | enable experimental mode in the game's settings; the game resets it after some updates |
| The mod is disabled | `StreamingAssets\mods\NML\disabled_mods.txt` lists its uid | remove the uid from that file |
| The mod id collides with another | duplicate detection in NML | give the mod a unique `GUID` |

### It compiles but does nothing

| Cause | Evidence | Fix |
|---|---|---|
| NML picked a different entry class | the mod's own log line is absent from `Player.log` | ensure exactly one non-abstract `MonoBehaviour` implements `IMod` |
| `OnModLoad` threw partway | an exception follows the mod's log lines | wrap each registration stage in try/catch (pattern 7 in `patterns.md`) |
| The asset registered but nothing uses it | no error at all | a god power needs a `PowerButton` on a `PowersTab`; a trait needs `unlock(true)` |
| Duplicate registration on reload | two `Compile Mod` runs, assets present twice | guard with `AssetManager.traits.get(id) == null` |

### Names show as raw keys, or `missing text:` in the log

`LocalizedTextManager: missing text: sakuga_title_bedrock_quarry_brawl`

The locale key does not match what the game asks for. Real mod keys missing in this
install come from a mod that registers `sakura_title_*` while the game asks for
`sakuga_title_*`.

| Asset | Correct name key | Correct description key |
|---|---|---|
| Trait | `trait_<id>` | `trait_<id>_info` |
| Trait group | `trait_group_<id>` | — |
| God power | `<id>` | `<id>_description` |
| Status effect | the `locale_id` field | the `locale_description` field |

**There is no `power_` prefix on god powers.** `power_my_power` is wrong; the key is
`my_power`.

Also: asking the game for a key it does not have returns the key as the text *and* logs
one `missing text:` error per key. Register every string before anything renders.

### Compile errors

```text Player.log
[NML]: Code\Main.cs(9,42): error CS1002: ; expected
[NML]: Failed to compile mod HelloBox
```

Read it **right to left**: `; expected` is the problem, `(9,42)` is line 9 char 42,
`Code\Main.cs` is the file. **The useful line is the first one** — "Failed to compile"
is only the summary.

Common codes: `CS0103` name not in scope · `CS0117`/`CS1061` no such member · `CS0246`
type or namespace not found · `CS0111` duplicate member · `CS0161` not all code paths
return a value.

One early syntax failure cascades into many secondary messages. Fix the first error and
re-run.

Do this offline instead of launching the game:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>\scripts\compile-mod.ps1" -ModPath "<mod folder>"
```

### Runtime exceptions

```text Player.log
[NML]: [HelloBox]: HelloBox is alive!
NullReferenceException: Object reference not set to an instance of an object.
  at HelloBox.HelloTraits.Initialize () [0x00021] in HelloTraits.cs:24
  at HelloBox.Main.OnModLoad () [0x0000c] in Main.cs:12
```

`in HelloTraits.cs:24` → **line 24 of your own file**. Read that line.

Stack frames whose path is `/github/workspace/Assets/Scripts/...` are the **game's** code,
not yours — for example `BaseEffect.prepare` / `EffectsLibrary.showSpawnEffect` come from
the game's own spawn-effect pipeline.

### `Failed to construct listener instance`

```text Player.log
[NML]: Failed to construct listener instance of NeoModLoader.General.Event.Listeners.WarStartListener+<>c
```

NML tried to construct an event listener type and construction failed. This is a
**scoped** failure — it does not mean every NML event is broken, and it does not stop
other mods loading.

### Missing icons

| Cause | Fix |
|---|---|
| `path_icon` still has `.png` | drop the extension |
| PNG is not under `GameResources\` at the matching path | the path under `GameResources` must match the lookup path exactly |
| Wrong casing | Unity resource paths are case-sensitive on Linux/macOS builds |
| Sprite is null | probe with `SpriteTextureLoader.getSprite(path) == null` |

### Edits do not take effect

NML caches compiled mods by timestamp in `NML\mod_compile_records.json`.

1. Restart the game (usually enough).
2. If not, delete `NML\CompiledMods\<uid>.dll` and `<uid>.pdb`.
3. If still not, remove the mod's entry from `NML\mod_compile_records.json`.

### EVERY mod fails to compile with `references[185]` — the loader is missing

```text Player.log
[NML]: Error when load default reference ...\StreamingAssets\mods\NeoModLoader.dll:
       Could not find file "..."
004: Compile Mods And Load resources     = 0.0006
System.ArgumentNullException: Value cannot be null.
Parameter name: references[185]
  at Microsoft.CodeAnalysis.Compilation.ValidateReferences[T] ...
  at NeoModLoader.services.ModCompileLoadService.compileMod (...) ModCompileLoadService.cs:170
```

**This is not a problem with your mod.** NML adds its own DLL as a compile reference,
so when `StreamingAssets\mods\NeoModLoader.dll` is gone the reference list contains a
null and Roslyn refuses to compile *anything*. The index in the message (`references[185]`)
is the position of the missing reference.

**Cause: NML's bundled auto-updater destroyed the loader.** Decompiling
`NeoModLoader.AutoUpdate_memload.dll` shows the mechanism:

- `UpdateHelper.BackupFile(path)` reads the file into an **in-memory** dictionary and
  then **deletes** it from disk.
- `UpdateHelper.TryReplaceFile(old, new)` deletes `old` and copies `new` over it.

The backup lives only in the process's memory. If the in-game download fails — the log
shows `Curl error 35: Handshake failed. UnityTls error code: 7` and
`Unable to complete SSL connection` — the loader is lost permanently when the process
exits.

**Fix — install the version the updater wants.** `UpdateHelper.GetDLLVersion` reads
`AssemblyName.GetAssemblyName(path).Version`, so an installed loader that is already at
the latest release makes the updater a no-op:

```powershell
$sa = "C:\Program Files (x86)\Steam\steamapps\common\WorldBox\worldbox_Data\StreamingAssets\mods"
$ver = "1.2.1.1"
$base = "https://github.com/WorldBoxOpenMods/ModLoader/releases/download/$ver"
Invoke-WebRequest "$base/NeoModLoader.dll" -OutFile "$sa\NeoModLoader.dll" -UseBasicParsing -TimeoutSec 600
Invoke-WebRequest "$base/NeoModLoader.pdb" -OutFile "$sa\NeoModLoader.pdb" -UseBasicParsing -TimeoutSec 600
```

Then write that release's commit hash into `NML\commit` (read it from
`https://api.github.com/repos/WorldBoxOpenMods/ModLoader/tags`) and delete any 0-byte
staged files in `%TEMP%\NeoModLoader_*` so a later launch cannot repeat the broken
replace.

**Check it before launching the game:**

```powershell
Test-Path "$sa\NeoModLoader.dll"
```

If that is `False`, no mod will compile — fix it first.

### Compile works offline but the game says `error CS0101` — a definition already exists

```text Player.log
[NML]: Failed to compile mod COM_EXAMPLE_WORLDBOXMODDERTEMPLATE:
  Code\Content.cs(18,25): error CS0101: The namespace 'MyMod' already contains a definition for 'Content'
  Code\Main.cs(10,18): error CS0101: The namespace 'MyMod' already contains a definition for 'Main'
```

**The installed folder contains two copies of the sources.** NML compiles every `.cs`
file found under the mod folder — recursively — so a stale copy alongside the new one
puts two `Main` classes in the same namespace.

Check for a nested copy:

```powershell
Get-ChildItem "C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\<MyMod>" -Recurse -Filter *.cs |
  Select-Object FullName
```

If you see the same file twice, one of them is nested one level deeper.

**Cause:** `Copy-Item -Path $src -Destination $dest -Recurse -Force` copies the
**source folder itself into** the destination when the destination already exists —
it does not replace the destination's contents.

**Fix:** use `scripts/install-mod.ps1`, which mirrors with `robocopy /MIR` and so
replaces the destination exactly. If you copied by hand, delete the installed folder
and copy it again so nothing is left over.

**This only shows up in the game.** The offline compile check runs against your source
folder, not the installed copy, so it will pass while the game fails. Always verify
the installed folder after reinstalling.

### `error CS1661` / `CS1678` — a callback delegate does not match

```text Player.log
[NML]: Failed to compile mod COM_SAIYANBOX_WORLDBOX:
  Code\SaiyanTraits.cs(73,85): error CS1661: Cannot convert lambda expression to type 'WorldAction' because the parameter types do not match the delegate parameter types
  Code\SaiyanTraits.cs(73,46): error CS1678: Parameter 1 is declared as type 'NanoObject' but should be 'BaseSimObject'
  Code\SaiyanTraits.cs(73,77): error CS1678: Parameter 2 is declared as type 'BaseAugmentationAsset' but should be 'WorldTile'
```

The lambda was written with the `WorldActionTrait` parameter shape
(`NanoObject`, `BaseAugmentationAsset`) but assigned to a field typed `WorldAction`
(`BaseSimObject`, `WorldTile`).

`WorldAction` and `WorldActionTrait` are **not** interchangeable:

| Delegate | Signature |
|---|---|
| `WorldAction` | `bool (BaseSimObject pTarget, WorldTile pTile)` |
| `WorldActionTrait` | `bool (NanoObject pTarget, BaseAugmentationAsset pTrait)` |

**Fix** — change the parameter types to match the field:

```csharp
blood.action_birth = (BaseSimObject pTarget, WorldTile pTile) => { ... };
```

**Which field to use:**

- `action_birth`, `action_growth`, `action_death`, `action_special_effect` → `WorldAction`
- `action_on_augmentation_add`, `action_on_augmentation_remove`,
  `action_on_augmentation_load`, `action_on_object_remove` → `WorldActionTrait`

If the callback needs to know **which trait fired**, it must use a `WorldActionTrait`
field — only those receive the `BaseAugmentationAsset`.

### `error CS1615` — `out` on a parameter that is not an out parameter

```text Player.log
  Code\SaiyanSpecies.cs(37,54): error CS1615: Argument 1 may not be passed with the 'out' keyword
```

`AssetLibrary<T>` has two `clone` overloads and the call matched the wrong one:

```csharp
AssetLibrary`1.clone(String pNew, String pFrom)   // by value, by value
AssetLibrary`1.clone(T& pNew [out], T pFrom)       // out, object
```

`clone(out saiyan, "human")` binds to the **string** overload, whose first parameter is
a by-value `string` — so `out` is rejected.

**Fix**, pick the overload that matches your intent:

```csharp
// by id: copies "human" into a new asset, sets id = SpeciesId,
// ADDS it to the library, and RETURNS it
ActorAsset saiyan = AssetManager.actor_library.clone(SpeciesId, "human");

// by object: reflection deep copy, does NOT add to the library
ActorAsset template = AssetManager.actor_library.get("human");
AssetManager.actor_library.clone(out ActorAsset saiyan, template);
AssetManager.actor_library.add(saiyan);   // add it yourself
```

### `error CS1061` — `'KingdomAsset' does not contain a definition for 'color'`

```text Player.log
  Code\SaiyanSpecies.cs(140,35): error CS1061: 'KingdomAsset' does not contain a definition for 'color' and no accessible extension method 'color' accepting a first argument of type 'KingdomAsset' could be found
```

`KingdomAsset` has **no** `color`, `culture_asset_id`, `language_asset_id`, `banner_id`,
`name_locale` or `traits` field. What it actually has:

| You probably want | Real field |
|---|---|
| `kingdom.color` | `default_kingdom_color` (a `ColorAsset`) |
| | `default_civ_color_index` (an `int` index) |
| | `color_building` (a `Color`) |
| `kingdom.culture_asset_id` | *not on the asset* — culture lives on the runtime `KingdomData.id_culture` / `Kingdom.culture` |
| `kingdom.language_asset_id` | *not on the asset* — see `KingdomData.id_language` / `Kingdom.language` |

**Fix** for the common "make my kingdom the same colour as the humans" case:

```csharp
saiyanKingdom.default_kingdom_color = humanKingdom.default_kingdom_color;
```

Colours themselves come from `AssetManager.color_style_library` and
`AssetManager.kingdom_colors_library`.

### The game updated and the mod stopped working
| Signature | Cause | Fix |
|---|---|---|
| `MissingMethodException` / `TypeLoadException` | the game's API moved | re-run `setup-toolchain.ps1`, re-run the compile check, fix what broke |
| `HarmonyException` / `AmbiguousMatchException` | patch target missing or has overloads | re-check the target method name; disambiguate with an explicit `Type[]` |
| Everything broke at once | the publicized assembly moved | re-run `setup-toolchain.ps1` — it reads the live install, so this never drifts |

### Log noise you should NOT chase

`Curl error …`, `UnityTls error …`, `Fallback handler could not load library …` and
`Missing translation for …` coexist with working mods. Do not promote a scary-looking
line into a root cause just because it sits near your test. Ask instead: did the mod
continue compiling and loading after this line? Is there a later exception tied to my
code? Does the same line appear in a known-good run?

### The `Compile Mod` line is red

```text Player.log
<color=red>005: Compile Mod Godzilla                = 2.2847</color>
<color=yellow>006: Compile Mod PowerBox                = 0.9840</color>
```

**Red does not mean broken.** NML colours those lines by elapsed time. A red line only
means that mod took longer to compile than the others (Godzilla takes 2.28 s here).

### Custom unit renders headless (missing head sprite)

| Cause | Evidence | Fix |
|---|---|---|
| `has_advanced_textures = false` but head was separated into `heads/head_0.png` | Decapitated body walking around the map; headless model | For mob/boss units with `has_advanced_textures = false`, WorldBox's sprite engine renders only base `walk_0..3` frames and does not attach separate head sprites. Bake the complete unified character (head, face, body, limbs) directly into `walk_0..3.png` |

### Custom actor shows pink texture or fails to load sprite

| Cause | Evidence | Fix |
|---|---|---|
| Textures registered post-startup were not relinked | Pink square texture or invisible unit on map | In WorldBox 0.51.x, adding an `ActorAsset` post-startup requires calling relink methods: `AssetManager.actor_library.loadAutoTextures(AssetManager.actor_library.list);`, `AssetManager.actor_library.loadShadows();`, and `AssetManager.actor_library.linkAssets();` |

### Unit cannot be clicked or inspected (Unit Window does not open)

| Cause | Evidence | Fix |
|---|---|---|
| `inspect_stats` missing or unit scale/bounds offset from tile origin | Clicking on unit does nothing; cannot inspect HP, name, traits | Set `actor.inspect_stats = true` and `actor.can_edit_traits = true`. For large or custom-scaled units whose sprites extend above the tile origin, patch `ActionLibrary.getActorNearPos`, `getActorFromTile`, and `inspectUnit` to check multiple vertical sample points (feet `u.Pos`, torso `u.BodyCenter()`, head `u.Pos + Vector2.up * (u.Size * 1.8f)`) and invoke `ActionLibrary.openUnitWindow(target)` |

### Visual effects (VFX) render behind map or lack additive glow

| Cause | Evidence | Fix |
|---|---|---|
| Particle sprites placed on `Default` sorting layer or using opaque shaders | Beams and energy bursts appear behind ground tiles or render with dark black halos | Set `spriteRenderer.sortingLayerID` to WorldBox native layers: `SortingLayer.NameToID("EffectsTop")` for surface blasts, `"Objects"` for unit hits, or `"EffectsBack"` for ground scorched earth. Use `Shader.Find("Legacy Shaders/Particles/Additive")` for incandescent energy glows and `Shader.Find("GUI/Text Shader")` for impact silhouette flashes |

### Wielded weapons or beams point backwards / swing from the blade tip

| Cause | Evidence | Fix |
|---|---|---|
| Weapon sprite inverted or pivot set to tip instead of hilt | Sword is held by the blade tip, swings upside down, or points 180° in reverse | Orient the sprite so pommel and grip are at the bottom (low Y) and the blade points upward (+Y). Set the rotation pivot at the grip handle (e.g. `Vector2(0.5f, 0.18f)`). In rotation math, rotate by `(AimAngle - 90f) * Mathf.Deg2Rad` so the upward-resting sprite points accurately along the aim angle |

### Docile or sleeping AI never detects nearby units or viewers

| Cause | Evidence | Fix |
|---|---|---|
| `if (u.Sleeping) return;` placed before environmental scanning logic | Units like SCP-096 in docile weeping state never notice viewers or wake up unless hit with damage | Place sensory awareness, line-of-sight raycasting (`HasObstacleBetween`), and field-of-view dot-product checks (`Vector2.Dot(faceDir, toTarget.normalized) > 0.15f`) *before* the `if (u.Sleeping)` early-return in the update loop |

### Standalone compiler fails with CS0012 (ValueType in netstandard)

```text
error CS0012: The type 'ValueType' is defined in an assembly that is not referenced. You must add a reference to assembly 'netstandard, Version=2.1.0.0...'
```

When writing offline diagnostic scripts or running `csc.exe` outside NML's automated runner, Unity's assemblies require the .NET Standard 2.1 facade. Add `-r:"<WorldBox>\worldbox_Data\Managed\netstandard.dll"` to the compiler arguments.

---

## 3. Healthy log shape

```text Player.log
005: Compile Mod MyMod                = 0,2130
006: Load Resources From Mod MyMod    = 0,0012
[NML]: [MyMod]: MyMod loading
[NML]: [MyMod]: MyMod ready
008: Init Mod MyMod                   = 0,0014
```

Three markers to look for: `Compile Mod`, the mod's own log lines, `Init Mod`.

---

## 4. A real bug this reference catches

`StreamingAssets\mods\ElementalPowersMod\Powers\CustomPowers.cs` (a locally authored
mod) registers three god powers like this:

```csharp
power.id = "celestial_strike";
power.name = "celestial_strike";
...
NeoModLoader.General.LM.AddToCurrentLocale("power_celestial_strike", "Celestial Strike");
NeoModLoader.General.LM.AddToCurrentLocale("power_celestial_strike_info", "Calls down divine strikes...");
```

**The `power_` prefix is wrong.** `power.name` *is* the locale key the game looks up, and
the game's own powers use `<id>` and `<id>_description` — `earthquake` /
`earthquake_description`, `volcano` / `volcano_description`, `blessing` /
`blessing_description`. The game therefore asks for `celestial_strike` and
`celestial_strike_description`, finds neither, and renders the raw key.

The fix is to drop the prefix and use the `_description` suffix:

```csharp
NeoModLoader.General.LM.AddToCurrentLocale("celestial_strike", "Celestial Strike");
NeoModLoader.General.LM.AddToCurrentLocale("celestial_strike_description", "Calls down divine strikes...");
```

Note that the *trait* keys in the same mod (`trait_<id>` / `trait_<id>_info`) are
already correct — the god power and trait families use different conventions, which is
exactly why it is worth having both tables side by side.

---

## 5. Quick triage checklist

1. `mod.json` at the mod root? → `Mods\<folder>\mod.json`
2. Is there a `Compile Mod <name>` line? If no → the folder was skipped or the game is
   not in experimental mode.
3. Is there a `Compile Failed` line? → read the **first** `error CSxxxx` line.
4. Is the mod's own log line present? If no → wrong entry class, or `OnModLoad` threw
   before the log call.
5. Is there an exception right after it? → read the frame that points at *your* file.
6. Are raw keys showing in the UI? → the locale key does not match the game's convention
   (§2 table).
7. `missing text:` lines in the log? → the exact key the game wants is in that line.
