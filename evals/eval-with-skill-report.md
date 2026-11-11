# Evaluation: `worldbox-modder` skill — "god power that turns villagers into giants"

**Task:** Build a WorldBox mod adding a god power that gives units on the clicked tile a
new trait making them huge and fast.

**Skill used:** `<skill-dir>\SKILL.md`
**Game install:** `C:\Program Files (x86)\Steam\steamapps\common\WorldBox`
**Deliverable mod:** `<repo-root>\eval-with-skill\com_example_giantpower\`

**Result: BUILD OK, `compile-mod.ps1` exit code 0.** The mod compiles against the live
game assemblies on the first attempt, no compile errors, no warnings.

**Headline assessment:** The skill's *workflow* is solid and its scaffolding,
localisation-key table, tab-creation pattern and compile-check script all worked exactly
as documented. The skill's *game-mechanics knowledge* is where it falls short — it does
not explain how to make a unit "huge" or "fast", and the one stat list it does provide
would have led me to the wrong stat. Everything about stat semantics in section 4.1
below had to be reverse-engineered from the game's own assembly.

---

## 1. Steps I actually took

### 1.1 Skill files read (all of them)

| Path | What I took from it |
|---|---|
| `SKILL.md` | The 8-step Procedure, the output contract, the win32 script-invocation rule, the Examples section (which is literally this prompt) |
| `references/game-api.md` | `AssetManager` library list, `BaseStats` members, stat-id lists, `checkStatName` behaviour, snake_case locale-key rule |
| `references/patterns.md` | Idiom recipes for traits / god powers / powers tabs |
| `references/nml-api.md` | `BasicMod<T>` member list, `ModDeclare` schema, `LM` localisation API, GUID→UID normalisation rule |
| `references/sprites-and-resources.md` | `GameResources\<path>\<name>.png` → resource path `<path>/<name>` (no extension), 64×64 icon guidance, path-casing warning |
| `references/troubleshooting.md` | Symptom→cause→fix table (not needed — the compile passed) |
| `references/sources.md` | Provenance of the API facts |
| `scripts/new-mod.ps1`, `scripts/compile-mod.ps1`, `scripts/setup-toolchain.ps1` | Read before running, so I knew what each one does |
| `templates/minimal-mod/{mod.json, Code/Main.cs, Code/Content.cs, Locales/en.json}` | The scaffold I started from |

### 1.2 Procedure steps 1–7 of `SKILL.md` (step 8 install/launch deliberately skipped, per the task)

**Step 1 — locate the install and read the loader's state.**

```
read  C:\Program Files (x86)\Steam\steamapps\common\WorldBox\worldbox_Data\StreamingAssets\mods\NML\commit
→  f6017bdcb6a3cfd4855d634e41b274f013463092
```

> **This does not match what the skill says.** `SKILL.md` line 41 says "Everything in
> `references/` is verified against commit `02266fe8`". The live install is
> `f6017bdc…`. The skill tells you to read the commit file but never tells you to compare
> it to `02266fe8`, nor what to do if they differ. I proceeded because
> `compile-mod.ps1` reads the **live** `Assembly-CSharp-Publicized.dll` from the install,
> so the compile check remains authoritative regardless of the reference doc's provenance.

Loader presence check (skill's `Test-Path` guard):

```
NML\NeoModLoader.dll present  → OK
NML\Assembly-CSharp-Publicized.dll present (4,514,816 bytes) → OK
NML\Assemblies\ (19 dlls, incl. Mono.Cecil.dll) → OK
```

**Toolchain** — I did **not** run `setup-toolchain.ps1`; I checked first and the Roslyn
4.9.2 net472 compiler was already present:

```
Test-Path ...\skills\worldbox-modder\scripts\toolchain\pkg\compilers\tasks\net472\csc.exe
→ True
```

**Step 2 — scaffold the mod.**

```
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill-dir>\scripts\new-mod.ps1" `
  -ModId "com.example.giantpower" -Namespace "GiantPower" -Author "Example" `
  -Description "Adds a god power that turns units on the clicked tile into huge, fast giants." `
  -Destination "<repo-root>\eval-with-skill"

