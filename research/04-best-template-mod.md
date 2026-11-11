# ─────────────────────────────────────────────────────────

## Verdict

### 🏆 Primary template: `TRIICKSTR_DEMON_SLAYER_MOD`

**Why it wins:**
- **880 lines / 7 files** — readable in ~10 minutes.
- It performs the **complete** loop a real mod needs: entry point → config → trait registration → status registration → item registration → entity/quest wiring → Harmony patching → sprite paths → localization.
- Its code is **self-contained**: `grep -i "plenty|PoB|Biomes"` over the entire folder matches **only `mod.json`**. The `Dependencies` entry is what blocks it today, not the code.
- It compiles successfully: `NML\CompiledMods\TRIICKSTR_DEMON_SLAYER_MOD.dll` exists.
- It demonstrates *both* Harmony idioms (manual `AccessTools.Method` + `prefix:`/`postfix:`) and *both* localization idioms.

> ⚠️ **Known caveat, stated up front:** NML currently has it `disabled: true` because its declared dependency `TRIICKSTR_PLENTY_O_BIOMES` is also disabled. To use it as a template: **delete the `"Dependencies"` line** (or enable PoB). Nothing in the code needs it.

### 🥈 Minimal skeleton: `TRIICKSTR_SELECTIVE_BREEDING`
62 lines, 2 files, `disabled: false` — the true "hello world", but it registers **no** asset; it only Harmony-patches `BabyHelper.traitsInherit`.

### 🥉 Best-structured reference (too big to reproduce): `SCPBOX_MOD`
6,921 lines / 23 files — has the best error isolation, a real `ModSettings` persistence class, and a clean `Stage()` init pipeline.

---

## Full file manifest — `TRIICKSTR_DEMON_SLAYER_MOD`

Root: `C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\TRIICKSTR_DEMON_SLAYER_MOD\`

| Path | Lines | Role |
|---|---:|---|
| `mod.json` | 9 | manifest |
| `icon.png` | — | mod icon |
| `default_config.json` | ~130 | NML config schema (`Swords`, `Ranks`, `Rank stats`, `Oni` groups) |
| `Code\Main.cs` | 88 | entry point + `DSConfig` |
| `Code\Traits.cs` | 117 | 22 `ActorTrait`s (11 slayer ranks + 12 Oni moons + Lesser Oni) |
| `Code\Items.cs` | 241 | 11 nichirin swords + Oni weapon + 8 sword *statuses* |
| `Code\Demons.cs` | 142 | Oni actor assets |
| `Code\Quests.cs` | 123 | world-log quests |
| `Code\Patches.cs` | 87 | 6 Harmony patches |
| `Code\UpdatedChecks.cs` | 92 | per-frame coroutine |
| `GameResources\ui\Icons\*.png` | 26 | trait icons |
| `GameResources\ui\Icons\items\*.png` | 11 | item icons |
| `GameResources\actors\oni\*.png` | 6 | Oni sprites |
| `GameResources\actors\races\items\w_*\w_*.png` + `sprites.json` | 11 dirs | weapon sprites |
| `GameResources\effects\**\*.png` + `sprites.json` | ~12 dirs | effect sheets |

**Total C# to reproduce: 880 lines across 7 files.** Copy each file verbatim from the paths above.

---

## 1. `mod.json` — verbatim

Source: `C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\TRIICKSTR_DEMON_SLAYER_MOD\mod.json`
```json
{
    "name": "Demon Slayer Mod",
    "author": "Triickstr",
    "version": "3.0.0",
    "description": "11 nichirin swords with elemental combat animations, demon slayer ranks, Onis and slayer quests. Requires Plenty o Biomes.",
    "iconPath": "icon.png",
    "targetGameBuild": 719,
    "Dependencies": ["TRIICKSTR_PLENTY_O_BIOMES"]
}
```
> For a template, **drop the `Dependencies` line** (nothing in the code uses it) — or keep it and also enable `TRIICKSTR_PLENTY_O_BIOMES`.

**Line-by-line:**
| Line | Key | Why |
|---|---|---|
| 2 | `name` | shown in the NML mod list. Required. |
| 3 | `author` | shown in the mod list. Required. |
| 4 | `version` | semver; bump it or NML's recompile check may skip you. |
| 5 | `description` | one-line summary shown in the mod list. |
| 6 | `iconPath` | path **relative to the mod folder** → `icon.png` must sit next to `mod.json`. |
| 7 | `targetGameBuild` | **719** = this install's build. A stale value (e.g. `115`) silently blocks the mod. |
| 8 | `Dependencies` | array of mod ids that must be enabled. **Remove for a standalone template.** |

---

## 2. `Code\Main.cs` — verbatim (88 lines)

Source: `...\TRIICKSTR_DEMON_SLAYER_MOD\Code\Main.cs`
```csharp
using System;
using System.Collections.Generic;
using NeoModLoader.api;
using NCMS.Utils;
using UnityEngine;
using HarmonyLib;

namespace abox{
    class Main : BasicMod<Main>{
        internal const string id = "triickstr.mods.worldbox.demonslayer";
        internal static Harmony harmony;
        private static bool started = false;

        protected override void OnModLoad(){
            harmony = new Harmony(id);
            DSConfig.init(GetConfig());
            DSConfig.addLabelsNew();
            Items.init();
            Traits.init();
            Demons.init();
            Quests.init();
            Patches.init();
        }

        void Update(){
            if(!global::Config.game_loaded){
                return;
            }
            if(!started){
                started = true;
                StartCoroutine(UpdatedChecks.LoopUnits());
            }
        }
    }

    class DSConfig
    {
        private static Dictionary<string, ModConfigItem> items = new Dictionary<string, ModConfigItem>();

