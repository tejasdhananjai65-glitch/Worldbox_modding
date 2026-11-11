# Baseline: WorldBox "Giant Villagers" god-power mod

Task: *add a god power which turns villagers into giants; it should give the units on the
clicked tile a new trait that makes them huge and fast.*

Constraints honoured:

* WorldBox was **inspected read-only** at `C:\Program Files (x86)\Steam\steamapps\common\WorldBox`.
* Nothing was installed into the game's `Mods\` folder and **the game was never launched**.
* Everything I created lives under `<repo-root>\eval-baseline\`.
* **No skill file was loaded or read** (per the instruction for this baseline). Everything
  below comes from my own inspection of the game install plus my own tooling.

---

## 1. The steps I actually took

### 1.1 Orientation: what is actually in the install

```
C:\Program Files (x86)\Steam\steamapps\common\WorldBox\
  worldbox.exe
  worldbox_Data\
    Managed\                  <- Unity runtime + Assembly-CSharp.dll (the real game assembly)
    resources.assets          <- 116 MB of sprites/audio/assets
    StreamingAssets\mods\
      NeoModLoader.dll         <- NML (22.7 MB) - the modding API
      NML\
        Assembly-CSharp-Publicized.dll   <- de-obfuscated + publicized game assembly
        Assemblies\            <- Mono.Cecil.dll, Microsoft.CodeAnalysis.CSharp.dll, 0Harmony.dll ...
        CompiledMods\
      ElementalPowersMod\      <- a working example NML mod (source only)
      test_asset_load\
  Mods\                       <- workshop mods: AGRICHE_GODZILLA, _VILTRUM_EMPIRE,
                                 AVOIDINGBOREDOM...ULTRA_TRAIT_PACK, SCPBOX_MOD,
                                 RAYTRACERX_SHINOBIBOX, com_example_worldboxmoddertemplate, ...
```

Key realisation: **NML ships a de-obfuscated, publicized copy of the game assembly**
(`Assembly-CSharp-Publicized.dll`). That is the API I am allowed to code against, and it is
the single most valuable file in the install. Reading it statically is what replaced guesswork.

### 1.2 Tooling I built (all under `eval-baseline\tools\`)

Mono.Cecil is already on disk (`NML\Assemblies\Mono.Cecil.dll`), so I wrote five small
PowerShell tools that load an assembly and print what I need:

| Tool | Purpose |
| --- | --- |
| `dump-types.ps1` | Public surface of every type matching a pattern (fields, properties, methods). |
| `list-types.ps1` | Every type name in an assembly, optionally regex-filtered. |
| `dump-il.ps1` | **IL of individual method bodies** - the decisive tool. |
| `dump-strings.ps1` | Every `ldstr` literal with the method that uses it - used to find valid stat ids and icon paths. |
| `find-refs.ps1` | Call sites of a method, field references, and delegate invocation sites. |
| `compile-check.ps1` | Offline compile check (section 4). |

Output of the API dumps is kept in `eval-baseline\api\` so the analysis is reproducible.

### 1.3 Working out the API, one question at a time

**(a) How does a mod register a god power and make it visible?**
`GodPower` (from the publicized assembly) has `id`, `name`, `rank`, `path_icon`,
`click_action`, `click_power_action`, `type`, `force_brush`, ... and `AssetManager.powers`
is a `PowerLibrary`. But a `GodPower` alone is invisible: `PowerButton::init` is what calls
`GodPower::addPower(power, button)`, and the base game builds its buttons from scene
prefabs. So a mod must create a button itself.
NML provides exactly that:
`NeoModLoader.General.PowerButtonCreator.CreateGodPowerButton(id, sprite, parent = null,
pos = default)` and `NeoModLoader.General.UI.Tab.TabManager.CreateTab(name, titleKey, descKey,
icon, optionDescKey = "hotkey_tip_tab_other")`. `PowersTab.SetLayout/AddPowerButton/
UpdateLayout` are **C# extension methods** (verified: they carry
`System.Runtime.CompilerServices.ExtensionAttribute`), so `tab.SetLayout(...)` compiles with
`using NeoModLoader.General.UI.Tab;`.

**(b) What is the click-action delegate signature?**
IL of the delegate types:
```
PowerActionWithID : System.MulticastDelegate
    METHOD System.Boolean Invoke(WorldTile pTile, System.String pPowerID)