Created mod at: <repo-root>\eval-with-skill\com_example_giantpower
Next: compile-check it with scripts\compile-mod.ps1 -ModPath "<repo-root>\eval-with-skill\com_example_giantpower"
EXITCODE=0
```

**Steps 3–6 — write the mod.** See section 2 for the final files.

**Step 7 — compile-check.** See section 3.

### 1.3 Independent verification I had to do myself (not in the skill)

The skill gives no way to answer "which stat makes a unit *huge*?", so I decompiled the
live game assembly with the Mono.Cecil DLL that ships inside the NML install
(`mods\NML\Assemblies\Mono.Cecil.dll`) and read the relevant IL:

* `Assembly-CSharp-Publicized.dll` — for stat semantics, trait stat conventions, the
  `AssetManager` field list, the `BaseStatsLibrary` stat registry, and the localisation
  key conventions.
* `NeoModLoader.dll` — for `ModDeclare`'s `mod.json` schema, `BasicMod`, the
  `PowersTab` extension methods, and `ParseDepenNameToPreprocessSymbol`.

I also confirmed every API signature I used against the real assembly *before* writing
code, so the compile check passed on the first try:

```
Actor::addTrait(System.String pTraitID, System.Boolean pRemoveOpposites = false) -> System.Boolean
BaseSimObject.current_tile -> WorldTile   (field)
GodPower.click_action -> PowerActionWithID
AssetManager.traits -> ActorTraitLibrary ; trait_groups -> ActorTraitGroupLibrary ; powers -> PowerLibrary
BaseStats::set_Item(String,Single) / get_Item(String) -> Single
BaseStatsLibrary.add(T) via AssetLibrary`1 ; ActorTraitLibrary.add(ActorTrait)
TabManager.CreateTab(String, String, String, Sprite, String=hotkey_tip_tab_other) -> PowersTab
PowerButtonCreator.CreateGodPowerButton(String, Sprite, Transform=, Vector2=) -> PowerButton
PowersTabExtension::SetLayout / AddPowerButton / UpdateLayout  (NeoModLoader.General.UI.Tab)
SpriteTextureLoader.getSprite(String) -> Sprite
TraitType: Positive=0, Negative=1, Other=2
```

---

## 2. Final mod folder tree and full contents

```
<repo-root>\eval-with-skill\
└── com_example_giantpower\
    ├── icon.png                                   312 bytes  (from template, binary)
    ├── mod.json                                   522 bytes
    ├── Code\
    │   ├── Content.cs                            5644 bytes
    │   └── Main.cs                               1224 bytes
    ├── GameResources\
    │   └── ui\
    │       └── icons\
    │           └── icongiantpower.png             312 bytes  (from template, binary)
    └── Locales\
        └── en.json                                389 bytes
```

Nothing else was written under `eval-with-skill\` — no `obj\`, `bin\` or temp dirs. The
game's `Mods\` folder was **not** touched and the game was **not** launched:

```
C:\Program Files (x86)\Steam\steamapps\common\WorldBox\worldbox_Data\StreamingAssets\mods\
  ElementalPowersMod\   (pre-existing)
  NML\                  (pre-existing)
  test_asset_load\      (pre-existing)
  NeoModLoader.dll, NeoModLoader.pdb   (pre-existing)
