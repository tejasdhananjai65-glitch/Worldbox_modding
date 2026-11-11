# ─────────────────────────────────────────────────────────

## 0. TL;DR of the platform

WorldBox ships a mod loader called **NeoModLoader (NML)**. Verified locations:

| Artifact | Path |
|---|---|
| NML runtime | `worldbox_Data\StreamingAssets\mods\NeoModLoader.dll` (4.5 MB) |
| NML data dir | `worldbox_Data\StreamingAssets\mods\NML\` |
| Publicized game asm | `worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll` (4,514,816 B) |
| Compiler + libs | `worldbox_Data\StreamingAssets\mods\NML\Assemblies\` (23 DLLs) |
| Compile output | `worldbox_Data\StreamingAssets\mods\NML\CompiledMods\<MODID>.dll` + `.pdb` |
| Enable/disable | `worldbox_Data\StreamingAssets\mods\NML\mod_compile_records.json` |
| Tab ordering | `worldbox_Data\StreamingAssets\mods\NML\tab_order_records.json` |
| NML version | `worldbox_Data\StreamingAssets\mods\NML\commit` → `02266fe8185d940c4065185de0a117c18975cf09` |
| Game assemblies | `worldbox_Data\Managed\` (162 DLLs) |
| Per-mod config | `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\` |

`NeoModLoader.dll` embedded-resource names (verified by byte-scanning the DLL):
`NeoModLoader.resources.assemblies.{0Harmony.dll, Assembly-CSharp-Publicized.dll, Microsoft.CodeAnalysis.CSharp.dll, Microsoft.CodeAnalysis.dll, Mono.Cecil.dll, Mono.Cecil.Pdb.dll, MonoMod.RuntimeDetour.dll, MonoMod.Utils.dll, YamlDotNet.dll, Facepunch.Steamworks.*.dll, Gameloop.Vdf.dll, System.*.dll, NeoModLoader.AutoUpdate.dll}`, plus `NeoModLoader.resources.locales.{ch,cz,en}.json`.

`NeoModLoader.dll` UTF-16 string literals that define the **mod folder contract** (verified by byte scan at offsets 598388–600000):
```
mods, Managed, .Managed, NML, commit, Assembly-CSharp-Publicized.dll, mods_config,
BepInEx, plugins, Mods, Assets, CompiledMods, tab_order_records.json,
mod_compile_records.json, disabled_mods.txt, default_config.json,
GameResources, Resources, GameResourcesReplace, AssetBundles, workshop, content,
EmbededResources, bin, obj, Properties, packages, packages.config,
packages-lock.json, packages-lock.xml, Locales, .config
```
and (offsets 541834–547918):
```
/Mods, /../Managed, /NCMS, /Core, /Assemblies, /Temp, /StreamingAssets/Mods,
0Harmony, Create Mods folder at, Create CompiledMods folder at,
Create mods_config folder at, Create mod_compile_records.json at,
Create NMLAssemblies folder at, No mod.json file for folder, in Mods
```

---

## 1. `mod.json` — the exact field set

### 1a. Field frequency across the 16 mods that have one

| Field | Present in | Notes |
|---|---|---|
| `name` | 16/16 | display name |
| `author` | 16/16 | |
| `version` | 16/16 | semver string |
| `description` | 14/16 | missing in `RAYTRACERX_SHINOBIBOX`? (present), missing in `_VILTRUM_EMPIRE` and `CORE4777_COREBOX` |
| `iconPath` / `IconPath` | 16/16 | **case matters**: `_VILTRUM_EMPIRE` uses `IconPath`, everyone else `iconPath` |
| `targetGameBuild` | 10/16 | `719` everywhere except `INVASION_SUMMONER` = `115` (stale → disabled) |
| `GUID` | 7/16 | mod id, uppercase, no spaces |
| `Dependencies` | 6/16 | array of mod ids |
| `OptionalDependencies` | 3/16 | |
| `IncompatibleWith` | 2/16 | |
| `ModType` | 2/16 | `"NEOMOD"` |
| `UsePublicizedAssembly` | 2/16 | `true` |

**In ALL mods:** `name`, `author`, `version`, `iconPath`.
**Mod-specific:** `GUID`, `targetGameBuild`, `Dependencies`, `OptionalDependencies`, `IncompatibleWith`, `ModType`, `UsePublicizedAssembly`, `description`.

There is **no** `main`, `entry`, `scripts`, `dll` or `assembly` key in any mod — NML infers everything from folder layout.

### 1b. Four real `mod.json` files, verbatim

**`C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\TURBO_SAKUGA\mod.json`** — every optional field:
```json
{
  "name": "Combat Gods",
  "author": "Turbo",
  "version": "1.0.4",
  "description": "Anime combat for WorldBox: six tiers from Novice to Combat God, with auras, techniques and duels.",
  "GUID": "TURBO_SAKUGA",
  "iconPath": "icon.png",
  "targetGameBuild": 719,
  "ModType": "NEOMOD",
  "UsePublicizedAssembly": true,
  "Dependencies": [],
  "OptionalDependencies": [],
  "IncompatibleWith": []
}
```

**`...\Mods\TRIICKSTR_DEMON_SLAYER_MOD\mod.json`** — the 4-field minimum + dependency:
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

**`...\Mods\TRIICKSTR_SELECTIVE_BREEDING\mod.json`** — the true minimum:
```json
{
    "name": "Selective Breeding",
    "author": "Triickstr",
    "version": "3.0.0",
    "description": "Inherit traits inside! Babies get every inheritable trait from both parents.",
    "iconPath": "icon.png",
    "targetGameBuild": 719
}
```

**`...\Mods\_VILTRUM_EMPIRE\mod.json`** — note `IconPath` capitalisation:
```json
{
  "name": "Viltrum Empire",
  "author": "SonOfViltrum",
  "version": "4.0.20",
  "GUID": "_VILTRUM_EMPIRE",
  "IconPath": "icon.png",
  "Dependencies": [],
  "OptionalDependencies": []
}
```

### 1c. `.csproj` / `.dll` / `Assemblies/`

- **`.csproj` / `.sln` / `.rsp` / `.props` / `.targets`: 0 hits across all 1,216 files in all 17 mod folders.**
- **`.dll` inside a mod: exactly 1** — `_VILTRUM_EMPIRE\Assemblies\Assembly-CSharp.dll` (a stray copy of the game assembly, *not* a mod build output).
- **No mod has an `Assemblies/` folder other than `_VILTRUM_EMPIRE`.** Everything else is source-only.

---

## 2. Build system — **there is none; the game compiles it**

### 2a. Evidence that the game compiles at runtime

1. All 17 mods contain `Code/*.cs` and **no** compiled binary.
2. `worldbox_Data\StreamingAssets\mods\NML\CompiledMods\` contains **27 `.dll` + 27 `.pdb` pairs**, named exactly by mod id, e.g. `TRIICKSTR_SELECTIVE_BREEDING.dll`, `SCPBOX_MOD.dll`, `TURBO_SAKUGA.dll`. Timestamps span 2026-07-07 → 2026-10-19 — i.e. produced by the *game*, not the mod author.
3. NML embeds the Roslyn compiler. From `NeoModLoader.dll` embedded resources:
   `NeoModLoader.resources.assemblies.Microsoft.CodeAnalysis.CSharp.dll` (7,917,848 B) and `Microsoft.CodeAnalysis.dll` (4,896,928 B).
4. The Cecil API dump of NML (`<repo-root>\_tools\nml_all.txt:1742-1761`) shows the compile service:
   ```
   === TYPE public abstract sealed classNeoModLoader.services.ModCompileLoadService : System.Object
       FIELD private static System.String[] _default_ref_path
       FIELD private static readonly System.Collections.Generic.Dictionary`2<System.String,System.String> mod_inc_path
       FIELD private static readonly System.Collections.Generic.HashSet`1<System.String> _loaded_ref
       FIELD private static Microsoft.CodeAnalysis.MetadataReference[] _default_ref
       FIELD private static Microsoft.CodeAnalysis.MetadataReference _publicized_assembly_ref
       FIELD private static readonly System.Collections.Generic.Dictionary`2<System.String,Microsoft.CodeAnalysis.MetadataReference> mod_ref
       METHOD private static System.Boolean compileMod(NeoModLoader.api.ModDeclare pModDecl, System.Collections.Generic.IEnumerable`1<Microsoft.CodeAnalysis.MetadataReference> pDefaultInc, System.String[] pAddInc, System.Collections.Generic.Dictionary`2<System.String,Microsoft.CodeAnalysis.MetadataReference> pModInc, System.Boolean pForce = False, System.Boolean pDisableOptionalDepen = False)
       METHOD public static System.Void prepareCompile(System.Collections.Generic.List`1<NeoModLoader.utils.ModDependencyNode> pModNodes)
       METHOD public static System.Void prepareCompileRuntime(NeoModLoader.utils.ModDependencyNode pModNode)
       METHOD public static System.Boolean compileMod(NeoModLoader.utils.ModDependencyNode pModNode, System.Boolean pForce = False)
       METHOD public static System.Void loadMods(System.Collections.Generic.List`1<NeoModLoader.api.ModDeclare> mods_to_load)
       METHOD public static System.Void LoadMod(NeoModLoader.api.ModDeclare pMod)
       METHOD public static System.Boolean TryInitMod(NeoModLoader.api.IMod mod)
       METHOD public static System.Void PostInitMod(NeoModLoader.api.IMod mod)
       METHOD public static System.Boolean IsModLoaded(System.String uid)
   ```
   `_default_ref_path` + `mod_inc_path` + `_publicized_assembly_ref` + Roslyn `MetadataReference` = the exact reference-resolution model.
5. NML decides when to recompile: `nml_all.txt:3018`
   `METHOD public static System.Boolean doesModNeedRecompile(NeoModLoader.api.ModDeclare pModDeclare, System.Collections.Generic.List`1<System.String> pDependencies, System.Collections.Generic.List`1<System.String> pOptionalDependencies)`
   plus `getModLastCompileTimestamp` / `getModNewestUpdateTimestamp` / `clearModCompileTimestamp`.
6. NML extracts its embedded assemblies on startup (`nml_all.txt` / DLL strings):
   `Create NMLAssemblies folder at` → `NML\Assemblies\`; `Assembly-CSharp-Publicized` → `NML\Assembly-CSharp-Publicized.dll`.

### 2b. Exact reference set (VERIFIED on disk)

| Reference | Path | Why |
|---|---|---|
| `Assembly-CSharp-Publicized.dll` | `worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll` | game API with `private`/`internal` widened to `public` so mods can touch privates |
| `0Harmony.dll` | `worldbox_Data\StreamingAssets\mods\NML\Assemblies\0Harmony.dll` (205,824 B) | Harmony patching |
| `mscorlib.dll`, `System.dll`, `System.Core.dll`, `netstandard.dll`, … | `worldbox_Data\Managed\` | Mono BCL that the game actually runs on |
| `UnityEngine*.dll` (≈60 modules), `UnityEngine.UI.dll` | `worldbox_Data\Managed\` | engine API |
| `Newtonsoft.Json.dll` (691,712 B) | `worldbox_Data\Managed\` | used by mods (`using Newtonsoft.Json;`) |
| `Assembly-CSharp-firstpass.dll`, `DOTween.dll`, `FMODUnity.dll`, … | `worldbox_Data\Managed\` | transitively needed |

NML string literals `"/../Managed"`, `".Managed"`, `"Managed"` (offsets 599302–599346) confirm `_default_ref_path` resolves to `worldbox_Data\Managed`, with `Assembly-CSharp.dll` **swapped for** `Assembly-CSharp-Publicized.dll` (offset 543440: `NeoModLoader.resources.assemblies.Assembly-CSharp-Publicized.dll`).

### 2c. Target framework

NML's own PDB path embedded in `NeoModLoader.dll`:
`%USERPROFILE%\RiderProjects\ModLoader\obj\Debug\net48\NeoModLoader.pdb`
→ NML itself is a **.NET Framework 4.8 / Rider** project. The mods it compiles target the game's Mono BCL (`worldbox_Data\Managed\mscorlib.dll`, 4.6 MB), i.e. **net48-compatible C#, compiled by Roslyn 4.x at runtime**.
The `Microsoft.CodeAnalysis.dll` string heap also contains `.NETFramework,Version=v4.8` and `.NETStandard,Version=v2.0`, consistent with a net48 compilation that also sees `netstandard.dll`.

---

## 3. Code conventions

### 3a. The two entry-point families

**Family A — NeoModLoader (12 of 15 mods with code):** `class X : BasicMod<X>` + `protected override void OnModLoad()`

| Mod | Class | File:line |
|---|---|---|
| AGRICHE_GODZILLA | `public class GodzillaMod : BasicMod<GodzillaMod>` | `Code\Mod.cs:8,12` |
| AHOYOS__KEYMASTERER__IFAILEDLIFE__DON_NIKON_POWERBOX | `public class PowerBox : BasicMod<PowerBox>` | `Code\PowerBox.cs:31,44` |
| AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS | `class Main : BasicMod<Main>` | `Code\Main.cs:13` |
| AVOIDINGBOREDOM_AVB_S_EXPANDED_ARMORY | `class Main : BasicMod<Main>` | `Code\Main.cs:17` |
| AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK | `class Main : BasicMod<Main>` | `Code\Main.cs:14` |
| CORE4777_COREBOX | `public class Main : BasicMod<Main>` | `Code\Main.cs:7` |
| INVASION_SUMMONER | `public class Main : BasicMod<Main>` | `Code\Main.cs:10,165` |
| RAYTRACERX_SHINOBIBOX | `public class Main : BasicMod<Main>` | `Code\Main.cs:8` |
| SCPBOX_MOD | `class Main : BasicMod<Main>` | `Code\Main.cs:11` |
| TRIICKSTR_DEMON_SLAYER_MOD | `class Main : BasicMod<Main>` | `Code\Main.cs:9` |
| TURBO_SAKUGA | `public class SakugaMod : BasicMod<SakugaMod>` | `Code\SakugaMod.cs:22,24` |
| _VILTRUM_EMPIRE | `public class ViltrumEmpireMod : BasicMod<ViltrumEmpireMod>` | `Code\ViltrumEmpire.cs:8,23` |

**Family B — legacy NCMS (3 mods):** `[ModEntry] class Main : MonoBehaviour` + `void Awake()`

| Mod | Class | File:line |
|---|---|---|
| TRIICKSTR_SELECTIVE_BREEDING | `class Main : MonoBehaviour` | `Code\Main.cs:13-21` |
| TRIICKSTR_PLENTY_O_BIOMES | `class Main : MonoBehaviour, IConfigurable` | `Code\Main.cs:23-24` |
| TAYFIM_ABYSSFALL | `class Main : MonoBehaviour` | `Code\Main.cs:42-43` |

Verbatim, `TRIICKSTR_SELECTIVE_BREEDING\Code\Main.cs` (the entire file, 25 lines):
```csharp
using System.IO;
using System.Linq;
using System.Collections.Generic;
using NCMS;
using NCMS.Utils;
using UnityEngine;
using ReflectionUtility;
using HarmonyLib;
using System.Reflection;
using Newtonsoft.Json;

namespace babiess{
    [ModEntry]
    class Main : MonoBehaviour{
        internal const string id = "triickstr.mods.worldbox.selectivebreeding";
		internal static Harmony harmony;

        void Awake(){
            harmony = new Harmony(id);
            Breeding.init();
        }

    }

}
```

### 3b. Namespace pattern

One namespace per mod family, matching the mod's brand — never a generic "MyMod":
`babiess` (Selective Breeding) · `abox` (Demon Slayer) · `biomes` (Plenty o Biomes) · `Magic` (Abyssfall) · `aaaMod` (AVB Aesthetic) · `Godzilla` · `Sakuga` · `ViltrumEmpire` · `ScpBox` · `InvasionSummoner` · `PowerBox.Code` · `ClanSuccession.AssignTool`.

### 3c. Required `using` set (every working mod has these)

```csharp
using UnityEngine;          // MonoBehaviour, Sprite, Debug
using NCMS;                 // AssetManager, ActorTrait, GodPower, Config (game API)
using NCMS.Utils;           // Localization, Sprites, extension helpers
using HarmonyLib;           // Harmony, AccessTools, HarmonyPatch
using NeoModLoader.api;     // BasicMod<T>, ModConfig, ModConfigItem  (NML family)
using System.Reflection;    // Assembly, MethodInfo
```
`Newtonsoft.Json` only when persisting JSON.

### 3d. Logging

Three idioms coexist:
- `Debug.LogError("[Godzilla] " + id + ": " + e);` — `AGRICHE_GODZILLA\Code\Powers.cs:109`
- `ScpUtils.Log("loading...")` / `ScpUtils.Error($"stage '{pName}' failed: {e}")` — `SCPBOX_MOD\Code\Main.cs:47,71`
- NML's own `LogService` (`nml_all.txt:1730-1740`: `LogType.Info|Warning|Error`, `WrappedMessage`).

### 3e. Success / failure signalling

**There is no return code and no exception-based contract.** A mod "works" if `OnModLoad()` runs to completion without throwing. Three defensive styles are used:

1. **Stage isolation** (best) — `SCPBOX_MOD\Code\Main.cs:68-72`:
   ```csharp
   private static void Stage(string pName, Action pAction)
   {
       try { pAction(); }
       catch (Exception e) { ScpUtils.Error($"stage '{pName}' failed: {e}"); }
   }
   ```
   used as `Stage("traits", ScpTraits.Initialize);` (`Main.cs:49-63`).
2. **Per-patch isolation** — `SCPBOX_MOD\Code\Main.cs:74-94`:
   ```csharp
   Harmony harmony = new Harmony("scpbox.mod");
   int applied = 0, failed = 0;
   foreach (Type type in Assembly.GetExecutingAssembly().GetTypes())
   {
       if (type.GetCustomAttributes(typeof(HarmonyPatch), true).Length == 0) continue;
       try { new PatchClassProcessor(harmony, type).Patch(); applied++; }
       catch (Exception e) { failed++; ScpUtils.Error($"patch '{type.Name}' failed: {e.Message}"); }
   }
   ScpUtils.Log($"harmony: {applied} applied, {failed} failed");
   ```
3. **Null guards before touching the world** — e.g. `SCPBOX_MOD\Code\ScpTraits.cs:117-118`:
   ```csharp
   ActorTrait existing = AssetManager.traits.get(pId);
   if (existing != null) return existing;
   ```

---

## 4. Registration patterns (verbatim)

### 4a. Trait — register, icon, give-flag, localize

`TRIICKSTR_DEMON_SLAYER_MOD\Code\Traits.cs:55-69`:
```csharp
public static void addTraitNew(string id, string icon, string name, string description){
    ActorTrait trait = new ActorTrait();
    trait.id = id;
    trait.path_icon = icon;
    trait.group_id = "special";
    trait.type = TraitType.Positive;
    trait.spawn_random_trait_allowed = false;
    trait.rate_inherit = 0;
    trait.can_be_given = false;
    AssetManager.traits.add(trait);
    foreach(string key in new string[]{"trait_" + id, ("trait_" + id).Underscore()}){
        Localization.addLocalization(key, name);
        Localization.addLocalization(key + "_info", description);
    }
}
```
Called from `Traits.cs:43-53`:
```csharp
public static void init()
{
    foreach(string rank in RankIds.Keys){
        addTraitNew(rank, "ui/Icons/icon" + rank, rank.Replace("_", " "), "Demon slayer " + RankNames[rank].ToLower() + ". Earned with kills while holding a nichirin sword.");
    }
    foreach(string rank in OniSteps.Keys){
        addTraitNew(rank, "ui/Icons/" + rank, OniNames[rank], "One of the twelve demon moons.");
    }
    addTraitNew(LESSER, "ui/Icons/iconOni", "Lesser Oni", "A weak demon, prey for new demon slayers.");
    applyStatsNew();
}
```

### 4b. Trait — idempotent variant (get-then-add)

`SCPBOX_MOD\Code\ScpTraits.cs:115-135`:
```csharp
private static ActorTrait Make(string pId, string pIcon)
{
    ActorTrait existing = AssetManager.traits.get(pId);
    if (existing != null) return existing;

    ActorTrait trait = new ActorTrait
    {
        id = pId,
        path_icon = "ui/Icons/" + pIcon,
        group_id = "special",
        rate_birth = 0,
        rate_inherit = 0,
        rate_acquire_grow_up = 0,
        spawn_random_trait_allowed = false,
        can_be_cured = false,
        can_be_removed_by_divine_light = false,
        is_mutation_box_allowed = false
    };
    AssetManager.traits.add(trait);
    return trait;
}
```

### 4c. Trait — with unlock (the "player can use it" step)

`_VILTRUM_EMPIRE\Code\DevelopedAbilitySystem.cs:538-548`:
```csharp
private static void RegisterTrait(int index)
{
    ActorTrait trait = AssetManager.traits.get(AllTraits[index]);
    if (trait == null) { trait = new ActorTrait(); trait.id = AllTraits[index]; AssetManager.traits.add(trait); }
    trait.group_id = GroupId;
    trait.path_icon = IconPath(index);
    if (trait.base_stats == null) trait.base_stats = new BaseStats();
    trait.base_stats.set("skill_combat", 1f + index % 3);
    if (index / 3 == 7) trait.base_stats.set("warfare", 2f + index % 3);
    trait.can_be_given = true; trait.can_be_removed = true; trait.unlock(true);
}
```

Only **3 of 17** mods call `unlock(true)`: `RAYTRACERX_SHINOBIBOX`, `_VILTRUM_EMPIRE`, (`TAYFIM_ABYSSFALL` uses bare `unlock()`).
`_VILTRUM_EMPIRE\Code\CustomTraitSafetySystem.cs:248-262` shows the bulk-unlock pattern:
```csharp
if (AssetManager.traits == null)
    return;

for (int i = 0; i < AllCustomTraits.Length; i++)
{
    string traitId = AllCustomTraits[i];
    ActorTrait trait = AssetManager.traits.get(traitId);
    if (trait == null)
        continue;

    trait.can_be_given = true;
    trait.can_be_removed = true;
    trait.unlock(true);
    EditorAvailableTraitCount++;
}
```
Item unlock example — `RAYTRACERX_SHINOBIBOX\Code\ShinobiItems.cs:63-71`:
```csharp
EquipmentAsset scythe = AssetManager.items.clone("weapon_triple_scythe", "$weapon");
scythe.id = "weapon_triple_scythe";
scythe.translation_key = scythe.id;
scythe.material = "basic";
scythe.equipment_subtype = "scythe";
scythe.group_id = GroupId_ShinobiEquipment;
scythe.quality = Rarity.R3_Legendary;
scythe.is_pool_weapon = false;
scythe.unlock(true);
```

### 4d. Power — register + click action + tab button

`AGRICHE_GODZILLA\Code\Powers.cs:89-114`:
```csharp
private static void Add(string id, string icon, Func<WorldTile, bool> action, string group)
{
    GodPower p = AssetManager.powers.add(new GodPower
    {
        id = id,
        name = id,
        path_icon = icon,
        rank = PowerRank.Rank0_free,
        requires_premium = false,
        unselect_when_window = true,
        set_used_camera_drag_on_long_move = true
    });
    p.click_action = (PowerActionWithID)Delegate.Combine(p.click_action, new PowerActionWithID((tile, power) =>
    {
        try
        {
            return tile != null && action(tile);
        }
        catch (Exception e)
        {
            Debug.LogError("[Godzilla] " + id + ": " + e);
            return false;
        }
    }));
    _buttons.Add(new Button { Id = id, Icon = icon, Group = group });
}
```
Tab wiring, `AGRICHE_GODZILLA\Code\Powers.cs:122-131`:
```csharp
public static void AddTab()
{
    PowersTab tab = TabManager.CreateTab(Tab, Tab, Tab + "_description", Icon("godzilla/godzilla_tab"));
    tab.SetLayout(new List<string> { Group, GroupC, GroupW });
    foreach (Button b in _buttons)
    {
        tab.AddPowerButton(b.Group, PowerButtonCreator.CreateGodPowerButton(b.Id, Icon(b.Icon)));
    }
    tab.UpdateLayout();
}
```

### 4e. Status (effect)

`TRIICKSTR_DEMON_SLAYER_MOD\Code\Items.cs:50-62`:
```csharp
effect.locale_id = "status_title_" + id;
effect.locale_description = "status_description_" + id;
effect.path_icon = "ui/Icons/iconOni";
AssetManager.status.add(effect);
effect.sprite_list = SpriteTextureLoader.getSpriteList("effects/" + texture);
effect.need_visual_render = true;
effect.material = LibraryMaterials.instance.dict[effect.material_id];
Localization.addLocalization(effect.locale_id, "Struck");
Localization.addLocalization(effect.locale_description, "Hit by a breathing technique.");
```

### 4f. Trait groups

`_VILTRUM_EMPIRE\Code\DevelopedAbilitySystem.cs:535`: `AssetManager.trait_groups.add(group);`

### 4g. Buildings / races

`AssetManager.buildings.add(...)` appears in `TAYFIM_ABYSSFALL` and `_VILTRUM_EMPIRE` (both `buildings.clone` for vanilla clones). `AssetManager.races` is **never** used by any of the 17 mods — races are added via `AssetManager.actor_library.add(...)` (`AGRICHE_GODZILLA`, `CORE4777_COREBOX`, `RAYTRACERX_SHINOBIBOX`, `SCPBOX_MOD`).

### 4h. Tab creation

`SCPBOX_MOD\Code\ScpTab.cs:14-22`:
```csharp
public static void Initialize()
{
    Tab = TabManager.CreateTab(
        "Tab_ScpBox",
        "ScpBox",
        "scp_tab_desc",
        Sprites.LoadSprite($"{Main.ModFolder}/EmbededResources/UI/Icons/iconScpTab.png")
    );
}
```
`Main.ModFolder` is the mod's own helper — `SCPBOX_MOD\Code\Main.cs:17-32`:
```csharp
public static string ModFolder
{
    get
    {
        string baseDir = ModPath ?? AppDomain.CurrentDomain.BaseDirectory;
        string modsDir = System.IO.Path.Combine(baseDir, "Mods");
        if (System.IO.Directory.Exists(modsDir))
        {
            foreach (string dir in System.IO.Directory.GetDirectories(modsDir))
            {
                if (System.IO.Path.GetFileName(dir).ToLower().Contains("scpbox")) return dir;
            }
        }
        return baseDir;
    }
}
```
Tab order is global and persisted in `NML\tab_order_records.json`:
`["PowerBox","ViltrumEmpire","Shinobi","godzilla_tab","creation","noosphere","units","nature","destruction","other","CoreBox","sakuga_tab","clansuccession","Tab_Magic"]`

---

## 5. Localization

### 5a. Two mechanisms

**Mechanism 1 — inline, via NCMS (`Localization.addLocalization`)**
Used by `TRIICKSTR_DEMON_SLAYER_MOD`, `SCPBOX_MOD`, `AGRICHE_GODZILLA`.
```csharp
Localization.addLocalization(effect.locale_id, "Struck");
Localization.addLocalization(effect.locale_description, "Hit by a breathing technique.");
```
`TRIICKSTR_DEMON_SLAYER_MOD\Code\Main.cs:82-84`:
```csharp
foreach(KeyValuePair<string, string> label in labels){
    Localization.addLocalization(label.Key, label.Value);
}
```

**Mechanism 2 — via NML (`LM.AddToCurrentLocale`)**
Used by `_VILTRUM_EMPIRE\Code\AbilityEvolutionSystem.cs:279-281`:
```csharp
// Install every alias first so registration never emits a missing-text warning.
LM.AddToCurrentLocale("trait_" + id, name); LM.AddToCurrentLocale("trait_" + id + "_info", description);
LM.AddToCurrentLocale(id, name); LM.AddToCurrentLocale(id + "_info", description);
```
NML API (`nml_all.txt:1050-1056`):
```
METHOD public static System.Void LoadLocale(System.String pLanguage, System.IO.Stream pStream)
METHOD public static System.Void LoadLocale(System.String pLanguage, System.String pFilePath)
METHOD public static System.Void AddToCurrentLocale(System.String key, System.String value)
METHOD public static System.Void Add(System.String language, System.String key, System.String value)
METHOD public static System.Void ApplyLocale(System.String language, System.Boolean pUpdateTexts = True)
```
NML auto-loads a mod's locale folder on mod load — `nml_all.txt:1763`:
`METHOD internal static System.Void <LoadMod>g__auto_localize|11_0(System.Object mod_component, ...)`, and `nml_all.txt:281`:
`METHOD public virtual System.String GetLocaleFilesDirectory(NeoModLoader.api.ModDeclare pModDeclare)`.

### 5b. `Locales/*.json` structure

**Flat one-level JSON object: `"<key>": "<value>"`.** No nesting, no locale wrapper.

Verbatim, `...\Mods\AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS\Locales\en.json`:
```json
{
  "aaa_config": "Aesthetic Options (restart)",
  "config_unevo": "Classic Animal Recolors",
  "config_unevo Description": "Unevolved animals now match the palette of their evolved forms (recommended)",
  "config_evo": "Evolved Animal Recolors",
  "config_evo Description": "Evoled animals now match the palette of their unevolved forms",
  "config_phenoSort": "Phenotype Sort",
  "config_phenoSort Description": "Sorts phenotypes based on color instead of name",
  "config_phenoPlates": "Phenotype and Meta Color Considerate Icons",
  "config_phenoPlates Description": "Nameplates and Subspecies Overviews that feature a species's icon will have that icon match the color of the respective subspecies's phenotype amd kingdom/meta color (also adds mutations as species icons)",
  "config_genDimensions": "Map Size Dimensions",
  "config_genDimensions Description": "Displays the dimension of the selected map size in the New World menu (may not display correctly for custom map sizes in the menu)",

  "sponge": "Broom"
}
```

Verbatim, `...\Mods\CORE4777_COREBOX\Locales\en.json` (first 12 entries):
```json
{
  "status_title_corebox_weakened": "Weakened",
  "status_description_corebox_weakened": "Temporarily reduces damage and movement speed.",
  "CoreBoxCredits": "CoreBox Credits",
  "corebox.divine_scar": "Scar of divinity",
  "corebox.divine_scar Description": "The mark the game leaves on anything a god edits by hand. Off means it is never applied.",
  "corebox.forbidden_knowledge": "Forbidden knowledge from the start",
  "corebox.forbidden_knowledge Description": "Every world generated from now on starts with forbidden knowledge switched on.",
  "corebox.frame_cap": "Frame rate cap",
  "corebox.frame_cap Description": "Caps the drawn frames per second and switches vertical sync off so the cap applies. 0 leaves it to the game's own graphics options.",
  "corebox.miracle_born": "Miracle Born",
  "corebox.miracle_born Description": "Allow the Miracle Born trait to be added. Turning this off keeps it on creatures that already have it.",
  ...
}
```

### 5c. Key naming conventions (observed)

| Pattern | Example | Consumer |
|---|---|---|
| `trait_<id>` / `trait_<id>_info` | `"trait_Mizunoto"` | `ActorTrait` display name/desc |
| `trait_<id_with_underscores>` | same string, `_`→`"` variant registered too (`Traits.cs:65`) | fallback |
| `status_title_<id>` / `status_description_<id>` | `"status_title_corebox_weakened"` | `StatusAsset.locale_id` / `.locale_description` |
| `item_<id>` / `<id>_description` | `Localization.addLocalization("item_" + id, swordNames[element]);` (`Items.cs:78-79`) | `EquipmentAsset.translation_key` |
| `translation_key = <asset id>` | `scythe.translation_key = scythe.id;` (`ShinobiItems.cs:65`) | item name |
| `<modprefix>.<config_id>` + `"<config_id> Description"` | `"corebox.miracle_born"` / `"corebox.miracle_born Description"` | ModConfig label/description |
| `<id>_description` | `"corebox_army_join_description"` | world-log / action text |

**How a trait gets its name:** the asset sets `path_icon` and the mod registers `trait_<id>` → display name and `trait_<id>_info` → description. `ActorTrait` has no `locale_id` field, so the `trait_` prefix convention is the contract (WorldBox's own `trait_<id>` / `trait_<id>_info` scheme). `StatusAsset` **does** have `locale_id`/`locale_description` fields, which are set explicitly.

### 5d. Locale coverage per mod

| Mod | Locale dir | Files |
|---|---|---|
| AGRICHE_GODZILLA | `Locales` | br, en |
| AHOYOS__KEYMASTERER… | `Locales` | ch, cz, de, en, es, fi, ja, ko, ro, ru, ua (11) |
| AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS | `Locales` | ch, cz, en, ru |
| AVOIDINGBOREDOM_AVB_S_EXPANDED_ARMORY | `locales` *(lowercase)* | ch, cz, en, ru |
| AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK | `locales` *(lowercase)* | ch, cz, en, ru, ua |
| CORE4777_COREBOX | `Locales` | br, ch, cz, en, ja, ko, ru |
| RAYTRACERX_SHINOBIBOX | `Locales` | ch, cz, en, ru |
| TURBO_SAKUGA | `Locales` | br, cz, en, es, ru |
| INVASION_SUMMONER, KIVEN_CHEN_CLANSUCCESSION, SCPBOX_MOD, TAYFIM_ABYSSFALL, TRIICKSTR_DEMON_SLAYER_MOD, TRIICKSTR_PLENTY_O_BIOMES, TRIICKSTR_SELECTIVE_BREEDING, _VILTRUM_EMPIRE | — | none (inline `Localization.addLocalization`) |

> **Folder name is case-sensitive on Linux and inconsistent in the wild**: `Locales` vs `locales`. Both appear. NML's literal is `Locales`.

---

## 6. Sprites

### 6a. Folder layout (VERIFIED)

```
<WorldBox>\Mods\<MOD_ID>\
├── mod.json
├── icon.png                       ← optional mod icon, referenced by mod.json "iconPath"
├── Code\                          ← all .cs
├── GameResources\                 ← Unity "Resources" overlay for this mod
│   ├── ui\Icons\<iconName>.png
│   ├── actors\<actorId>\Main\*.png
│   ├── actors\races\items\<itemId>\<itemId>.png
│   ├── effects\<effectId>\tile000.png … + sprites.json
│   └── buildings\<buildingId>\*.png
├── Locales\<lang>.json            ← or `locales/`
├── EmbededResources\              ← note the typo, used by NML for tab icons
├── GameResourcesReplace\          ← overlays vanilla assets
└── Sprites\                       ← legacy (AGRICHE_GODZILLA, KIVEN_CHEN_CLANSUCCESSION)
```

Real examples:
- `TRIICKSTR_DEMON_SLAYER_MOD\GameResources\actors\oni\walk_0.png`
- `TRIICKSTR_DEMON_SLAYER_MOD\GameResources\actors\races\items\w_firesword\w_firesword.png` + `sprites.json`
- `TRIICKSTR_DEMON_SLAYER_MOD\GameResources\effects\ds_fire\tile000.png` + `sprites.json`
- `TRIICKSTR_DEMON_SLAYER_MOD\GameResources\ui\Icons\iconOni.png`
- `AGRICHE_GODZILLA\GameResources\ui\Icons\godzilla\godzilla_tab.png`
- `SCPBOX_MOD\GameResources\actors\scp\Scp001\...`, `...\buildings\...`, `...\ui\...`

### 6b. How code loads them

**Path string in the asset, resolved by the game.** The asset stores a *resource path*, not a file:
```csharp
trait.path_icon = "ui/Icons/iconOni";      // Traits.cs:46,51  → GameResources\ui\Icons\iconOni.png
scythe.path_icon = "ui/Icons/items/icon_" + weapon.id;   // Items.cs:101
```
Explicit loaders:
```csharp
SpriteTextureLoader.getSprite("ui/Icons/" + path)                       // AGRICHE_GODZILLA\Code\Powers.cs:118
SpriteTextureLoader.getSpriteList("effects/" + texture)                 // TRIICKSTR_DEMON_SLAYER_MOD\Code\Items.cs:58
SpriteTextureLoader.getSpriteList(weapon.path_gameplay_sprite)         // Items.cs:100
Resources.Load<Sprite>("ui/Icons/iconMyTrait")                          // mods load directly from Unity Resources
Sprites.LoadSprite($"{Main.ModFolder}/EmbededResources/UI/Icons/iconScpTab.png")  // SCPBOX_MOD\Code\ScpTab.cs:20
```
`NCMS.Utils.Sprites.LoadSprite(System.String path, Single offsetX = 0, Single offsetY = 0)` exists in the game assembly (`nml_all.txt:181-183`).

### 6c. The sprite loader with `.meta` support

`NeoModLoader.utils.SpriteLoadUtils` (`nml_all.txt:3256-3269`) — this is what resolves mod `GameResources` paths and reads Unity `.meta` files for pivot/border/PPU:
```
METHOD public static UnityEngine.Sprite LoadSingleSprite(System.String path)
METHOD public static UnityEngine.Sprite[] LoadSprites(System.String path)
METHOD private static NeoModLoader.utils.SpriteLoadUtils/NCMSSpritesSettings/SpecificSetting searchUpNCMSSetting(System.String path)
METHOD private static UnityEngine.Sprite loadSpriteSimply(System.String path)
METHOD private static UnityEngine.Sprite[] loadSpriteWithMeta(System.String path, NeoModLoader.utils.TextureImporter textureImporter)
METHOD private static NeoModLoader.utils.TextureImporter loadMeta(System.String path)
```
`SpecificSetting` fields: `Alias, BorderB, BorderL, BorderR, BorderT, Path, PivotX, PivotY, PixelsPerUnit, RectH, RectW, RectX, RectY` — i.e. a `sprites.json`/`meta` file can set pivot & border per sheet.

### 6d. `sprites.json`

Each sprite folder in `GameResources` may carry a `sprites.json` listing the frames (seen on every `actors\races\items\*` and `effects\*` folder of DEMON_SLAYER). NML's `loadSpriteWithMeta` + `TextureImporter` handles the Unity meta side.

---

## 7. Harmony

### 7a. Where it comes from

`0Harmony.dll` (205,824 B) lives in **`worldbox_Data\StreamingAssets\mods\NML\Assemblies\0Harmony.dll`** and is *also* embedded in NML as `NeoModLoader.resources.assemblies.0Harmony.dll`. NML's string literal `0Harmony` (offset 542522) is the `mod_inc_path` map key that maps the assembly name → the file NML adds as a compile reference and later loads at runtime.
**No mod ships its own `0Harmony.dll`** — none of the 17 mod folders contains one.

### 7b. Idioms in use

**Attribute + `PatchAll()`** (6 mods) — `AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS\Code\Main.cs:28-29`:
```csharp
_harmony = new Harmony("AvbCCC");
_harmony.PatchAll();
```
with the patch class declared next to the entry point (`Main.cs:53-55`):
```csharp
[HarmonyPatch(typeof(StatsRowsContainer), "showStatRow")]
public class subspeciesTest{
    static bool Prefix(StatsRowsContainer __instance, ref KeyValueField __result, string pId, object pValue, string pColor, MetaType pMetaType = MetaType.None, long pMetaId = -1L, bool pColorText = false, string pIconPath = null, string pTooltipId = null, TooltipDataGetter pTooltipData = null, bool pLocalize = true){
```

**Explicit `AccessTools.Method` + named prefix/postfix** (manual patches) — `TRIICKSTR_DEMON_SLAYER_MOD\Code\Patches.cs:9-34`:
```csharp
public static void init()
{
    Main.harmony.Patch(
    AccessTools.Method(typeof(Actor), "takeItems"),
    prefix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(NoTakeweap))));

    Main.harmony.Patch(
    AccessTools.Method(typeof(City), "giveItem"),
    prefix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(keepSwordArmory))));

    Main.harmony.Patch(
    AccessTools.Method(typeof(ItemCrafting), "craftItem"),
    prefix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(keepSwordCrafting))));

    Main.harmony.Patch(
    AccessTools.Method(typeof(Item), "getDamaged"),
    prefix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(noDurability))));

    Main.harmony.Patch(
    AccessTools.Method(typeof(Actor), "isImmuneToFire"),
    postfix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(fireFix))));

    Main.harmony.Patch(
    AccessTools.Method(typeof(Actor), "addForce"),
    prefix: new HarmonyMethod(AccessTools.Method(typeof(Patches), nameof(knockbackFix))));
}
```
And `TRIICKSTR_SELECTIVE_BREEDING\Code\Breeding.cs:20-22`:
```csharp
Main.harmony.Patch(
AccessTools.Method(typeof(BabyHelper), "traitsInherit"),
postfix: new HarmonyMethod(AccessTools.Method(typeof(Breeding), nameof(newBABIES))));
```

**Per-patch isolation** — `SCPBOX_MOD\Code\Main.cs:79-93` (see §3e).

**Harmony instance** is always a static field on the mod's entry class, keyed by a stable id string:
`internal const string id = "triickstr.mods.worldbox.demonslayer";` (`Main.cs:10`), `new Harmony("AvbCCC")`, `new Harmony("scpbox.mod")`, `new Harmony("GodzillaMod")`.

### 7c. Per-mod Harmony density

| Mod | `[HarmonyPatch]` | `new Harmony(` | `PatchAll` |
|---|---|---|---|
| CORE4777_COREBOX | 107 | 2 | 2 |
| _VILTRUM_EMPIRE | 61 | 2 | 2 |
| AVOIDINGBOREDOM_ULTRA_TRAIT_PACK | 53 | 1 | 1 |
| TURBO_SAKUGA | 46 | 1 | 0 |
| AVOIDINGBOREDOM_EXPANDED_ARMORY | 20 | 1 | 1 |
| SCPBOX_MOD | 18 | 1 | 0 |
| AVOIDINGBOREDOM_AESTHETIC | 13 | 1 | 1 |
| RAYTRACERX_SHINOBIBOX | 11 | 2 | 1 |
| AGRICHE_GODZILLA | 10 | 1 | 0 |
| TAYFIM_ABYSSFALL | 7 | 1 | 2 |
| TRIICKSTR_SELECTIVE_BREEDING | 0 | 1 | 0 (manual) |
| TRIICKSTR_DEMON_SLAYER_MOD | 0 | 1 | 0 (manual) |
| TRIICKSTR_PLENTY_O_BIOMES | 0 | 1 | 0 |
| AHOYOS__KEYMASTERER… | 0 | 1 | 0 |
| KIVEN_CHEN_CLANSUCCESSION | 0 | 2 | 0 |
| INVASION_SUMMONER | 0 | 8 | 0 |

---

## 8. Failure modes — the real ones

### 8a. Hard evidence: 5 of 17 mods are **disabled** in NML

`worldbox_Data\StreamingAssets\mods\NML\mod_compile_records.json` (top-level object keyed by mod id):

| Mod id | `disabled` | `dependencies` |
|---|---|---|
| AGRICHE_GODZILLA | **false** | |
| AHOYOS__KEYMASTERER__IFAILEDLIFE__DON_NIKON_POWERBOX | **false** | |
| AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS | **false** | |
| AVOIDINGBOREDOM_AVB_S_EXPANDED_ARMORY | **false** | |
| AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK | **false** | |
| CORE4777_COREBOX | **false** | |
| KIVEN_CHEN_CLANSUCCESSION | **false** | |
| RAYTRACERX_SHINOBIBOX | **false** | |
| TAYFIM_ABYSSFALL | **false** | |
| TRIICKSTR_SELECTIVE_BREEDING | **false** | |
| TURBO_SAKUGA | **false** | |
| _VILTRUM_EMPIRE | **false** | |
| **INVASION_SUMMONER** | **true** | |
| **SCPBOX_MOD** | **true** | |
| **TRIICKSTR_DEMON_SLAYER_MOD** | **true** | `TRIICKSTR_PLENTY_O_BIOMES` |
| **TRIICKSTR_PLENTY_O_BIOMES** | **true** | |
| **MARKAMI_5286_TRAITBOX** | **true** | |

Note: **all of them still have a compiled DLL in `NML\CompiledMods\`** — compilation succeeded; the *load* was gated.

### 8b. Failure mode #1 — missing `mod.json` ⇒ never compiles

`...\Mods\traitbox\` contains **only** `TraitBox\GameResources\ui\Icons\desktop.ini` (86 bytes). **No `mod.json`, no `Code/`.**
NML's literal: `"No mod.json file for folder "` + `" in Mods"` (offset 547860). The folder is skipped entirely. `MARKAMI_5286_TRAITBOX.dll` in `CompiledMods\` is a **stale artifact from a previous install** (compile timestamp `639189999210375615` ≈ 2025-12-21, versus the `639275831…` batch ≈ 2026-04-04 for everything else).
→ **Lesson: the folder name in `Mods/` is irrelevant; `mod.json` is what registers the mod.**

### 8c. Failure mode #2 — stale `targetGameBuild` ⇒ mod refuses to load

`INVASION_SUMMONER\mod.json` has `"targetGameBuild": 115` while every other current mod has `719`. It is the only mod with `115` and it is **disabled**. `AGRICHE_GODZILLA`, `TURBO_SAKUGA` and the rest all declare `719`.
→ **Lesson: bump `targetGameBuild` whenever the game updates, or the mod silently never loads.**

### 8d. Failure mode #3 — unsatisfied dependency ⇒ mod never loads

`TRIICKSTR_DEMON_SLAYER_MOD\mod.json` declares `"Dependencies": ["TRIICKSTR_PLENTY_O_BIOMES"]`, and `TRIICKSTR_PLENTY_O_BIOMES` is itself `disabled: true` → the dependent is blocked (NML: `doesModNeedRecompile(pModDeclare, pDependencies, pOptionalDependencies)`, `nml_all.txt:3018`).
Verified: `grep -i "plenty|PoB|Biomes"` across the whole `TRIICKSTR_DEMON_SLAYER_MOD` folder matches **only `mod.json`** — the *code* has no dependency on that mod at all. The dependency declaration alone is what blocks it.

### 8e. Failure mode #4 — one bad asset aborts the whole mod

`INVASION_SUMMONER`'s own changelog (in `mod.json`) documents this exact class of bug:
> *"DungeonTick handled the dungeons hardest-first in one loop, and an error in any dungeon stopped the loop, so the dungeons at the end of the list (the E rank ones) never reached their 'break after N years' … Every dungeon is now processed on its own inside a try/catch"*
and
> *"Circuit breaker: any mod task that takes over 250 ms in a frame is slowed down and, if it keeps happening (3 times, or once over 2 s), switched OFF for the session with a [Perf] line in the log, so one runaway task can no longer freeze the game."*

### 8f. Failure mode #5 — defensive code actually present in the wild

| Pattern | Where | Quote |
|---|---|---|
| Stage isolation | `SCPBOX_MOD\Code\Main.cs:68-72` | `try { pAction(); } catch (Exception e) { ScpUtils.Error($"stage '{pName}' failed: {e}"); }` |
| Per-patch isolation + counter | `SCPBOX_MOD\Code\Main.cs:79-93` | `ScpUtils.Log($"harmony: {applied} applied, {failed} failed");` |
| Idempotent asset registration | `SCPBOX_MOD\Code\ScpTraits.cs:117-118` | `ActorTrait existing = AssetManager.traits.get(pId); if (existing != null) return existing;` |
| Null-guard on the asset manager | `_VILTRUM_EMPIRE\Code\CustomTraitSafetySystem.cs:248-249` | `if (AssetManager.traits == null) return;` |
| Localize **before** register | `_VILTRUM_EMPIRE\Code\AbilityEvolutionSystem.cs:279-281` | `// Install every alias first so registration never emits a missing-text warning.` |
| Try/catch inside every power action | `AGRICHE_GODZILLA\Code\Powers.cs:103-111` | `catch (Exception e) { Debug.LogError("[Godzilla] " + id + ": " + e); return false; }` |
| World-changed detector | `SCPBOX_MOD\Code\Main.cs:139-155` | `try { now = World.world.getCurWorldTime(); } catch (Exception) { return; }` |
| Gate on game loaded | `SCPBOX_MOD\Code\Main.cs:107` | `if (!Config.game_loaded \|\| !ScpUtils.WorldReady()) return;` |
| Config read/write guards | `SCPBOX_MOD\Code\ModSettings.cs:78-81, 90-93` | `catch (Exception e) { ScpUtils.Warn($"could not read mod_settings.json: {e.Message}"); }` |
| Config fallback values | `TRIICKSTR_DEMON_SLAYER_MOD\Code\Main.cs:51-57` | `return items.TryGetValue(id, out ModConfigItem item) ? item.BoolVal : fallback;` |
| Framework null guards | `TRIICKSTR_SELECTIVE_BREEDING\Code\Breeding.cs:28-30, 36-38` | `if(pActorTarget == null){ return; }` |
| Perf guard | `INVASION_SUMMONER\Code\*.cs` (176 try / 164 catch) | — |
| "Game ready" gate before touching assets | `SCPBOX_MOD\Code\Main.cs:107-113` | `_factionsReady` latch |

### 8g. "Mod compat scanner"

There is **no** generic cross-mod compatibility scanner in the installed set. What exists:
- **Per-mod foreign-mod checks.** `AHOYOS__KEYMASTERER__IFAILEDLIFE__DON_NIKON_POWERBOX\Code\PowerBox.cs` contains an explicit *"CollectionMod compatibility"* region that tests for another mod's assets before touching them.
- **NML's own dependency resolver** (`ModDependencyNode`, `prepareCompile`, `doesModNeedRecompile`) — this is the *real* compat layer.
- **`_VILTRUM_EMPIRE\Code\CustomTraitSafetySystem.cs`** — a self-check that re-scans `AssetManager.traits` and repairs `can_be_given` / `can_be_removed` / `unlock(true)` on every custom trait, counting `EditorAvailableTraitCount`.
- **External-mod compat shim:** `TURBO_SAKUGA\Code\Compat\Worldfall3D.cs` (242 lines) — a dedicated compatibility module for the *Worldfall3D* mod.

---

## 9. Save / load persistence

Four distinct mechanisms observed:

### 9a. `mod_settings.json` in the mod folder (hand-rolled)

`SCPBOX_MOD\mod_settings.json` exists on disk (verified). Writer: `SCPBOX_MOD\Code\ModSettings.cs:67-94`:
```csharp
private static string ConfigPath => Path.Combine(Main.ModFolder, "mod_settings.json");

public static void Load()
{
    try
    {
        string path = ConfigPath;
        if (!File.Exists(path)) return;
        SettingsData loaded = JsonConvert.DeserializeObject<SettingsData>(File.ReadAllText(path));
        if (loaded != null) Data = loaded;
    }
    catch (Exception e)
    {
        ScpUtils.Warn($"could not read mod_settings.json: {e.Message}");
    }
}

public static void Save()
{
    try
    {
        File.WriteAllText(ConfigPath, JsonConvert.SerializeObject(Data, Formatting.Indented));
    }
    catch (Exception e)
    {
        ScpUtils.Warn($"could not write mod_settings.json: {e.Message}");
    }
}
```
Data class `SCPBOX_MOD\Code\ModSettings.cs:8-20` (`SettingsData` with bools + tuning floats/ints).

### 9b. NML `ModConfig` → `mods_config\<ModId>.config`

`%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\` contains:
`Triickstr.PlentyoBiomes.config` (3,029 B) · `CoreBoxWorld.json` · `CoreBoxTerritoryNames.json` (and other mod configs).
NML writes `<ModId>.config` here; the mod reads it via `GetConfig()` inside `OnModLoad()`:
`TRIICKSTR_DEMON_SLAYER_MOD\Code\Main.cs:16` → `DSConfig.init(GetConfig());`
then flattens groups into a lookup (`Main.cs:40-49`):
```csharp
foreach(string group in new string[]{"Swords", "Ranks", "Rank stats", "Oni"}){
    foreach(KeyValuePair<string, ModConfigItem> item in config[group]){
        items[item.Key] = item.Value;
    }
}
```
The **schema** comes from `<mod>\default_config.json` (NML literal `default_config.json`). Verbatim, `...\AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS\default_config.json`:
```json
{
  "aaa_config": [
    {
      "Id": "config_unevo",
      "Type": "SWITCH",
      "IconPath": "ui/Icons/iconFoxNew",
      "BoolVal": true,
      "Callback": "Configs:TurnOffUnevoColor"
    },
    {
      "Id": "config_evo",
      "Type": "SWITCH",
      "IconPath": "ui/Icons/civ_foxNew",
      "BoolVal": false,
      "Callback": "Configs:TurnOffEvoColor"
    },
    {
      "Id": "config_phenoSort",
      "Type": "SWITCH",
      "IconPath": "ui/Icons/iconPhenoSort",
      "BoolVal": true,
      "Callback": "Configs:SortPheno"
    },
    {
      "Id": "config_phenoPlates",
      "Type": "SWITCH",
      "IconPath": "ui/Icons/phenoPlates",
      "BoolVal": false,
      "Callback": "Configs:CheckPhenoNameplates"
    },
    {
      "Id": "config_genDimensions",
      "Type": "SWITCH",
      "IconPath": "ui/Icons/iconSizeInfo",
      "BoolVal": false,
      "Callback": "Configs:CheckMapSizeInfo"
    }
  ]
}
```
`TRIICKSTR_DEMON_SLAYER_MOD\default_config.json` uses the same shape but with `"Type": "SWITCH", "BoolVal": true` and group `"Swords"` / `"Ranks"` / `"Rank stats"` / `"Oni"`.
NML also supports non-SWITCH types and a `Callback` of the form `"Type:Method"` (resolved by `nml_all.txt:3011` region + `Callback`/`Type` literals at offsets 541952/541978).

### 9c. Save-folder-local state

`%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\`:
- `mods_config\` — as above
- `ClanSuccession\houses.txt` — `KIVEN_CHEN_CLANSUCCESSION` persists clan state next to the save
- `ViltrumEmpire\SystemUI.state` — `_VILTRUM_EMPIRE` UI state
- `autosaves\<saveId>\viltrum_ai_command.json` — per-world AI state (this **is** the "persist across world saves" pattern)

### 9d. In-world save hook

`AGRICHE_GODZILLA\Code\Persist.cs` (184 lines) is a dedicated persistence module; `Code\Settings.cs` (74 lines) holds runtime settings.

---

## 10. Scale

| Mod folder | .cs files | .cs LOC | Total files | Verdict |
|---|---:|---:|---:|---|
| TRIICKSTR_SELECTIVE_BREEDING | 2 | **62** | 4 | **smallest** — skeleton only |
| TRIICKSTR_DEMON_SLAYER_MOD | 7 | **880** | 517 | **best small complete template** |
| AVOIDINGBOREDOM_AVB_S_AESTHETIC_ADJUSTMENTS | 7 | 1,225 | 337 | small, edits-only |
| INVASION_SUMMONER | 13 | 7,001 | 14 | medium, no assets |
| AGRICHE_GODZILLA | 20 | 7,381 | 5,712 | medium |
| AVOIDINGBOREDOM_AVB_S_EXPANDED_ARMORY | 11 | 7,428 | 611 | medium |
| SCPBOX_MOD | 23 | 6,921 | 216 | medium, best-structured |
| RAYTRACERX_SHINOBIBOX | 30 | 10,341 | 1,066 | large |
| TRIICKSTR_PLENTY_O_BIOMES | 44 | 11,145 | 9,122 | large |
| KIVEN_CHEN_CLANSUCCESSION | 28 | 14,195 | 96 | large, code-dense |
| AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK | 19 | 9,556 | 393 | medium |
| TAYFIM_ABYSSFALL | 65 | 25,211 | 752 | large |
| CORE4777_COREBOX | 176 | 25,574 | 278 | huge |
| _VILTRUM_EMPIRE | 167 | 83,283 | 1,616 | huge |
| TURBO_SAKUGA | 303 | 196,715 | 959 | huge |
| AHOYOS__KEYMASTERER__IFAILEDLIFE__DON_NIKON_POWERBOX | 112 | 3,102 | 794 | odd: many tiny files |
| AdeptusAstartes | 31 | 38,400 | 1,420 | **masterpiece** — multi-part boss rigs, smears, auras |
| SUPERPOWERS___WORLDBOX_MODDER_ONEPUNCHMAN_COSMICFEAR | 20 | 14,800 | 850 | **top tier** — custom animated directional sprites, projectiles |
| traitbox | 0 | 0 | 3 | **broken — no mod.json** |

**Good templates:** `TRIICKSTR_SELECTIVE_BREEDING` (skeleton) → `TRIICKSTR_DEMON_SLAYER_MOD` (complete small) → `SCPBOX_MOD` (clean modular structure) → `AdeptusAstartes` & `TURBO_SAKUGA` (studio-grade combat, visuals & resilience).

---

## 11. Modern Studio-Grade Architectural Patterns (October 2026 Additions)

Deep inspection of `AdeptusAstartes`, `TURBO_SAKUGA` (Combat Gods), `SUPERPOWERS___WORLDBOX_MODDER_ONEPUNCHMAN_COSMICFEAR`, `ShinobiBox: Reborn`, and `Godzilla` reveals the engineering practices that elevate community mods from simple stat tweaks to professional game-studio-tier expansions.

### 11a. Resilient Subsystem Bootstrapping (`Step` Pattern)

Amateur mods put all registration calls in a single monolithic `OnModLoad()` or `Awake()` method. If a single item, icon, or trait fails due to a missing asset or API update, an unhandled exception immediately halts mod loading, leaving the entire mod broken.

**The Professional Pattern (`AdeptusAstartes/Code/AstartesMod.cs`):**
```csharp
protected override void OnModLoad()
{
    Step("settings", Settings.Reload);
    Step("factions", Factions.Register);
    Step("weapons", Weapons.Register);
    Step("items", Items.Register);
    Step("traits", Traits.Register);
    Step("effects", Fx.Register);
    Step("smears", W40kSmears.Init);
    Step("combat engine", W40kCombatEngine.Init);
    Step("auras", W40kAuras.Init);
    Step("titan", Titan.Register);
    Step("units", Units.Register);
    Step("powers", Powers.Register);
    Step("tab", Powers.AddTab);
    Step("locales", Locales.Refresh);
    PatchEach(new Harmony("turbo.adeptus_astartes"));
}

private void Step(string what, Action action)
{
    try { action(); }
    catch (Exception e) { LogError(what + " failed: " + e); }
}
```
**Benefits:** Every subsystem initializes in its own protected scope. If one weapon or trait has an error, the remaining 95% of the mod functions smoothly and logs clear diagnostics to `Player.log`.

### 11b. Granular Harmony Patching (`PatchEach` vs `PatchAll`)

Calling `harmony.PatchAll()` is an all-or-nothing risk: if the game updates and changes the signature of even one patched method, `PatchAll()` throws an unhandled exception and aborts all other patches in the mod.

**The Professional Pattern (`AstartesMod.cs`):**
```csharp
private void PatchEach(Harmony harmony)
{
    foreach (Type t in AccessTools.GetTypesFromAssembly(typeof(AstartesMod).Assembly))
    {
        if (t.GetCustomAttributes(typeof(HarmonyPatch), false).Length == 0) continue;
        try
        {
            harmony.CreateClassProcessor(t).Patch();
        }
        catch (Exception e)
        {
            LogError("patch " + t.Name + " failed: " + e);
        }
    }
}
```
**Benefits:** Decouples patch application. If a minor UI tooltip patch breaks on a game patch, the combat and unit patches remain active.

### 11c. World Lifecycle & Memory Guarding (`clearWorld`)

VFX in flight, custom camera zooms, hit-stops, and tracked GameObjects must never leak across world saves or map regenerations.

**The Professional Pattern:**
```csharp
[HarmonyPatch(typeof(MapBox), nameof(MapBox.clearWorld))]
internal static class ClearWorldPatch
{
    public static void Postfix()
    {
        Fx.ClearAll();
        W40kSmears.Clear();
        HitStop.Clear();
        Targeting.Reset();
    }
}
```
Hooking `MapBox.clearWorld` ensures zero ghost projectiles, orphaned sprite transforms, or memory leaks when the player generates a new world or returns to the menu.

### 11d. Game Feel & "Juice" (Hit-Stop, Camera Shakes, Smears)

What makes combat feel weighty and satisfying in mods like `TURBO_SAKUGA` and `AdeptusAstartes` is procedural animation feedback:
1. **Hit-Stop (`HitStop.cs`):** Freezes world simulation for 0.05–0.15s on critical impacts (`Time.unscaledDeltaTime` countdown) so the player registers the visual "impact frame".
2. **Camera Shake (`Wreck.Shake` / `World.world.startShake`):** Scaled inversely with orthographic camera size so zoomed-in players feel localized impacts without disorienting zoomed-out views.
3. **Procedural Weapon Smears (`W40kSmears.cs`):** Generates dynamic trail meshes or directional slash sprites connecting the attacker's weapon transform to the target.

### 11e. Multi-Part Boss Rigs & Transform Synchronization

WorldBox units are normally single sprites. For gargantuan units like the Imperator Titan or Godzilla:
- The base unit handles movement, pathfinding, and health stats.
- Attached sub-elements (arms, turrets, shoulders, shadow offsets) are managed as child GameObjects or updated synchronously in `LateUpdate()` via `Fx.FollowTitanRigs()` after WorldBox positions its actor transform.

### 11f. Direct Audio Playback via FMOD Core (`PlayWavDirectly`)

WorldBox uses FMOD Studio. Traditional audio mods required authoring and compiling FMOD `.bank` files with FMOD Studio. `ShinobiBox` introduces a clean alternative using FMOD's core API:
```csharp
var result = RuntimeManager.StudioSystem.getCoreSystem(out FMOD.System fmodSystem);
fmodSystem.createSound(filePath, MODE._3D | MODE._3D_LINEARROLLOFF, out FMOD.Sound sound);
fmodSystem.playSound(sound, masterChannelGroup, false, out Channel channel);
```
Mod authors can ship standard `.wav` files directly in their mod folders and play spatialized 3D positional sound effects at zero licensing or external toolchain cost.

### 11g. Custom Resource Pools & BaseStats Registration

Rather than hacking actor variables, `ShinobiBox` registers native `BaseStatAsset` instances directly into `AssetManager.base_stats_library`:
```csharp
AssetManager.base_stats_library.add(new BaseStatAsset
{
    id = "chakra",
    icon = "ui/icons/staticon",
    normalize = true,
    normalize_min = 0f,
    sort_rank = 895,
    translation_key = "chakra"
});
```
This enables traits to modify the stat directly (`trait.base_stats["chakra"] = 100f`), seamlessly displaying within the unit's native stats breakdown.