PowerAction : System.MulticastDelegate
    METHOD System.Boolean Invoke(WorldTile pTile, GodPower pPower)
```
So `power.click_action` is `bool (WorldTile, string)`.

**(c) When is `click_action` actually invoked?**
`find-refs.ps1 -InvokeType PowerActionWithID` gave exactly one game-side call site:
`MapBox::loopWithBrush`. Tracing it:
`PowerLibrary::loopWithBrush(WorldTile, GodPower)` reads
`ldfld PowerActionWithID GodPower::click_action` and `ldfld System.String Asset::id`, then calls
`MapBox::loopWithBrush(centerTile, brush, pPower.click_action, pPower.id)`, which invokes the
delegate once **per tile of the active brush**. Confirmed the hook is right.

**(d) "the units on the clicked tile" - the brush problem.**
`MapBox::loopWithBrush` expands the *player's current brush*, not just the clicked tile, and
`Config::.cctor` shows `Config::_current_brush = "circ_5"` - an 11x11 circle by default. So
without intervention the power would hit a huge area. `GodPower.force_brush` overrides it
(`PowerLibrary::loopWithBrush`: `if (!IsNullOrEmpty(pPower.force_brush)) brush = pPower.force_brush;`).
`BrushLibrary::init` creates brushes `circ_0`, `circ_1` ... `circ_70`, `sqr_0`, ... and the
`circ_0` / `sqr_0` assets get their `BrushData.pos` from a generate-action that sets
`pos = new BrushPixelData[]{ new BrushPixelData(0,0,0) }` - exactly one tile at offset
(0,0). So `power.force_brush = "circ_0"` gives precisely "the clicked tile".

**(e) How do I get the units on a tile?**
`WorldTile` has `_units` (a `List<Actor>`), `doUnits(Action<Actor>)`,
`doUnits(Func<Actor,bool>)`, `countUnits()`, `hasUnits()`. I used `pTile.doUnits(actor => ...)`.

**(f) How does a trait get onto an actor?**
`Actor.addTrait(string pTraitID, bool pRemoveOpposites)` and
`Actor.addTrait(ActorTrait pTrait, bool pRemoveOpposites)` - **both take two arguments**.
IL of `Actor::addTrait(ActorTrait, bool)`: it looks the trait up in `AssetManager.traits`,
adds it to `Actor::traits`, and calls `BaseSimObject::setStatsDirty()`.
*(Note: the in-install reference mod `com_example_worldboxmoddertemplate` calls
`actor.addTrait(TraitId)` with a single argument, and so does
`StreamingAssets\mods\ElementalPowersMod`. That does not match the publicized assembly and
would not compile. I used the two-argument form.)*

**(g) How does a trait actually make a unit "huge"?**
This was the hardest part and needed IL, not guessing.
* `Actor::updateStats` merges each trait's stats:
  `ldfld BaseStats BaseUnlockableAsset::base_stats` -> `BaseStats::mergeStats(trait.base_stats, 1f)`.
  So the stat goes in **`trait.base_stats`** (not `base_stats_meta`).
* `BaseStats::mergeStats` is **additive**: `this[id] = this[id] + source.value * multiplier`.
* `BaseStats::set` does `AssetManager.base_stats_library.get(pID)` and then dereferences it
  -> **an unknown stat id throws a NullReferenceException**. Only ids that exist in the
  base stat library may be used.
* `BaseStatsLibrary::init` defines the stat `scale`:
  `id = "scale"`, `show_as_percents = true`, `tooltip_multiply_for_visual_number = 1000`,
  `translation_key = "size"`. The `ActorAsset` base template `$basic_unit$` sets
  `base_stats["scale"] = 0.1`, i.e. **0.1 == 100% of normal size**.
* The base game's own genes confirm the additive semantics:
  `GeneLibrary::addBonusStats` -> gene `scale_plus` has `base_stats["scale"] = 0.03`
  (a +3% size gene) and `scale_minus` = `-0.01`.
* `Actor::updateStats` ends with `this.target_scale = this.stats["scale"]`, and
  `Actor::updateChangeScale(float)` (called from `Actor::updateParallelChecks`) lerps
  `actor_scale` towards `target_scale` at `0.2 * elapsed` per frame.
  `Actor::setActorScale(float)` sets `actor_scale` and `current_scale`.
  => adding a trait that raises `scale` makes the unit visibly grow.
* Conclusion for my numbers: a trait bonus of **+0.2** on top of the base **0.1** gives
  `0.3` = **300% of normal size** (3x a villager).

**(h) How does a trait make a unit "fast"?**
`BaseStatsLibrary::init` defines `speed` as an absolute stat (`normalize = true`,
`normalize_min = 1`) and a separate `multiplier_speed`. The base game's own traits use the
multiplier form - e.g. `ActorTraitLibrary::addTraitsBody` sets
`base_stats["multiplier_speed"] = 0.3` / `0.25` / `-0.5`.
`BaseStats::checkMultipliers()` (called at the end of `Actor::updateStats`) applies
`main.value = main.value + main.value * multiplier.value`, i.e. `multiplier_speed = 0.5`
means **+50% speed**. I used the multiplier form so the boost scales with the unit
instead of depending on an absolute base speed I could not pin down.

**(i) Locale keys.**
* Trait: `BaseTrait.getLocaleID()` -> `get_typed_id() + "_" + id`, and
  `ActorTrait.get_typed_id()` returns the literal `"trait"` -> key **`trait_<id>`**.
  Description -> `BaseTrait.getDescriptionID()` -> **`trait_<id>_info`**.
* Group: `BaseCategoryAsset.name` -> key **`trait_group_<id>`**.
* God power: `GodPower.getLocaleID()` -> `name.Underscore()`, i.e. `GodPower.name` *is* the
  locale key; the description key is `<name>_description`.

**(j) Which icon?**
`SpriteTextureLoader.getSprite(path)` is just `Resources.Load(path, typeof(Sprite))`, and
`BaseUnlockableAsset.getSprite()` resolves `path_icon` through exactly that call. The base
game's own "giant" trait uses `path_icon = "ui/Icons/actor_traits/iconGiant"`, so I reuse that
exact string - it is guaranteed to resolve the same way the vanilla trait's icon does.
A binary scan of `resources.assets` confirms the string `iconGiant` is present.

**(k) Is there a name clash?**
The base game **already has a trait with id `giant`** (`ActorTraitLibrary::addTraitsBody`:
`id = "giant"`, `group_id = "physique"`, `path_icon = "ui/Icons/actor_traits/iconGiant"`).
So my trait must not be called `giant` - I used **`giant_villager`**.

**(l) When can the tab be created?**
`TabManager.CreateTab` needs the game UI. The reference pattern (both
`com_example_worldboxmoddertemplate` and `AGRICHE_GODZILLA`) is: create the tab on the first
frame where `Config.game_loaded` is true and `MapBox.instance != null`, from a
`BasicMod<T>.Update()`.

### 1.4 Reference material I read (read-only, in the game install)

* `Mods\com_example_worldboxmoddertemplate\Code\Content.cs` + `Main.cs` + `mod.json` +
  `Locales\en.json` - the closest thing to a canonical NML template on this machine; it
  showed the trait-group -> trait -> god-power -> powers-tab sequence and the `Locales/en.json`
  format. (Its `actor.addTrait(TraitId)` single-argument call does not match the assembly -
  see 1.3(f).)
* `Mods\AGRICHE_GODZILLA\Code\Powers.cs` - `TabManager.CreateTab` + `tab.SetLayout` +
  `PowerButtonCreator.CreateGodPowerButton` usage.
* `Mods\_VILTRUM_EMPIRE\Code\ViltrumTraits.cs` - `AssetManager.traits.add(...)` + the
  `LM.AddToCurrentLocale("trait_<id>", ...)` convention.
* `Mods\AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK\Code\CreatureTraits.cs` -
  `trait.base_stats["health"] = ...` idiom and `pActor.addTrait(trait, false)`.
* `Mods\AGRICHE_GODZILLA\Code\Registry.cs`, `Mods\SCPBOX_MOD\Code\Anomalies.cs`,
  `Mods\RAYTRACERX_SHINOBIBOX\Code\ShinobiActors.cs` - working mods using
  `base_stats["scale"]` with values 0.15-0.48, which corroborates "larger = bigger".
* `StreamingAssets\mods\ElementalPowersMod\*` - an NML example mod (source only).

---

## 2. Final mod folder tree and the full contents of every file

Mod root: `<repo-root>\eval-baseline\GiantVillagers\`

```
GiantVillagers\
    icon.png                                792 bytes  (generated 64x64 PNG)
    mod.json                                304 bytes
    Locales\
        en.json                             361 bytes
    Code\
        GiantVillagersContent.cs           7436 bytes
        Main.cs                             1438 bytes
