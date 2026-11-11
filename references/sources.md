# Sources

Every claim in this skill traces to one of the sources below. Nothing here is recalled
from memory — it was read out of the live install or fetched from the web.

---

## 1. Local artifacts (primary — highest authority)

| Path | What it proves |
|---|---|
| `worldbox_Data\StreamingAssets\mods\NML\commit` | The exact NML revision in use: `02266fe8185d940c4065185de0a117c18975cf09`. |
| `worldbox_Data\StreamingAssets\mods\NeoModLoader.dll` | The loader itself — `IMod`, `BasicMod<T>`, `ModDeclare`, `LM`, `RF`, `PowerButtonCreator`, `TabManager`, the feature system. Read via Mono.Cecil metadata + IL, no execution. |
| `worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll` | The de-obfuscated + publicized game assembly. The source of every game API signature in `game-api.md`. |
| `worldbox_Data\StreamingAssets\mods\NML\Assemblies\` | The embedded toolchain: `Microsoft.CodeAnalysis*.dll` (Roslyn **4.9.2**), `0Harmony.dll` (**2.9.0**), `Mono.Cecil.dll`, `MonoMod.*`, `YamlDotNet`, `Facepunch.Steamworks.*`. |
| `worldbox_Data\StreamingAssets\mods\NML\CompiledMods\` | 27 compiled mod DLL/PDB pairs — proof that the runtime-compile path works. |
| `worldbox_Data\StreamingAssets\mods\NML\mod_compile_records.json` | NML's compile cache and its record schema. |
| `worldbox_Data\StreamingAssets\mods\NML\tab_order_records.json` | Power-tab ordering persistence. |
| `worldbox_Data\StreamingAssets\mods\NML\ModCompileLoadService` source (pinned checkout) | The exact compile pipeline: reference set, source discovery, output path, precompiled-DLL escape hatch, entry-class discovery, locale loading. |
| `worldbox_Data\Managed\Assembly-CSharp.dll` | The real game assembly (**Beebyte-obfuscated**). Source of the original (non-publicized) signatures. |
| `worldbox_data\Managed\Beebyte.Obfuscator.dll` | Proof that the game is obfuscated. |
| `worldbox_Data\globalgamemanagers` | Unity version **2022.3.60f1**. |
| `worldbox_Data\resources.assets` | The game's own localisation strings — the authoritative source for the locale key conventions in `game-api.md` §7. |
| `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log` | 4 MB of real runtime log: `Compile Mod` lines, `No mod.json file for folder`, `missing text:` keys, `Failed to construct listener instance`, and `Experimental mode is enabled`. |
| `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\` | Where per-mod player settings are persisted. |
| `Mods\` (20 installed mods) | Real working mods: `SCPBOX_MOD`, `TAYFIM_ABYSSFALL`, `_VILTRUM_EMPIRE`, `traitbox`, `CORE4777_COREBOX`, `AGRICHE_GODZILLA`, `TRIICKSTR_*`, `AVOIDINGBOREDOM_*`, `RAYTRACERX_SHINOBIBOX`, `TURBO_SAKUGA`, `INVASION_SUMMONER`, `KIVEN_CHEN_CLANSUCCESSION`. Source of every idiom in `patterns.md`. |
| `StreamingAssets\mods\ElementalPowersMod\` | A locally authored mod using the raw `IMod` interface — the source of the `tab.SetLayout` / `AddPowerButton` / `UpdateLayout` pattern. |
| `StreamingAssets\mods\NeoModLoader.AutoUpdate_memload.dll` | The auto-updater. Decompiled to recover `UpdateHelper.BackupFile` / `TryReplaceFile` / `GetDLLVersion` — the mechanism behind the loader-loss incident in `troubleshooting.md`. |
| `NML\mod_compile_records.json` | The `compile_environment` field — the real preprocessor symbols (`NML_WINDOWS`, `NML_GAME_VERSION_0_51_2`, `NML_GAME_VERSION_0_51`). |
| `NML\CompiledMods\COM_EXAMPLE_WORLDBOXMODDERTEMPLATE.dll` | The compiled output of the verification mod — proof the whole pipeline works. |

### Pinned upstream source

The loader source was cloned at the exact commit the live install reports:

```
https://github.com/WorldBoxOpenMods/ModLoader
  commit 02266fe8185d940c4065185de0a117c18975cf09
  local copy: <repo-root>\_tools\src-pinned\ModLoader-02266fe8185d940c4065185de0a117c18975cf09\
