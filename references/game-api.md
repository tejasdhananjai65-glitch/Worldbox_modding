# WorldBox Game API — Reference

Everything here was read out of the **live** game assembly
(`worldbox_Data\Managed\Assembly-CSharp.dll`) and its publicized copy
(`StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll`) with Mono.Cecil, and
cross-checked against 20 real installed mods.

The game assembly is **Beebyte-obfuscated**. NML ships a *publicized* copy
(`Assembly-CSharp-Publicized.dll`) that also exposes `internal` members, so a mod can
touch members the raw assembly hides. Compile against that — NML does it automatically
unless `mod.json` sets `UsePublicizedAssembly: false`.

> **Type names below are the real ones.** The obfuscator renames *method bodies and
> fields*, but public type names and most public members keep readable names because
> mods depend on them.

---

## 1. Where everything registers: `AssetManager`

`AssetManager` is the single registry. Every library is a public static field. This is
the complete list — it is the index of everything a mod can add to the game.

### Content you will actually use

| Field | Type | Adds |
|---|---|---|
| `AssetManager.traits` | `ActorTraitLibrary` | actor traits (the big one) |
| `AssetManager.trait_groups` | `ActorTraitGroupAsset` → `ActorTraitGroupLibrary` | trait-group tabs |
| `AssetManager.powers` | `PowerLibrary` | god powers |
| `AssetManager.status` | `StatusLibrary` | status effects |
| `AssetManager.actor_library` | `ActorAssetLibrary` | species / creature types |
| `AssetManager.buildings` | `BuildingLibrary` | buildings |
| `AssetManager.items` | `ItemLibrary` | equipment |
| `AssetManager.kingdoms` | `KingdomLibrary` | kingdoms |
| `AssetManager.power_tab_library` | `PowerTabLibrary` | power tabs |
| `AssetManager.world_laws_library` | `WorldLawLibrary` | world laws |
| `AssetManager.plots_library` | `PlotsLibrary` | story plots |
| `AssetManager.projectiles` | `ProjectileLibrary` | projectiles |
| `AssetManager.spells` | `SpellLibrary` | spells |
| `AssetManager.options_library` | `OptionsLibrary` | player options |
| `AssetManager.achievements` | `AchievementLibrary` | achievements |

### Trait libraries, per creature category

`culture_traits`, `culture_trait_groups`, `language_traits`, `language_trait_groups`,
`subspecies_traits`, `subspecies_trait_groups`, `clan_traits`, `clan_trait_groups`,
`religion_traits`, `religion_trait_groups`, `kingdoms_traits`, `kingdoms_traits_groups`,
`trait_rains`, `personality`/`personalities`, `professions`, `drops`.

### Everything else

`architecture_library`, `achievement_groups`, `architect_mood_library`, `armies_colors_library`,
`base_stats_library`, `behavior`/`behaviour_task_*` (`job_actor`, `tasks_actor`, `job_city`,
`tasks_city`, `job_kingdom`, `tasks_kingdom`), `biome_library`, `book_types`, `brush_library`,
`building`/`buildings`, `city_build_orders`, `clan_colors_library`, `clan_banners_library`,
`cloud_library`, `color_style_library`, `combat_action_library`, `communication_library`,
`culture_banners_library`, `culture_colors_library`, `decisions_library`, `dynamic_sprites_library`,
`effects_library`, `era_library`, `families_colors_library`, `family_banners_library`,
`happiness_library`, `hotkey_library`, `items_modifiers`, `item_groups`, `job_*`,
`knowledge_library`, `languages_colors_library`, `language_banners_library`, `linguistics_library`,
`list_window_library`, `loyalty_library`, `map_gen_settings`, `map_gen_templates`, `map_sizes`,
`meta_*`, `month_library`, `music_box`, `name_generator`, `name_sets`, `nameplates_library`,
`onomastics_library`, `opinion_library`, `phenotype_library`, `plots_library`,
`plot_category_library`, `quantum_sprites`, `rarity_library`, `religion_banners_library`,
`religion_colors_library`, `resources`, `signals_library`, `sim_globals_library`,
`species`/`subspecies_colors_library`, `spells`, `story_library`, `terrain`/`tiles`,
`terraform`, `tester_jobs`, `tester_tasks`, `time_scales`, `tooltips`, `top_tiles`,
`unit_hand_tools`, `war_types_library`, `words_library`, `world_age`/`era_library`,
`world_behaviours`, `world_law_groups`, `world_log_library`.