```

NML compiles `Code\*.cs` at game start, so no DLL is shipped. (The compile-check DLL lives
under `tools\build\`, not in the mod.)

### `GiantVillagers\mod.json`

```json
{
  "name": "GiantVillagers",
  "GUID": "com.eval.giantvillagers",
  "author": "eval-baseline",
  "version": "1.0.0",
  "description": "Adds a god power that turns the units on the clicked tile into huge, fast giants.",
  "iconPath": "icon.png",
  "targetGameBuild": 0,
  "UsePublicizedAssembly": true
}
```

### `GiantVillagers\Locales\en.json`

```json
{
  "trait_group_giants_group": "Giants",
  "trait_giant_villager": "Giant",
  "trait_giant_villager_info": "Huge and fast.",
  "giant_villager_power": "Turn Into Giants",
  "giant_villager_power_description": "Turns every unit on the clicked tile into a huge, fast giant.",
  "giants_tab": "Giants",
  "giants_tab_description": "Powers from GiantVillagers."
}
```

### `GiantVillagers\Code\Main.cs`

```csharp
using NeoModLoader.api;
using UnityEngine;

namespace GiantVillagers
{
    /// <summary>
    /// Entry point. NeoModLoader picks the first non-abstract MonoBehaviour that
    /// implements IMod, so this class must be the only such class in the assembly.
    /// </summary>
    public class Main : BasicMod<Main>
    {
        private bool _tabCreated;

