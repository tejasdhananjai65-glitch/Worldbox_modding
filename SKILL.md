---
name: worldbox-modder
description: |
  Author, compile-check, install and debug WorldBox (God Simulator) mods built on the
  NeoModLoader (NML) C# modding API. Use this when the user asks to "make a WorldBox
  mod", "add a trait / god power / race / effect / building to WorldBox", "why isn't my
  WorldBox mod loading", "WorldBox modding", "NML mod", or wants to extend an existing
  mod inside the WorldBox Mods folder. Also use when a WorldBox mod fails to compile,
  loads but does nothing, shows raw keys instead of names, has missing icons, or has
  missing translations. Do NOT use for general C# questions unrelated to a WorldBox
  mod, or for mods of other Unity games.
---

# WorldBox Modder

NeoModLoader (NML) is the maintained loader for WorldBox. It compiles a mod's C# source
**at game startup** with an embedded Roslyn 4.9.2 and loads the result. Mod authors ship
source, not DLLs.

Everything below is verified against a live install (WorldBox 0.51.2, NML 1.2.0.1,
Unity 2022.3.60f1). The full API surface lives in `references/`.

## Inputs to collect

- **What the mod should do** — one trait, one god power, one race, one effect, a UI tab,
  a gameplay tweak. If the user says "make me a mod" without specifics, agree **one
  concrete mechanic** before writing code. Undefined scope is the main source of broken
  mods.
- **The mod id** — becomes `GUID` in `mod.json`. It must be unique in the install and
  must never change after release: NML keys the compiled DLL, the saved mod config, and
  dependency symbols off it. Changing it orphans the player's settings.
- **Whether to install and launch** — installing writes into the game folder, launching
  opens a window. Confirm before doing either.

## Procedure

### 1. Locate the install and read the loader's state

The game lives at `C:\Program Files (x86)\Steam\steamapps\common\WorldBox`.
Read `worldbox_Data\StreamingAssets\mods\NML\commit` for the exact NML revision in use —
**read it, do not assume it.** The API in `references/` was verified against
`02266fe8` (1.2.0.1) and re-verified against `f6017bdc` (1.2.1.1); both agree on every
point documented here. If the commit differs from both, re-verify before trusting
anything that was not measured against the live assembly.

**Check the loader is present before you launch the game:**

```powershell
Test-Path "C:\Program Files (x86)\Steam\steamapps\common\WorldBox\worldbox_Data\StreamingAssets\mods\NeoModLoader.dll"
```

If that is `False`, **every** mod silently fails to compile — NML adds its own DLL as a
compile reference, so a missing loader makes Roslyn reject the whole reference list.
`references/troubleshooting.md` has the cause and the one-command fix. Do not launch the
game until this passes.

### 2. Scaffold the mod

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>/scripts/new-mod.ps1" `
  -ModId "com.example.giantpower" -Namespace GiantPower -Author "<user>"
```

This copies `templates/minimal-mod`, rewrites `mod.json` and renames the placeholder
namespace, trait, power and effect ids so the new mod cannot collide with the template.

The resulting folder:

```
<ModId>/
├── mod.json         required - without it NML skips the folder entirely
├── icon.png         optional - mod list icon, path comes from "iconPath"
├── Code/            all .cs sources
├── Locales/         en.json etc - auto-loaded only if the class implements ILocalizable
└── GameResources/   PNGs patched into the game's Resources tree
```

### 3. Write the entry class as `BasicMod<T>`

It supplies `LogInfo`/`LogWarning`/`LogError`, persisted config, `Locales\` auto-loading
and a prefab library. Override `OnModLoad()`:

```csharp
using NeoModLoader.api;

namespace GiantPower
{
    public class Main : BasicMod<Main>
    {
        protected override void OnModLoad()
        {
            LogInfo("GiantPower loading");
            Content.Init();
            LogInfo("GiantPower ready");
        }
    }
}
```

**Trap:** NML finds the entry class by scanning for the first non-abstract
`MonoBehaviour` that implements `IMod`. The `"main"` key in `mod.json` is **not read** by
NML's native path — it only exists for NCMS compatibility. If the assembly has two such
classes, the wrong one runs.

The full `BasicMod<T>` member list, the `ModDeclare` schema, the `LM` localisation API
and the feature system are in `references/nml-api.md`.

### 4. Register content, then unlock it

Order matters: create the asset, add it to its library, then unlock.

```csharp
ActorTrait trait = new ActorTrait();
trait.id = "giant_trait";
trait.group_id = "giant_group";
trait.path_icon = "ui/icons/iconGiant";
trait.type = TraitType.Positive;