Each library exposes `add(T asset)` returning the asset, and `get(string id)` returning
`T` or null.

---

## 2. Traits

```csharp
ActorTrait trait = new ActorTrait();
trait.id = "giant_trait";                 // Asset.id
trait.group_id = "giant_group";           // BaseAugmentationAsset.group_id
trait.path_icon = "ui/icons/iconGiant";   // BaseUnlockableAsset.path_icon
trait.base_stats = new BaseStats();       // BaseUnlockableAsset.base_stats
trait.base_stats["health"] = 500f;

AssetManager.traits.add(trait);           // registers it
trait.unlock(true);                       // makes it player-selectable
```

**Fields worth knowing**

| Field | Declared on | Notes |
|---|---|---|
| `id` | `Asset` | the identity string; other mods reference it |
| `group_id` | `BaseAugmentationAsset` | which trait-group tab it appears under |
| `path_icon` | `BaseUnlockableAsset` | resource path, no extension |
| `base_stats` | `BaseUnlockableAsset` | the stat block |
| `base_stats_meta` | `BaseTrait<T>` | stats shown in the meta editor |
| `type` | `ActorTrait` | `TraitType` — `Positive` / `Negative` / `Other`. This is the bucket the trait editor sorts traits into; a buff is `Positive`. |
| `rarity` | `BaseTrait<T>` | `Rarity` |
| `can_be_given` / `can_be_removed` | `BaseAugmentationAsset` | whether the player may grant/remove it |
| `special_icon_logic`, `special_locale_description` | `BaseTrait<T>` | advanced |
| `action_growth`, `action_birth`, `action_death` | `BaseTrait<T>` | `WorldActionTrait` callbacks |
| `opposite_list`, `opposite_traits` | `BaseTrait<T>` | mutually exclusive traits |
| `traits_to_remove_ids` | `BaseTrait<T>` | traits removed when this one is added |

**Registration order.** `AssetManager.traits.add(trait)` calls
`AssetLibrary<T>.add` and then, *only if still null*, allocates `base_stats` and
`base_stats_meta`. So you may set stats before **or** after the `add()` call. Calling
`add()` twice registers two assets with the same id — prefer the idempotent form:

```csharp
ActorTrait existing = AssetManager.traits.get("giant_trait");
if (existing == null) { /* create + add */ }
```

**`unlock(bool pSaveData)`** lives on `BaseUnlockableAsset` and returns `bool`. Pass
`true` so the unlock persists to the save.

**Trait groups** — a tab in the trait editor:

```csharp
ActorTraitGroupAsset group = new ActorTraitGroupAsset();
group.id = "giant_group";
group.name = "trait_group_giant_group";   // locale key
group.color = "#ff8c00ff";
AssetManager.trait_groups.add(group);
```

`name` and `color` come from `BaseCategoryAsset`.

---

## 3. Stats — `BaseStats`

`BaseStats` is a stat bag with a string indexer.

| Member | Purpose |
|---|---|
| `set(string, float)` | set a stat (`stats["health"] = 500f`) |
| `get(string)` | read a stat |
| `hasStat(string)` | does the stat exist |
| `getList()` | all stats as a list |
| `mergeStats(BaseStats, float)` | merge another bag with a multiplier |
| `hasTag(string)` / `hasTags(string[])` | tag checks |
| `normalize()` / `clear()` | bulk operations |

### The complete list of valid stat ids

Extracted from `BaseStatsLibrary::init` — every `ldstr` that is stored into a
`BaseStatAsset.id`. **67 ids. Using anything else logs an error.**

```
accuracy              age_adult             age_breeding          area_of_effect
armor                 army                  attack_speed          birth_rate
bonus_towers          cities                construction_speed    critical_chance
critical_chance_multiplier                    critical_damage_multiplier
damage                damage_range          diplomacy             experience
happiness             health                intelligence          knockback
lifespan              limit_clan_members    limit_population      loyalty
loyalty_mood          loyalty_traits        mana                  mass
mass_2                maturation            max_nutrition         metabolic_rate
multiplier_attack_speed                       multiplier_crit       multiplier_damage
multiplier_diplomacy  multiplier_health     multiplier_lifespan   multiplier_mana
multiplier_mass       multiplier_offspring   multiplier_speed      multiplier_stamina
multiplier_supply_timer                      mutation              offspring
opinion               personality_administration                   personality_aggression
personality_diplomatic                        personality_rationality
projectiles           range                 recoil                scale
size                  skill_combat          skill_spell           speed
stamina               status_chance         stewardship           targets
throwing_range        warfare
```