```

`compile-mod.ps1` writes its throwaway assembly to
`%LOCALAPPDATA%\Temp\com_example_giantpower.check.dll` — that is the script's own
behaviour, not something I authored.

### `mod.json` (as written by `new-mod.ps1`; note the UTF-8 BOM, see 4.4)

```json
{
    "name":  "GiantPower",
    "GUID":  "com.example.giantpower",
    "author":  "Example",
    "version":  "0.1.0",
    "description":  "Adds a god power that turns units on the clicked tile into huge, fast giants.",
    "RepoUrl":  "",
    "iconPath":  "icon.png",
    "Dependencies":  [

                     ],
    "OptionalDependencies":  [

                             ],
    "IncompatibleWith":  [

                         ],
    "targetGameBuild":  0,
    "UsePublicizedAssembly":  true
}
```

### `Code\Main.cs`

```csharp
using NeoModLoader.api;

namespace GiantPower
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
            LogInfo("GiantPower loading");
            Content.Init();
            LogInfo("GiantPower ready");
        }

        /// <summary>
        /// The power tab needs the game UI to exist, and OnModLoad runs before there is
        /// a world at all. Create it on the first frame where the UI is ready.
        /// </summary>
        private void Update()
        {
            if (_tabCreated) return;
            if (!global::Config.game_loaded) return;
            if (MapBox.instance == null) return;

            _tabCreated = true;
            try
            {
                Content.CreatePowerTab();
                LogInfo("GiantPower power tab created");
            }
            catch (System.Exception e)
            {
                LogError("failed to create power tab: " + e);
            }
        }
    }
}
```

### `Code\Content.cs`

```csharp
using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using UnityEngine;

namespace GiantPower
{
    /// <summary>
    /// Registers everything this mod adds to the game:
    ///
    ///   1. a trait group (shows up as a tab in the trait editor)
    ///   2. the "giant" trait
    ///   3. the god power that hands that trait out
    ///   4. a powers tab that hosts the god power button
    ///
    /// Order matters:
    ///   1. create the asset and add it to its AssetManager library
    ///   2. fill in the stats
    ///   3. unlock it / attach it to the UI
    ///
    /// AssetManager.traits.add() allocates base_stats if it is still null, so it is
    /// safe to assign stats either before or after the add() call.
    /// </summary>
    public static class Content
    {
        public const string TraitGroupId = "giantpower_group";
        public const string TraitId = "giantpower_trait";
        public const string PowerId = "giantpower_power";
        public const string TabId = "giantpower_tab";
        public const string IconPath = "ui/icons/icongiantpower";

        public static void Init()
        {
            CreateTraitGroup();
            CreateTrait();
            CreatePower();
        }

        // --- trait group ------------------------------------------------------------
        // The trait group shows up as a new tab in the trait editor.
        // The locale key is "trait_group_" + group id.
        private static void CreateTraitGroup()
        {
            ActorTraitGroupAsset group = new ActorTraitGroupAsset();
            group.id = TraitGroupId;
            group.name = "trait_group_" + TraitGroupId;
            group.color = "#ff8c00ff";
            AssetManager.trait_groups.add(group);

            LM.AddToCurrentLocale("trait_group_" + TraitGroupId, "Giant Power");
        }

        // --- trait -----------------------------------------------------------------
        // Locale keys: "trait_" + id  and  "trait_" + id + "_info"
        private static void CreateTrait()
        {
            ActorTrait trait = new ActorTrait();
            trait.id = TraitId;
            trait.group_id = TraitGroupId;
            trait.path_icon = IconPath;
            trait.type = TraitType.Positive;

            AssetManager.traits.add(trait);

            // "scale" is the absolute sprite scale of the unit. A plain villager sits at
            // 0.1 (the $basic_unit$ template), and the trait stat is ADDED to that, so
            // +0.1 makes the unit exactly twice as tall as it was. The vanilla "giant"
            // trait only adds 0.05 (1.5x), so this one is deliberately bigger.
            trait.base_stats["scale"] = 0.1f;

            // "multiplier_speed" is multiplicative: the game computes
            // speed = speed * (1 + multiplier_speed). 0.5 means +50% movement speed,
            // the same value the vanilla "blessed" trait uses.
            trait.base_stats["multiplier_speed"] = 0.5f;

            // Same convention as the vanilla "giant" trait: giants are tougher too.
            trait.base_stats["multiplier_health"] = 0.5f;

            trait.unlock(true);

            LM.AddToCurrentLocale("trait_" + TraitId, "Giant");
            LM.AddToCurrentLocale("trait_" + TraitId + "_info", "Enormous and blisteringly fast.");
        }