        protected override void OnModLoad()
        {
            LogInfo("GiantVillagers loading");
            GiantVillagersContent.Init();
            LogInfo("GiantVillagers ready");
        }

        /// <summary>
        /// The power tab needs the game UI to exist, and OnModLoad runs before there
        /// is a world at all. Create it on the first frame where the UI is ready.
        /// </summary>
        private void Update()
        {
            if (_tabCreated)
            {
                return;
            }

            if (!global::Config.game_loaded)
            {
                return;
            }

            if (MapBox.instance == null)
            {
                return;
            }

            _tabCreated = true;

            try
            {
                GiantVillagersContent.CreatePowerTab();
                LogInfo("GiantVillagers power tab created");
            }
            catch (System.Exception e)
            {
                LogError("GiantVillagers: failed to create power tab: " + e);
            }
        }
    }
}
```

### `GiantVillagers\Code\GiantVillagersContent.cs`

```csharp
using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using System.Collections.Generic;
using UnityEngine;

namespace GiantVillagers
{
    /// <summary>
    /// Registers everything this mod adds to the game:
    ///   - a trait group ("Giants")
    ///   - a trait that makes a unit huge and fast
    ///   - a god power that hands that trait to every unit on the clicked tile
    ///   - a powers tab so the god power is actually reachable in the UI
    ///
    /// Stat notes (verified against Assembly-CSharp-Publicized.dll):
    ///   - "scale" is the size stat. The base actor template uses 0.1, which is
    ///     100% of normal size (the stat asset shows it as a percentage with a
    ///     x1000 display multiplier). Trait stats are merged additively into the
    ///     actor's stats, so a trait bonus of +0.2 turns a villager into 300%.
    ///   - "multiplier_speed" is a percentage-style multiplier (+0.5 == +50% speed)
    ///     and is what the base game traits use.
    ///   - Actor.addTrait() marks the actor's stats dirty, so Actor.updateStats()
    ///     recomputes target_scale and the actor visibly grows.
    /// </summary>
    public static class GiantVillagersContent
    {
        public const string TraitGroupId = "giants_group";
        public const string TraitId = "giant_villager";
        public const string PowerId = "giant_villager_power";
        public const string TabId = "giants_tab";