Note what is **not** in the list: `fertility`, `endurance`, `age`, `vision`. The real
names are `offspring` / `birth_rate`, `stamina`, `age_adult` / `age_breeding` /
`lifespan`, and `range` / `throwing_range` / `damage_range`.

A misspelled id is **not** harmless — it is **fatal at runtime**.
`BaseStats.set(string, float)` does:

```
ldsfld  AssetManager::base_stats_library
ldarg.1
callvirt AssetLibrary`1<BaseStatAsset>::get(String)   // null for an unknown id
stloc.0
ldloc.0
ldfld   System.Boolean BaseStatAsset::ignore           // <-- dereference of null
```

There is **no null guard**, so an unknown stat id throws a `NullReferenceException`.
`BaseStats.checkStatName` runs first and logs a clear diagnostic — but only once
`Config.game_loaded` is true:

```
base_stats_library.get() - no asset with id: <your id>
Only call stats with S.id, never with pure strings to avoid typos
```

Both `Debug.LogError` calls. So the symptom is: **an error in `Player.log` *and* a
`NullReferenceException` in the same frame.** The compile check cannot catch this — it
is a runtime failure. Search `Player.log` for `no asset with id` when a stat "does
nothing" or the mod throws on load.

### Stat arithmetic — the part that changes your numbers

**Plain stats are additive. A trait's values are DELTAS on top of the species base.**

`BaseStats.mergeStats(other, multiplier)` computes `this[id] = this[id] + other.get(id) * multiplier`,
and `MetaObjectWithTraits.recalcBaseStats` merges each trait's `base_stats` with
multiplier `1`. So `trait.base_stats["health"] = 500f` means *+500 health*, not
"health becomes 500".

**`multiplier_*` stats are multiplicative.** `BaseStats.checkMultipliers()` computes
`main.value = main.value + main.value * multiplier.value`. So:

```csharp
trait.base_stats["multiplier_speed"] = 0.5f;   // x1.5 movement speed
trait.base_stats["multiplier_health"] = 0.5f;  // +50% max health
```

`multiplier_speed = 0.5` is **not** "+0.5 speed" — it is a 50% increase.

### Making a unit look huge, and making it fast

This is the single most common thing a new modder gets wrong.

| Stat | What it actually controls |
|---|---|
| `scale` | **the visual size of the sprite.** It is the *target* scale the actor lerps to. |
| `size` | **the combat hitbox / attack reach** — used by `MapBox.checkAttackFor`, `Actor.isInAttackRange`, `Actor.getSlashPosition`, `QuantumSpriteLibrary.drawUnitSize`. It does **not** change how big the unit looks. |

The reference scale is **0.1**. `Actor.getMassKG` computes
`target_scale / 0.1 * stats["mass_2"]`, which proves 0.1 is "normal", and the vanilla
`$basic_unit$` asset sets `scale = 0.1`, `size = 0.5`, `speed = 5`.

The exact pipeline, from `Actor::create` IL:

```
setActorScale( asset.base_stats["scale"] * 0.6f );   // start at 60% of target
if (asset.finish_scale_on_creation) {
    target_scale = asset.base_stats["scale"];
    finishScale();                                    // snap straight to target
}
```

and afterwards `Actor.updateChangeScale(elapsed)` lerps `actor_scale` toward
`target_scale` every frame. So a unit with `scale = 0.2` starts at 0.12 and grows to
0.2. Set `ActorAsset.finish_scale_on_creation = true` for units that should appear at
full size immediately.

So a unit that looks **twice as big** needs:

```csharp
trait.base_stats["scale"] = 0.1f;              // +0.1 on top of the base 0.1 => 2x
trait.base_stats["multiplier_speed"] = 0.5f;   // x1.5 movement speed
```

### The vanilla body traits are the reference values

From `ActorTraitLibrary::addTraitsBody` — copy these rather than guessing:

| Vanilla trait | Stats |
|---|---|
| `giant` | `scale +0.05`, `multiplier_health +0.5`, `multiplier_speed −0.25` |
| `fat` | `scale +0.02` |
| `agile` | `scale −0.01` |
| `tiny` | `scale −0.02` |
| `fast` | `multiplier_speed +0.3` |
| `blessed` | `multiplier_speed +0.5` |

Vanilla `giant` is only 1.5× visually (`+0.05` on a base of `0.1`). A "huge" unit
usually wants more than that.

**Snake_case is how the game turns ids into locale keys.** `StringExtension.Underscore`
converts CamelCase to snake_case, and a string that is already snake_case comes back
unchanged. So a trait with `id = "ScpAnomaly"` is looked up as `trait_scp_anomaly`, and
a trait with `id = "giant_trait"` is looked up as `trait_giant_trait`. Keeping your ids
lowercase snake_case avoids the whole class of mismatch.

---

## 4. God powers

```csharp
GodPower power = new GodPower();
power.id = "giant_power";
power.name = "giant_power";                 // the locale key for the title
power.path_icon = "ui/icons/iconGiant";

