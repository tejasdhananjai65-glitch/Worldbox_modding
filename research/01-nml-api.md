# NeoModLoader (NML) — API Reference for WorldBox Mod Authors

**Target game:** WorldBox (Unity/Mono, IL2CPP-free managed build), installed at
`C:\Program Files (x86)\Steam\steamapps\common\WorldBox`

**Provenance of this document.** Every claim below is backed by one of:

| Evidence | Location |
|---|---|
| **E1** | The installed loader itself: `worldbox_Data\StreamingAssets\mods\NeoModLoader.dll` (22,417,408 bytes) — read via Mono.Cecil metadata + IL disassembly (no execution). |
| **E2** | `worldbox_Data\StreamingAssets\mods\NML\` (loader support folder: `commit`, `tab_order_records.json`, `mod_compile_records.json`, `Assemblies\`, `Assembly-CSharp-Publicized.dll`). |
| **E3** | 17 real installed mods under `<Game>\Mods\` (source + `mod.json` + `Locales\` + `default_config.json`). |
| **E4** | Game code `worldbox_Data\Managed\Assembly-CSharp.dll` (Cecil metadata + IL). |
| **E5** | Upstream source `github.com/WorldBoxOpenMods/ModLoader` (master `36a891b5dcd0`, and pinned commit `02266fe8185d940c4065185de0a117c18975cf09` = the hash in `NML\commit`). Wiki: `github.com/WorldBoxOpenMods/ModLoader/wiki`. |
| **E6** | Live runtime log `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`. |

> **Version caveat (important).** `NML\commit` says `02266fe8185d940c4065185de0a117c18975cf09` (dated 2024-10-02), but the **installed `NeoModLoader.dll` is newer than both that commit and upstream `master`** — it contains types absent from both (`NeoModLoader.utils.Builders.*`, `NeoModLoader.utils.SerializedAssets.*`, `NeoModLoader.api.ModConfig+SchemaEntries` style members). Treat **E1 (the installed DLL) as ground truth**; E5 is used to explain semantics. Where E1 and E5 disagree, E1 wins and the difference is called out.

---

## 0. The 10 facts that matter most

1. **A mod is a folder under `<Game>\Mods\` containing `mod.json` plus C# source.** `mod.json` is mandatory — NML logs `[NML]: No mod.json file for folder <path>` and skips the folder otherwise (E1, E6).
2. **NML compiles your `.cs` at runtime with Roslyn (C#), it does not require a prebuilt DLL.** Output goes to `StreamingAssets\mods\NML\CompiledMods\<UID>.dll` + `.pdb` (E1, E5).
3. **`.cs` files are found recursively anywhere in the mod folder** — `Code/` is a *convention*, not a requirement (E1: `SystemUtils.SearchFileRecursive` over `FolderPath`; E3: all 17 mods use `Code/`, but nothing enforces it).
4. **Compile references = every DLL in `worldbox_Data\Managed\` + every DLL in `NML\Assemblies\` + `NeoModLoader.dll` itself + `NML\Assembly-CSharp-Publicized.dll`.** You get `Assembly-CSharp`, `UnityEngine.*`, `Harmony (0Harmony)`, `Newtonsoft.Json`, `YAML`, `Mono.Cecil` for free (E1 `prepareCompile`, E5 `CreateCompileSessionContext`).
5. **Put a `*.dll` in the mod folder and compilation is skipped** — NML logs `<UID> detected as precompiled, compilation phase will be skipped on it!` and loads it directly (E1, E5).
6. **Your entry class must be a `MonoBehaviour` implementing `IMod`, or carry the NCMS `[ModEntry]` attribute.** The idiomatic base class is `NeoModLoader.api.BasicMod<T>` (E1, E5).
7. **Lifecycle order is `OnModLoad → Awake → OnEnable → Start → Update`** (documented in E5 `BasicMod.cs` XML doc comment; `OnLoad` calls `OnModLoad()` then `ModFeatureManager.InstantiateFeatures()`).
8. **Localization = `Locales\<language>.json`, a flat `{"key":"value"}` map.** NML auto-loads every file in `Locales/` at mod load; the filename (minus extension) is the language code (E1, E5, E3 `CoreBox\Locales\*.json`, E5 wiki `Mod制作教程3-语言文件.md`).
9. **Game lookup keys are snake_case of `typed_id + "_" + id`**: a trait `id = "ScpAnomaly"` → `trait_scp_anomaly`; a GodPower `id = "GodzillaControl"` → `godzilla_control` (description = `+ "_description"`) (E4 IL).
10. **Logs go to `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`**; NML prefixes everything with `[NML]: ` and mod-level logs with `[NML]: [YourModName]: ` (E6, E1 `BasicMod.LogInfo` IL).

---

## 1. Installation layout and the exact paths NML uses

From `NeoModLoader.constants.Paths` (E1, values reconstructed from the `.cctor` IL):

| Constant | Value (player build) |
|---|---|
| `Paths.GamePath` | `<Game>` = `C:\Program Files (x86)\Steam\steamapps\common\WorldBox` |
| `Paths.ManagedPath` | `<Game>\worldbox_Data\Managed` |
| `Paths.StreamingAssetsPath` | `<Game>\worldbox_Data\StreamingAssets` |
| `Paths.NMLModPath` | `StreamingAssets\mods\NeoModLoader.dll` (this assembly's own location) |
| `Paths.NMLPath` | `StreamingAssets\mods\NML` |
| `Paths.NMLCommitPath` | `StreamingAssets\mods\NML\commit` |
| `Paths.NMLAssembliesPath` | `StreamingAssets\mods\NML\Assemblies` |
| `Paths.PublicizedAssemblyPath` | `StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll` |
| `Paths.CompiledModsPath` | `StreamingAssets\mods\NML\CompiledMods` |
| `Paths.ModsPath` | `<Game>\Mods` |
| `Paths.NativeModsPath` | `StreamingAssets\mods` |
| `Paths.PersistentDataPath` | `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox` (`Application.persistentDataPath`) |
| `Paths.ModsConfigPath` | `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config` |
| `Paths.CommonModsWorkshopPath` | `<Game>\..\..\workshop\content\1206560` (Steam Workshop app id `1206560`) |
| `Paths.TabOrderRecordPath` | `StreamingAssets\mods\NML\tab_order_records.json` |
| `Paths.ModCompileRecordPath` | `StreamingAssets\mods\NML\mod_compile_records.json` |
| `Paths.ModsDisabledRecordPath` | `StreamingAssets\mods\NML\disabled_mods.txt` |
| `Paths.ModDeclarationFileName` | `mod.json` |
| `Paths.ModDefaultConfigFileName` | `default_config.json` |
| `Paths.ModResourceFolderName` | `GameResources` (player build; editor build uses `Resources`) |
| `Paths.NCMSAdditionModResourceFolderName` | `GameResourcesReplace` |
| `Paths.ModAssetBundleFolderName` | `AssetBundles` |
| `Paths.NCMSModEmbededResourceFolderName` | `EmbededResources` |
| `Paths.IgnoreSearchDirectories` | `bin`, `obj`, `Properties`, `packages`, `packages.config`, `packages-lock.json`, `packages-lock.xml` |

Observed on this machine (E2):
```
StreamingAssets\mods\
  NeoModLoader.dll
  NML\
    commit                      -> 02266fe8185d940c4065185de0a117c18975cf09
    Assembly-CSharp-Publicized.dll
    Assemblies\                 -> 0Harmony.dll, Microsoft.CodeAnalysis*.dll, Mono.Cecil.dll,
                                    MonoMod.*.dll, YamlDotNet.dll, Facepunch.Steamworks.*.dll,
                                    Gameloop.Vdf.dll, System.*.dll
    CompiledMods\               -> <UID>.dll + <UID>.pdb per compiled mod
    mod_compile_records.json
    tab_order_records.json