```

To re-pin after a loader update, read the new hash from `NML\commit` and check out that
revision.

---

## 2. Web sources

Fetched successfully. Ratings: 5 = authoritative and detailed, 1 = thin or outdated.

| URL | Contributed | Rating |
|---|---|---|
| https://github.com/WorldBoxOpenMods/ModLoader | The loader source itself, wiki, releases | 5 |
| https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1 | NML 1.2.1 release notes — Mod Hub upload, `SELECT` config type, Workshop tags | 5 |
| https://github.com/WorldBoxOpenMods/ModLoader/releases/tag/1.2.1.1 | The newest NML release at time of writing | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/01-mod-structure.md | Mod folder structure, `Assemblies\` rule | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/03-logs-and-debugging.md | Log format, healthy-log shape, staged-init pattern, world-not-ready guard | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/04-localization.md | Locale file naming, CSV format, key conventions, `ApplyLocale` discipline | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/05-sprites-and-resources.md | Sprite pipeline | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/06-mod-config.md | `default_config.json` schema, config locale rows, config file path | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/07-harmony-patches.md | HarmonyX rules, magic parameter names, threading warning, patch targets | 5 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/nml/08-publishing.md | Publishing channels, GameBanana packaging | 4 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/install-nml.md | Install paths per platform, log folder location | 4 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/04-getting-the-sprites.md | AssetRipper workflow, resource path rule | 4 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/05-bepinex-modding.md | BepInEx alternative | 3 |
| https://raw.githubusercontent.com/MarkamiBox/worldbox-modding-box/main/src/content/en/toolbox/07-bepinex-publishing.md | BepInEx packaging and log location | 3 |
| https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/recipes/read-player-log.md | The three-question diagnosis order, signature table | 5 |
| https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/csharp-compile-errors.md | How to read `error CSxxxx` lines | 5 |
| https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/common-player-log-noise.md | Which log noise to ignore | 4 |
| https://raw.githubusercontent.com/Lous12/worldbox-modding-docs/main/src/content/docs/troubleshooting/nml-listener-errors.md | `Failed to construct listener instance` is scoped | 4 |
| https://lous12.github.io/worldbox-modding-docs/troubleshooting/nullreferenceexception/ | NullReference triage | 4 |
| https://lous12.github.io/worldbox-modding-docs/troubleshooting/stack-overflow-recursive-initialization/ | Recursive-init failure mode | 3 |
| https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/mod.json | Canonical `mod.json` template | 5 |
| https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/ModClass.cs | Canonical entry class template | 5 |
| https://raw.githubusercontent.com/WorldBoxOpenMods/ModTemplate/master/Locales/en.json | Canonical locale file template | 5 |
| https://raw.githubusercontent.com/wiki/WorldBoxOpenMods/ModLoader/ModTutorialHome.md | Official mod tutorial | 4 |
| https://raw.githubusercontent.com/WorldBoxOpenMods/ModLoader/master/README.md | Loader distribution contents (`.dll` + `.pdb`) | 4 |
| https://the-official-worldbox-wiki.fandom.com/wiki/Modding | Official wiki modding page — the six mod systems, install paths, sprite extraction tools | 4 |
| https://worldbox.fandom.com/ru/wiki/Моддинг | Russian wiki — install paths, workshop item ids, precompiled-mod rules | 3 |
| https://gamebanana.com/tuts/20297 | NML + BepInEx guide (newer) | 4 |
| https://gamebanana.com/tuts/16266 | Legacy NCMS guide — concepts and the older localisation approach | 2 |
| https://gamebanana.com/games/11196 | GameBanana WorldBox hub — where the modding scene actually lives | 3 |
| https://steamcommunity.com/app/1206560/workshop/ | The live Workshop — confirms app id **1206560** and the current mod categories | 5 |
| https://steamcommunity.com/sharedfiles/filedetails/?id=3080294469 | NML Workshop item — returns "hidden or no permission", so **unverified as publicly subscribable** | 2 |
| https://steamcommunity.com/sharedfiles/filedetails/?id=3273791624 | WBML Workshop item — confirmed **removed** from the community | 4 |
| https://github.com/DipCrai/WorldBoxModLoader | The legacy WBML loader | 2 |
| https://denq04.github.io/ncms/downloads/ | Legacy NCMS downloads | 2 |
| https://github.com/Perfare/AssetStudio | Sprite extraction tool | 3 |
| https://api.github.com/repos/DipCrai/WorldBoxModLoader | Legacy loader repo metadata | 1 |

### Not fetched

Cited by other sources but not retrieved directly, so treat their details as unconfirmed:

- https://gamebanana.com/mods/ — the GameBanana mod listings themselves
- https://lous12.github.io/worldbox-modding-docs/ — the site root (individual pages above were fetched)

---

## 3. Where the sources disagree

- **`mod.json` field naming.** The GameBanana NML guide and the lous12 docs describe a
  slightly different field set from the one `ModDeclare` actually parses. The
  `ModDeclare` schema in `nml-api.md` §2 is the one that wins — it was read from the
  installed loader.
- **God power locale keys.** The NML `PowerButtonCreator` XML doc comment says
  `"{pId}"` and `"{pId} Description"` (space, capital D). That form is real, but only
  for **mod settings rows**. The game's own god powers use `<id>` and `<id>_description`,
  confirmed against `resources.assets`. The god power convention in this skill follows
  the game, not the doc comment.
- **NML version.** The installed loader is 1.2.0.1 while upstream has released 1.2.1 and
  1.2.1.1. Features added in 1.2.1 (Mod Hub upload, `SELECT` config type) may not exist in
  the installed build.
- **The installed `NeoModLoader.dll` is newer than the pinned commit** recorded in
  `NML\commit` — it contains types absent from that commit and from upstream `master`
  (notably `NeoModLoader.utils.Builders.*`). The installed DLL is treated as ground
  truth; the pinned source is used only to explain semantics.

---

## 4. Known gaps

- **The `IncompatibleWith` and `targetGameBuild` fields are declared but not
  implemented** by NML. Do not rely on them.
- **Races** are not implemented as a separate `Race` type in this build — the Cecil
  sweep found no `Race` type. Custom civs are built from `ActorAsset` +
  `AssetManager.actor_library`. Treat any "custom race" recipe with suspicion until
  verified against the live assembly.
- The exact **sprite size** the game expects for custom icons is not enforced by any
  loader code; 64×64 is the safe default observed in the community, not a hard
  requirement.