power.click_action = (WorldTile pTile, string pPowerId) =>
{
    if (pTile == null) return false;
    foreach (Actor actor in MapBox.instance.units)
    {
        if (actor != null && actor.isAlive() && actor.current_tile == pTile)
        {
            actor.addTrait("giant_trait");
        }
    }
    return true;
};

AssetManager.powers.add(power);
```

**A registered god power is invisible until it has a button on a power tab.** See §9.

**Fields worth knowing**

| Field | Purpose |
|---|---|
| `name` | locale key for the title (see §7) |
| `path_icon` | resource path, no extension |
| `click_action` | `PowerActionWithID` — main click |
| `click_brush_action`, `click_power_action` | `PowerAction` variants |
| `toggle_name`, `toggle_action` | toggle powers |
| `type` | `PowerActionType` |
| `rank` | `PowerRank` (`Rank0_free`, …) — free vs premium |
| `requires_premium` | premium gate |
| `actor_asset_id`, `actor_asset_ids` | spawn this species instead |
| `actor_spawn_height`, `show_spawn_effect` | spawn presentation |
| `tile_type`, `top_tile_type`, `drop_id`, `force_brush` | brush behaviour |
| `sound_drawing`, `sound_event` | audio |
| `map_modes_switch`, `unselect_when_window` | UI behaviour |
| `force_brush` | **overrides the brush size** — see below |

### The brush is an area, not a tile

A god power's brush defines **which tiles it applies to**. The default brush is
`circ_5` — an **11×11 block** around the cursor, not a single tile. So "units on the
clicked tile" is, by default, "units in an 11×11 area around the clicked tile".

`force_brush` overrides it:

```csharp
power.force_brush = "circ_0";   // exactly one tile
```

Brush ids are `circ_<n>`: `circ_0` is a single pixel, `circ_5` is the default 11×11.
Leaving `force_brush` empty means the player can change the brush size in the UI (some
powers show a brush-size selector), so the affected area is player-controlled.

If your mod's description says "on the clicked tile" but the effect clearly covers a
wide area, this is why — either set `force_brush = "circ_0"` or describe it honestly.

---

## 5. Status effects

```csharp
StatusAsset effect = new StatusAsset();
effect.id = "status_giant_rage";
effect.locale_id = "status_giant_rage";                 // title key
effect.locale_description = "status_giant_rage_description";  // description key
effect.duration = 30f;
effect.path_icon = "ui/icons/iconGiant";

AssetManager.status.add(effect);