```

---

## 2. `mod.json` schema

Parsed by `NeoModLoader.api.ModDeclare` (E1; source E5 `api/ModDeclare.cs`) via
`JsonConvert.DeserializeObject<ModDeclare>(File.ReadAllText(path))` — Newtonsoft, so **unknown keys are silently ignored** and property names match **case-insensitively**. The one exception is `GUID`, which is bound by an explicit `[JsonProperty("GUID")]` attribute.

| JSON key | .NET property | Type | Required? | What NML does with it |
|---|---|---|---|---|
| `name` | `Name` | string | **Yes in practice** | Display name. Used in the log prefix `[NML]: [<name>]: …`, in the mod-list UI, as the fallback UID source, and as the namespace of the generated `<Name>.GlobalObject.cs`. |
| `GUID` | `UID` | string | No | **The mod's identity.** Normalised (see below) and used as: compiled DLL/PDB file name, key in `mod_compile_records.json`, dependency identifier, duplicate-mod detection key. If absent → `Author + "." + Name`, normalised. |
| `author` | `Author` | string | Recommended | Part of the UID fallback (`Author.Name`). |
| `version` | `Version` | string | Recommended | Shown in the mod list; part of the workshop metadata. |
| `description` | `Description` | string | Optional | Shown in the mod list. |
| `iconPath` | `IconPath` | string | Optional | Path **relative to the mod folder**, e.g. `"icon.png"`. |
| `RepoUrl` | `RepoUrl` | string | Optional | Link opened by the mod list; falls back to `CoreConstants.OrgURL` (`NeoModLoader.General.GetUrl()`). |
| `Dependencies` | `Dependencies` | string[] | Optional | **Required** mods — the mod will not load without them. Values are other mods' UIDs. |
| `OptionalDependencies` | `OptionalDependencies` | string[] | Optional | Optional mods; if present they are enabled first and are exposed as C# **preprocessor symbols**. |
| `IncompatibleWith` | `IncompatibleWith` | string[] | Optional | Mods that must not be loaded together. |
| `targetGameBuild` | `TargetGameBuild` | int | **Ignored by NML** | `ModDeclare`'s file constructor never copies this field, so it stays `0`. Only the NCMS-compat layer (`NCMSCompatibleLayer.GenerateNCMSMod`) reads it. **Do not rely on it.** |
| `ModType` | `ModType` | `ModTypeEnum` | Optional | `NEOMOD=0`, `COMPILED_NEOMOD=1`, `BEPINEX=2`, `RESOURCE_PACK=3`. Normally set by NML itself (a folder containing `*.dll` becomes `COMPILED_NEOMOD`). |
| `UsePublicizedAssembly` | `UsePublicizedAssembly` | bool | Optional, **default `true`** | When true, `NML\Assembly-CSharp-Publicized.dll` is added as a compile reference in addition to the normal `Assembly-CSharp.dll`. This is what lets you patch private members via Harmony. |

**UID normalisation.** After reading the JSON, NML runs the UID through
`ModDependencyUtils.ParseDepenNameToPreprocessSymbol` (E1 IL): characters that are letters/digits are **upper-cased**; everything else becomes `_`.
So `"ScpBox.mod"` → `SCPBOX_MOD`, `"_VILTRUM_EMPIRE"` → `_VILTRUM_EMPIRE`.
If no `GUID` is supplied the fallback `Author + "." + Name` is normalised the same way, e.g. `"Core4777" + "." + "CoreBox"` → `CORE4777_COREBOX`.

**Verified against every installed mod** (E3 × `mod_compile_records.json` E2) — the recorded `mod_id` equals the normalised `GUID` when present, otherwise the normalised `Author.Name`. Examples:

| Mod folder | `mod.json` `GUID` | `mod.json` `author` + `name` | recorded `mod_id` |
|---|---|---|---|
| `SCPBOX_MOD` | `ScpBox.mod` | `MarKami#5286` + `ScpBox` | `SCPBOX_MOD` |
| `_VILTRUM_EMPIRE` | `_VILTRUM_EMPIRE` | `SonOfViltrum` + `Viltrum Empire` | `_VILTRUM_EMPIRE` |
| `CORE4777_COREBOX` | *(none)* | `Core4777` + `CoreBox` | `CORE4777_COREBOX` |
| `TAYFIM_ABYSSFALL` | *(none)* | `Tayfim` + `Abyssfall` | `TAYFIM_ABYSSFALL` |
| `AGRICHE_GODZILLA` | `AGRICHE_GODZILLA` | `Agriche` + `Godzilla` | `AGRICHE_GODZILLA` |

> ⚠️ **Do not put a `GUID` that differs from your folder name unless you intend to rename the compiled DLL.** NML's "duplicate mod" detection and its dependency system both key on the normalised UID.

**Minimal working `mod.json`:**
```json
{
  "name": "MyMod",
  "author": "Me",
  "version": "1.0.0",
  "description": "Does a thing.",
  "iconPath": "icon.png",
  "GUID": "MY_MOD"
}
```