        /// <summary>Vanilla icon of the base game "giant" trait - always present.</summary>
        public const string IconPath = "ui/Icons/actor_traits/iconGiant";

        /// <summary>Vanilla tab icon used if <see cref="IconPath"/> cannot be loaded.</summary>
        public const string FallbackIconPath = "ui/Icons/power_tabs/icon_tab_creatures";

        /// <summary>+0.2 on top of the base 0.1 == 300% of normal size.</summary>
        public const float ScaleBonus = 0.2f;

        /// <summary>+50% movement speed.</summary>
        public const float SpeedBonus = 0.5f;

        public static void Init()
        {
            CreateTraitGroup();
            CreateTrait();
            CreatePower();
        }

        // --- trait group ------------------------------------------------------------
        // A trait needs a group; the group shows up as a tab in the trait editor.
        // The locale key for a group is "trait_group_" + group id.
        private static void CreateTraitGroup()
        {
            if (AssetManager.trait_groups.get(TraitGroupId) != null)
            {
                return;
            }

            ActorTraitGroupAsset group = new ActorTraitGroupAsset();
            group.id = TraitGroupId;
            group.name = "trait_group_" + TraitGroupId;
            group.color = "#7fd4ffff";
            AssetManager.trait_groups.add(group);

            LM.AddToCurrentLocale("trait_group_" + TraitGroupId, "Giants");
        }

        // --- trait -----------------------------------------------------------------
        // Locale keys: "trait_" + id and "trait_" + id + "_info".
        private static void CreateTrait()
        {
            if (AssetManager.traits.get(TraitId) != null)
            {
                return;
            }

            ActorTrait trait = new ActorTrait();
            trait.id = TraitId;
            trait.group_id = TraitGroupId;
            trait.path_icon = IconPath;
            trait.type = TraitType.Positive;
            trait.rarity = Rarity.R1_Rare;

            // AssetManager.traits.add() allocates base_stats / base_stats_meta when
            // they are still null, so the stats have to be set after the add() call.
            AssetManager.traits.add(trait);

            trait.base_stats["scale"] = ScaleBonus;
            trait.base_stats["multiplier_speed"] = SpeedBonus;

            trait.unlock(true);

            LM.AddToCurrentLocale("trait_" + TraitId, "Giant");
            LM.AddToCurrentLocale("trait_" + TraitId + "_info", "Huge and fast.");
        }

        // --- god power ---------------------------------------------------------------
        // GodPower.name is the locale key of the title, the description key is
        // <name> + "_description".
        private static void CreatePower()
        {
            if (AssetManager.powers.get(PowerId) != null)
            {
                return;
            }

            GodPower power = new GodPower();
            power.id = PowerId;
            power.name = PowerId;
            power.path_icon = IconPath;
            power.rank = PowerRank.Rank0_free;

            // Config._current_brush defaults to "circ_5" (an 11x11 circle), and the
            // click action is invoked once per tile of the active brush. "circ_0" is
            // the single-tile brush (its BrushData.pos holds exactly one pixel at
            // offset 0,0), so the power only ever touches the tile that was clicked.
            power.force_brush = "circ_0";

            // PowerActionWithID: bool (WorldTile pTile, string pPowerId)
            power.click_action = (WorldTile pTile, string pPowerId) =>
            {
                if (pTile == null)
                {
                    return false;
                }

                bool applied = false;

                pTile.doUnits(actor =>
                {
                    if (actor == null || !actor.isAlive())
                    {
                        return;
                    }

                    if (actor.hasTrait(TraitId))
                    {
                        return;
                    }

                    // false == do not remove opposing traits, just refuse if one is present.
                    if (actor.addTrait(TraitId, false))
                    {
                        applied = true;
                    }
                });

                return applied;
            };

            AssetManager.powers.add(power);

            LM.AddToCurrentLocale(PowerId, "Turn Into Giants");
            LM.AddToCurrentLocale(PowerId + "_description",
                "Turns every unit on the clicked tile into a huge, fast giant.");
        }