AssetManager.traits.add(trait);   // allocates base_stats if still null

trait.base_stats["scale"] = 0.1f;              // visual size (normal = 0.1)
trait.base_stats["multiplier_speed"] = 0.5f;   // x1.5 movement speed

trait.unlock(true);
```

**Stats are deltas, and `multiplier_*` are percentages.** A trait's `base_stats` are
*added* to the species base, and `multiplier_*` values are applied as percentages of the
current value:

- `base_stats["health"] = 500f` → **+500** health, not "health becomes 500".
- `base_stats["multiplier_speed"] = 0.5f` → **×1.5** speed, not "+0.5 speed".
- `base_stats["multiplier_health"] = 0.5f` → **+50%** max health.

**`scale` is the visual size; `size` is the combat hitbox.** `scale` drives the sprite
transform (normal reference value `0.1`); `size` drives attack reach. A unit that
"looks the same but hits from further away" has `size` set and `scale` not.

Vanilla body traits are the reference values to copy — `giant` is `scale +0.05`,
`multiplier_health +0.5`, `multiplier_speed −0.25`; `fast` is `multiplier_speed +0.3`;
`fat` is `scale +0.02`.

There are exactly **67** valid stat ids. Using any other logs
`no asset with id: …` in `Player.log`. The full list, and the `scale` / `multiplier_*`
rules in detail, are in `references/game-api.md` §3.

Libraries: `AssetManager.traits`, `AssetManager.trait_groups`, `AssetManager.powers`,
`AssetManager.status`, `AssetManager.actor_library`, `AssetManager.buildings`,
`AssetManager.power_tab_library`, `AssetManager.kingdoms`, `AssetManager.items`.

There is **no** `actor_assets`, `powers_tab` or `races` field — those names do not
exist in this build and the code will not compile against them. A "race" is an
`ActorAsset` + `Subspecies` + `KingdomAsset`, not a separate asset type.

Full field lists, required initialisation and gotchas per subsystem:
`references/game-api.md`. Idiomatic recipes: `references/patterns.md`.

### 5. Give every new asset a localised name

The game builds lookup keys itself, so they must match exactly:

| Asset | Name key | Description key |
|---|---|---|
| Trait | `trait_<id>` | `trait_<id>_info` |
| Trait group | `trait_group_<id>` | — (none) |
| God power | `<id>` | `<id>_description` |
| Status effect | the `locale_id` **field** you set | the `locale_description` **field** you set |
| World law | `<law_id>_title` | `<law_id>_description` |

From code:

```csharp
NeoModLoader.General.LM.AddToCurrentLocale("trait_giant_trait", "Giant");
NeoModLoader.General.LM.AddToCurrentLocale("trait_giant_trait_info", "A very large unit.");
NeoModLoader.General.LM.AddToCurrentLocale("giant_power", "Grow Giants");
NeoModLoader.General.LM.AddToCurrentLocale("giant_power_description", "Makes units on the tile giant.");
```

**There is no `power_` prefix on god powers.** Registering `power_my_power` leaves the
title showing as a raw key.

For a multi-language release, ship `Locales\<lang>.json` instead — a flat
`{"key":"value"}` map, filename = language id. `BasicMod<T>` implements `ILocalizable`,
so NML loads it before `OnModLoad` with no code from you.

### 6. Make a god power visible

A registered `GodPower` is invisible on its own — it needs a `PowerButton` on a
`PowersTab`. The tab needs the game UI, which does not exist during `OnModLoad`, so
create it from `Update()` once the UI is ready:

```csharp
private bool _tabCreated;

private void Update()
{
    if (_tabCreated) return;
    if (!global::Config.game_loaded) return;
    if (MapBox.instance == null) return;

    _tabCreated = true;
    Content.CreatePowerTab();
}
```

```csharp
Sprite icon = SpriteTextureLoader.getSprite("ui/icons/iconGiant");
PowersTab tab = TabManager.CreateTab("giant_tab", "giant_tab", "giant_tab_description", icon);
tab.SetLayout(new System.Collections.Generic.List<string> { "giant_group" });
tab.AddPowerButton("giant_group", PowerButtonCreator.CreateGodPowerButton("giant_power", icon));
tab.UpdateLayout();
```

### 7. Compile-check before touching the game

This is the fast feedback loop — about two seconds, no game launch:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>/scripts/compile-mod.ps1" -ModPath "<path-to-mod-folder>"
```