        // --- god power ---------------------------------------------------------------
        // GodPower.name is the locale key for the title. The description key is
        // <name> + "_description" - there is no "power_" prefix.
        private static void CreatePower()
        {
            GodPower power = new GodPower();
            power.id = PowerId;
            power.name = PowerId;
            power.path_icon = IconPath;

            // PowerActionWithID: bool (WorldTile pTile, string pPowerId)
            power.click_action = (WorldTile pTile, string pPowerId) =>
            {
                if (pTile == null) return false;

                bool applied = false;
                foreach (Actor actor in MapBox.instance.units)
                {
                    if (actor != null && actor.isAlive() && actor.current_tile == pTile)
                    {
                        if (actor.addTrait(TraitId))
                        {
                            applied = true;
                        }
                    }
                }
                return applied;
            };

            AssetManager.powers.add(power);

            LM.AddToCurrentLocale(PowerId, "Become Giants");
            LM.AddToCurrentLocale(PowerId + "_description", "Turns every unit on the clicked tile into a huge, fast giant.");
        }

        // --- power tab ----------------------------------------------------------------
        // A GodPower on its own is invisible: it needs a PowerButton on a PowersTab.
        // This creates a brand new tab holding the mod's powers.
        // Call this only once the game UI exists - see Main.Update().
        public static void CreatePowerTab()
        {
            Sprite icon = SpriteTextureLoader.getSprite(IconPath);
            if (icon == null) return;

            PowersTab tab = TabManager.CreateTab(TabId, TabId, TabId + "_description", icon);
            tab.SetLayout(new System.Collections.Generic.List<string> { TraitGroupId });
            tab.AddPowerButton(TraitGroupId, PowerButtonCreator.CreateGodPowerButton(PowerId, icon));
            tab.UpdateLayout();

            LM.AddToCurrentLocale(TabId, "Giant Power");
            LM.AddToCurrentLocale(TabId + "_description", "Powers from GiantPower.");
        }
    }
}
```

### `Locales\en.json`

```json
{
  "trait_group_giantpower_group": "Giant Power",
  "trait_giantpower_trait": "Giant",
  "trait_giantpower_trait_info": "Enormous and blisteringly fast.",
  "giantpower_power": "Become Giants",
  "giantpower_power_description": "Turns every unit on the clicked tile into a huge, fast giant.",
  "giantpower_tab": "Giant Power",
  "giantpower_tab_description": "Powers from GiantPower."
}
```

### `icon.png` and `GameResources\ui\icons\icongiantpower.png`

Both are the template's demo asset — a 64×64 solid orange square with a darker border
(312 bytes each, identical bytes). They are valid PNGs and will render, but they are
placeholder art, not a "giant" icon. See 4.3.

---

## 3. The compile check — exact command, real output, exit code

Command (run **twice**; both runs produced byte-identical output):

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\compile-mod.ps1" -ModPath "<repo-root>\eval-with-skill\com_example_giantpower"
```

Real output:

```
=== WorldBox mod compile check: com_example_giantpower ===
sources : 2 file(s) under <repo-root>\eval-with-skill\com_example_giantpower\Code
refs    : 187

BUILD OK -> %USERPROFILE%\AppData\Local\Temp\com_example_giantpower.check.dll
compile-check only; NML recompiles from Code\*.cs at game start
```

**Exit code: `0`** (= clean build; the skill defines `0` = clean, `1` = compile errors,
`2` = toolchain/install not found).

Supporting checks I ran alongside it:

