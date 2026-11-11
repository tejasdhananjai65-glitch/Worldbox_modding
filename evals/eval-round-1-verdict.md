# Eval round 1 — `worldbox-modder` skill vs baseline

**Date:** 2026-10-23
**Eval prompt (identical for both arms):**
> "Make a WorldBox mod that adds a god power which turns villagers into giants. It should
> give the units on the clicked tile a new trait that makes them huge and fast."

**Arm A (producer):** a fresh worker agent with the skill loaded.
**Arm B (baseline):** a fresh worker agent with no skill, using only its own knowledge and
its own tools.
Neither was allowed to install into the game's `Mods\` folder or launch the game.

---

## 1. Is with-skill actually better?

**Yes — on time-to-working-mod and on repeatability.** Both arms eventually produced a
**correct, compiling** mod, so the skill does not change the outcome on this prompt; it
changes how long it takes and how much has to be rediscovered.

| Measure | With skill | Baseline |
|---|---|---|
| Files produced | 6 (mod.json, 2 × .cs, Locales/en.json, icon.png, sprite) | 41 — of which **35 are tooling and IL dumps**, only 6 are the mod |
| Bytes generated | ~7 KB of mod | **4.83 MB** of tooling + API dumps |
| Reverse-engineering tooling built | 0 (scripts supplied) | 5 PowerShell RE tools from scratch |
| Time to a compiling mod | one pass | ~50 minutes, and only after the dumps |
| Compile verification | `compile-mod.ps1` → **BUILD OK, exit 0** | built its own verifier → also **BUILD OK, exit 0** |
| Locale keys correct | yes | yes |
| Stat semantics correct (`scale` = visual size, `multiplier_*` = percentage) | yes | yes |

**The honest finding: the skill is a time-and-effort multiplier, not a correctness
differentiator on this prompt.** The baseline agent eventually got everything right —
but only after reverse-engineering the same facts the skill already contains.

**What the baseline had to build to get there:**

```
api/game-api-full.txt        2,264,773 bytes   every type in the game assembly
api/nml-api-full.txt           329,882 bytes   every type in the loader
api/il_assetlib_init.txt     1,481,271 bytes   IL of the asset library init
api/il_actor_addTrait.txt      250,591 bytes
api/il_traits_body.txt          69,768 bytes   <- the vanilla body-trait stat table
api/il_mergestats.txt            2,634 bytes   <- the stat arithmetic rule
api/types_traittype.txt           185 bytes   <- the TraitType enum
api/types_basestats.txt         1,610 bytes   <- BaseStats
tools/dump-il.ps1, dump-types.ps1, dump-strings.ps1, find-refs.ps1, list-types.ps1
```

Those four small files — `il_traits_body.txt`, `il_mergestats.txt`,
`types_traittype.txt` and `types_basestats.txt` — are exactly the facts a modder most
needs, and they took 50 minutes and 4.8 MB to extract by hand. **The skill now hands
them over ready-made in `references/game-api.md` §3 and `references/patterns.md` §4.**

**The compounding argument.** The skill's value is largest on the *second* mod, and on
any mod that touches a subsystem the first one did not. The baseline has to re-derive
the asset registry, the IL of every relevant method and the localisation conventions
for every new task; the skill holder re-reads two files.

---

## 2. Where the skill won

- **Procedure, not recall.** The skill's 8-step workflow went: locate install → check the
  loader is present → scaffold → entry class → register + unlock → localise → compile
  check → install + verify. The baseline had to *design* that sequence, and it built
  its own negative-control test harness to do it.
- **The compile-check loop.** `compile-mod.ps1` gave a verdict in ~2 seconds against
  NML's exact 187-assembly reference set.
- **Two-second feedback beats launch-the-game feedback.** The producer never needed to
  start WorldBox to know its code was correct.
- **The localisation convention.** Both arms got `<id>` / `<id>_description` right for
  the god power — the skill makes that a lookup rather than a derivation.
- **The stat semantics.** Both arms got `scale` vs `multiplier_*` right; the skill
  states it as a rule with the vanilla reference values, so there is nothing to
  re-derive.

---

## 3. Where the skill was worse — and what was fixed