effect.base_stats["speed"] = 1.5f;
effect.action = (BaseSimObject pTarget, WorldTile pTile) =>
{
    Actor actor = pTarget as Actor;
    if (actor != null && actor.isAlive()) actor.restoreHealth(5);
    return true;
};
```

**Fields worth knowing**

| Field | Purpose |
|---|---|
| `locale_id`, `locale_description` | the two locale keys — *you* choose them |
| `duration` | seconds; `0` = permanent |
| `base_stats` | stat modifiers while active |
| `action` | `WorldAction` — runs every tick |
| `action_interval` | seconds between `action` ticks |
| `action_finish`, `action_death`, `action_on_receive`, `action_get_hit` | lifecycle hooks |
| `tier` | `StatusTier` |
| `can_be_cured`, `removed_on_damage`, `allow_timer_reset` | behaviour |
| `sprite_list`, `texture`, `animated`, `scale`, `offset_x/y` | visuals |
| `opposite_traits`, `opposite_status`, `remove_status` | interactions |
| `affects_mind` | whether it touches mental stats |

---

## 6. Actors, species, kingdoms

```csharp
Actor actor = ...;              // a live unit
actor.addTrait("giant_trait");  // returns bool; second arg defaults to false
actor.hasTrait("giant_trait");  // bool
actor.restoreHealth(5);
actor.isAlive();                // from NanoObject
actor.current_tile;             // WorldTile (BaseSimObject)
```

`MapBox.instance.units` is an `ActorManager`, which derives from
`SimSystemManager<Actor, ActorData>` and implements `IEnumerable<Actor>` — so
`foreach (Actor actor in MapBox.instance.units)` works.

### Species = `ActorAsset`

There is **no `ActorSpecies` class and no `Race` type** in this build — a "species" is
an `ActorAsset` in `AssetManager.actor_library` (`ActorAssetLibrary`).

| Field | Notes |
|---|---|
| `id` | unique; what `addTrait` / `spawnNewUnit` resolve by |
| `name_locale` | locale key for the display name, e.g. `"kaiju_slug_name"` |
| `texture_asset` | `ActorTextureSubAsset` — where the frames live |
| `animation_walk` / `animation_swim` / `animation_idle` | `string[]` frame names |
| `has_sprite_renderer` | set `false` when supplying custom frames |
| `base_stats` | assigned explicitly |
| `traits`, `traits_ignore` | starting traits |
| `default_*_traits` | `default_subspecies_traits`, `default_clan_traits`, `default_culture_traits`, `default_language_traits`, `default_kingdom_traits`, `default_religion_traits` |
| `job` / `job_citizen` / `job_kingdom` / `job_baby` / `job_attacker` | behaviour jobs |
| `color_hex`, `shadow`, `shadow_texture` | appearance |
| `is_humanoid`, `can_have_subspecies`, `species_spawn_radius` | behaviour |
| `name_template_sets`, `name_template_unit` | naming |
| `skeleton_id`, `mush_id`, `tumor_id`, `zombie_color_hex` | conversions |
| `can_edit_traits`, `inspect_stats`, `has_advanced_textures`, `texture_atlas` | flags |

**Clone from a vanilla template** rather than constructing one — the field set is large:

```csharp
AssetManager.actor_library.clone(out ActorAsset asset, template);
asset.id = design.id;
asset.name_locale = design.id;
AssetManager.actor_library.add(asset);
```

### Custom creature sprites

```csharp
a.texture_asset = new ActorTextureSubAsset("actors/mymod/" + pId + "/", false);
a.animation_walk = ActorAnimationSequences.walk_0_2;
a.animation_swim = ActorAnimationSequences.swim_0_2;
a.animation_idle  = ActorAnimationSequences.walk_0;
a.has_sprite_renderer = false;
```

The base path **must end with a slash**. `ActorTextureSubAsset` derives these
sub-paths from it: `main`, `king`, `leader`, `warrior_1`, `zombie`, `heads`,
`heads_male`, `heads_female`, `head_king`, `head_warrior`, `head_old_male`,
`head_old_female`, `male_1`, `female_1`, `child`, `unitShadow_2`, `unitShadow_4`,
`unitShadow_5`. So the frames live at `GameResources/actors/<id>/main/walk_0.png`.

`ActorAnimationSequences` provides the ready-made frame lists: `walk_0`, `walk_0_1` …
`walk_0_5`, `swim_0` … `swim_0_5`, `idle_0_3`.

### Mandatory relink after registering a species

The game links assets during startup. A species added afterwards is unbound until you
re-run the link steps — real mods do exactly this:

```csharp
AssetManager.actor_library.loadAutoTextures(AssetManager.actor_library.list);
AssetManager.actor_library.linkSpells();
AssetManager.actor_library.loadShadows();
AssetManager.actor_library.setupBoolsAvatarPrefabs();
AssetManager.actor_library.setupBoolSpriteOverrides();
AssetManager.actor_library.linkArchitectures();
AssetManager.actor_library.generateFmodPaths();
```

`ActorAssetLibrary` also exposes `post_init()` and `linkAssets()`. If a method is not
reachable directly, call it via `Reflection.CallMethod(...)` as
`TAYFIM_ABYSSFALL\Code\Main.cs:198-209` does.

### Spawning

```csharp
Actor a = ActorManager.spawnNewUnit(
    string pActorAssetID, WorldTile pTile, bool pSpawnSound, bool pMiracleSpawn,
    float pSpawnHeight, Subspecies pSubspecies, bool pGiveOwnerlessItems, bool pAdultAge);
