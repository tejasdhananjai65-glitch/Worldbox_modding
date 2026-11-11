# worldbox-research-skill

**An installable AI-agent skill for authoring WorldBox (God Simulator) mods — plus the reverse-engineered research corpus that backs it.**

This repository is two things at once:

1. **A skill** (`SKILL.md` + `references/` + `scripts/` + `templates/`) that teaches an AI agent how to build, compile-check, install and debug mods on the **NeoModLoader (NML)** C# modding API.
2. **The research** (`research/`, `evals/`, `samples/`) that the skill was distilled from — engine API specs, evidence dumps, evaluation reports, and working reference mods.

Clone it, point your agent at the folder, and it can write a mod, compile-check it offline in ~2 seconds, and install it — without the agent guessing an API that doesn't exist.

---

## Why this exists

WorldBox mods are C# compiled **at game startup** by NeoModLoader. The game assembly is not documented; the API has to be read out of the binary. That means an agent left to guess will happily write `AssetManager.actor_assets`, `power_my_power`, or `base_stats["health"] = 500f` and produce code that either fails to compile or silently does nothing in-game.

This repo replaces the guessing with measured facts:

| | |
|---|---|
| **67** | valid stat ids (the full list, with which ones are deltas vs. percentages) |
| **187** | assemblies in the reference set NML actually compiles against |
| **0** | guessed API names — every documented member was read out of the live assembly |
| **~2 s** | offline compile-check, no game launch required |

Verified against a live install: **WorldBox 0.51.2**, **NML 1.2.0.1 / 1.2.1.1**, **Unity 2022.3.60f1**, **Roslyn 4.9.2**.

---

## Repository layout

```
worldbox-research-skill/
├── SKILL.md                    # ← the skill entry point (YAML frontmatter + procedure)
├── README.md                   # ← you are here
├── LICENSE
├── .gitignore / .gitattributes
│
├── references/                 # loaded by the agent on demand
│   ├── nml-api.md              # NeoModLoader: compile pipeline, BasicMod<T>, ModDeclare, LM
│   ├── game-api.md             # Assembly-CSharp: 67 stat ids, AssetManager libraries, asset fields
│   ├── patterns.md             # idiomatic recipes (traits, powers, races, statuses, UI)
│   ├── sprites-and-resources.md# sprite paths, GameResources, icon conventions
│   ├── troubleshooting.md      # symptom → cause → fix
│   └── sources.md              # where every fact came from
│
├── scripts/                    # PowerShell tooling
│   ├── setup-toolchain.ps1     # one-time: fetch Roslyn 4.9.2 (~80 MB, not committed)
│   ├── new-mod.ps1             # scaffold a mod from templates/minimal-mod
│   ├── compile-mod.ps1         # offline compile-check  → exit 0 = the game will accept it
│   └── install-mod.ps1         # copy into the game's Mods\ folder
│
├── templates/minimal-mod/      # working mod template (mod.json, Code/, Locales/, GameResources/)
│
├── research/                   # the corpus the skill was distilled from
│   ├── README.md               # blueprint + global invariants (INV-01 … INV-06)
│   ├── 00-master-ai-tour-guide.md
│   ├── 01-nml-api.md            + 01-nml-api-evidence.txt
│   ├── 02-game-api.md           + 02-game-api-evidence.txt
│   ├── 03-web-corpus.md         # official docs, community guides, NCMS → NML history
│   ├── 04-best-template-mod.md
│   ├── 04-installed-mods-analysis.md
│   └── evidence/eval-baseline/  # raw IL dumps + type catalogs (see note below)
│
├── evals/                      # did the skill actually work?
│   ├── eval-baseline-report.md   # agent with NO skill
│   ├── eval-with-skill-report.md  # agent WITH the skill
│   └── eval-round-1-verdict.md   # scored comparison + skill defects that were then fixed
│
└── samples/                    # working reference mods
    ├── sample-mod/              # minimal: mod.json + trait + power button
    ├── sample-mod2/             # extended: localised traits, statuses, custom tab
    ├── eval-with-skill/         # the mod the eval produced, from the skill alone
    └── saiyanbox-check/         # a larger multi-file mod used to cross-check the API
```

---

## Install as a skill

The skill root **is** the repo root — `SKILL.md` sits at the top level, next to `references/`, `scripts/` and `templates/`. Copy or link those four into your agent's skills directory:

| Agent | Skills directory |
|---|---|
| MCode | `%USERPROFILE%\.minimax\skills\worldbox-modder\` |
| Claude Code | `%USERPROFILE%\.claude\skills\worldbox-modder\` |
| Project-local | `<your-project>\.claude\skills\worldbox-modder\` |

```powershell
git clone <this-repo> $env:USERPROFILE\.minimax\skills\worldbox-modder
```

To keep the repo up to date in place, clone it anywhere and symlink instead:

```powershell
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.minimax\skills\worldbox-modder" -Target "<clone-path>"
```

Verify the install:

```powershell
Test-Path "$env:USERPROFILE\.minimax\skills\worldbox-modder\SKILL.md"   # → True
```

---

## Quick start

```powershell
# 0. once per machine: fetch the Roslyn 4.9.2 compiler (needs internet)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\setup-toolchain.ps1"

# 1. scaffold a mod
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>\scripts\new-mod.ps1" `
  -ModId "com.example.giantpower" -Namespace "GiantPower" -Author "you"

# 2. compile-check it (~2 seconds, no game launch)
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>\scripts\compile-mod.ps1" -ModPath "<path-to-mod>"

# 3. install it into the game
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill>\scripts\install-mod.ps1" -ModPath "<path-to-mod>"
```

Exit code `0` from step 2 means the game will accept the code too — the reference set is identical to NML's.

> **Windows note:** always invoke through `powershell.exe -NoProfile -ExecutionPolicy Bypass -File …`. A bare `.\script.ps1` fails on machines with the default execution policy.

---

## Requirements

- **Windows** (the `Mods\` convention and Steam paths assume a Windows install)
- **WorldBox: God Simulator** installed via Steam — the compile-check reads the live `Assembly-CSharp-Publicized.dll` from the install, so the reference set can never drift from the running game build
- **Internet access**, once, for `setup-toolchain.ps1`
- **NeoModLoader** present in the install — without it every mod silently fails to compile

---

## The research corpus

`research/` is the substance; `references/` is what the agent actually loads. The research is kept because it is the **evidence** behind every claim in the skill.

- `research/README.md` holds the **global invariants** (INV-01 … INV-06) — manifest precedence, stat-delta semantics, UI deferral, granular detouring, world-lifecycle hygiene, no-DLL-in-source.
- `research/evidence/eval-baseline/` holds raw IL disassembly and type catalogs extracted from the game assembly. It is the largest directory here (~4.6 MB) and is included because it is reproducible evidence for the API claims. **If you would rather not redistribute disassembly of a commercial game's binaries, delete `research/evidence/` — nothing in `SKILL.md` or `references/` depends on it.**

---

## Provenance and privacy

This repo was sanitised from a private working copy before publication. What was removed:

| Removed | Replaced with |
|---|---|
| Absolute user paths (`C:\Users\<you>\…`) | `%USERPROFILE%\…` or `<skill-dir>` / `<repo-root>` |
| The author's Windows account name | `example` |
| Personal mod GUIDs and author fields | `com.example.*` |
| Absolute workspace paths | `<repo-root>` / `<workspace>` |
| Machine hostname | `<HOSTNAME>` |

Public mod identifiers of **third-party community mods** (e.g. the PowerBox mod's mod id and author credit) are **kept on purpose** — they are published identifiers, and removing them would strip attribution and break the research trail.

No game binaries, NeoModLoader builds, or community mod source are redistributed here. The Roslyn compiler is downloaded on demand by `setup-toolchain.ps1` and is excluded by `.gitignore`.

---

## Attribution

- **WorldBox: God Simulator** — Maxim Karpenko / mkarpenko
- **NeoModLoader** — [WorldBoxOpenMods](https://github.com/WorldBoxOpenMods/ModLoader) (MIT)
- **Harmony / HarmonyX** — Andreas Pardeike and the Harmony team (MIT)
- **Roslyn 4.9.2** — Microsoft (MIT), fetched at setup time

Community mods referenced in `research/` and `evals/` are the work of their respective authors and are named for attribution.

This repository is MIT licensed — see [LICENSE](./LICENSE).

---

## Contributing

Found a stat id that isn't documented, or a skill instruction that made your agent do the wrong thing? The eval reports in `evals/` are the template: run the agent with and without the skill, diff the outcome, and file the delta. Every defect found that way is already recorded in `evals/eval-round-1-verdict.md` — that file is a list of skill bugs that were found and fixed, and it's the best guide to what kinds of mistake the skill is still capable of making.