        // --- power tab ----------------------------------------------------------------
        // A GodPower on its own is invisible: it needs a PowerButton on a PowersTab.
        // The tab can only be built once the game UI exists - see Main.Update().
        public static void CreatePowerTab()
        {
            Sprite icon = SpriteTextureLoader.getSprite(IconPath);
            if (icon == null)
            {
                // Fall back to a vanilla tab icon so the power stays reachable even
                // if the giant trait icon is ever renamed.
                icon = SpriteTextureLoader.getSprite(FallbackIconPath);
            }

            if (icon == null)
            {
                Main.LogError("GiantVillagers: no usable icon found (" + IconPath + ")");
                return;
            }

            PowersTab tab = TabManager.CreateTab(TabId, TabId, TabId + "_description", icon);
            tab.SetLayout(new List<string> { TraitGroupId });
            tab.AddPowerButton(TraitGroupId, PowerButtonCreator.CreateGodPowerButton(PowerId, icon));
            tab.UpdateLayout();

            LM.AddToCurrentLocale(TabId, "Giants");
            LM.AddToCurrentLocale(TabId + "_description", "Powers from GiantVillagers.");
        }
    }
}
```

### `GiantVillagers\icon.png`

A 64x64 PNG generated with `System.Drawing` at build time (a stylised orange giant head on a
dark background). It is only the mod-list icon (`mod.json` -> `iconPath`); the in-game power
button uses the vanilla `iconGiant` sprite.

### Supporting tooling I created (not part of the mod)

```
eval-baseline\tools\
    dump-types.ps1        type/member surface dumper (Mono.Cecil)
    list-types.ps1        type-name lister
    dump-il.ps1           IL body dumper (-ExactType / -Method / -AllMembers)
    dump-strings.ps1      ldstr literal extractor with owning method
    find-refs.ps1         call sites / field refs / delegate invocation sites
    compile-check.ps1     offline Roslyn compile check
    build\GiantVillagers.check.dll      (compile-check artifact)
    _negctl\GiantVillagersBad\Code\Broken.cs   (negative control, see section 4)
eval-baseline\api\        ~30 dumped API/IL text files used for the analysis above
```

---

## 3. How the mod works (behaviour summary)

1. `Main.OnModLoad` -> `GiantVillagersContent.Init()`.
2. A trait group `giants_group` is registered in `AssetManager.trait_groups`.
3. The trait `giant_villager` is registered in `AssetManager.traits` with
   `base_stats["scale"] = 0.2` and `base_stats["multiplier_speed"] = 0.5`.
4. The god power `giant_villager_power` is registered in `AssetManager.powers` with
   `click_action` that walks `pTile.doUnits(...)` and calls
   `actor.addTrait("giant_villager", false)` on every living unit that does not already
   have it. `force_brush = "circ_0"` pins the effect to the single clicked tile.
5. On the first frame with `Config.game_loaded`, a new powers tab `giants_tab` is created
   and a button for the power is added to it.
6. In game: `Actor.addTrait` marks stats dirty -> `Actor.updateStats` merges the trait's
   `base_stats` additively into `actor.stats`, sets `target_scale = stats["scale"]`
   (0.1 + 0.2 = 0.3 -> 300% size), `checkMultipliers()` applies
   `speed = speed + speed * 0.5` -> +50% speed, and `Actor.updateChangeScale` lerps the
   sprite up to the new scale over a few frames.

---

## 4. How I verified it compiles

**I could verify compilation, but not runtime behaviour** (the game was deliberately not
launched, and I did not install the mod into `Mods\`).

### The tool

`eval-baseline\tools\compile-check.ps1` reproduces what NML does at game start: it invokes
the Roslyn 4.9.2 (net472) `csc.exe` that already ships in the workspace toolchain at
`<repo-root>\toolchain\pkg\compilers\tasks\net472\csc.exe`, referencing the
same assemblies NML hands to Roslyn:

* `worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll` (game API)
* `worldbox_Data\StreamingAssets\mods\NeoModLoader.dll` (NML API)
* `worldbox_Data\StreamingAssets\mods\NML\Assemblies\0Harmony.dll`
* `worldbox_Data\Managed\{mscorlib,System,System.Core,netstandard}.dll`
* `worldbox_Data\Managed\UnityEngine.*.dll` (13 modules) and `Newtonsoft.Json.dll`

21 references total, matching the workspace toolchain's reference set.

### Exact command

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<repo-root>\eval-baseline\tools\compile-check.ps1" -ModPath "<repo-root>\eval-baseline\GiantVillagers"
```