        public static void init(ModConfig config){
            if(config == null){
                return;
            }
            foreach(string group in new string[]{"Swords", "Ranks", "Rank stats", "Oni"}){
                foreach(KeyValuePair<string, ModConfigItem> item in config[group]){
                    items[item.Key] = item.Value;
                }
            }
        }

        public static bool on(string id, bool fallback = true){
            return items.TryGetValue(id, out ModConfigItem item) ? item.BoolVal : fallback;
        }

        public static int value(string id, int fallback = 0){
            return items.TryGetValue(id, out ModConfigItem item) ? item.IntVal : fallback;
        }

        public static bool worldEffects => on("ds_world_effects");

        public static void addLabelsNew(){
            Dictionary<string, string> labels = new Dictionary<string, string>{
                {"Swords", "Swords"}, {"Ranks", "Kills needed per rank"}, {"Rank stats", "Slayer rank stats"}, {"Oni", "Oni"},
                {"ds_world_effects", "World effects (lava, lightning, quakes...). Off = animations only"},
                {"ds_oni_spawn", "Onis spawn"}, {"ds_oni_spawn_year", "First Oni year"}, {"ds_oni_spawn_interval", "Years between moons"},
                {"ds_lesser_oni_max", "Max Lesser Onis alive"}, {"ds_lesser_oni_per_year", "Lesser Onis per year"}
            };
            foreach(string element in Items.swords.Keys){
                labels["ds_sword_" + element] = Items.swordNames[element];
            }
            foreach(KeyValuePair<string, string> req in Traits.RankReqs){
                labels[req.Value] = req.Key.Replace("_", " ");
            }
            foreach(string prefix in new string[]{"ds_rank", "ds_oni"}){
                string who = prefix == "ds_rank" ? "Rank" : "Oni";
                foreach(KeyValuePair<string, string> stat in new Dictionary<string, string>{{"hp", "health"}, {"armor", "armor"}, {"damage", "damage"}, {"attack_speed", "attack speed %"}}){
                    labels[prefix + "_" + stat.Key] = who + " " + stat.Value;
                    labels[prefix + "_base_" + stat.Key] = who + " base " + stat.Value;
                    labels[prefix + "_step_" + stat.Key] = who + " " + stat.Value + " per rank";
                }
            }
            foreach(KeyValuePair<string, string> label in labels){
                Localization.addLocalization(label.Key, label.Value);
            }
        }
    }

}
```

### Line-by-line explanation

**Lines 1-6 — usings.**
- `System`, `System.Collections.Generic` — `Dictionary`, `KeyValuePair`.
- `NeoModLoader.api` — **required**: supplies `BasicMod<T>`, `ModConfig`, `ModConfigItem`.
- `NCMS.Utils` — supplies `Localization.addLocalization(...)` and the `.Underscore()` string extension.
- `UnityEngine` — `MonoBehaviour` (the `BasicMod<T>` base is a `MonoBehaviour`), `StartCoroutine`.
- `HarmonyLib` — `Harmony`, `AccessTools`, `HarmonyMethod`.

**Line 8 — `namespace abox{`.** One namespace per mod; must not collide with another mod's namespace (each mod is a separate assembly, but NML loads them into one AppDomain — collisions break `BasicMod` discovery).

**Line 9 — `class Main : BasicMod<Main>{`.** The NML entry point. `BasicMod<T>` is self-typed so NML can instantiate it. The class **must be discoverable** — NML scans the compiled assembly for `IMod` implementors (`TryInitMod` / `PostInitMod`, `nml_all.txt:1755-1756`). `Main` is a convention, not a requirement (`GodzillaMod`, `SakugaMod`, `ViltrumEmpireMod`, `PowerBox` all work too).

**Line 10 — `internal const string id = "triickstr.mods.worldbox.demonslayer";`.** A stable unique id used for the Harmony instance. Must be globally unique across all installed mods, or two mods' patches collide.

**Line 11 — `internal static Harmony harmony;`.** The Harmony instance lives on the entry class so every other file can reach it via `Main.harmony`.

**Line 12 — `private static bool started = false;`.** One-shot latch so the coroutine starts exactly once.

**Lines 14-23 — `protected override void OnModLoad(){`.** The single most important method. NML calls it after the assembly is loaded and the config is available. **Order matters:**
1. `harmony = new Harmony(id);` — create Harmony *first*, because `Patches.init()` needs it.
2. `DSConfig.init(GetConfig());` — read NML's config (from `default_config.json` + `mods_config\<id>.config`). `GetConfig()` can return `null` if `default_config.json` is missing → hence the `config == null` guard at line 41.
3. `DSConfig.addLabelsNew();` — register **all** localization strings **before** registering assets, so the UI never shows a missing-text warning.
4. `Items.init();` `Traits.init();` `Demons.init();` `Quests.init();` — asset registration.
5. `Patches.init();` — Harmony patches last, so the patched methods exist and the assets they touch are already in `AssetManager`.

**Lines 25-33 — `void Update(){`.** Unity's per-frame callback (the class is a `MonoBehaviour`). It gates on `global::Config.game_loaded` (note the `global::` — needed because the mod also has a class named `Config`/`DSConfig`) and uses the `started` latch to start the coroutine exactly once.

**Lines 36-38 — `class DSConfig`.** A flat, typed accessor over NML's `ModConfig`. NML's config is a `Dictionary<group, Dictionary<id, ModConfigItem>>`; the mod flattens it into one `Dictionary<string, ModConfigItem>` so call sites can just do `DSConfig.on("ds_world_effects")`.

**Lines 40-49 — `init(ModConfig config)`.** `config[group]` is a *group* lookup; th
</task_output>