The eval agent found real defects in the skill. **Every one was independently
re-verified against the live assembly before being fixed** — the eval was right on all
counts.

| # | Defect found by the eval | Verified? | Fix |
|---|---|---|---|
| 1 | `SKILL.md` named three `AssetManager` fields that **do not exist**: `actor_assets`, `powers_tab`, `races` | Confirmed — `actor_library`, `power_tab_library`, and no races field exist | `SKILL.md` now lists the real names and states explicitly that the three do not exist |
| 2 | `game-api.md` listed four **non-existent stat ids**: `fertility`, `endurance`, `age`, `vision` | Confirmed against all 67 registered `BaseStatAsset` ids | Replaced with the complete 67-id list; the real names are `offspring`/`birth_rate`, `stamina`, `age_adult`/`age_breeding`/`lifespan`, `range`/`throwing_range`/`damage_range` |
| 3 | The skill claimed a bad stat id is "silently ignored" | Wrong — `BaseStats.checkStatName` calls `Debug.LogError("… no asset with id: …")` | Corrected; the troubleshooting table now tells you to grep `Player.log` for `no asset with id` |
| 4 | `sprites-and-resources.md` §3 contradicted §2 and §4 about the icon path rule | Confirmed | Rewrote §3 as "Icons vs frame trees": icons follow the extension-less path rule; only `ActorTextureSubAsset` uses a trailing-slash base path |
| 5 | **The biggest gap: nothing explained how to make a unit huge or fast** | Confirmed against `Actor.updateStats` / `updateChangeScale` / `finishScale` / `getMassKG` / `BaseStats.mergeStats` / `checkMultipliers` | Added `game-api.md` §3 "Stat arithmetic", `patterns.md` §4, and a `SKILL.md` callout: stats are **deltas**, `multiplier_*` are **percentages**, `scale` is the **visual size** (reference 0.1) and `size` is the **hitbox** — plus the vanilla body-trait values (`giant` = `scale +0.05`, `multiplier_health +0.5`, `multiplier_speed −0.25`, etc.) |
| 6 | `new-mod.ps1` did **not** rewrite the `my_mod_tab` placeholder | Confirmed — every scaffolded mod would have claimed the same tab id | Added `my_mod_tab` → `<prefix>_tab` to the rename map |
| 7 | The generated `mod.json` was written with a UTF-8 **BOM** | Confirmed | `new-mod.ps1` now writes UTF-8 without BOM for every file it generates |
| 8 | `SKILL.md` cited a stale commit hash (`02266fe8`) as if current | Confirmed — the live install is now `f6017bdc` (1.2.1.1) | `SKILL.md` now names both commits, tells the reader to **read** `NML\commit` rather than assume, and says to re-verify if it differs from both |
| 9 | The step-6 snippet used an unqualified `List<string>` | Minor | Now `System.Collections.Generic.List<string>` |
| 10 | The template ships demo content a modder did not ask for (notably a status effect) | Fair | `patterns.md` §14 now lists exactly what the scaffold ships and what to delete; the template's trait now demonstrates `scale` / `multiplier_speed` instead of a bare stat bump |

**Did the skill overfit or constrain judgement?** No. The eval agent used the skill as a
starting point and made its own design decisions (it chose its own mod id
`com.example.giantpower`, its own namespace, its own sprite). The skill supplied facts
and a checklist, not a fixed output shape.

**Token use.** The with-skill arm spent fewer tokens than the baseline would have needed
to finish, because the baseline was emitting 4 MB of IL dumps — most of which the skill
already contains in distilled form. The with-skill arm did read the full 46 KB
`references/nml-api.md` and 16 KB `references/game-api.md`, which is a real cost, but it
bought a finished, compiling mod.

---

## 4. Improvements made after this round

### 4a. Ten defects found by the eval agent (all fixed and re-verified)

All ten fixes above are applied. The skill was re-linted and re-verified after the
changes:

```
node .../skill-creator/scripts/lint-skill.js .../skills/worldbox-modder
✓ All checks passed
```

### 4b. An eleventh defect, found by the in-game verification instead

`install-mod.ps1` used `Copy-Item -Path $src -Destination $dest -Recurse -Force`.
When the destination already exists, PowerShell copies the **source folder itself into**
the destination, leaving the previous version's `.cs` files in place:

```
Mods\com_example_worldboxmoddertemplate\
├── Code\Main.cs                    <- old
└── com_example_worldboxmoddertemplate\
    └── Code\Main.cs                <- new
```

NML compiles every `.cs` file under the mod folder, so both copies landed in the same
namespace and the mod failed with `error CS0101: The namespace … already contains a
definition for 'Main'`.

**No offline check could have caught this** — the compile check runs against the source
folder, not the installed copy. Only launching the game exposed it.

**Fix:** `install-mod.ps1` now mirrors the source onto the destination with
`robocopy.exe /MIR`, which replaces the contents exactly and removes leftovers.
Re-verified in game: the installed tree is clean and the mod compiles and loads.

This is a concrete argument for keeping the in-game tier of the verification loop even
when the offline tier passes.

### 4c. Re-verified after all fixes

- `templates/minimal-mod` → `BUILD OK`, exit 0
- `sample-mod\com_example_worldboxmoddertemplate` → `BUILD OK`, exit 0
- the eval producer's independently written `com_example_giantpower` → `BUILD OK`, exit 0
- scaffold → compile loop → `BUILD OK`, exit 0, **no leftover placeholders**, **no BOM**
- all four scripts pass a PowerShell AST syntax check
- in-game: compile → resource load → `OnLoad` → marker → power tab created → Init →
  Post-Init, **no exception, no compile failure**

## 5. Should a script be bundled?

Yes — already done. The eval confirmed the highest-value bundled script is
`compile-mod.ps1`: it is the deterministic local step that turns "I think this compiles"
into "this compiles, with NML's own reference set", in about two seconds, without
launching the game. `new-mod.ps1` and `install-mod.ps1` remove the two other
mechanical steps that would otherwise be re-derived every time.

## 6. What the baseline arm contributed — and where it was wrong too

The baseline report surfaced two facts the skill did not have, both now added:

1. **The default god-power brush is `circ_5` — an 11×11 block, not a single tile.**
   "Units on the clicked tile" is really "units in an 11×11 area". `force_brush = "circ_0"`
   gives exactly one tile. This is now in `SKILL.md` step 4, `patterns.md` §5 and
   `game-api.md` §4. It is the kind of thing that makes a mod behave differently from
   its own description.
2. **`ui/Icons/actor_traits/iconGiant`** is the base game's own icon for the vanilla
   `giant` trait — added to the known-good paths list.

And the baseline made two claims that are **wrong**, caught by re-verification:

| Baseline claim | Verdict |
|---|---|
| "`addTrait(string, bool)` is the only overload, so `actor.addTrait(TraitId)` does not compile" | **False.** The second parameter has a default (`optional=True, const=False`). The one-argument call is legal and equivalent to `addTrait(id, false)` — which is why the template and the installed sample mod both compile and run. |
| "Setting `base_stats` *before* the `add()` call would have thrown" | **False.** `BaseTraitLibrary<T>.add` only allocates `base_stats` when it is still null, so setting it beforehand is safe. The skill's "before **or** after" guidance stands. |
| "An unknown stat id throws a NullReferenceException" | **True, and the skill was incomplete.** `BaseStats.set` dereferences the null `BaseStatAsset` with no guard — so it throws *after* `checkStatName` has already logged `no asset with id: <id>`. The skill now states both: the error line and the throw. |

The full `Actor::create` scale pipeline was also pinned down from IL, and is now in
`game-api.md` §3:

```
setActorScale( asset.base_stats["scale"] * 0.6f );   // start at 60% of target
if (asset.finish_scale_on_creation) { target_scale = base_stats["scale"]; finishScale(); }
```

## 7. Should there be a round 2?

**No.** The skill reaches the same correctness as the baseline with roughly two orders
of magnitude less work, and the eval found no remaining *wrong* facts — only gaps,
which have been filled and re-verified. A second round would most likely re-confirm the
same result.

The one thing a round 2 would add is a **second, different prompt** (a custom species
or a Harmony patch rather than a god power), to check the skill covers the harder
subsystems as well as the common path. That is the recommended follow-up, not a
correction.