```

`Actor.spawnOn(WorldTile pTile, float pZHeight)` places an existing actor.

### Kingdoms

`KingdomAsset` lives in `AssetManager.kingdoms` (`KingdomLibrary`). Kingdom traits are
`KingdomTrait` in `AssetManager.kingdoms_traits` (`KingdomTraitLibrary`), with groups in
`AssetManager.kingdoms_traits_groups` (`KingdomTraitGroupLibrary`).

**`KingdomAsset` has no `color`, no `culture_asset_id`, no `language_asset_id`, no
`banner_id`, no `name_locale` and no `traits`.** Those names do not exist and code
using them will not compile. The actual fields are:

| Field | Type | Purpose |
|---|---|---|
| `id` | `string` | from `Asset` |
| `civ` | `bool` | is this a playable civ |
| `default_civ_color_index` | `int` | index into the kingdom colour set — the simplest way to colour a new kingdom |
| `default_kingdom_color` | `ColorAsset` | the kingdom's main colour |
| `color_building` | `Color` | building colour |
| `path_icon` | `string` | icon resource path |
| `show_icon` | `bool` | |
| `nature` / `abandoned` / `concept` / `mobs` / `nomads` / `neutral` / `brain` | `bool` | kingdom flavour |
| `always_attack_each_other`, `units_always_looking_for_enemies`, `count_as_danger`, `friendship_for_everyone` | `bool` | behaviour |
| `group_miniciv`, `group_minicivs_cool`, `group_creeps`, `group_main` | `bool` | grouping |
| `is_forced_by_trait`, `forced_by_trait_kingdom_id` | `bool` / `string` | trait-forced kingdoms |
| `building_attractor_id` | `string` | |
| `friendly_tags` / `enemy_tags` / `list_tags` | `HashSet` | diplomacy tags |

**Culture and language live on the runtime objects, not the asset.** `KingdomData` has
`id_culture` and `id_language`; the live `Kingdom` exposes `culture` and `language`
objects of type `Culture` / `Language`. `KingdomAsset` itself carries neither.

Colours come from `AssetManager.color_style_library` (`ColorStyleLibrary`) and
`AssetManager.kingdom_colors_library` (`KingdomColorsLibrary`).

### There is no "Race"

A "race" in WorldBox is expressed as a combination of `ActorAsset` (the creature),
`Subspecies` (the runtime variant), and `KingdomAsset` (the civ). Any recipe that
mentions a `Race` class is wrong for this build.

### Cloning an existing asset

Every `AssetLibrary<T>` has two `clone` overloads, and picking the wrong one is a
compile error:

```csharp
// 1. clone by id - copies pFrom into a new asset, sets its id to pNew,
//    ADDS it to the library, and RETURNS it.
ActorAsset saiyan = AssetManager.actor_library.clone(SpeciesId, "human");