```
mod.json      → parses as JSON (12 top-level keys)
Locales\en.json → parses as JSON (7 top-level keys)
code files    → 2 .cs files, CRLF/LF preserved as written, no BOM
```

---

## 4. What the skill got wrong, left out, or that I had to work out myself

### 4.1 Wrong API facts in the skill (all verified against the live assembly)

**(a) Three of the nine `AssetManager` libraries listed in `SKILL.md` step 4 do not exist.**

`SKILL.md` lines 124–126 list `AssetManager.actor_assets`, `AssetManager.powers_tab` and
`AssetManager.races`. Enumerating the real `AssetManager` public fields:

| Skill says | Reality |
|---|---|
| `AssetManager.actor_assets` | **does not exist** → the real field is `actor_library` (`ActorAssetLibrary`) |
| `AssetManager.powers_tab` | **does not exist** → the real field is `power_tab_library` (`PowerTabLibrary`) |
| `AssetManager.races` | **does not exist** → there is no races library at all; the nearest are `kingdoms`, `clan_traits`, `culture_traits`, `language_traits`, `subspecies_traits`, `religion_traits` |

(`traits`, `trait_groups`, `powers`, `status`, `buildings`, `items` from the same list are
all correct.)

**(b) Four of the eleven names in `references/game-api.md`'s "Common stat names" list are
not real stat ids.**

I extracted the complete `BaseStatsLibrary` registry (65 registered `BaseStatAsset` ids)
by walking `BaseStatsLibrary::init` and collecting every `ldstr` immediately followed by
`stfld <BaseStatAsset>::id`. Checked against the skill's list:

| Skill's list | In registry? |
|---|---|
| `health`, `damage`, `speed`, `armor`, `happiness`, `diplomacy`, `size` | EXISTS |
| `fertility`, `endurance`, `age`, `vision` | **MISSING** |

`fertility`, `endurance`, `age` and `vision` are not actor stats. (The real ids are
`offspring`/`birth_rate`, `stamina`, `age_adult`/`age_breeding`/`lifespan`,
`vision`-equivalent `range`/`throwing_range`/`damage_range`.) Using any of the four
would log a runtime error via `BaseStats::checkStatName`.

**(c) `references/game-api.md` says a misspelled stat id is "silently ignored rather than
throwing".** In the live build it is not silent —
`BaseStats::checkStatName` calls `Debug.LogError("base_stats_library.get() - no asset with
id: " + id)` and adds *"Only call stats with S.id, never with pure strings to avoid
typos"*. The skill's claim understates the diagnostic that is actually available.

**(d) `references/sprites-and-resources.md` contradicts itself about `path_icon`.**
§2 and §4 give full file paths (`trait.path_icon = "ui/icons/iconGiant";` with the PNG at
`GameResources/ui/icons/iconGiant.png`, and the known-good vanilla list
`ui/icons/eight_gates`, `ui/Icons/iconKings`, …). §3's table instead says a trait icon
looks up "the **folder** path". The §3 row looks copy-pasted from the creature-frame rule
in §6 (which genuinely does use a trailing-slash base path). I followed §2/§4 and the
skill's own template; for icons they are the correct ones.

### 4.2 The biggest gap: the skill never explains how to make a unit *huge* or *fast*

This is the part of the task the skill does not cover at all, and where following the
skill literally would have produced a mod that does not do what was asked.

* `references/game-api.md` lists `size` first in its "Common stat names" line, right next
  to `speed`. **`size` is not the visual size.** From the IL, `size` is used by
  `MapBox::checkAttackFor`, `Actor::isInAttackRange`, `Actor::getSlashPosition` and
  `QuantumSpriteLibrary::drawUnitSize` — i.e. it is the **combat hitbox / attack reach**.
  Setting `trait.base_stats["size"] = 2f` would make the unit hit from further away and
  would not make it one pixel bigger on screen.