### Real output

```
=== WorldBox mod compile check: GiantVillagers ===
compiler : <repo-root>\toolchain\pkg\compilers\tasks\net472\csc.exe
sources  : 2 file(s) under <repo-root>\eval-baseline\GiantVillagers\Code
refs     : 21

csc exit code: 0
BUILD OK -> <repo-root>\eval-baseline\tools\build\GiantVillagers.check.dll
SCRIPT EXIT CODE: 0
```

**Exit code: 0.** No errors, no warnings. (`Write-Host` writes to the host, so the compiler
produced no diagnostic output at all - which is what a clean build looks like.)

### Independent sanity check on the emitted assembly

I dumped the produced DLL with my own tool to confirm it contains real code and not a stub:

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File "...\tools\list-types.ps1" -Assembly "...\tools\build\GiantVillagers.check.dll"
TOTAL TYPES: 7
<Module>
GiantVillagers.GiantVillagersContent
GiantVillagers.GiantVillagersContent/<>c
GiantVillagers.GiantVillagersContent/<>c__DisplayClass10_0
GiantVillagers.Main
Microsoft.CodeAnalysis.EmbeddedAttribute
System.Runtime.CompilerServices.RefSafetyRulesAttribute
```

```
=== TYPE GiantVillagers.Main : NeoModLoader.api.BasicMod`1<GiantVillagers.Main>
    FIELD System.Boolean _tabCreated
    METHOD System.Void OnModLoad()
    METHOD System.Void Update()

=== TYPE GiantVillagers.GiantVillagersContent/<>c : System.Object
    FIELD PowerActionWithID <>9__10_0 [static]
    METHOD System.Boolean <CreatePower>b__10_0(WorldTile pTile, System.String pPowerId)
```

The `<CreatePower>b__10_0(WorldTile, String)` lambda being stored in a `PowerActionWithID`
field confirms the delegate binds to the exact signature the game invokes.

### Negative control (proves the check is not silently passing)

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File "...\tools\compile-check.ps1" -ModPath "...\tools\_negctl\GiantVillagersBad"
=== WorldBox mod compile check: GiantVillagersBad ===
compiler : <repo-root>\toolchain\pkg\compilers\tasks\net472\csc.exe
sources  : 3 file(s) under <repo-root>\eval-baseline\tools\_negctl\GiantVillagersBad\Code
refs     : 21