// 2. clone by object - reflection deep copy, does NOT add to the library.
ActorAsset template = AssetManager.actor_library.get("human");
AssetManager.actor_library.clone(out ActorAsset saiyan, template);
AssetManager.actor_library.add(saiyan);   // you must add it yourself
```

Overload 2 copies every non-`[NonSerialized]` field, deep-copying `ICloneable`
members and re-creating `ICollection` / `IEnumerable` members.

**`clone(out x, "someId")` does not compile.** The string overload's first parameter is
a by-value `string`, so `out` is rejected (CS1615). Use overload 1, or pass an actual
asset object to overload 2.

---

## 7. Buildings, tiles and effects

**Buildings** are `BuildingAsset` in `AssetManager.buildings`. The locale convention
used by working mods is `building_<id>`. Clone a vanilla building asset and override
`id` / `path_icon` rather than constructing one from scratch — the field set is large
and not fully documented here.

**Tiles** live in `AssetManager.tiles` (`TileLibrary`), `AssetManager.top_tiles`
(`TopTileLibrary`), `AssetManager.tile_tile_effects` (`TileEffectsLibrary`),
`AssetManager.terraform` (`TerraformLibrary`) and `AssetManager.biome_library`.
The `TileAsset` / `TopTileAsset` field sets were not extracted; the same clone-and-
override approach applies.

**Effects** are driven through `AssetManager.effects_library` (`EffectsLibrary`), whose
useful entry points are:

```csharp
EffectsLibrary.spawnExplosionWave(...);
EffectsLibrary.spawnSlash(...);
EffectsLibrary.spawnMeteorite(...);
EffectsLibrary.spawnCloud(...);
EffectsLibrary.spawnFireworks(...);
EffectsLibrary.showSpawnEffect(...);
EffectsLibrary.showMetaEventEffect(...);
EffectsLibrary.highlightKingdomZones(...);
EffectsLibrary.showMoneyEffect(...);
```

Registering a brand-new `BaseEffect` asset is possible but its field set was not
extracted — use the existing effects until that is mapped.

---

## 8. Localisation keys

The game builds the lookup key itself from the asset's typed id and its own id,
**snake-cased**. Verified against the game's own locale data in `resources.assets`.

| Asset | Name key | Description key |
|---|---|---|
| Trait | `trait_<id>` | `trait_<id>_info` |
| Trait group | `trait_group_<id>` | — (none) |
| God power | `<id>` | `<id>_description` |
| Item | `<id>` or its `translation_key` | `<id>_description` |
| Status effect | the `locale_id` field | the `locale_description` field |
| World law | `<law_id>_title` | `<law_id>_description` |
| Actor task | `task_unit_<task_id>` | — |

Real vanilla examples pulled from the game's own strings: `earthquake` /
`earthquake_description`, `volcano` / `volcano_description`, `blessing` /
`blessing_description`, `trait_aggressive` / `trait_aggressive_info`,
`trait_group_body`.

> **There is no `power_` prefix on god powers.** A mod that registers
> `power_my_power` leaves the title showing as the raw key. This is the single most
> common localisation mistake.

**From code:**

```csharp
NeoModLoader.General.LM.AddToCurrentLocale("trait_giant_trait", "Giant");
NeoModLoader.General.LM.AddToCurrentLocale("trait_giant_trait_info", "A very large unit.");
NeoModLoader.General.LM.AddToCurrentLocale("giant_power", "Grow Giants");
NeoModLoader.General.LM.AddToCurrentLocale("giant_power_description", "Makes units on the tile giant.");
```

**From a file** — `Locales\<lang>.json`, a flat map, filename = language id
(`en`, `ru`, `ja`, `ch`, `cz`… — the ids the game registers, not ISO guesses):

```json
{
  "trait_giant_trait": "Giant",
  "trait_giant_trait_info": "A very large unit.",
  "giant_power": "Grow Giants",
  "giant_power_description": "Makes units on the tile giant."
}
```

`BasicMod<T>` implements `ILocalizable`, so NML loads `Locales\` before `OnModLoad`
with no code from you. A `.csv` in the same folder covers every language at once
(`key,en,ru`); implement `ICsvSepCustomized` if the separator is not a comma.

---

## 9. Delegate signatures

These exact shapes are used when assigning lambdas.

| Delegate | Signature |
|---|---|
| `WorldAction` | `bool (BaseSimObject pTarget, WorldTile pTile)` |
| `WorldActionTrait` | `bool (NanoObject pTarget, BaseAugmentationAsset pTrait)` |
| `PowerAction` | `bool (WorldTile pTile, GodPower pPower)` |
| `PowerActionWithID` | `bool (WorldTile pTile, string pPowerID)` |
| `GetHitAction` | `bool (BaseSimObject pSelf, BaseSimObject pAttackedBy, WorldTile pTile)` |
| `PowerToggleAction` | toggle handler |
| `PowerButtonClickAction` | `void ()` |
| `WorldTileAction` / `WorldActionWithID` variants | see the assembly |

### Which callback goes where

`WorldAction` and `WorldActionTrait` are **not** interchangeable, and picking the wrong
one is a compile error (CS1661 / CS1678).

| Field | Declared on | Delegate | Signature |
|---|---|---|---|
| `action_birth` | `BaseTrait<T>` | `WorldAction` | `bool (BaseSimObject, WorldTile)` |
| `action_growth` | `BaseTrait<T>` | `WorldAction` | `bool (BaseSimObject, WorldTile)` |
| `action_death` | `BaseTrait<T>` | `WorldAction` | `bool (BaseSimObject, WorldTile)` |
| `action_get_hit` | `BaseTrait<T>` | `GetHitAction` | `bool (BaseSimObject, BaseSimObject, WorldTile)` |
| `action_on_augmentation_add` | `BaseAugmentationAsset` | `WorldActionTrait` | `bool (NanoObject, BaseAugmentationAsset)` |
| `action_on_augmentation_remove` | `BaseAugmentationAsset` | `WorldActionTrait` | `bool (NanoObject, BaseAugmentationAsset)` |
| `action_on_augmentation_load` | `BaseAugmentationAsset` | `WorldActionTrait` | `bool (NanoObject, BaseAugmentationAsset)` |
| `action_on_object_remove` | `BaseAugmentationAsset` | `WorldActionTrait` | `bool (NanoObject, BaseAugmentationAsset)` |
| `action_special_effect` | `BaseAugmentationAsset` | `WorldAction` | `bool (BaseSimObject, WorldTile)` |
| `action_attack_target` | `BaseAugmentationAsset` | `AttackAction` | see the assembly |

All of these are called by the game — `action_birth` has 3 call sites,
`action_on_augmentation_add` has 8, `action_death` has 18.

**A trait callback that wants to know which trait fired** must use a `WorldActionTrait`
field (`action_on_augmentation_add` / `_remove` / `_load`), because only those receive
the `BaseAugmentationAsset`. A `WorldAction` field gets the target object and the tile
instead.

---

## 10. UI: power tabs, buttons, windows

NML exposes `NeoModLoader.General.UI.Tab.TabManager` and
`NeoModLoader.General.PowerButtonCreator`.

```csharp
Sprite icon = SpriteTextureLoader.getSprite("ui/icons/iconGiant");

