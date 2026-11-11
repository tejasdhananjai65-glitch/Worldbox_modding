# WorldBox Modding Research Repository Blueprint

> **Framework:** Elephant-and-Goldfish Model (EGM) Root Blueprint (Hay)  
> **Target Scope:** WorldBox Modding Engine, NeoModLoader (NML), Community Architectural Standards, and Master AI Modder Guidance  
> **Repository Root:** the skill root (the folder containing `SKILL.md`)

---

## 1. System Overview

This repository houses the ground-truth research, reverse-engineered engine specifications, empirical API evidence, and architectural blueprints for developing studio-grade mods for **WorldBox: God Simulator** (Unity 2022.3.60f1, Mono runtime) using the **NeoModLoader (NML)** C# compile-on-startup runtime framework.

It synthesizes findings from:
- Live byte-scanned game assemblies (`Assembly-CSharp-Publicized.dll`) and NML loader metadata.
- Empirical source code analysis of the most advanced community mods (`AdeptusAstartes`, `TURBO_SAKUGA / Combat Gods`, `PowerBox`, `_VILTRUM_EMPIRE`, `OnePunchMan CosmicFear`, `ShinobiBox: Reborn`, and `Godzilla`).
- Formal EGM architectural contracts ensuring reliable, autonomous mod authoring by AI agents and human engineers alike.

---

## 2. Core Knowledge Base & Component Documents

| Document | Format | Description / Interface |
|---|---|---|
| [00-master-ai-tour-guide.md](./00-master-ai-tour-guide.md) | EGM Master Guide | **The Master Tour Guide for AI & Developers**: Complete blueprints for resilient initialization, Harmony patching, custom races, god powers, combat feel (hit-stops, smears), direct FMOD audio, multi-part boss rigs, and localization. |
| [01-nml-api.md](./01-nml-api.md) | Technical Specification | Deep reverse-engineered specification of **NeoModLoader (NML)**: runtime compile pipeline, assembly references, folder conventions, lifecycle methods, and configuration systems. |
| [02-game-api.md](./02-game-api.md) | Engine API Reference | Complete reference for `Assembly-CSharp.dll` assets: 67 valid Stat IDs, `AssetManager` libraries, `ActorAsset`, `GodPower`, `ItemAsset`, and behavioral delegate hooks. |
| [03-web-corpus.md](./03-web-corpus.md) | Research Corpus | Curated web and community documentation covering official guides, GitHub repositories, and historical modding evolution (NCMS to NML). |
| [04-installed-mods-analysis.md](./04-installed-mods-analysis.md) | Empirical Analysis | Exhaustive comparative audit of community mods, scale metrics, common anti-patterns, and modern studio-grade architectural recipes. |
| [04-best-template-mod.md](./04-best-template-mod.md) | Template Blueprint | Structural specification of the ideal WorldBox mod template incorporating multi-language support, custom UI, and automated compile checks. |

---

## 3. Subdirectories & Working Workspaces

- [../samples/sample-mod/](../samples/sample-mod/): Baseline reference mod project demonstrating minimal working `mod.json` and basic power button registration.
- [../samples/sample-mod2/](../samples/sample-mod2/): Extended reference mod project featuring localized traits, custom status effects, and custom tab layouts.
- [../scripts/](../scripts/): Offline compile-check scripts. The Roslyn 4.9.2 Net472 compiler environment is restored on demand into `scripts/toolchain/` by `setup-toolchain.ps1`, giving a 2-second compile check without launching WorldBox.
- [evidence/eval-baseline/](./evidence/eval-baseline/): Empirical benchmarks, disassembled IL traces, and decompiled method catalogs used to verify engine behavior.

---

## 4. Global Invariants

- **INV-01 (Manifest Precedence):** Every mod root MUST contain a valid `mod.json` with `name`, `author`, `version`, and `iconPath`. Absence causes NML to silently discard the folder.
- **INV-02 (Stat Delta Semantics):** Trait stat modifications are additive deltas, and `multiplier_*` values are percentage modifiers. They must never be treated as absolute value assignments.
- **INV-03 (UI Deferral):** UI tabs, buttons, and windows must never be instantiated during `OnModLoad()`. Instantiation must be deferred to `Update()` once `Config.game_loaded && MapBox.instance != null`.
- **INV-04 (Granular Detouring):** Harmony patches must be processed per-class using `harmony.CreateClassProcessor(t).Patch()` inside a try-catch block to prevent a single patch failure from disabling all mod features.
- **INV-05 (World Lifecycle Hygiene):** All active transient game objects, procedural visual effects, camera modifications, and timers must be cleared when `MapBox.clearWorld` executes.
- **INV-06 (No DLL Artifacts in Source Mods):** Mods intended for source-level distribution must not leave leftover `.dll` files in their root, which causes NML to skip runtime compilation.

---

## 5. Global Side Effects

- **Filesystem Writes:** NML generates cached binaries at `worldbox_Data\StreamingAssets\mods\NML\CompiledMods\<GUID>.dll` and persists configuration at `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\<GUID>.json`.
- **Game Engine Mutators:** Dynamic registration into static `AssetManager` dictionaries permanently extends the running game session's asset dictionaries until game restart.
- **FMOD Audio Channels:** Direct audio playback via `FMOD.System.createSound` allocates audio channels on the master channel group.

---

## 6. System Verification

To verify that any mod authored against this research adheres to the compilation contract:

```powershell
# Run the 2-second offline Roslyn compile check
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill-dir>\scripts\compile-mod.ps1" `
  -ModPath "<path-to-target-mod>"
```

Target verification criteria:
- **Exit Code:** `0` (Zero errors, zero missing references).
- **Runtime Log:** `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log` reports `[NML]: Compile Mod <GUID> - Success` with no subsequent exceptions.