* The stat that actually controls how big a unit looks is **`scale`** — and the skill
  mentions `scale` only in a flat "Stat ids observed in the game data" list, with no
  explanation, no base value, and no hint that it is the sprite scale. The chain is:
  `Actor::updateStats` → `target_scale = stats["scale"]` → `Actor::updateChangeScale`
  lerps `actor_scale` toward it each frame → `Actor::finishScale` → the sprite transform.
  `Actor::getMassKG` computes `target_scale / 0.1 * stats["mass_2"]`, which proves
  **0.1 is the "normal" reference scale**; the `$basic_unit$` template asset sets
  `scale = 0.1`, `size = 0.5`, `speed = 5`.
* The skill's own step-4 example (`trait.base_stats["health"] = 500f;
  trait.base_stats["damage"] = 25f;`) makes the unit tougher and hit harder — it does
  **not** make it huge or fast. Its Examples section describes exactly my prompt and
  still never names the size or speed stat.

**Stat arithmetic is also absent from the skill**, and it changes the numbers you write:

* `BaseStats::mergeStats(other, multiplier)` is **additive**:
  `this[id] = this[id] + other.get(id) * multiplier`. `MetaObjectWithTraits.recalcBaseStats`
  merges each trait's `base_stats` with multiplier `1`, so **a trait's stat values are
  deltas** added to the species base.
* `BaseStats::checkMultipliers()` shows `multiplier_*` stats are **multiplicative**:
  `main.value = main.value + main.value * multiplier.value`. So
  `multiplier_speed = 0.5` means ×1.5 movement speed — *not* "+0.5 absolute speed".
* The vanilla body traits (`ActorTraitLibrary::addTraitsBody`) are the reference values,
  and the skill never mentions them: `giant` = `scale +0.05`, `multiplier_health +0.5`,
  `multiplier_speed −0.25`; `fat` = `scale +0.02`; `agile` = `scale −0.01`;
  `tiny` = `scale −0.02`; `fast` = `multiplier_speed +0.3`; `blessed` =
  `multiplier_speed +0.5`.

**What I chose, and why** (this is my judgement, not the skill's):

| Stat | Value | Reasoning |
|---|---|---|
| `scale` | `0.1f` | villager base is `0.1`, and the trait stat is additive → **exactly 2× visual size**. Vanilla `giant` only adds `0.05` (1.5×), so mine is deliberately bigger to read as "huge". |
| `multiplier_speed` | `0.5f` | ×1.5 movement speed; the same value the vanilla `blessed` trait uses. |
| `multiplier_health` | `0.5f` | +50% max health, matching the vanilla `giant` trait. **This is beyond the literal request** (which said "huge and fast") — I added it because it is the game's own convention for giantness. |
| `size` | *not touched* | Deliberate. `size` is the combat hitbox; changing it shifts attack-range/slash-position maths that I could not validate without launching the game. Consequence: the giant **looks** 2× but keeps its normal hitbox. |

### 4.3 The template scaffold leaves placeholders that `new-mod.ps1` does not rewrite

* The scaffold's `Locales\en.json` still carried the template's `my_mod_tab` /
  `my_mod_tab_description` keys and `"My Mod"` labels — `new-mod.ps1`'s rename map covers
  `my_mod_group`, `my_trait`, `my_power`, `my_effect`, `MyMod` and the icon, but **not**
  `my_mod_tab`. Left alone, every mod generated from this template would register a tab
  with the **same id**, and the tab id is what NML keys the powers-tab entry on. I
  renamed it to `giantpower_tab` / `giantpower_tab_description`.
* The scaffold ships a complete **status effect** (`status_giantpower_effect`,
  "My Effect", 30-second duration, `restoreHealth(5)` action) plus its locale entries,
  even when the mod does not want one. This request is one god power + one trait, so I
  deleted the effect and its locale keys rather than shipping dead content.
* The scaffold's `icon.png` and `icongiantpower.png` are the **same generic orange
  square** (the template's demo art), not a giant icon. The skill's
  `sprites-and-resources.md` §8 says 64×64 is a safe default (both are 64×64, so the
  size guidance is satisfied) but the skill offers no icon-authoring workflow, so this
  stays as placeholder art. It will render as an orange square in the powers tab.

### 4.4 Smaller things

* **Stale commit reference.** `SKILL.md` says the references are verified against NML
  commit `02266fe8`; the live install is `f6017bdcb6a3cfd4855d634e41b274f013463092`.
  Step 1 tells you to read the commit file but never says to reconcile it with the
  documented hash. In practice this is harmless here because `compile-mod.ps1` compiles
  against the live `Assembly-CSharp-Publicized.dll`, but the skill presents the
  reference docs as authoritative without a staleness check.
* **`mod.json` gets a UTF-8 BOM.** `new-mod.ps1` line 49 uses
  `Set-Content … -Encoding UTF8`, which in Windows PowerShell 5.1 writes a BOM
  (verified: first bytes `EF BB BF 7B 0D 0A`). The one working reference mod in the game
  (`ElementalPowersMod\mod.json`) has **no** BOM. It is nevertheless harmless, because
  NML parses it with `File.ReadAllText(path)` → `JsonConvert.DeserializeObject<ModDeclare>`,
  and `File.ReadAllText` strips a BOM. The script *does* write `Locales\en.json` without
  a BOM (line 61, `$utf8NoBom`), so the two files are inconsistent.
* **`GUID` → `UID` mapping is correct but undocumented.** I verified
  `NeoModLoader.api.ModDeclare.UID` carries `[JsonProperty("GUID")]`, so the `GUID` key
  in `mod.json` really is the mod's UID, and `ParseDepenNameToPreprocessSymbol` turns
  `com.example.giantpower` into `COM_EXAMPLE_GIANTPOWER` (letters upper-cased,
  non-alphanumerics → `_`). The skill's `nml-api.md` states that rule; it is right. Note
  the resulting UID differs in case from the folder name `com_example_giantpower` — harmless,
  but the skill's own "do not let the GUID differ from the folder name" advice is
  contradicted by what `new-mod.ps1` generates.
* **`TraitType` is never mentioned.** The trait editor buckets traits by
  `TraitType.Positive` / `Negative` / `Other`. The skill does not list it. I set
  `trait.type = TraitType.Positive`.
* **Minor doc nit.** The step-6 snippet writes `new List<string> { … }` without
  `using System.Collections.Generic;`; the skill's own template correctly uses
  `System.Collections.Generic.List<string>`.
* **The request's "villagers" vs "units on the clicked tile".** The two sentences of the
  request differ slightly in scope. I followed the explicit second sentence ("give the
  units on the clicked tile a new trait") and the skill's Examples section, which
  resolves the same prompt the same way: `actor.addTrait("giant_trait")` on **every**
  unit on the clicked tile. Villagers are therefore included, but so is everything else.
  Narrowing it to humans would be a one-line filter on the actor's civ/tribe.

### 4.5 What I could **not** verify

* **The mod was never installed or launched** (explicitly out of scope for this
  evaluation), so I have **no** `Player.log` evidence that the mod loads, that the power
  button appears on the tab, or that the trait renders. The skill's step 8 and its
  output contract ("the exact `Player.log` lines proving load, quoted") are therefore
  **not** satisfied — by design of this task, not by omission.
* **The gameplay magnitudes are reasoned from the game's own code, not observed.** The
  2× size and ×1.5 speed follow from the stat arithmetic in the assembly plus the
  vanilla reference values, but I have not seen the unit on screen. If the effect reads
  as too small or too large in game, `scale` (currently `0.1f`) and
  `multiplier_speed` (currently `0.5f`) are the two numbers to turn.
* **Whether the giant should also grow its hitbox** (`size`) is an open design question
  I deliberately left conservative, for the reason in 4.2.