PowersTab tab = TabManager.CreateTab("giant_tab", "giant_tab", "giant_tab_description", icon);
tab.SetLayout(new List<string> { "giant_group" });
tab.AddPowerButton("giant_group", PowerButtonCreator.CreateGodPowerButton("giant_power", icon));
tab.UpdateLayout();
```

`TabManager.CreateTab(string name, string pTitleKey, string pDescKey, Sprite pIcon,
string pOptionDescKey = …)`.

`PowerButtonCreator` factories:

| Method | Makes |
|---|---|
| `CreateGodPowerButton(pGodPowerId, pIcon, pParent, pLocalPosition)` | a button that fires a god power |
| `CreateToggleButton(pGodPowerId, pIcon, …)` | a toggle button (auto-wires `toggle_action`) |
| `CreateSimpleButton(pId, pAction, pIcon, …)` | a plain button with your callback |
| `CreateWindowButton(pId, pWindowId, pIcon, …)` | a button that opens a window |

Also available: `PowerButtonCreator.GetTab(pId)` and
`PowerButtonCreator.AddButtonToTab(button, tab, position)`.

**Timing.** `OnModLoad` runs before the game UI exists. Build UI from `Update()` once
`Config.game_loaded` is true and `MapBox.instance != null`, guarded by a one-shot flag.

---

## 11. Gotchas

- **Do not touch the world before it exists.** `OnModLoad` runs before any map or unit
  exists. Guard every frame loop with `Config.game_loaded` and `MapBox.instance != null`.
- **`Actor.updateStats` runs as a parallel job.** Inside a Harmony Postfix on it, touch
  only that unit's own numbers. Calling Unity API, the game's `Randy`, or writing a
  shared list from there crashes in ways that only reproduce elsewhere.
- **One `MonoBehaviour` + `IMod` per assembly.** NML picks the first one it finds. A
  helper `MonoBehaviour` in the same assembly can shadow your entry class.
- **A trait's stats are deltas, and `multiplier_*` are percentages.** See §3.
  `base_stats["health"] = 500f` adds 500 health; `multiplier_speed = 0.5` is ×1.5.
- **`scale` is the visual size; `size` is the hitbox.** See §3. Getting these the wrong
  way round produces a unit that attacks from further away but looks the same size.
- **A misspelled stat id logs an error** (`no asset with id: …`), it does not fail
  quietly. Search `Player.log` for `no asset with id` when a stat "does nothing".
- **`OnModLoad` has no return code and no exception contract.** A mod "works" if it runs
  to completion without throwing. Wrap stages in try/catch so one failure does not
  silently disable the rest.
- **`AssetManager.traits.add()` twice = two assets, same id.** Use `get()` first.
- **Idempotency matters on reload.** The game can reload mods without restarting; guard
  registration with `get()` checks or your assets will be registered twice.
- **`MapBox.instance` is null before a world loads.** Never dereference it unguarded.
- **`global::Config.game_loaded`** — use the `global::` prefix if your mod has its own
  `Config` type, or the name resolves to yours.
