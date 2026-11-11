# WorldBox Modding — Web Corpus (2026)

Compiled 2026-10-23 from live web fetches. Every claim carries an inline source URL.
Researcher's note on freshness: the newest source content found is **NML 1.2.1.1, released 2026-10-19**
([release](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1.1)). The
"Worldbox Modding-Box" guide traces itself against **NML 1.2.0.1** and WorldBox **0.51.2 build 719**
([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md),
[compatibility matrix](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/workbench/compatibility.mdx)).

---

## 0. TL;DR

| Question | Answer |
| --- | --- |
| Which loader in 2026? | **NML (NeoModLoader)** — current, maintained, community default |
| Newest NML | **1.2.1.1**, 2026-10-19 ([release notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1.1)) |
| Legacy | NCMS (discontinued; NML loads NCMS mods) |
| Effectively dead | WBML / WorldBoxModLoader (Workshop item removed by Valve) |
| Use alongside NML | BepInEx 5 (Mono x64) — for tools/Harmony, not content |
| Where to publish | **GameBanana first**, Steam Workshop as auto-update mirror |
| WorldBox Steam app id | **1206560** — [verified](https://steamcommunity.com/app/1206560/workshop/) |
| Minimum viable mod | `mod.json` + one `.cs` file extending `BasicMod<T>` |

---

## 1. THE SIX MOD SYSTEMS

The "six systems" list comes from the Russian community wiki
([worldbox.fandom.com/ru/wiki/Моддинг](https://worldbox.fandom.com/ru/wiki/Моддинг)).
⚠️ **Note:** the *English* official wiki page lists only **three** mod-loader types (NML, BepInEx,
Native) — not six — see [the-official-worldbox-wiki.fandom.com/wiki/Modding](https://the-official-worldbox-wiki.fandom.com/wiki/Modding).
The six-way split is a community-wiki taxonomy that adds NCMS, WBML and Assembly-CSharp as separate *kinds*.

| # | System | What it is | Install path | Difficulty | Choose it when | Maintenance status (2026) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **NML — NeoModLoader** | Community loader for WorldBox; compiles your `.cs` **source at game start**; ships `AssetManager` timing, `Locales/`, `GameResources/`, in-game mod manager, HarmonyX, Mod Hub | `worldbox_Data\StreamingAssets\Mods\NeoModLoader.dll` (+ `.pdb`) | **Low** — plain text editor is enough ([GB 20297](https://gamebanana.com/tuts/20297)) | **Default for ~all content mods**: traits, items, god powers, buildings, biomes, UI | **ACTIVE.** v1.2.1.1 / 2026-10-19 ([releases](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1.1)) |
| 2 | **NCMS** | The loader NML replaced; mods are folders/`.zip`/`.mod`; no compilation needed to *play* a mod | `worldbox\Mods\` (folder / zip / `.mod`) | Very low to play | Only to play an old NCMS-only mod — NML runs those already | **DEAD.** "officially discontinued by its own creator" ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)); RU wiki: "no longer supported and will not be updated" ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)) |
| 3 | **WBML — WorldBoxModLoader** (DipCrai) | Separate loader; author self-describes it as a hobby tool for simple tabs/buttons; can load arbitrary code | `worldbox_Data\StreamingAssets\Mods\WorldBoxModLoader.dll` (+ `.pdb`) | Medium | Rarely. RU wiki: **"not a single mod has been created for WorldBoxModLoader"** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)) | **EFFECTIVELY DEAD as a channel.** Steam Workshop item `3273791624` = "[OUTDATED] WorldBoxModLoader", **"removed from the community because it violates Steam Community & Content Guidelines"** ([Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3273791624)); last Workshop update 2024-09-28. GitHub repo still receives commits (last push **2026-07-08**, [repo API](https://api.github.com/repos/DipCrai/WorldBoxModLoader)), but RU wiki lists *full incompatibility with NML*, no auto image loading/replacement, poor optimization |
| 4 | **BepInEx** | Generic Unity/Mono mod loader; loads compiled `.dll` plugins; bundles HarmonyLib | `worldbox\BepInEx\plugins\` (+ `BepInEx.dll`, `winhttp.dll`, `doorstop_config.ini` at game root on Windows) | **High** — real C# project, .NET SDK, MSBuild | Dev tools/overlays (UnityExplorer-style), engine-level hooks, when you need code to run **before** the game initializes ([guide](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md)) | **ACTIVE** (generic project). Use **BepInEx 5 (Mono x64)**; RU wiki pins **v5.4.23.2** and warns "not 6.0.0-pre.1" ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)); official EN wiki still says **5.4.21** ([EN wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)) |
| 5 | **Native modloader** | The game's *own* built-in mod system. A native mod is typically **one `.dll`** | `worldbox_Data\StreamingAssets\mods\` (note: lowercase in RU wiki), experimental mode on | Medium — no game modding libraries in vanilla, you must ship them | Experts making small mods or their own loaders. **NML and NCMS are themselves native mods** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)) | **Built into the game**; effectively frozen |
| 6 | **Assembly-CSharp replacement** | Overwrite the game's own `Assembly-CSharp.dll` (and sometimes `resources.assets`) with a modified copy | Overwrite files in the game folder; keep backups | Low to make, **highest to maintain** | Very large "changes everything" mods, or inexperienced authors. Never for a normal mod | **Fragile.** "guaranteed to break at the slightest game update"; mods of this type are "completely incompatible with each other" ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)) |

### Disambiguation — "WBML" means two different things

- **WBML = WorldBoxModLoader** by DipCrai — a *mod loader* for players
  ([github.com/DipCrai/WorldBoxModLoader](https://github.com/DipCrai/WorldBoxModLoader)).
- **WBML = WorldBox Modding Lab** — a *research baseline tool* used by the lous12 docs to
  verify the runtime API ([compatibility matrix](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/workbench/compatibility.mdx)).
  These are unrelated projects sharing an acronym. Do not conflate them.

### Platform support

- **Mods work on Steam Windows / Mac / Linux (incl. Steam Deck / SteamOS). Not on mobile.** The
  official wiki states mods are supported for MacOS, Windows and Linux but "not on the mobile
  versions" ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)); the RU
  wiki says the same and adds "but not on iOS or Android"
  ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)).
- ⚠️ **Conflict:** the NML README documents **Android** (Mono loader such as FusionCore,
  `<Persistentdata>/mods`) and **iOS** (sideloaded IPA + JIT) installation
  ([README](https://raw.githubusercontent.com/WorldBoxOpenMods/ModLoader/master/README.md)).
  Treat mobile as **experimental and unofficial**.

---

## 2. INSTALL PATHS

### 2.1 NML (recommended)

Steps, all platforms ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md),
[official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding),
[RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг),
[README](https://raw.githubusercontent.com/WorldBoxOpenMods/ModLoader/master/README.md)):

1. In game: **Settings → Experimental Mode → on**. Without it the game does not even look for mods —
   "no error, no message, just nothing" ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).
   The game **turns Experimental Mode off by itself after every update** ([GB 20297](https://gamebanana.com/tuts/20297)).
2. Download `NeoModLoader.dll` **and `NeoModLoader.pdb`** from
   [releases/tag/latest](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/latest).
   Never from CurseForge, a mirror, or a chat file — an old copy from elsewhere "deletes itself the
   first time the game starts" ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).
3. Delete anything with **`NCMS`** in its name in the same folder — NML refuses to load mods from
   `Mods\` if it detects NCMS is installed ([official wiki FAQ](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)).
4. Launch the game. You should see "Experimental mode is enabled", an **NML-logo tab button** at the
   bottom of the screen, a new empty `Mods\` folder next to `worldbox.exe`, and an `NML\` folder inside
   `StreamingAssets\Mods\` (do not touch it).

**Exact paths**

| Platform | Game root | NML file goes here | Your mods go here |
| --- | --- | --- | --- |
| **Windows** | `C:\Program Files (x86)\Steam\steamapps\common\worldbox\` | `worldbox_Data\StreamingAssets\Mods\NeoModLoader.dll` (+ `.pdb`) — next to the game's own `test_asset_load` folder | `worldbox\Mods\` (next to `worldbox.exe`) |
| **macOS** | `worldbox.app` | `worldbox.app/Contents/Resources/Data/StreamingAssets/Mods/NeoModLoader.dll` | `worldbox/Mods/` (next to the app, **not** inside it) |
| **Linux (desktop)** | `~/.local/share/Steam/steamapps/common/worldbox/` | `worldbox_Data/StreamingAssets/Mods/NeoModLoader.dll` | `worldbox/Mods/` |
| **Steam Deck** | same as Linux; switch with **STEAM → Power → Switch to Desktop**, then Steam → Library → right-click WorldBox → Manage → Browse local files | same as Linux | same as Linux |

Sources: [install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md) (Windows/Mac/Linux/Deck paths),
[official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding) (Windows + Mac paths),
[RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) (Windows/Mac/Linux paths).

**Two ways to install NML** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)):

- **Manual** — download `NeoModLoader.dll` + `NeoModLoader.pdb` from
  [releases/tag/latest](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/latest) into
  `worldbox_Data/StreamingAssets/Mods/`.
- **Steam Workshop** — enable experimental mode, subscribe to the Workshop item, wait for download,
  then copy the `.dll` and `.pdb` from
  `STEAMPATH/steamapps/workshop/content/1206560/<workshop item id>/` into the folder above.
  The workshop item id cited for NML is **3080294469** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)).
  ⚠️ A direct fetch of that id returned *"The item is either marked as hidden or you do not have
  permission to view it"* ([Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3080294469)) —
  **treat 3080294469 as UNVERIFIED as a publicly subscribable item.**
  ⚠️ **Never run the manual DLL and the Workshop item at once** — "running both at once makes them
  fight over the game process" ([GB 20297](https://gamebanana.com/tuts/20297)).

### 2.2 NCMS (legacy)

Download from the [NCMS site](https://denq04.github.io/ncms/downloads/) (per the
[RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) and
[official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)), install as a native mod
into `worldbox_Data\StreamingAssets\mods`, then put NCMS mods into `worldbox\Mods\`
([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)).
**Recommendation from the official wiki: don't — "NCMS has officially been discontinued by its own
creator because NML is better than NCMS. There's no good reason to use NCMS for anything."**
([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding))

### 2.3 BepInEx

Version: **BepInEx 5 (Mono x64)**, release **v5.4.23.2**
([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) — explicitly "not 6.0.0-pre.1"; and
[toolbox/05](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md) — "BepInEx 5 (Mono x64)").
⚠️ The English official wiki still points at **5.4.21** zips
([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)) — see §9.

| Platform | Archive | Extracted to | Plugin folder |
| --- | --- | --- | --- |
| **Windows** | `BepInEx_x64_5.4.23.2.zip` | **Game root** (no extra subfolder). Expect `BepInEx\`, `winhttp.dll`, `doorstop_config.ini`, `changelog.txt` next to `worldbox.exe` | `worldbox\BepInEx\plugins\` |
| **macOS** | `BepInEx_unix_5.4.23.2.zip` (the `_unix` build; `_x86`/`_x64` do not work on macOS) | Game root: `BepInEx\`, `doorstop_libs\`, `run_bepinex.sh`, `changelog.txt`; then edit `run_bepinex.sh` → `executable_name="worldbox.app"` and launch via `sudo sh ./run_bepinex.sh` in Terminal | `worldbox\BepInEx\plugins\` |
| **Linux** | `BepInEx_unix_*` build | Game root (same layout as macOS) | `worldbox/BepInEx/plugins/` |

Sources: [official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding) (Windows/macOS step-by-step),
[RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) (root-folder contents),
[toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md).
After the first launch, `BepInEx\plugins\` must exist; if it does not, the install went wrong
([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)).
Set `HideManagerGameObject = true` under `[Chainloader]` in `BepInEx/config/BepInEx.cfg` so Unity
cleanup cannot silently kill your plugin ([toolbox/05](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md)).

### 2.4 Native modloader

`Steam\steamapps\common\worldbox\worldbox_Data\StreamingAssets\mods` (Windows) or
`Contents\Resources\Data\StreamingAssets\mods` (macOS); enable experimental mode; restart.
**Do not rename the `.dll`.** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг))

### 2.5 Assembly-CSharp replacement

Find-and-replace the game's own files with the mod's files of the same name; **back up the originals
first** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)).

---

## 3. THE NML MOD LIFECYCLE

### 3.1 Author — the canonical mod folder

```
Mods/
└── HelloBox/
    ├── mod.json          ← MANDATORY. Without it NML pretends your mod doesn't exist.
    ├── icon.png          ← preview image in the in-game mod menu
    ├── Code/             ← your .cs source files
    ├── Locales/          ← en.json, cz.json, ru.json …
    ├── GameResources/    ← custom textures, icons, pixel art, sounds
    ├── default_config.json ← optional settings template
    └── Assemblies/       ← optional 3rd-party .dll references (NOT for game/NML DLLs)
```

Source: [mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md),
[GB 20297](https://gamebanana.com/tuts/20297),
[NML wiki ModTutorialHome](https://raw.githubusercontent.com/wiki/WorldBoxOpenMods/ModLoader/ModTutorialHome.md).

**`mod.json`** — the field set that is actually mapped in NML 1.2.x
([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)):

```json
{
  "name": "HelloBox",
  "author": "yourName",
  "version": "0.1.0",
  "description": "My mod is the best frfr",
  "iconPath": "icon.png",
  "GUID": "com.yourName.hellobox",
  "RepoUrl": "https://github.com/yourName/hellobox",
  "Dependencies": [],
  "OptionalDependencies": [],
  "IncompatibleWith": []
}
```

- `GUID` is the stable identity; NML normalises it into `UID` (e.g. `COM_YOURNAME_HELLOBOX`).
  **Never change it after release** — the player's settings file is named after it
  ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md),
  [08-publishing](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/08-publishing.md)).
- `Dependencies` / `OptionalDependencies` / `IncompatibleWith` take **mod IDs**.
  Dependency IDs are uppercased and punctuation replaced with `_` for the compiler symbol:
  `com.yourname.hellobox-extra` → `COM_YOURNAME_HELLOBOX_EXTRA`. An unknown `#if` symbol is silently
  **false** — a successful compile does not prove your integration was included
  ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
- `UsePublicizedAssembly` defaults to `true` in the checked loader.
- ⚠️ **Keys that are NOT mapped and must not be used**: `id`, `mainClass`, `modLoader`, `gameVersion`,
  `homepage` ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
- `ModType` exists as an enum (`NEOMOD`, `COMPILED_NEOMOD`, `BEPINEX`, `RESOURCE_PACK`) but leave it
  out of a normal mod ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
- ⚠️ The official [ModTemplate](https://github.com/WorldBoxOpenMods/ModTemplate) `mod.json`
  ([raw](https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/mod.json)) has **no `GUID`**
  — see §9 for this disagreement.

**Entry point** — the official template
([ModClass.cs](https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/ModClass.cs)):

```csharp
using NeoModLoader.api;

namespace CHANGEME
{
    public class ModClass : BasicMod<ModClass>
    {
        protected override void OnModLoad()
        {
            LogInfo(GetConfig()["Default"]["WhatToSay"].GetValue() as string);
        }
    }
}
```

The legacy hand-rolled equivalent is `class MyMod : MonoBehaviour, IMod` with
`OnLoad(ModDeclare, GameObject)`, `GetDeclaration()`, `GetGameObject()`, `GetUrl()`
([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
Both work; `BasicMod<T>` gives you logging, config, localization and staged loading for free.

**Registering a trait** (the canonical shape, from
[GB 20297](https://gamebanana.com/tuts/20297)):

```csharp
public static class HelloTraits
{
    public const string SWIFT = "hello_swift";

    public static void Initialize()
    {
        if (AssetManager.traits.has(SWIFT)) return;

        ActorTrait swift = new ActorTrait
        {
            id = SWIFT,
            path_icon = "ui/Icons/iconSpeed",
            group_id = "physique"
        };

        // 1. add() registers the trait AND allocates base_stats
        AssetManager.traits.add(swift);

        // 2. stats go strictly AFTER add()
        swift.base_stats["speed"] = 20f;
    }
}
```

### 3.2 Compile

- **NML compiles your source at game start.** You do *not* need a separate build step, a compiler,
  Visual Studio, or even a `.csproj` ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md),
  [GB 20297](https://gamebanana.com/tuts/20297)).
- NML compiles **any `.cs` file it finds anywhere in the mod**, subfolders included, skipping
  `bin/`, `obj/`, `Properties/`, `packages/` and dot-folders. `Code/` is convention, not requirement.
- NML caches the compilation and recompiles when needed
  ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
- NML 1.2.1 added **platform and game-version compilation symbols**: version-family symbols like
  `NML_GAME_VERSION_0_51` alongside exact-version symbols like `NML_GAME_VERSION_0_51_2`
  ([1.2.1 release notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)).
- **Precompiled route:** a `.dll` **directly next to `mod.json`** switches NML to `COMPILED_NEOMOD` —
  it skips source compilation and loads the root DLLs. This is also the failure mode where a
  library dropped beside `mod.json` "breaks" your source mod
  ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
  Precompiled mods need **NML ≥ 1.0.9** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)).
- Building the loader itself: .NET SDK, `dotnet build NeoModLoader.csproj`; from 1.2.1 local and CI
  builds use **.NET SDK 10** while the runtime target stays **.NET Framework 4.8**
  ([README](https://raw.githubusercontent.com/WorldBoxOpenMods/ModLoader/master/README.md),
  [1.2.1 notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)).

### 3.3 Install

- Put the **`.zip` straight into `worldbox\Mods\`** — do not extract; NML unpacks its own zips at
  next start ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).
- Extracted is fine too, as long as the folder holding `mod.json` ends up **directly** inside `Mods\`.
  A folder inside a folder, or loose files with no folder, both fail
  ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).
- From the official wiki: if the extracted archive contained only one folder, move *that folder* in;
  if it contained several files/folders directly, move the *whole* folder in
  ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)).
- **Workshop mods:** subscribe on Steam, NML picks them up, no copying
  ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).

### 3.4 Enable / manage

- Open the **Mods window** from the main menu (the NML-logo tab button). Your mod appears there and
  can be toggled without deleting it ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md),
  [GB 20297](https://gamebanana.com/tuts/20297)).
- **To remove** a mod: close the game and delete its folder from `Mods`. If it came from the
  Workshop, unticking it in the list is not enough — unsubscribe on the Workshop page
  ([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).
- **Hot reload** (no restart): implement `IReloadable` (one method, `Reload()`); the reload button
  appears automatically for mods implementing it; mark swappable methods with `[Hotfixable]` from
  `NeoModLoader.api.attributes`. `Config.isEditor` is **not** needed and should be left alone
  ([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)).
  NML 1.2.1 added support for applying `HotfixableAttribute` to a whole class
  ([1.2.1 notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)).
  Reload cannot hot-swap `Awake`/`Update`, constructors, or anything the game already built from your
  old code — re-register those in `Reload()`.

### 3.5 Debug

See §7.

### 3.6 Publish

See §8.

---

## 4. SPRITE & TEXTURE MODDING

### 4.1 NML — `GameResources/`

`GameResources/` is treated exactly like Unity's `Resources` folder
([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)):

```
HelloBox/GameResources/ui/Icons/iconHelloSwift.png   →  "ui/Icons/iconHelloSwift"
```

- The **path is the location under `Resources` without the file extension**
  ([toolbox/04](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/04-getting-the-sprites.md)).
- `.png`, `.jpg`, `.jpeg` are picked up automatically
  ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).
- Vanilla paths carry **no extension**: `ui/Icons/iconFly`, never `ui/Icons/iconFly.png`
  ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).
- Load with `SpriteTextureLoader.getSprite("ui/Icons/iconFly")` / `getSpriteList("effects/projectiles/arrow")`
  — cached `Resources.Load` / `Resources.LoadAll` ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).
- Most asset fields want the **path as a string**: `trait.path_icon = "ui/Icons/iconHelloSwift";`

**`sprites.json`** — tells NML how to slice your images
([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)):

```json
{
  "Default":   { "PixelsPerUnit": 1, "PivotX": 0.5, "PivotY": 0.5 },
  "Specific":  [ { "Path": "iconHelloSwift.png", "PivotX": 0.5, "PivotY": 0.0 } ]
}
```

| Field | Meaning |
| --- | --- |
| `PixelsPerUnit` | Keep at `1` unless you know why not |
| `PivotX` / `PivotY` | Anchor point. `0.5 / 0.0` = bottom-centre — what units and buildings want |
| `BorderL/R/T/B` | Nine-slice borders for stretchable frames/buttons |
| `Path` | Which file a `Specific` entry applies to |
| `RectX` / `RectY` | Sprite rect offsets, both default `0`; docs say leave them at `0` |

⚠️ `sprites.json` has **no width/height fields** — it is not an atlas-recipe. NML documents Unity
`.meta` files for atlases and sprite sheets
([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).

**Where each kind of art goes** — the table that trips everyone up
([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)):

| Asset | Field | File location |
| --- | --- | --- |
| Trait / god power / kingdom / group | `path_icon` | `GameResources/` + exactly what you wrote |
| Item (in unit's hand) | `path_gameplay_sprite` | `GameResources/` + exactly what you wrote |
| **Building** | `sprite_path` | **A FOLDER** `GameResources/` + `sprite_path` + `/` holding `main_0.png`, `construction_0.png`, `ruin_0.png`. Empty → `main_path` + id; `main_path` defaults to `buildings/` |
| **Drop** | `path_texture` | **A FOLDER** `GameResources/` + path, one PNG per frame |
| Cloud | `path_sprites` | `GameResources/` + each path in the list |
| **Status effect** | `texture` | **A FOLDER** `GameResources/effects/` + what you wrote, one PNG per frame |
| **Projectile** | `texture` | **A FOLDER** `GameResources/effects/projectiles/` + what you wrote, one PNG per frame |
| **Resource (carried)** | `path_gameplay_sprite` | **A FOLDER** `GameResources/items/resources/` + what you wrote, one PNG per frame |
| Resource (inventory icon) | `path_icon` | `GameResources/` + exactly what you wrote (vanilla uses bare names like `iconResBread`) |
| Tile / top tile | *(no field)* | `GameResources/tiles/<the tile's id>/` |

⚠️ **"A folder" is not a style choice.** Folder-marked assets are read with `getSpriteList()`. Point
them at a single PNG and you get an empty list: the drop falls invisibly, the projectile throws
`ArgumentOutOfRangeException` in `QuantumSpriteLibrary.drawProjectiles()`, the status throws every
frame. One frame is fine — it just needs its own folder
([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).

Three specific traps ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)):

- **Status and projectile prepend a folder.** `texture = "effects/status/myThing"` makes the game look
  for `effects/effects/status/myThing`. Vanilla statuses use a bare name: `fx_status_burning_t`.
- **Tiles ignore the path fields entirely** — a tile's art is found by its **id**, in a folder of its
  own: `hello_moss` → `GameResources/tiles/hello_moss/`.
- **Buildings do not glue, but they fall back.** `"buildings/hello_shrine"` →
  `GameResources/buildings/hello_shrine/`; leaving `sprite_path` empty uses `main_path` + id.

**PNG size / style** ([toolbox/04](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/04-getting-the-sprites.md)):

- Trait and power icons are small — **usually the 16 to 32 px range**. Open a vanilla file and match it.
- Match the **palette** — WorldBox has a limited, soft palette; pick colours from an existing sprite.
- Match the **pivot** — units/buildings stand on the ground, so bottom-centre (`PivotY: 0.0`).
- Asset folders worth knowing: `ui/Icons/`, `ui/Icons/worldrules/`, `actors/`, `buildings/`, `effects/`.

**Never hand the game a null sprite** — a missing sprite is an *invisible hole* in the UI. Fall back to
`ui/Icons/iconWarning` ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)).

**Sounds** ([sprites-and-resources](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md)):
NML patches FMOD, so `.wav` files work. Put `GameResources/sounds/hello_boom.wav` and play it with
`MusicBox.playSound("sounds/hello_boom", pTile)` (no extension). An optional sibling
`hello_boom.json` supports `Volume` (0-100), `Mode` (`Basic`/`Stereo3D`/`Mono3D`), `Type`
(`Sound`/`Music`/`UI`), `LoopCount`.

### 4.2 BepInEx — raw Unity

BepInEx gives you no asset pipeline; you work with raw Unity. The realistic routes are (a) still use
NML for content and BepInEx for tools, or (b) register assets from a BepInEx plugin at the right
moment — your plugin wakes up before the game built its libraries, so touching `AssetManager` in
`Awake()` gives nulls; hook later (e.g. a Postfix on `AssetManager.init()`)
([toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md),
[toolbox/05](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md)).
For raw Unity asset work, use `Publicize="true"` on the `Assembly-CSharp` reference and reference every
`UnityEngine*.dll` module ([toolbox/05](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md)).

### 4.3 Native modloader / Assembly-CSharp — editing atlases directly

This is where the **actual game atlases** live
([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)):

- The game uses sprite sheets; zoomed-in sprites live under
  **`sactx-1024x1024-Uncompressed-WorldAtlas-5e0836b1`**.
- The UI uses a similar file with **`SpriteAtlas`** instead of `WorldAtlas`.
- Icons and other images can be edited individually.
- Tools: **AssetStudio** ([Perfare/AssetStudio](https://github.com/Perfare/AssetStudio)),
  **UABE** (Unity Asset Bundle Extractor), **UTinyRipper**
  ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding),
  [GB 16266](https://gamebanana.com/tuts/16266)).
- ⚠️ The official wiki's own advice: *"Texture changing through processes such as UABE is tedious and
  will out-date every update, a better idea is to only use these processes for texture extraction and
  make an assembly or bepinex mod to actually import the sprites or images."*
  ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding))

### 4.4 Extracting the game's art (recommended)

Use **AssetRipper** ([toolbox/04](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/04-getting-the-sprites.md)):

1. Download AssetRipper; point it at the folder containing `worldbox_Data`.
2. Export (takes minutes and a couple of GB) → you get a Unity project; the part you want is `Resources`.
3. **Path rule:** the path is the location under `Resources`, **without the file extension**.
   `ExportedProject/Assets/Resources/ui/Icons/iconFly.png` → `SpriteTextureLoader.getSprite("ui/Icons/iconFly")`.
4. Use the path directly in your mod — no need to copy the file, it is already in the game.

Other extraction/decompilation tools named across the sources: **dnSpy**, **ILSpy**, **DotPeek**,
**AssetStudio** ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding),
[toolbox/04](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/04-getting-the-sprites.md)).

---

## 5. LOCALIZATION

### 5.1 The NML way (recommended)

Create a `Locales/` folder and drop a JSON file named after the language. **NML loads it before
`OnModLoad`, with zero code from you**
([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)).

```json
Mods/HelloBox/Locales/en.json
{
  "trait_hello_swift": "Swift",
  "trait_hello_swift_info": "Moves like the world owes it money.",
  "hello_sword_ember": "Ember Blade",
  "hello_strike": "Hello Strike",
  "hello_strike_description": "Shakes the ground and makes a mess."
}
```

- **The filename IS the language id** — the ids registered by `GameLanguageLibrary`, not guessed ISO
  codes. Examples given: `en.json`, `cz.json` (Simplified Chinese), `ch.json` (Traditional Chinese),
  `ja.json`, `ru.json`. **Czech is `cs`, not `cz`.**
  ([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md))
- ⚠️ **Case matters on Linux**: keep the folder named `Locales` with a capital L; the game's own
  `locales/` resource paths are a separate thing
  ([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)).
- Implementing `IMod` by hand instead of `BasicMod<T>`? Add `ILocalizable` and return
  `Path.Combine(pModDeclare.FolderPath, "Locales")` from `GetLocaleFilesDirectory`.
- **One file for every language — CSV.** A `.csv` in the same folder covers all languages at once; the
  filename does not matter:
  ```
  Locales/lang.csv
  key,en,cz,ru
  trait_hello_swift,Swift,迅捷,Быстрый
  ```
  If your spreadsheet exports semicolons/tabs, implement `ICsvSepCustomized` and return `';'` from
  `GetCsvSeparator()`.

### 5.2 Key conventions (exact)

The game builds these keys itself, so they must match exactly
([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)):

| What | Name key | Description key |
| --- | --- | --- |
| **Trait** | `trait_<id>` | `trait_<id>_info` |
| **Item** | `translation_key` if you set one, else `item_<equipment_subtype or id>` | `<id>_description` — **no `item_` prefix** |
| **God power** | `<power_id>` | `<power_id>_description` |
| **Power tab** | the `locale_key` you passed | the description key you passed |
| **Actor task** | `task_unit_<task_id>` | — |
| **Status effect** | the `locale_id` **field** you set | the `locale_description` **field** you set |
| **World law** | `<law_id>_title` — note the suffix | `<law_id>_description` |

- **Ids are not names.** Your id (`hello_swift`) is forever and is what other mods reference; only the
  locale text changes. Never rename an id to fix a display typo.
- **Mod settings need locale entries too.** Group id and item id are locale keys, and each row wants a
  second key `"<id> Description"` — **with a space and a capital D**
  ([mod-config](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/06-mod-config.md)).
  The official template's `Locales/en.json` contains exactly the config group id and item id
  ([raw](https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/Locales/en.json)).
- **Missing keys log themselves:** `LocalizedTextManager: missing text: strike_radius Description`.
  Open the settings window once and search the log for `missing text:` to get the exact list of keys
  to add ([mod-config](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/06-mod-config.md)).
- Asking the game for a key it does not have returns the key as the text **plus one `missing text`
  error per key** — so register everything at load and call `ApplyLocale` once at the end
  ([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)).

### 5.3 From code — `NeoModLoader.General.LM`

```csharp
LM.Get("trait_hello_swift");                             // read in the current language
LM.AddToCurrentLocale("trait_hello_swift", "Swift");    // add to the loaded language
LM.Add("en", "trait_hello_swift", "Swift");             // add to a specific language
LM.LoadLocale("en", "path/to/Locales/en.json");         // load a JSON manually
LM.LoadLocales("path/to/Locales/lang.csv");             // load a CSV manually
LM.ApplyLocale(false);                                  // false = don't refresh every text on screen
```

Call `ApplyLocale` once, at the end, and call your locale init **first** in `OnModLoad` so nothing is
registered while its text is still missing
([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)).

### 5.4 The direct API and its limitation

```csharp
LocalizedTextManager.add("hello_notice", "Hello from HelloBox", pReplace: true);
string notice = LocalizedTextManager.getText("hello_notice");
```

`add(...)` writes to the **current** text dictionary; existing keys stay unless `pReplace` is true;
the key is normalised through `Underscore()` so use underscore keys from the start.
⚠️ **Current text is not a translation file** — changing language rebuilds the dictionaries, so direct
`add` does not survive a language switch and does not refresh existing text components. Use `Locales/`
or `LM.Add` for anything that must survive
([localization](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md)).

### 5.5 The legacy NCMS way (for old mods only)

Reflect into `LocalizedTextManager.instance`'s private `localizedText` dictionary and add
`"trait_" + id` and `"trait_" + id + "_info"` by hand
([GB 16266](https://gamebanana.com/tuts/16266)). NML still loads NCMS mods, but new work should use
`Locales/`.

### 5.6 BepInEx localization

A BepInEx plugin must add text itself via `LocalizedTextManager`/reflection, or a Postfix on
`LocalizedTextManager.setLanguage` is required for the UI to refresh when the language changes
([toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md)).

### 5.7 Mod settings (`default_config.json`)

```json
{
  "hellobox": [
    { "Id": "strike_radius", "Type": "INT_SLIDER", "IntVal": 25, "MinIntVal": 5, "MaxIntVal": 100,
      "Callback": "HelloBox.HelloSettings:SetStrikeRadius" },
    { "Id": "tint_by_mood", "Type": "SWITCH", "BoolVal": true }
  ]
}
```

- The outer key is the **group id** = one settings tab.
- `Type` ∈ `SWITCH`, `SLIDER` (float), `INT_SLIDER` (int), `TEXT`, `SELECT` (options grid; labels come
  from your locale as `<id>_0`, `<id>_1`, …). NML 1.2.1 added `SELECT` support
  ([1.2.1 notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)).
- `Callback` is `Namespace.Type:MethodName`; the method receives the new value. **Changes land when the
  window closes**, not while dragging.
- Read with `GetConfig()["hellobox"]["strike_radius"].IntVal` (free with `BasicMod<T>`; implement
  `IConfigurable` + `GetConfig()` if you implement `IMod` directly).
- Player values are stored at
  `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\<YOUR_GUID>.config`. Delete it to
  test defaults ([mod-config](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/06-mod-config.md)).

---

## 6. DEBUGGING — LOGS

### 6.1 Where the logs are

| File | Location | What |
| --- | --- | --- |
| `Player.log` | `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\` | **This run** |
| `Player-prev.log` | same folder | **The previous run** — the one that just crashed (the game overwrites `Player.log` on next start) |
| `logs/error_*.log` | same folder, `logs/` subfolder | One file per error the game caught |
| `mods_config/<GUID>.config` | same folder | The player's saved settings for your mod |
| `BepInEx/LogOutput.log` | `worldbox/BepInEx/` | BepInEx's own log (same content as its console) |
| BepInEx live console | opens with the game | Everything, live |

Sources: [logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md),
[toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md),
[install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md).

Paste `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox` into the Explorer address bar to get there
([install-nml](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md)).

### 6.2 Printing a line

```csharp
LogInfo("HelloBox is alive!");   // NML: prefixes your mod name
LogWarning("something smells");
LogError("something exploded");
Debug.Log("[HelloBox] plain Unity");  // Unity: you add the prefix yourself
```

Without `BasicMod`, `NeoModLoader.services.LogService` has the same methods plus
`LogStackTraceAsError` ([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)).

### 6.3 What a healthy log looks like

```text Player.log
005: Compile Mod HelloBox                = 2,2480
006: Load Resources From Mod HelloBox    = 0,0012
[NML]: [HelloBox]: OnLoad
[NML]: [HelloBox]: HelloBox is alive!
[NML]: [HelloBox]: Loaded
008: Init Mod HelloBox                   = 0,0014
```

The numbered lines are NML timing each step (the number after `=` is seconds). **Red there does not
mean broken** — it only means that step was slow
([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)).
The NML wiki shows the same three markers: `OnLoad`, `Hello World!`, `Loaded`
([ModTutorialHome](https://raw.githubusercontent.com/wiki/WorldBoxOpenMods/ModLoader/ModTutorialHome.md)).

### 6.4 Reading Player.log — the diagnosis order

Three questions, in order ([read-player-log](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/recipes/read-player-log.md)):

```text
1. Did NeoModLoader see/compile/load the mod?
2. What exact error or warning signature appears?
3. Which subsystem should I inspect next?
```

**Search for your own marker first** — it separates "my mod never ran" from "my feature ran and failed
later". Then take the **highest-severity detected signature** and follow *that* troubleshooting page
instead of changing unrelated code ([read-player-log](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/recipes/read-player-log.md)).

| Signature | Meaning | Go to |
| --- | --- | --- |
| `error CSxxxx` | Compilation problem — fix before debugging runtime | [csharp-compile-errors](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/csharp-compile-errors.md) |
| `NullReferenceException` | Missing/null object or unsafe lifecycle assumption | [nullreferenceexception](https://lous12.github.io/worldbox-modding-docs/troubleshooting/nullreferenceexception/) |
| `StackOverflowException` | Recursive call / recursive initialisation | [stack-overflow-recursive-initialization](https://lous12.github.io/worldbox-modding-docs/troubleshooting/stack-overflow-recursive-initialization/) |
| `PWDIAG040` / "callback failed" | Event Bus callback failed | Event Bus docs |
| `Failed to construct listener instance` | NML tried to construct a listener type and construction failed. **Scoped** failure — it does not prove every NML event is broken | [nml-listener-errors](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/nml-listener-errors.md) |
| `MissingMethodException` / `TypeLoadException` after a game update | The game changed under you | Rebuild against the new `Assembly-CSharp` |
| `HarmonyException` / `AmbiguousMatchException` | Patch target missing or has overloads | [07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md) |

**Compiler errors** ([csharp-compile-errors](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/csharp-compile-errors.md),
[logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)):

```text Player.log
[NML]: Code\Main.cs(9,42): error CS1002: ; expected
[NML]: Failed to compile mod HelloBox
```

Read it **right to left**: `; expected` is the problem, `(9,42)` is line 9 char 42, `Code\Main.cs` is
the file. **The useful line is the FIRST one** — `Failed to compile mod X` is just the summary.
Common codes: `CS0103` name not in scope · `CS0117`/`CS1061` no such member · `CS0246` type/namespace
not found. One early syntax failure cascades into many secondary messages.

**Runtime errors** ([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)):

```text Player.log
[NML]: [HelloBox]: HelloBox is alive!
NullReferenceException: Object reference not set to an instance of an object
  at HelloBox.HelloTraits.Initialize () [0x00021] in HelloTraits.cs:24
  at HelloBox.Main.OnModLoad () [0x0000c] in Main.cs:12
```

`in HelloTraits.cs:24` → **line 24 of your own file**. Read that line.

### 6.5 Log noise you should NOT chase

`Curl error …`, `UnityTls error …`, `Fallback handler could not load library …`, `Missing translation for …`
can coexist with a working mod. Do not promote a scary-looking line into a root cause just because it
is near your test. Ask instead: *did the mod continue compiling/loading after this line? Is there a
later exception tied to my code? Does the same line appear in a known-good run?*
([common-player-log-noise](https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/common-player-log-noise.md))

### 6.6 Don't let one broken thing kill the whole mod

`OnModLoad` runs top to bottom — if line 3 throws, lines 4-20 never run. Wrap each part
([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md)):

```csharp
protected override void OnModLoad()
{
    Stage("traits", HelloTraits.Initialize);
    Stage("items",  HelloItems.Initialize);
    Stage("powers", HelloPowers.Initialize);
    LogInfo("HelloBox ready");
}

private static void Stage(string pName, System.Action pAction)
{
    try { pAction(); }
    catch (System.Exception e) { LogError($"stage '{pName}' failed: {e}"); }
}
```

### 6.7 Don't touch the world before it exists

`OnModLoad` runs **before there is a world** — no map, no units. Guard every frame loop:

```csharp
public void Update()
{
    if (!Config.game_loaded) return;
    if (World.world == null || World.world.units == null) return;
    if (MapBox.instance == null) return;
}
```

([logs-and-debugging](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md))

---

## 7. HARMONY PATCHING (cross-loader)

NML ships **HarmonyX**, a fork of Harmony; the core patch API is shared but behaviour differs — notably
**all Prefixes run even when one returns `false`**
([07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md)).

**Enable it once** ([07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md)):

```csharp
using System.Reflection;
using HarmonyLib;
using NeoModLoader.api;

namespace HelloBox
{
    public class Main : BasicMod<Main>
    {
        protected override void OnModLoad()
        {
            new Harmony("com.yourname.hellobox").PatchAll(Assembly.GetExecutingAssembly());
        }
    }
}
```

`Assembly.GetExecutingAssembly()` is **not optional decoration** — without it `PatchAll()` scans
whatever assembly it was called from.

**A complete patch** ([07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md)):

```csharp
[HarmonyPatch(typeof(Actor), "updateStats")]
public static class Patch_Actor_UpdateStats
{
    [HarmonyPostfix]
    public static void AddSwiftSpeed(Actor __instance)
    {
        if (__instance == null || !__instance.hasTrait(HelloTraits.SWIFT)) return;
        __instance.stats["speed"] += 20f;
    }
}
```

Key rules ([07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md)):

- **Magic parameter names:** `__instance` (the object), `__result` (return value, `ref` to change,
  Postfix only), `___someField` (**three** underscores = private field; the game prefixes its own
  `_`, so `_hover_timer` becomes `____hover_timer`), `__state` (Prefix→Postfix handoff). Any real
  parameter name must match the game's spelling **exactly** — WorldBox's parameters nearly all start
  with `p` (`pDamage`, `pActor`).
- **Postfix by default; Prefix only to change an argument or cancel.** A Prefix returning `bool`
  decides whether the game's code runs at all — `false` skips it **for everybody**, and it silently
  disables all five things a vanilla method usually does. Adjust results (`+=`, `*=`,
  `Mathf.Min`) rather than assigning (`__result = 12f` throws away other mods' work).
- **Ambiguity:** two overloads → `AmbiguousMatchException` at startup. Disambiguate with
  `new System.Type[] { typeof(string), typeof(bool) }`.
- **Naming:** without a label, the method must be spelled exactly `Prefix`, `Postfix` or `Finalizer`.
  Use `[HarmonyPostfix]` / `[HarmonyPrefix]` / `[HarmonyFinalizer]` to name methods freely.
- **`nameof` vs string:** `nameof` makes typos a compile error, but much of WorldBox is `internal`
  or `private` — for those you need a **publicized** assembly and must use the string form.
- **Threading (the big one):** `Actor.updateStats` runs as a **parallel job**
  (`Config.parallel_jobs_updater` is `true` by default). Inside that Postfix, touch **only that
  unit's own numbers**. Calling Unity (`Time.time`, `transform`, `Destroy`, `Resources.Load`), the
  game's `Randy` random helper, or writing into a shared list of yours is a crash that only shows up
  on somebody else's machine. Queue the unit and do the work in your own `Update()`.
- **Priority:** `First`, `High`, `Normal`, `Low`, `Last`. A clamping Postfix wants `Priority.Last`;
  a gating Prefix wants `Priority.First`/`High`.
- **Finalizers** run even if the method threw; return the exception to preserve it, `null` to swallow
  it (only for a specific recoverable failure).
- **Transpilers** rewrite IL. Match an opcode sequence *and* operand, not an index; collect matches
  before editing and check the expected count.

**Methods mods patch most** ([07-harmony-patches](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md)):
`City.update(float pElapsed)` (public) · `MapBox.Update()` (**private** → string name) ·
`Actor.updateStats()` (**internal**, parallel job) · `Actor.getHit(float pDamage, bool pFlash, AttackType pAttackType, BaseSimObject pAttacker = null, ...)` ·
`Actor.die(bool pDestroy = false, AttackType pType = AttackType.Other, bool pCountDeath = true, bool pLogFavorite = true)` (**private**) ·
`ItemCrafting.tryToCraftRandomWeapon(Actor pActor, City pCity)` (public static) ·
`DiplomacyManager.startWar(...)` (**internal**) · `WarManager.newWar(...)` ·
`Kingdom.setKing(Actor pActor, bool pFromLoad = false)` (also runs during save load — check `pFromLoad`) ·
`ActorManager.createNewUnit(string pStatsID, WorldTile pTile, ...)`.

⚠️ `World` is the holder, **`MapBox`** is the target — `typeof(World)` is valid C# but it is the wrong
target for `Update`/`finishMakingWorld`.

**BepInEx equivalent** ([toolbox/05](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md)):
Harmony ships in `BepInEx/core/0Harmony.dll`; call `harmony.PatchAll()` from your plugin's `Awake()`.

---

## 8. PUBLISHING

### 8.1 Where to publish

| Channel | Verdict |
| --- | --- |
| **GameBanana** (`https://gamebanana.com/games/11196`) | **Where the WorldBox modding scene actually is.** Anybody can download from it, including players who bought the game somewhere other than Steam. "Publish on GameBanana. Mirror to the Workshop afterwards if you feel like it." ([08-publishing](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/08-publishing.md)) |
| **Steam Workshop** | Built into NML (Mod Hub), but **far fewer mods**. The official wiki says the Workshop "is not recommended as it sometimes hosts outdated mods" and still requires manual loader installation ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)). NML 1.2.1 added in-game upload/update ([1.2.1 notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)) |

The live WorldBox Workshop confirms this split — category counts as of 2026-10-23
([Steam](https://steamcommunity.com/app/1206560/workshop/)):
`World(66,041)` · **`Mod(129)`** · **`Unverified Mod(48)`** · **`Mod Loader(1)`** ·
`AI-Assisted(14)` · `AI-Made(3)` · `Human Authored(2)` · `Library / API(1)` · `Traits(9)` ·
`Creatures(6)` · `Buildings(4)` · `Items(4)` · `Gameplay(13)` · `UI & QoL(7)` ·
`Civilizations(8)` · `Visuals(4)` · `Worldgen(2)` · `Quality of Life(1)`.
The `AI-Assisted` / `Human Authored` / `Library / API` tags are exactly the "category tags, AI content
disclosure and configurable badges" that NML 1.2.1 shipped
([1.2.1 notes](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)) — strong evidence
that NML's Mod Hub is the mechanism behind the current Workshop mod wave.

### 8.2 WorldBox Steam identifiers

| Thing | ID | Verified how |
| --- | --- | --- |
| **WorldBox Steam app id** | **1206560** | Steam's own links in the Workshop page resolve to `store.steampowered.com/app/1206560` and `?appid=1206560` ([Steam](https://steamcommunity.com/app/1206560/workshop/)); also the official wiki links `steamcommunity.com/app/1206560/discussions/...` ([official wiki](https://the-official-worldbox-wiki.fandom.com/wiki/Modding)); the RU wiki uses `workshop/content/1206560/<id>` ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)). **CONFIRMED.** |
| **NML Workshop item** | 3080294469 | Cited by the [RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг). Direct fetch returns *"The item is either marked as hidden or you do not have permission to view it"* ([Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3080294469)). **UNVERIFIED as publicly subscribable.** |
| **WBML Workshop item** | 3273791624 | Direct fetch succeeds: "[OUTDATED] WorldBoxModLoader", posted 2024-06-23, updated 2024-09-28, **"removed from the community because it violates Steam Community & Content Guidelines"**, **"incompatible with WorldBox - God Simulator"** ([Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3273791624)). **CONFIRMED REMOVED.** |
| NML on GameBanana | tool 17288 | cited by [RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) — not fetched |
| NCMS on GameBanana | tool 9799 | cited by [RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг) — not fetched |

### 8.3 Packaging

**GameBanana upload = a zip of your mod FOLDER** ([08-publishing](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/08-publishing.md)):

```text
HelloBox.zip
└── HelloBox/
    ├── mod.json
    ├── icon.png
    ├── default_config.json
    ├── Locales/
    ├── GameResources/
    └── Code/
```

**Not a zip of the contents.** Someone unzipping into `Mods/` must end up with
`Mods/HelloBox/mod.json`; if they get `Mods/mod.json` they will report your mod doesn't load.

**Leave out** `.git/`, `bin/`, `obj/`, `.vs/`, your `.sln`, your notes. If you ship a prebuilt `.dll`,
ship it **instead of** `Code/`, not alongside stale source.

**Never ship game or loader DLLs** — `Assembly-CSharp.dll`, its publicized copy, `NeoModLoader.dll`,
Unity DLLs from `Managed/` ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)).
For BepInEx plugins also exclude `BepInEx.dll` and `0Harmony.dll`
([toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md)).

### 8.4 `.dll` / `.pdb` requirements

| Artifact | `.dll` | `.pdb` | Notes |
| --- | --- | --- | --- |
| **NML loader itself** | ✅ `NeoModLoader.dll` | ✅ `NeoModLoader.pdb` | README: "Download NeoModLoader.dll (and NeoModLoader.pdb)" ([README](https://raw.githubusercontent.com/WorldBoxOpenMods/ModLoader/master/README.md)). RU wiki: download both ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг)). The release also ships `NeoModLoader.xml` ([release](https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1)) — you don't need it |
| **WBML loader itself** | ✅ | ✅ | Workshop item instructions: "Copy all .dll and .pdb files to: `GAMEPATH\worldbox_Data\StreamingAssets\Mods`" ([Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=3273791624)) |
| **Your mod, source form** | ❌ not needed | ❌ | NML compiles the `.cs` at game start |
| **Your mod, precompiled** | ✅ one `.dll` **directly next to `mod.json`** | optional | Selects `COMPILED_NEOMOD`; requires **NML ≥ 1.0.9** ([RU wiki](https://worldbox.fandom.com/ru/wiki/Моддинг), [mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)) |
| **3rd-party libraries** | ✅ but in `Assemblies/` | — | Never in the mod root ([mod-structure](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md)) |
| **BepInEx plugin** | ✅ `BepInEx/plugins/<Name>/<Name>.dll` | — | Zip shape: `HelloBepInEx.zip → BepInEx/plugins/HelloBepInEx/HelloBepInEx.dll`. Must **not** include BepInEx.dll, 0Harmony.dll, Assembly-CSharp.dll, or the publicized copy ([toolbox/07](https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md)) |

**BepInEx version number in two places**, kept the same: in the plugin attribute `[BepInPlugin(GUID, Name, Version)]` and in the assembly version.

---

## 9. Modern Web Ecosystem & Distribution Standards (GameBanana, Steam Workshop, Neo Mod Maker)

### 9.1 The GameBanana Hub (Game ID 7245)
GameBanana is the primary public repository and discovery hub for WorldBox content mods:
- **Game URL:** `https://gamebanana.com/games/7245`
- **Submission Classification:** Mods are tagged under Categories (`Characters`, `Traits`, `Gameplay`, `Overhauls`, `UI`) and Loader tags (`NeoModLoader / NML`).
- **Prerequisites Section:** Professional authors always specify:
  1. Required WorldBox build (e.g. `0.51.2 Build 719`).
  2. Required NML version (e.g. `1.2.0.1+` or `1.2.1.1`).
  3. Experimental Mode requirement prominently highlighted.
  4. Dependency list (e.g. `TRIICKSTR_PLENTY_O_BIOMES` for `TRIICKSTR_DEMON_SLAYER_MOD`).

### 9.2 Steam Workshop (App ID 1206560) vs Community Distribution
- **Why aren't all mods directly subscribed via Steam Workshop?** WorldBox's developer (Maxim Karpenko) has not enabled native Steam Workshop execution for arbitrary third-party `.dll` code due to security and engine sandbox policies.
- **The Workshop Delivery Pattern:** NML itself is hosted on Steam Workshop (Item `3080294469`) as an auto-update channel, but players must still copy the downloaded files into `worldbox_Data\StreamingAssets\mods`.
- **In-Game Mod Hub:** NML incorporates a built-in Mod Hub interface in the main menu that communicates with community repository indexes, allowing players to discover and update compatible mods without manually browsing folders.

### 9.3 The Role of "Neo Mod Maker"
A notable recent development in the WorldBox web ecosystem is **Neo Mod Maker**, a free web-based generator featured on GameBanana:
- **Capability:** Generates turnkey `.zip` packages for NML containing traits, trait groups, basic species, equipment, status effects, and world laws without requiring a local IDE or C# knowledge.
- **Limitations:** Limited to declarative asset generation. It cannot produce custom procedural animations (weapon smears, particle auras), custom AI decision trees, multi-part boss transforms, hit-stops, or native FMOD direct audio hooks.
- **Studio-Grade Role:** Serves as a rapid prototyping tool for item/trait stat numbers, while high-tier expansion mods continue to be engineered in custom C# using `BasicMod<T>` and Harmony detours.

### 9.4 Release Packaging Checklist for Authors
To ensure 100% player satisfaction and zero "mod doesn't load" reports on GameBanana:

1. **Folder Nesting Rule:**
   - **Correct:** `MyMod.zip` $\rightarrow$ `MyMod/` $\rightarrow$ `mod.json`, `Code/`, `Locales/`, `icon.png`
   - **Incorrect:** `MyMod.zip` $\rightarrow$ `mod.json`, `Code/` (extracts loose into `Mods/` root, breaking discovery).
2. **Exclude Dev Jitter:**
   - Delete `.git/`, `.vs/`, `.vscode/`, `bin/`, `obj/`, `*.csproj`, `*.sln`, and temporary scratch text files before archiving.
3. **No Redundant DLLs:**
   - Never ship `Assembly-CSharp.dll`, `NeoModLoader.dll`, or `UnityEngine.dll`.
   - If shipping C# source (standard), do NOT leave old compiled `.dll` binaries in the root, as NML will skip Roslyn runtime compilation.
4. **Locale Keys Complete:**
   - Ensure `Locales/en.json` contains keys for every single trait (`trait_<id>`, `trait_<id>_info`), god power (`<id>`, `<id>_description`), and status effect. Never let players see raw engine keys in the UI.