Exit code `0` = clean, `1` = compile errors (each printed as `file(line,col): error CSxxxx`),
`2` = toolchain or install not found. The reference set this uses is identical to NML's
(all 187 assemblies), so a clean check means the game will accept the code too.

Fix every error before proceeding. Never install a mod that fails the check.

### 8. Install and verify

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>/scripts/install-mod.ps1" -ModPath "<path-to-mod-folder>"
```

Launch WorldBox and read
`%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`. Confirm three things:

1. a `Compile Mod <uid>` line with no `Compile Failed` note,
2. the mod's own log line (e.g. `MyMod ready`),
3. no exception stack trace immediately after it.

Symptom → cause → fix table: `references/troubleshooting.md`.

## Output contract

- A mod folder with `mod.json` plus `Code\*.cs`, optionally `Locales\`, `GameResources\`,
  `icon.png`.
- A clean `compile-mod.ps1` run (exit code 0), reported to the user.
- When installed and launched: the exact `Player.log` lines proving load, quoted.
- Anything that could not be verified stated plainly, not implied.
- Where each API fact came from: `references/sources.md`.

## Failure handling

- **Compile error** — read the reported file and line, fix, re-run. Do not install a mod
  that fails the check.
- **Mod does not appear in game** — confirm `mod.json` exists at the mod root and the
  folder sits directly inside `Mods\`. NML logs "No mod.json file for folder" and skips
  the folder silently otherwise.
- **Mod appears but does nothing** — check `Player.log` for the mod's own log line. If it
  is absent, NML picked a different entry class. If it is present, the failure is inside
  your code.
- **Raw keys instead of names** — the locale key does not match the game's convention.
  See the table in step 5.
- **Blank icon** — `path_icon` must be the resource path *without* the file extension and
  the PNG must live under `GameResources\` at the matching path. See
  `references/sprites-and-resources.md`.
- **Edits do not take effect** — NML caches compiled mods by timestamp. Restart the game,
  or delete `NML\CompiledMods\<uid>.dll` and `<uid>.pdb`.
- **Compile works but the game fails** — the game assemblies changed since the toolchain
  was restored. Re-run `setup-toolchain.ps1`, re-check, then compare against
  `references/troubleshooting.md`.

## Windows (win32) platform notes

- Run every script through `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>`.
  This machine's default execution policy blocks unsigned `.ps1` files, so a bare
  `.\script.ps1` fails with "running scripts is disabled on this system".
- `compile-mod.ps1` auto-detects the WorldBox install across the three standard Steam
  locations. It reads the live `Assembly-CSharp-Publicized.dll` from the install, so the
  reference set can never drift from the running game build.
- The first compile-check needs `setup-toolchain.ps1` once, to fetch the Roslyn 4.9.2
  net472 compiler (the same version NML embeds). It requires internet access.
- The skill is Windows-only in practice: path handling and the `Mods\` convention assume
  a Windows Steam install.

## Examples

Input: "Make a WorldBox mod that adds a god power turning villagers into giants."
Output: a mod folder with `mod.json` (`GUID` = `com.<user>.giantpower`), `Code\Main.cs`
deriving from `BasicMod<Main>`, a `GodPower` whose `click_action` calls
`actor.addTrait("giant_trait")` on units on the clicked tile, a matching trait
registered via `AssetManager.traits.add(...)` then `trait.unlock(true)`, localisation for
both using `trait_<id>` / `trait_<id>_info` and `<id>` / `<id>_description`, a power tab
created from `Update()` once the UI is ready, a clean `compile-mod.ps1` run, and — if the
user approves installing — the mod copied into `Mods\` and the confirming `Player.log`
lines quoted back.

Input: "My WorldBox mod doesn't show up."
Output: check `mod.json` at the mod root, confirm the folder sits directly inside `Mods\`,
search `Player.log` for "No mod.json file for folder" and for the `Compile Mod <uid>`
line, then confirm the mod's own log line appears with no exception after it.