worldbox-research\eval-baseline\tools\_negctl\GiantVillagersBad\Code\Broken.cs(9,13): error CS0246: The type or namespace name 'NotARealType' could not be found (are you missing a using directive or an assembly reference?)
csc exit code: 1
BUILD FAILED (1 error(s))
SCRIPT EXIT CODE: 1
```

**Exit code: 1**, with the real `CS0246` error. The tool does compile the code and does report
failures.

### What is NOT verified

* The mod has **never been run inside WorldBox**. Compilation proves the API usage is
  type-correct; it does not prove the numbers look right on screen.
* I did not verify that `AssetManager` libraries are fully initialised at the moment NML
  calls `BasicMod.OnModLoad`. The in-install reference mods use exactly this pattern
  (`com_example_worldboxmoddertemplate`, `AGRICHE_GODZILLA`), so I followed it, but it is an
  assumption, not something I observed.
* The visual result of `scale = 0.1 + 0.2` is derived from static analysis of the assembly
  (template base 0.1, stat asset `translation_key = "size"`, `show_as_percents`, gene
  `scale_plus = 0.03` being a "+3% size" gene). I could not observe a giant on screen.

---

## 5. Hard, ambiguous, or guessed-at parts

1. **The meaning of the `scale` stat was the single biggest unknown.** Nothing in the API
   surface says "0.1 = 100% of normal size". I had to chain four separate pieces of evidence
   (template base value 0.1, the stat asset's `show_as_percents` + `tooltip_multiply_for_visual_number = 1000`
   + `translation_key = "size"`, the `scale_plus`/`scale_minus` genes, and `Actor::create`
   doing `base_stats["scale"] * 0.6f`). The chain is solid but it is inference. If the mod
   turns units into "3x" rather than "giant-ish", the fix is one constant
   (`ScaleBonus` in `GiantVillagersContent.cs`).
2. **Absolute vs. relative speed.** I could not pin down a villager's absolute `speed`
   stat (the base template says 5, the civ genome says 15, and genes/subspecies complicate
   it), so I used `multiplier_speed` (a relative +50%), which is also what the base game's
   own traits do. `base_stats["speed"] = X` would have been additive-absolute and therefore
   size-dependent.
3. **The in-install template mod does not compile as written.**
   `com_example_worldboxmoddertemplate\Code\Content.cs` calls `actor.addTrait(TraitId)`;
   the publicized assembly only has `addTrait(string, bool)` and `addTrait(ActorTrait, bool)`.
   `StreamingAssets\mods\ElementalPowersMod` has the same problem. I did **not** copy that
   line - I used `addTrait(TraitId, false)`. I could not tell whether those mods were ever
   successfully compiled by NML.
4. **Brush semantics.** "The units on the clicked tile" is not what the game does by
   default - the default brush is `circ_5` (11x11). I used `force_brush = "circ_0"`,
   which I verified has exactly one brush pixel. I did not verify in-game that the forced
   brush renders correctly in the UI (some powers show a brush-size selector; `circ_0`
   should show a single tile).
5. **`AssetManager.traits.add()` allocating `base_stats`.** I confirmed from the IL of
   `BaseTraitLibrary<T>.add` that it allocates both `base_stats` and `base_stats_meta` if
   null, so setting `trait.base_stats[...]` after the `add()` call is safe. Setting them
   *before* the `add()` call would have thrown.
6. **Unknown stat ids are fatal.** `BaseStats.set` dereferences the result of
   `base_stats_library.get(pID)` without a null check, so an invalid id throws a
   `NullReferenceException` at runtime. I restricted myself to ids I confirmed exist in
   `BaseStatsLibrary::init` (`scale`, `speed`, `multiplier_speed`).
7. **Icon path.** `ui/Icons/actor_traits/iconGiant` is the exact string the base game uses
   for its own "giant" trait, and it resolves through the identical
   `SpriteTextureLoader.getSprite` -> `Resources.Load` path. A raw string scan of
   `resources.assets` finds `iconGiant` but not the full path (Unity stores sprite resource
   paths in a way my ASCII scan does not surface), so I could not positively prove the
   Resources entry exists. I added a fallback to `ui/Icons/power_tabs/icon_tab_creatures`
   and a null-guard so a missing icon cannot prevent the tab from being created.
8. **Mod folder name.** NML identifies a mod by its folder. I named it `GiantVillagers`
   with `GUID` `com.eval.giantvillagers` and `name` `GiantVillagers`; whether NML requires
   the folder name to match the `name` field exactly was not something I could confirm
   without launching the game. The in-install template has a folder name
   (`com_example_worldboxmoddertemplate`) that differs from its `name`
   (`WorldBoxModderTemplate`), which suggests they need not match.
9. **`trait.unlock(true)`.** Copied from the reference mod. It marks the trait as unlocked
   so it is not hidden behind an achievement. I did not verify whether it needs
   `GameProgressData` to exist at that point in startup.
10. **"Villagers" vs. "all units".** The request says "turns villagers into giants" but
    then specifies "give the units on the clicked tile a new trait". I implemented the
    second (more specific) instruction literally: the trait is applied to *every* living
    unit on the clicked tile. Restricting it to humans would need a check on
    `actor.asset.kingdom_id_civilization` / subspecies, which I did not add.

## 6. Cleanup note

Two scratch artefacts remain on disk and could not be removed (deletion via the shell is
blocked by the local safety policy; I did not attempt to bypass it):
`eval-baseline\api\_icontest.png` (a 64x64 PNG I generated while checking that
`System.Drawing` was available) and `eval-baseline\tools\_negctl\` (the negative-control
sources). Neither is part of the mod.