**Real examples** (E3):
```json
// Mods\SCPBOX_MOD\mod.json
{ "name": "ScpBox", "author": "MarKami#5286", "version": "2.0.0",
  "description": "This mod adds Scp to WorldBox!", "iconPath": "icon.png", "GUID": "ScpBox.mod" }

// Mods\TAYFIM_ABYSSFALL\mod.json
{ "name": "Abyssfall", "author": "Tayfim", "version": "1.1.1",
  "description": "Abyssfall - a dark fantasy total conversion. ...",
  "iconPath": "icon.png", "targetGameBuild": 719 }

// Mods\_VILTRUM_EMPIRE\mod.json  (note capital "IconPath" — matching is case-insensitive)
{ "name": "Viltrum Empire", "author": "SonOfViltrum", "version": "4.0.20",
  "GUID": "_VILTRUM_EMPIRE", "IconPath": "icon.png",
  "Dependencies": [], "OptionalDependencies": [] }
```

---

## 3. Folder layout conventions

NML scans the mod folder recursively; only these sub-folders have special meaning.

| Folder / file | Exact casing | Purpose | Evidence |
|---|---|---|---|
| `mod.json` | lowercase | **Required.** Mod declaration. | E1 `Paths.ModDeclarationFileName`; E6 log |
| `Code/` | capital C | **Convention only.** All 17 installed mods put their `.cs` here, but NML compiles **every** `.cs` found anywhere under the mod folder. | E1 `SearchFileRecursive`; E3 |
| `Locales/` | capital L | Localisation files. Loaded automatically for any `IMod` that also implements `ILocalizable` (i.e. `BasicMod<T>`). Sub-folders are searched too. | E1 `BasicMod.GetLocaleFilesDirectory`; E5 `LoadLocales` |
| `GameResources/` | capital G | Game resource folder (player build). Editor builds use `Resources`. | E1 `Paths.ModResourceFolderName` |
| `GameResourcesReplace/` | capital G | Resource files that **replace** existing game resources. | E1 `Paths.NCMSAdditionModResourceFolderName` |
| `AssetBundles/` | capital A | Unity asset bundles. (**Note: not `Assets/`** — that name is only used by the *editor* build's `Paths.ModsPath`.) | E1 `Paths.ModAssetBundleFolderName` |
| `EmbededResources/` | capital E, **one `d`** | Files embedded into the compiled assembly as manifest resources (NCMS-compat mods). Accessed via the generated `EmbededResources.GetBytes(name)` / `EmbededResources.LoadSprite(...)`. Manifest resource name = `<ModName>.Resources.<relative path with `/` and `\` → `.>` | E1 `Paths.NCMSModEmbededResourceFolderName`; E5 `NCMSCompatibleLayer.modGlobalObject` |
| `Assemblies/` | capital A | **Not special.** Prebuilt DLLs are detected by a flat `Directory.GetFiles(FolderPath, "*.dll")` scan of the **mod root**, not `Assemblies/`. A DLL anywhere in the root switches the mod to `COMPILED_NEOMOD` and **skips compilation**. | E1 IL `compileMod`; E5 `ModCompileLoadService.cs:766` |
| `default_config.json` | lowercase | Default (schema) config for the mod's settings UI. | E1 `Paths.ModDefaultConfigFileName`; E3 `CORE4777_COREBOX\default_config.json` |
| `icon.png` | — | Mod-list icon, referenced by `iconPath`. | E3 |

**Directory names excluded from the `.cs` search** (E1 `Paths.IgnoreSearchDirectories`):
`bin`, `obj`, `Properties`, `packages`, `packages.config`, `packages-lock.json`, `packages-lock.xml`
(plus any directory starting with `.`). Master additionally honours `.gitignore` rules (E5 `GitIgnoreUtils.GetRuleSet`) — *not confirmed present in the installed build*.

### The generated `Mod` / `EmbededResources` classes

For mods detected as NCMS-compatible, NML injects a synthetic source file `<Name>.GlobalObject.cs` containing (E5 `NCMSCompatibleLayer.modGlobalObject`):

```csharp
internal class Mod {
    public static ModDeclaration.Info Info;
    public static GameObject GameObject;
    public static Action OnDebug;
    public static void Initialize(Button button) { ... }
}
public class EmbededResources {
    public static Sprite LoadSprite(string name, float pivotX = 0, float pivotY = 0, float pixelsPerUnit = 1f);
    public static byte[]  GetBytes(string name);   // Assembly.GetManifestResourceStream(name)
}
```

---

## 4. `NeoModLoader.api.BasicMod<T>` — the base class

`public abstract class BasicMod<T> : MonoBehaviour, IMod, ILocalizable, IConfigurable, IFeatureLoadManaged, IStagedLoad where T : BasicMod<T>` (E1).

### Full member list (E1, installed DLL)

| Member | Signature |
|---|---|
| `Instance` | `public static T Instance { get; private set; }` |
| `I` | `public static T I => Instance;` (shortcut) |
| `PrefabLibrary` | `public UnityEngine.Transform PrefabLibrary { get; }` — parent for `NewPrefab` objects; auto-creates a child `PrefabLibrary` |
| `ModFeatureManager` | `public virtual IModFeatureManager ModFeatureManager { get; private set; }` |
| `GetConfig()` | `public virtual ModConfig GetConfig()` |
| `GetLocaleFilesDirectory(ModDeclare)` | `public virtual string GetLocaleFilesDirectory(ModDeclare pModDeclare)` → `Path.Combine(pModDeclare.FolderPath, "Locales")` |
| `GetGameObject()` | `public virtual GameObject GetGameObject()` |
| `GetUrl()` | `public virtual string GetUrl()` → `RepoUrl` or `CoreConstants.OrgURL` |
| `OnLoad(ModDeclare, GameObject)` | `public virtual void OnLoad(ModDeclare pModDecl, GameObject pGameObject)` |
| `Init()` | `public virtual void Init()` → calls `ModFeatureManager.Init()` |
| `PostInit()` | `public virtual void PostInit()` → calls `ModFeatureManager.PostInit()` |
| `GetDeclaration()` | `public virtual ModDeclare GetDeclaration()` |
| `NewPrefab(string)` | `public static GameObject NewPrefab(string name)` |
| `OnModLoad()` | `protected abstract void OnModLoad()` — **you must override this** |
| `LogInfo(string)` | `public static void LogInfo(string message)` → `LogService.LogInfo($"[{Name}]: {message}")` |
| `LogWarning(string)` | `public static void LogWarning(string message)` |
| `LogError(string)` | `public static void LogError(string message)` |
| *(private)* `LoadConfig()` | builds the merged persistent + default `ModConfig` |

### Inherited helper behaviours

* **Config**: `LoadConfig()` reads `Paths.ModsConfigPath/<UID>.config` (persistent, e.g.
  `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\SCPBOX_MOD.config` — confirmed present on disk for `_VILTRUM_EMPIRE`, `KIVEN_CHEN_CLANSUCCESSION`, `Triickstr.PlentyoBiomes`), then merges the mod's `default_config.json` over it and applies callbacks.
* **Translations**: `Locales/` are loaded by NML before `OnLoad` (E5 `LoadLocales(main_component, pMod, false)` is called immediately before `mod_interface.OnLoad(...)`).
* **`GetDeclaration()`** gives you `Name`, `UID`, `Author`, `Version`, `Description`, `IconPath`, `FolderPath`, `Dependencies`, `OptionalDependencies`, `RepoUrl`.

### Minimal mod skeleton

```csharp
using NeoModLoader.api;
using UnityEngine;

public class Main : BasicMod<Main>
{
    protected override void OnModLoad()
    {
        LogInfo("hello from MyMod");
        // AssetManager.traits.add(myTrait);
    }
}
```

Real example (E3, `Mods\SCPBOX_MOD\Code\Main.cs`): `public class Main : BasicMod<Main>` with `[ModEntry]` on the class, calling `ScpTraits.Initialize()` etc. from `OnModLoad`.

---

## 5. Mod lifecycle — exact order

1. **NML scans** `<Game>\Mods\*` (and the Workshop folder `<Game>\..\..\workshop\content\1206560`) for folders containing a `mod.json` (searched recursively if not at the folder root).
2. **Dependencies are resolved** (`ModDepenSolveService`); missing required dependencies block loading; optional dependencies become preprocessor symbols.
3. **Compilation** (unless prebuilt) → `NML\CompiledMods\<UID>.dll` + `.pdb`.
4. **Assembly loaded** via `Assembly.Load(dllBytes, pdbBytes)`.
5. **Type discovery**: NML scans the assembly for a type that (a) is a `MonoBehaviour` subclass, (b) is not abstract, and (c) either implements `IMod` **or** carries the NCMS `[ModEntry]` attribute.
6. **GameObject created**: a child of `GameObject.Find("Services/ModLoader")`, named after the mod, created **inactive**.
7. **`LoadLocales(...)`** — the mod's `Locales/` are read into `LM`.
8. **`OnLoad(ModDeclare, GameObject)`** is called → this sets `Instance`, creates the `ModFeatureManager`, loads the config, logs `"OnLoad"`, calls **`OnModLoad()`**, then **`ModFeatureManager.InstantiateFeatures()`**, then logs `"Loaded"`.
9. **The GameObject is activated** → Unity runs **`Awake` → `OnEnable` → `Start`**.
10. **`Update`** every frame thereafter.

Documented order in E5 `api/BasicMod.cs`:
> *"The common order of calling is: OnModLoad -> Awake -> OnEnable -> Start -> Update"*

`Init()` and `PostInit()` are the `IStagedLoad` hooks: `Init` runs after all mods are loaded, `PostInit` after that.

**Confirmed at runtime (E6):**
```
[NML]: [Godzilla]: OnLoad
[NML]: [Godzilla]: Loaded
[NML]: [PowerBox]: OnLoad
```

---

## 6. The NML interfaces a mod can implement

All from `NeoModLoader.api` (E1):

| Interface | Members | Notes |
|---|---|---|
| `IMod` | `void OnLoad(ModDeclare pModDecl, GameObject pGameObject)` | The minimum contract. A class implementing only `IMod` must also be a `MonoBehaviour`. |
| `ILocalizable` | `string GetLocaleFilesDirectory(ModDeclare pModDeclare)` | Returning the `Locales` path makes NML auto-load locale files. |
| `IConfigurable` | `ModConfig GetConfig()` | Gives you the settings object. |
| `IStagedLoad` | `void Init()`, `void PostInit()` | Post-load staging hooks. |
| `IFeatureLoadManaged` | `IModFeatureManager ModFeatureManager { get; set; }` | Feature-manager injection. |
| `IReloadable` | `void OnReload()` | Called when the mod is reloaded without restarting the game. |
| `IUnloadable` | `void OnUnload()` | Called on mod unload. |
| `ICsvSepCustomized` | `char GetCsvSeparator()` | Overrides the CSV separator used for `.csv` locale files (default `,`). |
| `IModFeature` / `IModFeatureManager` | see §8 | Feature system. |

---

## 7. `NeoModLoader.General` — localization, UI and helpers

### `LM` — the localization API (E1, installed DLL; `public static abstract sealed`)

```csharp
namespace NeoModLoader.General {
  public static class LM {
    public static string Get(string key);
    public static bool   Has(string key, string lang = null);
    public static void   LoadLocales(string pFilePath, char pSep = ',');
    public static void   LoadLocales(Stream pStream, char pSep = ',');
    public static void   LoadLocale(string pLanguage, Stream pStream);
    public static void   LoadLocale(string pLanguage, string pFilePath);
    public static void   AddToCurrentLocale(string key, string value);
    public static void   Add(string language, string key, string value);
    public static void   ApplyLocale(string language, bool pUpdateTexts = true);
    public static void   ApplyLocale(bool pUpdateTexts = true);
  }
}
```

Internals: `LM.locales` is `Dictionary<language, Dictionary<key, value>>`; `ApplyLocale` copies the current language's table into `LocalizedTextManager.instance._localized_text` and refreshes UI text.

**Real-world usage** (E3, `Mods\SCPBOX_MOD\Code\ScpLocale.cs`):
```csharp
LM.AddToCurrentLocale(kvp.Key, kvp.Value);
LM.Add("en", kvp.Key, kvp.Value);
LM.ApplyLocale(false);
LocalizedTextManager.instance._localized_text[kvp.Key] = kvp.Value;   // direct route
```

### Other `NeoModLoader.General` types (E1)

| Type | Purpose |
|---|---|
| `LM` | Localization (above). |
| `OT` | `static void InitializeCommonText(UI.Text)`, `static void InitializeNoActionVerticalLayoutGroup(VerticalLayoutGroup)` — UI text helpers. |
| `RF` | Resource finder: `RF.Find(string pPath)`, `RF.FindSprite(string)`, `RF.FindTexture(string)`, `RF.FindAll(string)`, `RF.FindAllOfType<T>(string)`, `RF.FindInMod(...)` — locate assets by path. |
| `ResourcesFinder` | `Find(string)`, `FindAll(string)`, `FindAllOfType<T>(string)`, `FindSprite`, `FindTexture`, `FindPrefab` — the concrete implementation behind `RF`. |
| `PowerButtonCreator` | `Create(...)` overloads that build a `PowerButton` (game powers bar) programmatically. |
| `WindowCreator` | `Create(...)` overloads that build an in-game window. |
| `PowerTabNames` | Helper for naming/looking up power tabs. |
| `Event.*` | Event bus: `AbstractHandler`, `AbstractListener`, `BaseListener`, `Listeners.CityCreateListener`, `Handlers.CityCreateHandler`, etc. — hooks into game events. |
| `Game.extensions.*` | `AssetExtension`, `DataExtension` — helpers for extending `Asset`/`Data` objects. |
| `Game.ItemAssetCreator` | Helpers to create game assets (E5 master). |

### `NeoModLoader.ui` (E1)
`ui.ModListGUI`, `ui.ModListItem`, `ui.ModListTab`, `ui.CheatMenu` — the in-game mod list / cheat menu.

---

## 8. The feature system (`ModFeature`)

`NeoModLoader.api.ModFeature` (E1, installed DLL):

```csharp
public abstract class ModFeature : IModFeature {
    public virtual IModFeatureManager ModFeatureManager { get; set; }
    public virtual ModFeatureRequirementList RequiredModFeatures { get; }
    public virtual ModFeatureRequirementList OptionalModFeatures { get; }
    public virtual bool Init();        // override
    public virtual bool PostInit();    // override
    protected bool TryGetFeature<T>(out T feature);
    protected T    GetFeature<T>();
    protected bool IsFeatureLoaded<T>();
}
```

Concrete features shipped by NML (E1):
`ModAssetFeature`, `ModButtonFeature`, `ModGodPowerButtonFeature`, `ModObjectFeature`, `ModPowerTabFeature`, `ModWindowButtonFeature`.

Usage counts across the 17 installed mods (E3): `ModFeature` 59 hits, `ModAssetFeature` 48, `ModButtonFeature` 5, `ModObjectFeature` 5 — this is the most-used extension point after localization.

---

## 9. Localization — exact format

### File naming
`Locales/<language>.json` — **the filename without extension is the language code**. NML loads every file it finds under `Locales/` (recursively) via
`LM.LoadLocale(Path.GetFileNameWithoutExtension(file), file)` for `.json`, or `LM.LoadLocales(file, sep)` for `.csv` (E1 `LoadLocales`, E5).

Observed language codes across installed mods (E3): `en`, `cz` (Simplified Chinese), `ch` (Traditional Chinese), `ru`, `br`, `ja`, `ko`, `es`, `de`, `fi`, `ro`, `ua`.
(E5 wiki `Mod制作教程3-语言文件.md`: `cz` = 简体中文, `en` = English, `ch` = 繁体中文.)

### JSON format
A **flat, single-level object** of `string → string`:

```json
{
  "godzilla_name": "Godzilla",
  "godzilla_tab": "Godzilla",
  "godzilla_tab_description": "Spawn Godzilla and 31 kaijus: controlled or wild, calm until provoked or by their nature",
  "godzilla_power_control": "Godzilla (controlled)",
  "godzilla_power_control_description": "Spawns Godzilla and gives you control. ...",
  "kaiju_lang": "en"
}
```
(from E3 `Mods\AGRICHE_GODZILLA\Locales\en.json`)

E5 wiki states the same: the key is *the display key of your PowerTab*, the value is the display text.

### CSV format
`LM.LoadLocales(path, sep)` → the first row is the header (language names), each subsequent row is `key,lang1,lang2,…` (E1 `ParseCSV`).

### How game objects look up their strings (E4, `Assembly-CSharp.dll` IL)

| Asset type | Name key | Description key |
|---|---|---|
| **GodPower** | `StringExtension.Underscore(id)` — e.g. id `GodzillaControl` → `godzilla_control` | `getLocaleID() + "_description"` |
| **ActorTrait** | `BaseTrait.getLocaleID()` = `typed_id + "_" + Asset.id`, then `Underscore` applied at lookup → `trait_scp_anomaly` | `getLocaleID() + "_info"` (and `+ "_info_2"`) |
| **ActorAsset** (species) | `ActorAsset.getLocaleID()` | `getDescriptionID()` |
| **StatusAsset** | `status_title_<id>` / `status_description_<id>` (observed in E3 `CoreBox\Locales\en.json`: `status_title_corebox_weakened`, `status_description_corebox_weakened`) | |
| **BiomeAsset** | `getDescriptionID()` = `… + "_description"` | |

`StringExtension.Localize(key)` = `LocalizedTextManager.getText(StringExtension.Underscore(key), null, false)`.
`StringExtension.Underscore` converts CamelCase → snake_case.

**So, to localise a trait whose `id` is `ScpAnomaly`:**
```json
{ "trait_scp_anomaly": "SCP Anomaly", "trait_scp_anomaly_info": "Mentally unstable." }
```
**And a GodPower with `id = "GodzillaControl"`:**
```json
{ "godzilla_control": "Godzilla (controlled)",
  "godzilla_control_description": "Spawns Godzilla and gives you control." }
```

The exact trait-key shape `"trait_<snake_id>"` is **inferred** from E4 `BaseTrait.getLocaleID()` = `get_typed_id() + "_" + Asset.id` with `ActorTrait.get_typed_id()` returning the literal `"trait"`, plus `Underscore` being applied at lookup. The `_info` suffix is confirmed by E4 IL. *Marked as high-confidence inference, not a literal in-game example.*

### Runtime API (no file needed)
```csharp
LM.AddToCurrentLocale("my_key", "My text");
LM.Add("en", "my_key", "My text");
LM.ApplyLocale(false);
```
(347 `LM.Add` call sites across the installed mods — E3.)

---

## 10. Mod configuration (`ModConfig`)

`NeoModLoader.api.ModConfig` (E1):

```csharp
public class ModConfig {
    public ModConfig(string path, bool pIsPersistent = false);
    public Dictionary<string, Dictionary<string, ModConfigItem>> this[string pGroupId] { get; }
    public void MergeWith(ModConfig pDefaultConfig);
    public void Save(string path = null);
    public void CreateGroup(string pId);
    public void ApplyCallbacks();
}
public class ModConfigItem { /* Id, Type, BoolVal, IntVal, FloatVal, StringVal, IconPath, Callback, ... */ }
public enum ConfigItemType { SWITCH, INT_SLIDER, FLOAT_SLIDER, TEXT, SELECT, ... }
```

* **Persistent** file: `Paths.ModsConfigPath/<UID>.config` → `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\<UID>.config`.
* **Default/schema** file: `<mod folder>\default_config.json` (`Paths.ModDefaultConfigFileName`). NML merges defaults under the persistent values and then calls `ApplyCallbacks()`.

**`default_config.json` format** (E3, `Mods\CORE4777_COREBOX\default_config.json`):
```json
{
  "corebox_cfg": [
    { "Id": "corebox.rpg_enabled", "Type": "SWITCH", "IconPath": "ui/Icons/CoreBox/group_rpg",
      "BoolVal": true, "Callback": "CoreBox.CoreBoxConfig:OnRpgEnabled" },
    { "Id": "corebox.unlock_traits", "Type": "SWITCH", "IconPath": "ui/Icons/actor_traits/iconMadness",
      "BoolVal": true, "Callback": "CoreBox.CoreBoxConfig:OnUnlockTraits" }
  ]
}
```
Top level = **group id** → array of **items**. `Callback` is `"<Namespace>.<Type>:<Method>"`.

A simpler, second-style config also exists (E3, `Mods\SCPBOX_MOD\mod_settings.json`) — a flat JSON of `id → value`:
```json
{ "AutoSpawnEntities": false, "AutoSpawnBuildings": false, "SiteBreaches": false,
  "EnemyFactions": true, "SpawnChancePerTick": 0.0001, "BreachChancePerCheck": 0.02,
  "AgentsPerSite": 6, "ObservationRange": 9.0 }
```
**UNVERIFIED:** which of these two formats `ModConfig` parses natively (the flat one may be a bespoke loader inside SCPBOX_MOD).

---

## 11. Resources, sprites and assets

| API | Where | What it does |
|---|---|---|
| `NeoModLoader.utils.SpriteLoadUtils` | E1 | `LoadSprite(...)`, `LoadSpriteFromFile(...)`, `LoadSpriteFromBytes(...)` — build a `UnityEngine.Sprite` from a PNG on disk or in memory. |
| `NeoModLoader.utils.AssetBundleUtils` | E1 | `LoadAssetBundle(...)`, `LoadAllAssetBundle(...)`, `LoadSpriteFromBundle(...)` — load Unity asset bundles from the `AssetBundles/` folder. |
| `NeoModLoader.utils.HarmonyUtils` | E1 | `CreateAndPatchAll(string pAssemblyName, string[] pTypes = null, ...)`, `PatchAll`, `Patch(Harmony, Type, string)`, `UnpatchAll(string)`, `GetHarmonyInstance()` — batch Harmony patching. |
| `NeoModLoader.utils.OtherUtils` | E1 | Assorted helpers (`IsNullOrEmpty`, `SafeInvoke`, `GetOrDefault`, `CopyTo`, …). |
| `NeoModLoader.utils.SoundUtils` | E1 | Sound helpers. |
| `NeoModLoader.utils.ResourcesPatch` | E1 | Patches the game's resource lookup so mods can override/extend game assets. |
| `NeoModLoader.utils.Builders.*` | E1 **only** (not in upstream master) | `Builder`, `ActorTraitBuilder`, `AssetBuilder<T>` — fluent builders for game assets. |
| `NeoModLoader.utils.SerializableAsset` / `utils.SerializedAssets.SerializableAsset<T>` | E1 | Serializable asset wrapper. |
| `EmbededResources.GetBytes(name)` / `EmbededResources.LoadSprite(name, pivotX, pivotY, pixelsPerUnit)` | generated | Read files from `EmbededResources/` (NCMS-compat path). Manifest name = `<ModName>.Resources.<dotted relative path>`. |

> `SpriteLoadUtils`, `AssetBundleUtils` and `HarmonyUtils` have **0 call sites** across the 17 installed mods (E3) — the installed mods load sprites through the game's own asset pipeline instead. Their exact signatures were extracted from the installed DLL (E1) but were **not** validated by running them.

---

### `NeoModLoader.utils.Builders.*` — fluent asset builders (installed build only)

These types exist **only in the installed `NeoModLoader.dll`**, not in upstream `master` or the `NML\commit` hash (E1 + SECTION 16 of the evidence file). They are the newest and most ergonomic way to author game assets:

```csharp
NeoModLoader.utils.Builders.Builder                 // abstract base
NeoModLoader.utils.Builders.AssetBuilder<A, AL>      // generic asset builder
NeoModLoader.utils.Builders.AugmentationAssetBuilder<A, AL>
NeoModLoader.utils.Builders.UnlockableAssetBuilder<A, AL>
NeoModLoader.utils.Builders.BaseTraitBuilder<A, AL>
NeoModLoader.utils.Builders.GroupAssetBuilder<A>
NeoModLoader.utils.Builders.ActorTraitBuilder       // ActorTrait + ActorTraitLibrary
NeoModLoader.utils.Builders.ActorAssetBuilder
NeoModLoader.utils.Builders.ClanTraitBuilder
NeoModLoader.utils.Builders.CultureTraitBuilder
NeoModLoader.utils.Builders.SubspeciesTraitBuilder
NeoModLoader.utils.Builders.MasterBuilder
NeoModLoader.utils.Builders.SubSpeciesTrait          // enum
```

`ActorTraitBuilder` shape (E1):
* constructors — `ActorTraitBuilder(string ID)`, `(string ID, bool LoadImmediately)`, `(string ID, string CopyFrom)`
* `Build(bool SetRarityAutomatically = false, bool AutoLocalize = true, bool LinkWithOtherAssets = false)`
* chainable properties: `RateBirth`, `RateInherit`, `RateAcquireWhenGrownUp`, `Type` (`TraitType`), `AffectsMind`, `CanBeCured`, `RemovedByDevineLight`, `RemovedByAcceleratedHealing`, `IsCombatSkill`, `ActiveInDarkEra`, `ActiveInMoonEra`, `ForcedKingdomID`, `UsedInMutationBox`, `ActorsLikeability`, `SameTraitLikeability`, `OppositeTraitLikeability`, `RemoveForZombies`, `AdditionalBaseStatsMethod`

`AutoLocalize` on `Build()` is the hook that ties an asset to its `Locales/*.json` entry — it is the builder's counterpart to the key conventions in section 9.

> **UNVERIFIED:** this Builders API has no upstream documentation and **zero call sites** in the installed mods, so its exact semantics (e.g. how `AutoLocalize` derives the locale key) were not confirmed by execution.

### `NeoModLoader.General.UI.*` — a declarative UI framework (installed build)

E1 exposes a substantial retained-UI framework that the upstream `master` source also contains:

* `NeoModLoader.General.UI.Prefabs.APrefab<T>`, `SimpleButton`, `SimpleStatBar`, `SliderBar`, `SwitchButton`, `TextInput`
* `NeoModLoader.General.UI.Window.AutoLayoutWindow<T>`, `SingleAutoLayoutWindow<T>`, `MultiTabWindow<T>`, `AutoLayoutElement<T>`, `AutoLayoutGroup<TElement,TGroup>`, and the layouts `AutoVertLayoutGroup`, `AutoHoriLayoutGroup`, `AutoGridLayoutGroup`
* `NeoModLoader.General.UI.Tab.*` — `PowersTabExtension`, `ReconstructedVanillaTab` (+ `TabMain`, `TabCreatures`, `TabKingdoms`, `TabNature`, `TabOther`, `TabDrawing`, `TabBombs`), `TabManager`

`PowerButtonCreator` (E1) is the low-level way to add buttons to the game's powers bar:

```csharp
static PowerButton CreateSimpleButton(string pId, UnityAction pAction, Sprite pIcon, Transform pParent = null, Vector2 pLocalPosition = default);
static PowerButton CreateWindowButton(string pId, string pWindowId, Sprite pIcon, Transform pParent = null, Vector2 pLocalPosition = default);
static PowerButton CreateGodPowerButton(string pGodPowerId, Sprite pIcon, Transform pParent = null, Vector2 pLocalPosition = default);
static PowerButton CreateToggleButton(string pGodPowerId, Sprite pIcon, Transform pParent = null, Vector2 pLocalPosition = default, bool pNoAutoSetToggleAction = false);
static PowersTab  GetTab(string pId);
static void       AddButtonToTab(PowerButton button, PowersTab tab, Vector2 position, int? siblingIndex = null);
static void       AddButtonToTab(PowerButton button, PowersTab tab, int? siblingIndex = null);
```
## 12. Harmony patching

`0Harmony.dll` ships in `NML\Assemblies\` and is a **default compile reference** (E1/E5) — so `using HarmonyLib;` works out of the box.

* `NeoModLoader.utils.HarmonyUtils` gives batch patching helpers (E1).
* `UsePublicizedAssembly` defaults to `true`, so `NML\Assembly-CSharp-Publicized.dll` (which exposes private members) is referenced at compile time — this is what makes patching private game methods possible (E1, E5).
* Real installed mods use raw Harmony directly: 5 `using HarmonyLib;` imports, e.g. E3 `Mods\SCPBOX_MOD\Code\ScpLocale.cs` has `using HarmonyLib;` (E3).
* E5 wiki has a dedicated page `Mod进阶教程1-Harmony.md`.

---

## 13. How NML compiles your code — the exact pipeline

**NML compiles `.cs` at runtime with Roslyn (`Microsoft.CodeAnalysis.CSharp`).** A prebuilt DLL is *optional* (and if you place one in the mod root, compilation is skipped entirely).

### Step by step (E1 IL + E5 source)

1. **Collect sources.** `SystemUtils.SearchFileRecursive(FolderPath, fileFilter, dirFilter)` over the **whole mod folder**:
   * file filter: name ends with `.cs` and does not start with `.`
   * dir filter: directory name does not start with `.` and is not in `Paths.IgnoreSearchDirectories`
2. **Parse.** `CSharpSyntaxTree.ParseText(text, new CSharpParseOptions(LanguageVersion.Latest, preprocessorSymbols: <deps>))`, one syntax tree per file; the tree's path is the file path relative to the mod folder.
3. **NCMS detection.** If any file matches `NCMSCompatibleLayer.IsNCMSMod(syntax_tree)`, the mod is treated as NCMS-compatible and the synthetic `<Name>.GlobalObject.cs` is added (containing `class Mod` and `class EmbededResources`).
4. **Embed resources.** Files under `<mod>/EmbededResources/` are added as `ResourceDescription`s named `<ModName>.Resources.<relative path with separators replaced by '.'>`.
5. **Create the compilation.**
   `CSharpCompilation.Create(pModDecl.UID, syntaxTrees, references, new CSharpCompilationOptions(OutputKind.DynamicallyLinkedLibrary, ...))` — **the assembly name is the mod UID**.
6. **References** (`prepareCompile` / `CreateCompileSessionContext`):
   * every `*.dll` in `worldbox_Data\Managed\` → `Assembly-CSharp.dll`, `UnityEngine*.dll`, `UnityEngine.UI.dll`, `mscorlib`, `netstandard`, `Newtonsoft.Json.dll`, `DOTween.dll`, …
   * every `*.dll` in `NML\Assemblies\` → `0Harmony.dll`, `Microsoft.CodeAnalysis*.dll`, `Mono.Cecil.dll`, `MonoMod.*.dll`, `YamlDotNet.dll`, `Facepunch.Steamworks.*.dll`, `Gameloop.Vdf.dll`, `System.*.dll`
   * `Paths.NMLModPath` → **`NeoModLoader.dll` itself** (this is why `using NeoModLoader.api;` compiles)
   * `Paths.PublicizedAssemblyPath` → `NML\Assembly-CSharp-Publicized.dll`, added when `UsePublicizedAssembly` is true (default)
   * each **dependency's** compiled DLL from `NML\CompiledMods\<depUID>.dll` is added as a reference, so `Dependencies` are real compile-time references
7. **Emit.** `compilation.Emit(dllStream, pdbStream, manifestResources: embeded_resources, …)` → written to `NML\CompiledMods\<UID>.dll` and `<UID>.pdb`.
8. **Load.** `Assembly.Load(File.ReadAllBytes(<UID>.dll), File.ReadAllBytes(<UID>.pdb))`.
9. **Cache.** `NML\mod_compile_records.json` records `{ dependencies, disabled, mod_id, optional_dependencies, timestamp }` per UID so unchanged mods are not recompiled.

### Prebuilt-DLL mode
`Directory.GetFiles(FolderPath, "*.dll")` returning any file ⇒ the mod is switched to `ModTypeEnum.COMPILED_NEOMOD`:
```
[NML]: <UID> detected as precompiled, compilation phase will be skipped on it!
```
The main assembly is the DLL whose filename equals the UID, else the first DLL found; the mod's assembly is loaded with `Assembly.Load(bytes, pdbBytes)`.

### C# language level
`LanguageVersion.Latest` (E1 IL: `CSharpParseOptions(LanguageVersion.Latest, …)`) — so modern C# works. Roslyn shipped in `NML\Assemblies` is `Microsoft.CodeAnalysis.CSharp.dll` 7.9 MB + `Microsoft.CodeAnalysis.dll` 4.9 MB (E2), i.e. **Roslyn 4.x**.

### Preprocessor symbols
`preprocessorSymbols` come from the mod's dependency list, run through `ModDependencyUtils.ParseDepenNameToPreprocessSymbol` (E1 IL). **UNVERIFIED:** the exact symbol naming convention (whether it is the raw UID or a `DEP_<UID>`-style form) — the symbol list is produced in the dependency-solver path, which was not fully traced.

---

## 14. Logging

### Where the log is
Unity writes the player log to:

```
%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log
%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player-prev.log   (previous run)
```

Confirmed on this machine (E6). The company/product folder `mkarpenko\WorldBox` comes from the Unity player settings; `Application.persistentDataPath` = the same folder, and NML's `Paths.PersistentDataPath` points at it.

There is also `…\WorldBox\logs\` (game's own error logs, e.g. `error_*.log`) and `…\WorldBox\magic.log`.

### Format
`NeoModLoader.services.LogService` prefixes every message with **`[NML]: `**:

* `LogService.LogInfo(msg)` → `[NML]: <msg>`
* `LogService.LogWarning(msg)` → `[NML]: <msg>` (plus Unity's warning marker)
* `LogService.LogError(msg)` → `[NML]: <msg>`
* `LogService.LogException(e)` → `[NML]: <exception>`

`BasicMod.LogInfo/LogWarning/LogError` additionally prefix the **mod name** (E1 IL: `String.Concat("[", _declare.Name, "]: ", message)`):

```
[NML]: [Godzilla]: OnLoad
[NML]: [Godzilla]: Loaded
[NML]: No mod.json file for folder C:\...\Mods\SomeFolder
[NML]: Compile Mod Godzilla
```

Real lines captured from `Player.log` (E6):
```
[NML]: No mod.json file for folder C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\ElementalPowersMod
[NML]: Compile Mod Godzilla
[NML]: [Godzilla]: OnLoad
```

---

## 15. Other things worth knowing

* **Dependencies** — `Dependencies` (hard) / `OptionalDependencies` (soft). A missing hard dependency stops the mod from loading. Optional dependencies are compiled-in references and become preprocessor symbols.
* **Duplicate detection** — two mods with the same normalised UID: NML logs `Repeat Mod with <UID>, Only load one of them`.
* **Hot-reload** — `IReloadable.OnReload()` is invoked when a mod is reloaded in-game (E5 wiki `Mod进阶教程8-模组重载.md`); NML's log shows `Reload <file> as <lang>` when re-reading locale files.
* **`tab_order_records.json`** — controls the ordering of mod entries in the in-game mod list (E2).
* **NCMS compatibility** — NML can load NCMS (`[ModEntry]`) mods, BepInEx plugins (`BepInEx.BaseUnityPlugin`), and NCMS-mod resource packs. `ModTypeEnum` = `NEOMOD, COMPILED_NEOMOD, BEPINEX, RESOURCE_PACK` (E1).
* **Upstream repo** — `github.com/WorldBoxOpenMods/ModLoader`; wiki at `github.com/WorldBoxOpenMods/ModLoader/wiki` (mostly Chinese; `Home(English).md` is a stub).

---

## 16. UNVERIFIED / open questions

| # | Item | Status |
|---|---|---|
| 1 | The **installed `NeoModLoader.dll` is newer than upstream `master` and than the `NML\commit` hash**. Types present only in the installed DLL: `NeoModLoader.utils.Builders.*`, `NeoModLoader.utils.SerializedAssets.*`. | **UNVERIFIED** — no public commit matches. |
| 2 | `targetGameBuild` in `mod.json` is **not** honoured for NML mods (not copied by `ModDeclare`'s file constructor). | Verified as *ignored* by E1 IL + E5 source; whether some other NML path reads it: **UNVERIFIED**. |
| 3 | The exact **preprocessor symbol** naming for dependencies. | **UNVERIFIED** — traced to the dependency solver, not fully read. |
| 4 | Whether `ModConfig` natively parses the **flat** `mod_settings.json` style (E3 `SCPBOX_MOD\mod_settings.json`). | **UNVERIFIED** — may be a bespoke loader inside that mod. |
| 5 | `SpriteLoadUtils` / `AssetBundleUtils` / `HarmonyUtils` exact overloads and behaviour — extracted from metadata but **never executed**. | **UNVERIFIED** (signatures verified, semantics not). |
| 6 | The `GameResources` / `GameResourcesReplace` / `AssetBundles` **runtime consumption** path (which NML component copies them into the game). | **UNVERIFIED** — folder names and constants verified; the consuming code path was not traced. |
| 7 | Trait localization key shape `trait_<snake_id>` and `_info` / `_info_2` suffixes. | **High-confidence inference** from E4 IL (`BaseTrait.getLocaleID` = `typed_id + "_" + id`, `ActorTrait.get_typed_id()` = `"trait"`, `getDescriptionID` = `+ "_info"`). No literal in-game example was found. |
| 8 | Whether the installed build honours `.gitignore` when collecting `.cs` files (master does). | **UNVERIFIED** — `GitIgnoreUtils` exists upstream; not confirmed present in the installed DLL. |
| 9 | Exact CSV locale header semantics (which column is which language). | **UNVERIFIED** — `LM.ParseCSV` inspected, but no `.csv` locale file was found in any installed mod. |

---

## 17. Source references

* Loader source (master): `https://github.com/WorldBoxOpenMods/ModLoader` — tree at commit `36a891b5dcd067be43aa12574338d849c2947001`
* Loader source (pinned to `NML\commit`): `https://github.com/WorldBoxOpenMods/ModLoader/tree/02266fe8185d940c4065185de0a117c18975cf09`
* Wiki: `https://github.com/WorldBoxOpenMods/ModLoader/wiki` (pages: `Home(English).md`, `Mod制作教程3-语言文件.md`, `Mod制作教程5-模组配置.md`, `Mod进阶教程1-Harmony.md`, `Mod进阶教程6-模组依赖.md`, …)
* NCMS docs (referenced by NML): `https://denq04.github.io/ncms/getting-started/`
* Key upstream files consulted: `api/ModDeclare.cs`, `api/BasicMod.cs`, `api/ModConfig.cs`, `api/ModFeature.cs`, `api/ILocalizable.cs`, `api/IConfigurable.cs`, `api/IMod.cs`, `api/IStagedLoad.cs`, `constants/Paths.cs`, `constants/CoreConstants.cs`, `constants/Others.cs`, `services/ModCompileLoadService.cs`, `services/LogService.cs`, `general/LM.cs`, `general/OT.cs`, `general/RF.cs`, `general/ResourcesFinder.cs`, `ncms_compatible_layer/NCMSCompatibleLayer.cs`, `utils/SpriteLoadUtils.cs`, `utils/AssetBundleUtils.cs`, `utils/HarmonyUtils.cs`.

A machine-readable dump of every extracted type/method signature, file path, IL excerpt and URL is in the companion file **`01-nml-api-evidence.txt`**.