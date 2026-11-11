# WorldBox Game API Reference (Assembly-CSharp.dll)

Ground truth: `C:\Program Files (x86)\Steam\steamapps\common\WorldBox\worldbox_Data\Managed\Assembly-CSharp.dll`
(2444 types, names unobfuscated — verified identical to
`worldbox_Data\StreamingAssets\mods\NML\Assembly-CSharp-Publicized.dll`).

Namespace note: game types are in the **global namespace** (no namespace).
`NeoModLoader.*` / `NCMS.*` types come from `worldbox_Data\StreamingAssets\mods\NeoModLoader.dll`.

All namespaces below are global unless stated.

---

## 0. Frameworks & entry points (READ THIS FIRST)

WorldBox mods are loaded by **NeoModLoader (NML)**, not by the game itself.

### A. `NeoModLoader.api.BasicMod<T>` — used by 15 of 19 installed mods

```csharp
// NCMS namespace provides the [ModEntry] attribute.
using NCMS;
using NeoModLoader.api;

[ModEntry]
public class Main : BasicMod<Main>
{
    protected override void OnModLoad()
    {
        // Register everything here.
    }
}
```
- `BasicMod<T> : UnityEngine.MonoBehaviour`.
- Members: `Instance` / `I`, `PrefabLibrary`, `ModFeatureManager`, `GetConfig()`,
  `LoadConfig()`, `LogInfo/LogWarning/LogError`, `NewPrefab(string)`,
  `GetLocaleFilesDirectory(ModDeclare)` → `<modFolder>\Locales`,
  `GetDeclaration()`, `GetGameObject()`, `GetUrl()`.
- `OnModLoad()` is invoked by NML **after** the game's `AssetManager.init()` has run,
  which is why `AssetManager.traits.get(...)` is safe to call at load time.

### B. `NeoModLoader.api.IMod` — the low-level interface

```csharp
public class Main : MonoBehaviour, IMod
{
    public void OnLoad(ModDeclare pModDecl, GameObject pGameObject) { /* ... */ }
    public ModDeclare GetDeclaration() => ...;
    public GameObject GetGameObject() => gameObject;
    public string GetUrl() => "...";
}
```
`IMod` members: `OnLoad(ModDeclare, GameObject)`, `GetDeclaration()`, `GetGameObject()`, `GetUrl()`.

### C. Legacy `MonoBehaviour` + `[ModEntry]` + `Awake()`

Used by `TAYFIM_ABYSSFALL`, `TRIICKSTR_PLENTY_O_BIOMES`, `TRIICKSTR_SELECTIVE_BREEDING`.
`void Awake()` is the effective init point. Works, but `BasicMod<T>` is preferred.

### D. `mod.json` (required, at the mod root)

```json
{
  "name": "MyMod",
  "author": "You",
  "version": "1.0.0",
  "description": "...",
  "iconPath": "icon.png",
  "targetGameBuild": 0,
  "main": "MyMod.Main"
}
```
`main` names the entry class (namespace-qualified). `targetGameBuild` 0 = any build.
NML discovers mods in `<game>/Mods/<FolderName>/mod.json` (and Steam Workshop path).
`default_config.json` is the optional mod-settings file (see §11).

---

## 1. Traits

**Class** `ActorTrait : BaseTrait<ActorTrait> : BaseAugmentationAsset : BaseUnlockableAsset : Asset`

### Required field initialization
| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string` | **yes** | Unique across the trait library. Drives locale keys. |
| `group_id` | `string` | **yes** | Must equal the `id` of an already-registered `ActorTraitGroupAsset`. |
| `path_icon` | `string` | recommended | Resources path, no extension. |
| `base_stats` | `BaseStats` | optional | **Assign `new BaseStats()` explicitly** (see gotchas). |

### Useful optional fields (verified present)
- `ActorTrait`: `rate_birth` (int), `rate_inherit` (int), `rate_acquire_grow_up` (int),
  `acquire_grow_up_sapient_only`, `is_mutation_box_allowed`, `same_trait_mod`,
  `opposite_trait_mod`, `type` (`TraitType`: `Positive`/`Negative`/`Other`),
  `can_be_cured`, `affects_mind`, `is_kingdom_affected`, `forced_kingdom`,
  `can_be_removed_by_divine_light`, `can_be_removed_by_accelerated_healing`,
  `likeability` (float), `remove_for_zombie_actor_asset`, `in_training_dummy_combat_pot`.
- `BaseTrait<T>`: `value` (float), `action_birth` / `action_growth` / `action_death`
  (`WorldAction`), `action_get_hit` (`GetHitAction`), `spawn_random_trait_allowed`,
  `spawn_random_rate`, `rarity` (`Rarity`: `R0_Normal`/`R1_Rare`/`R2_Epic`/`R3_Legendary`),
  `can_be_in_book`, `plot_id`, `special_icon_logic`, `opposite_list`, `opposite_traits`,
  `traits_to_remove_ids` (`string[]`), `traits_to_remove` (`TTrait[]`),
  `default_for_actor_assets`, `has_localized_id`, `special_locale_id`.
- `BaseAugmentationAsset`: `action_special_effect` (`WorldAction`), `special_effect_interval`
  (float), `action_on_augmentation_add/remove/load` (`WorldActionTrait`),
  `action_on_object_remove`, `action_attack_target` (`AttackAction`),
  `group_id`, `priority` (int), `can_be_given`, `can_be_removed`, `show_in_meta_editor`,
  `spells` (`List<...>`), `decisions_assets`, `combat_actions`.
- `BaseUnlockableAsset`: `base_stats`, `path_icon`, `show_for_unlockables_ui`,
  `unlocked_with_achievement`, `needs_to_be_explored`, `achievement_id`,
  `show_in_knowledge_window`, `has_locales`, `cached_sprite`.

### Registration / unlock (must be called from `OnModLoad`)
```csharp
AssetManager.traits.add(trait);   // registers in the library
trait.unlock(true);                // makes it usable NOW (saves progress data)
```
- `AssetManager.traits` is `ActorTraitLibrary : BaseTraitLibrary<ActorTrait>`.
- `BaseTraitLibrary<T>.add(T)` → returns `T`; also `post_init()`, `autoSetRarity()`,
  `linkAssets()`, `fillOppositeHashsetsWithAssets()`, `checkOppositeErrors()`.
- `BaseUnlockableAsset.unlock(bool pSaveData)` → `bool`. Adds the asset id to
  `progress_elements` and calls `GameProgress.saveData()` when `pSaveData` is true.
  Returns `false` if the asset is not `isAvailable()`.
- There is **no** `PlayerConfig.unlockTrait(...)`. Unlock is always `asset.unlock(true)`.

### Opposites / conflicts
`t.addOpposite(string id)`, `t.addOpposites(IEnumerable<string>)`, `t.removeOpposite(string)`,
or set `traits_to_remove_ids`.

### Minimal working snippet (real mod)
`Mods\SCPBOX_MOD\Code\ScpTraits.cs:115-135`
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
`worldbox_Data\StreamingAssets\mods\ElementalPowersMod\Traits\CustomTraits.cs:30-47`
```csharp
ActorTrait trait = new ActorTrait();
trait.id = "elemental_titan";
trait.group_id = "ElementalPowers";
trait.path_icon = "ui/Icons/iconKings";

trait.base_stats = new BaseStats();
trait.base_stats["scale"] = 0.4f;
trait.base_stats["health"] = 1000f;
trait.base_stats["damage"] = 60f;
trait.base_stats["armor"] = 25f;
trait.base_stats["speed"] = 1.2f;

AssetManager.traits.add(trait);
trait.unlock(true);

NeoModLoader.General.LM.AddToCurrentLocale("trait_elemental_titan", "Elemental Titan");
NeoModLoader.General.LM.AddToCurrentLocale("trait_elemental_titan_info", "Turns the unit into a giant behemoth...");
```

### Trait groups
**Class** `ActorTraitGroupAsset : BaseCategoryAsset` — fields `id` (Asset), `name`, `color`.
`name` **is** the locale key (see §10). `color` is a hex string like `"#78D9FF"`.

```csharp
// Mods\CORE4777_COREBOX\Code\Features\UnitVault\SavedCreatureTrait.cs:15-17
if (AssetManager.trait_groups.get(group) == null)
    AssetManager.trait_groups.add(new ActorTraitGroupAsset
    { id = group, name = "trait_group_" + group, color = "#78D9FF" });
```
Register the group **before** the traits that reference it.

### Gotchas
- `group_id` pointing at a non-existent group ⇒ broken/blank trait in the UI.
- Duplicate `id` ⇒ `add()` collides; guard with `AssetManager.traits.get(id) != null` (all real mods do).
- `base_stats` is a **reference type**; if you mutate `trait.base_stats["x"]` on a
  freshly `new`ed trait without assigning `new BaseStats()`, you may hit a NullReferenceException.
  Always assign `new BaseStats()` first (the ElementalPowersMod snippet above does).
- `unlock()` is separate from `add()`. Forgetting it yields a trait that exists but is not
  obtainable. `unlock()` returns `false` if the asset is unavailable.
- `action_special_effect` is a **field** holding a delegate; add to it with `+=`.
- `WorldAction` signature: `bool (BaseSimObject target, WorldTile tile)`.
- `GetHitAction` and `WorldActionTrait` are distinct delegate types from `WorldAction`.

---

## 2. Stats

**Class** `BaseStats` (not `ActorStats`). Library: `AssetManager.base_stats_library`
(`BaseStatsLibrary : AssetLibrary<BaseStats>`).

### API
- Indexer: `stats["speed"] = 34f;` / `float v = stats["speed"];`
- `set(string pID, Single pAmount)`, `get(string pID)`, `hasStat(string pID)`,
  `getContainer(string pID)`, `mergeStats(BaseStats, float)`,
  `addTag(string)`, `hasTag(string)`, `hasTags(string[])`, `normalize()`, `clear()`,
  `reset()`, `getList()`, `addCombatAction(string)`, `Clone()`.

### Stat keys observed in real mods
`scale`, `health`, `damage`, `armor`, `speed`, `attack_speed`, `critical_chance`,
`accuracy`, `knockback`, `birth_rate`, `multiplier_damage`, `multiplier_speed`,
`multiplier_health`.
The full legal set is defined by the game data — **UNVERIFIED**: the complete list of valid
stat ids was not extracted. `BaseStats.checkStatName(string)` validates and
`BaseStatsLibrary.editorDiagnosticLocales()` reports problems.

### Snippet
`Mods\AGRICHE_GODZILLA\Code\Registry.cs:34`
```csharp
a.base_stats["speed"] = 34f;
```
`Mods\CORE4777_COREBOX\Code\Features\CoreRpg\JobMagic.cs:30-32`
```csharp
temporary.base_stats["multiplier_health"] = -.65f;
temporary.base_stats["multiplier_damage"] = -.65f;
temporary.base_stats["birth_rate"] = -10000f;
```

### Gotchas
- `BaseStats` is shared by reference if you assign the same instance to several assets —
  use `new BaseStats()` per asset or `Clone()`.
- Stat ids are validated at runtime; an unknown id logs an error rather than throwing.

---

## 3. Actors / Species (creatures)

**Classes**
- `ActorAsset : BaseUnlockableAsset` — the *creature template* (this is what modders
  call "a species"; there is no `ActorSpecies` class).
- `Subspecies` / `SubspeciesData` — the per-spawn runtime variant.
- `ActorData` — the **save-file** serialization of a spawned actor.
- `ActorTextureSubAsset` — sprite path descriptor.
- `ActorAnimationSequences` — static `string[]` frame-name arrays.

### ActorAsset required fields
| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Unique. `addTrait`/`spawnNewUnit` resolve by this. |
| `name_locale` | `string` | Locale key for the display name, e.g. `"kaiju_slug_name"`. |
| `texture_asset` | `ActorTextureSubAsset` | Where the frames live. |
| `animation_walk` / `animation_swim` / `animation_idle` | `string[]` | Frame names. |
| `has_sprite_renderer` | `bool` | Set false when you supply custom frames. |
| `base_stats` | `BaseStats` | Assigned explicitly. |

Other useful `ActorAsset` fields: `texture_id`, `architecture_id`, `shadow`,
`shadow_texture`, `shadow_texture_egg`, `shadow_texture_baby`, `is_humanoid`,
`color_hex`, `job` / `job_citizen` / `job_kingdom` / `job_baby` / `job_attacker`,
`traits` (`List<...>`), `traits_ignore`, `default_subspecies_traits`,
`default_clan_traits`, `default_culture_traits`, `default_language_traits`,
`default_kingdom_traits`, `default_religion_traits`, `name_template_sets`,
`name_template_unit`, `banner_id`, `build_order_template_id`, `can_have_subspecies`,
`species_spawn_radius`, `family_spawn_radius`, `language_spawn_radius`,
`create_family_at_spawn`, `show_icon_inspect_window_id`, `power_id`, `zombie_color_hex`,
`skeleton_id`, `mush_id`, `tumor_id`, `evolution_id`, `grow_into_id`, `age_spawn`,
`can_edit_traits`, `inspect_stats`, `has_advanced_textures`, `texture_atlas`.

### `ActorTextureSubAsset`
```csharp
new ActorTextureSubAsset(string pBasePath, bool pHasAdvancedTextures)
```
Base path e.g. `"actors/scp/Scp001/"` — **with trailing slash**.
The constructor derives these sub-paths (from IL string constants):
`main`, `king`, `leader`, `warrior_1`, `zombie`, `heads`, `heads_male`, `heads_female`,
`head_king`, `head_warrior`, `head_old_male`, `head_old_female`, `male_1`, `female_1`,
`child`, `unitShadow_2`, `unitShadow_4`, `unitShadow_5`.
So a creature's frames live at `GameResources/actors/<id>/main/walk_0.png` etc.

### `ActorAnimationSequences` (static `string[]`, verified from `.cctor`)
| Field | Frames |
|---|---|
| `walk_0` | `walk_0` |
| `walk_0_1` | `walk_0`, `walk_1` |
| `walk_0_2` | `walk_0`, `walk_1`, `walk_2` |
| `walk_0_3` | `walk_0..walk_3` |
| `walk_0_4` | `walk_0..walk_4` |
| `walk_0_5` | `walk_0..walk_5` |
| `swim_0` | `swim_0` |
| `swim_0_1` | `swim_0`, `swim_1` |
| `swim_0_2` | `swim_0..swim_2` |
| `swim_0_3` | `swim_0..swim_3` |
| `swim_0_5` | `swim_0..swim_5` |
| `idle_0_3` | `idle_0`, `idle_1`, `idle_2`, `idle_3` |

### Registration
```csharp
AssetManager.actor_library.add(asset);
```
`AssetManager.actor_library` is `ActorAssetLibrary`.

**Clone-from-template pattern** (`Mods\CORE4777_COREBOX\Code\Features\UnitCreation\UnitCreator.cs:94-123`):
```csharp
AssetManager.actor_library.clone(out asset, template);
asset.id = design.id;
asset.name_locale = design.id;
asset.architecture_asset = template.architecture_asset;
...
AssetManager.actor_library.add(asset);
WorldBoxActors.InvalidateActorLibrary();
```

### MANDATORY post-registration relink
Registering an `ActorAsset` after the game linked assets leaves the new asset unbound.
Real mods re-run the link steps (`Mods\TAYFIM_ABYSSFALL\Code\Main.cs:198-209`):
```csharp
Reflection.CallMethod(AssetManager.actor_library, "loadAutoTextures", AssetManager.actor_library.list);
Reflection.CallMethod(AssetManager.actor_library, "linkSpells");
Reflection.CallMethod(AssetManager.actor_library, "loadShadows");
Reflection.CallMethod(AssetManager.actor_library, "setupBoolsAvatarPrefabs");
Reflection.CallMethod(AssetManager.actor_library, "setupBoolSpriteOverrides");
Reflection.CallMethod(AssetManager.actor_library, "linkArchitectures");
Reflection.CallMethod(AssetManager.actor_library, "generateFmodPaths");
```
`ActorAssetLibrary` also exposes `post_init()`, `linkAssets()`, `loadShadows()`,
`setupBoolsAvatarPrefabs()`, `setupBoolSpriteOverrides()`, `linkArchitectures()`,
`generateFmodPaths()`, `loadAutoTextures(...)` — call them directly instead of via reflection
if the publicized assembly exposes them.

### Minimal snippet (real mod)
`Mods\SCPBOX_MOD\Code\FoundationUnits.cs:10,34-42`
```csharp
private const string TEXTURE_ROOT = "actors/scp/";
...
a.base_stats["speed"] = 34f;
a.has_advanced_textures = false;
a.texture_asset = new ActorTextureSubAsset(TEXTURE_ROOT + pId + "/", false);
a.animation_walk = ActorAnimationSequences.walk_0_2;
a.animation_swim = ActorAnimationSequences.swim_0_2;
a.animation_idle  = ActorAnimationSequences.walk_0;
a.auto_civ = false;
```
`Mods\AGRICHE_GODZILLA\Code\Registry.cs:64-67`
```csharp
AssetManager.actor_library.add(t);
t.allowed_status_tiers = StatusTier.None;
t.has_sprite_renderer = false;
t.name_locale = d.Legacy ? "godzilla_name" : "kaiju_" + d.Slug + "_name";
```

### Spawning
```csharp
// ActorManager
Actor a = ActorManager.spawnNewUnit(
    string pActorAssetID, WorldTile pTile, bool pSpawnSound, bool pMiracleSpawn,
    float pSpawnHeight, Subspecies pSubspecies, bool pGiveOwnerlessItems, bool pAdultAge);

Actor b = ActorManager.spawnNewUnitByPlayer(
    string pStatsID, WorldTile pTile, bool pSpawnSound, bool pMiracleSpawn,
    float pSpawnHeight, Subspecies pSubspecies);

Actor c = ActorManager.createNewUnit(
    string pStatsID, WorldTile pTile, bool pMiracleSpawn, float pSpawnHeight,
    Subspecies pSubspecies, Subspecies pSubspeciesMutateFrom, bool pSpawnWithItems,
    bool pAdultAge, bool pGiveOwnerlessItems, bool pSapientSubspecies);
```
`Actor.spawnOn(WorldTile pTile, float pZHeight)` places an existing actor.

### `Actor` — the runtime object
Traits: `addTrait(ActorTrait, bool pRemoveOpposites)`, `addTrait(string pTraitID, bool)`,
`removeTrait(ActorTrait)`, `removeTrait(string)`, `hasTrait(...)`, `removeTraits(ICollection<>)`,
`hasTraits()`.
Status: `addStatusEffect(StatusAsset, float pOverrideTimer, bool pColorEffect)`.
Health/stats: `restoreHealth(int)`, `restoreHealthPercent(float)`, `setStatsDirty()`,
`updateStats()`, `isAlive()`, `isRekt()`, `makeStunned()`, `addForce(...)`, `getHit(...)`.
World: `current_tile`, `kingdom`, `asset`.

---

## 4. Powers

**Class** `GodPower : Asset`. Library: `AssetManager.powers` (`PowerLibrary : AssetLibrary<GodPower>`).

### Required field initialization
| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Unique power id. |
| `name` | `string` | **Locale key source** — see §10. Usually set == `id`. |
| `path_icon` | `string` | Resources path, no extension. |
| `rank` | `PowerRank` | e.g. `PowerRank.Rank0_free`. |
| `click_action` | `PowerActionWithID` | `bool (WorldTile, string powerId)`. |

### Other useful fields
`click_power_action` (`PowerAction`: `bool (WorldTile, GodPower)`),
`click_brush_action`, `click_special_action`, `select_button_action`
(`PowerButtonClickAction`), `toggle_action` (`PowerToggleAction`), `toggle_name`,
`multi_toggle`, `type` (`PowerActionType`), `actor_asset_id`, `actor_asset_ids`,
`actor_spawn_height`, `show_spawn_effect`, `show_unit_stats_overview`, `show_tool_sizes`,
`multiple_spawn_tip`, `unselect_when_window`, `hold_action`, `ignore_cursor_icon`,
`click_interval`, `particle_interval`, `sound_event`, `sound_drawing`, `tile_type`,
`top_tile_type`, `drop_id`, `force_brush`, `terraform`, `draw_lines`, `highlight`,
`make_buildings_transparent`, `force_map_mode` (`MetaType`), `allow_unit_selection`,
`can_drag_map`, `track_activity`, `map_modes_switch`, `mouse_hold_animation`,
`falling_chance`, `printers_print`, `requires_premium`.

### Registration
```csharp
AssetManager.powers.add(power);
```
Post-registration: `AssetManager.powers.linkAssets()` (real mods call it —
`Mods\TAYFIM_ABYSSFALL\Code\Main.cs:229-231`).

### Clone-from-template
`PowerLibrary` exposes template constants; clone with:
```csharp
GodPower p = AssetManager.powers.clone("my_spawn_power", "$template_spawn_actor$");
```
Verified template ids: `$template_spawn_actor$`, `$template_drops$`, `$template_bombs$`,
`$template_explosive_tiles$`, `$template_seeds$`, `$template_plants$`,
`$template_drop_minerals$`, `$template_drop_building$`, `$template_printer$`,
`$template_spawn_special$`, `$template_terraform_tiles$`, `$template_wall$`,
`$template_draw$`, `$template_eraser$`.
`Mods\SCPBOX_MOD\Code\ScpPowers.cs:97` uses `"$template_spawn_actor$"`;
`Mods\CORE4777_COREBOX\Code\Features\Spawning\Ui\SpawnBuildingWindow.cs:140` uses `"$template_drops$"`.

### Minimal snippet (real mod)
`Mods\SCPBOX_MOD\Code\ScpPowers.cs:125-135`
```csharp
GodPower power = new GodPower
{
    id = pId,
    name = pId,
    hold_action = false,
    show_tool_sizes = false,
    unselect_when_window = false,
    ignore_cursor_icon = true,
    click_action = pAction
};
AssetManager.powers.add(power);
```
`worldbox_Data\StreamingAssets\mods\ElementalPowersMod\Powers\CustomPowers.cs:40-55`
```csharp
power.click_action = (WorldTile pTile, string pPowerId) =>
{
    if (pTile == null) return false;
    foreach (Actor actor in MapBox.instance.units)
        if (actor != null && actor.isAlive())
        {
            actor.restoreHealth(500);
            actor.addTrait("swift_phantom");
        }
    return true;
};
AssetManager.powers.add(power);
```
`Mods\CORE4777_COREBOX\Code\Features\Spawning\BuildingEvolve.cs:47-49` shows `+=` on the
delegate field: `_power.click_power_action += Spawn;` then `AssetManager.powers.add(_power);`

### Gotchas
- `click_action` is a **field**, not a property — `+=` works but `=` replaces.
- `name` is transformed by `StringExtension.Underscore(name)` to form the locale key.
  Register the **underscored** form (see §10) — `power_<id>` is *not* what the game looks up.
- `MapBox.instance` can be null before a world is loaded — null-check.
- `PowerLibrary` also has ~70 built-in action helpers (`spawnUnit`, `drawAxe`, `spawnMeteorite`, …)
  usable as `click_action` targets via reflection or direct calls.

---

## 5. Status effects

**Class** `StatusAsset : Asset`. Library: `AssetManager.status` (`StatusLibrary`).

### Required field initialization
| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Unique. |
| `locale_id` | `string` | **Explicit** title key (no prefixing by the game). |
| `locale_description` | `string` | **Explicit** description key. |
| `duration` | `float` | Seconds. |
| `tier` | `StatusTier` | `None` / `Basic` / `Advanced`. |
| `action` | `WorldAction` | `bool (BaseSimObject, WorldTile)`. |
| `action_interval` | `float` | Repeat interval. |
| `path_icon` | `string` | Resources path. |

Other fields: `action_finish`, `action_death`, `action_get_hit` (`GetHitAction`),
`action_on_receive`, `can_be_cured`, `allow_timer_reset`, `texture`, `random_frame`,
`can_be_flipped`, `animated`, `is_animated_in_pause`, `loop`, `animation_speed`,
`animation_speed_random`, `scale`, `offset_x/_y` (+ `_ui` variants), `rotation_z`,
`use_parent_rotation`, `removed_on_damage`, `position_z`, `random_flip`,
`cancel_actor_job`, `affects_mind`, `material_id`, `material`, `draw_light_area`,
`draw_light_size`, `base_stats`, `opposite_traits`, `opposite_tags`, `opposite_status`,
`remove_status`, `sprite_list` (`Sprite[]`), `render_priority`, `sound_idle`,
`decision_id`, `need_visual_render`, `get_override_sprite` (`GetEffectSprite`) and the
`_ui` / `_position` / `_rotationZ` / `_count` override variants.

### Registration
```csharp
AssetManager.status.add(status);
```
Post: `AssetManager.status.linkAssets()`, `setupCachedSprites()`, `setupBools()`.

### Minimal snippet (real mod)
`Mods\AVOIDINGBOREDOM_AVB_S_ULTRA_TRAIT_PACK\Code\Statuses.cs`
```csharp
StatusAsset bleeding = new StatusAsset() {
    id = "tbleeding",
    locale_id = "status_title_tbleeding",
    locale_description = "status_description_tbleeding",
    duration = 8f,
    action = new WorldAction(bleedingEffect),
    action_interval = 1f,
    path_icon = $"ui/Icons/iconBloodRain",
    decision_id = null
};
```
`worldbox_Data\StreamingAssets\mods\ElementalPowersMod\Effects\CustomEffects.cs:15-35`
```csharp
StatusAsset effect = new StatusAsset();
effect.id = "overcharged_buff";
effect.duration = 30f;
effect.path_icon = "ui/icons/icon_swift";
effect.action = (BaseSimObject pTarget, WorldTile pTile) =>
{
    Actor pActor = pTarget as Actor;
    if (pActor != null && pActor.isAlive()) pActor.restoreHealth(5);
    return true;
};
AssetManager.status.add(effect);
```

### Gotchas
- The game does **not** prefix status locale keys — `locale_id` / `locale_description` are
  used verbatim. The `"status_title_"` / `"status_description_"` prefixes are a *mod
  convention* (SCPBOX uses `status_description_`, ElementalPowersMod uses `status_desc_`).
  Pick one and be consistent.
- The ElementalPowersMod snippet mutates `effect.base_stats["speed"]` **without** assigning
  `new BaseStats()`. Assign it explicitly to avoid a possible NRE.
- `action` is invoked on `action_interval`; return `true` to keep the status alive.

---

## 6. Buildings & Tiles

### Buildings
**Class** `BuildingAsset : Asset`. Library: `AssetManager.buildings` (`BuildingLibrary`).

Required-ish fields: `id`, `sprite_path`, `atlas_asset`, `building_type` (`BuildingType`),
`construction_progress_needed`, `cost` (`ConstructionCost`).

```csharp
// Mods\SCPBOX_MOD\Code\ScpBuildings.cs:111-118
private static void Finish(BuildingAsset pAsset)
{
    pAsset.sprite_path = "buildings/" + pAsset.id;
    pAsset.atlas_asset = AssetManager.dynamic_sprites_library?.get("buildings");
    AssetManager.buildings.add(pAsset);
    Localization.AddOrSet(pAsset.id, pAsset.id);
}
```
Post-registration:
```csharp
AssetManager.buildings.linkAssets();
bAsset.checkSpritesAreLoaded();
```
(`Mods\TAYFIM_ABYSSFALL\Code\Main.cs:210-223` does exactly this.)

Other useful `BuildingAsset` fields: `building_sprites` (`BuildingSprites`),
`has_sprites_main`, `has_sprites_spawn`, `has_sprites_ruin`, `has_sprites_special`,
`has_sprite_construction`, `has_ruin_state`, `has_ruins_graphics`, `group`, `type`,
`kingdom`, `civ_kingdom`, `material`, `scale_base`, `bonus_z`, `grow_creep*`,
`resources_given`, `production` flags, `spawn_units`, `spawn_units_asset`, `tower`,
`tower_projectile`, `housing_slots`, `storage`, `docks`, `waypoint`, `burnable`,
`affected_by_lava`, `affected_by_acid`, `can_be_damaged_by_tornado`, `can_be_placed_on_liquid`,
`build_place_*`, `smoke`, `smoke_interval`, `spawn_drops`, `spawn_drop_id`,
`sound_spawn`/`sound_idle`/`sound_hit`/`sound_built`/`sound_destroyed`, `base_stats`,
`priority`, `upgrade_to`, `upgraded_from`, `get_map_icon_color`.

### Tiles
Libraries on `AssetManager`: `tiles` (`TileLibrary`), `top_tiles` (`TopTileLibrary`),
`tile_tile_effects` (`TileEffectsLibrary`), `terraform` (`TerraformLibrary`),
`biome_library` (`BiomeLibrary`).
**UNVERIFIED**: the field set of `TileAsset`/`TopTileAsset` was not extracted; register
tiles by cloning a vanilla asset and overriding `id`/`path_icon` in the same way as
buildings, and validate by running the game.

---

## 7. World effects (non-status VFX)

**Library** `AssetManager.effects_library` (`EffectsLibrary : AssetLibrary<BaseEffect>`).

Spawning (does **not** require registration — the effect must already exist):
```csharp
BaseEffect e = AssetManager.effects_library.spawnAtTile(string pID, WorldTile pTile, float pScale);
BaseEffect e2 = AssetManager.effects_library.spawnAt(string pID, Vector2 pPos, float pScale);
BaseEffect e3 = AssetManager.effects_library.spawnAtTileRandomScale(pID, tile, min, max);
BaseEffect e4 = AssetManager.effects_library.spawn(pID, tile, pParam1, pParam2, pFloatParam1, pX, pY, pActor);
```
Also `spawnExplosionWave`, `spawnSlash`, `spawnMeteorite`, `spawnCloud`, `spawnFireworks`,
`showSpawnEffect`, `showMetaEventEffect`, `highlightKingdomZones`, `showMoneyEffect`.
**UNVERIFIED**: `BaseEffect` field set / how to register a brand-new effect asset.

---

## 8. Kingdoms

**Class** `KingdomAsset`. Library: `AssetManager.kingdoms` (`KingdomLibrary`).

Fields observed in use: `id`, `civ`, `mobs`, `nomads`, `count_as_danger`,
`default_kingdom_color`, plus tag API `addTag(string)`, `addFriendlyTag(string)`,
`addEnemyTag(string)`.

```csharp
// Mods\TAYFIM_ABYSSFALL\Code\MagicKingdoms.cs:117-133
var Spirit = new KingdomAsset();
Spirit.id = "spirit";
Spirit.mobs = true;
Spirit.addTag("spirit");
Spirit.addFriendlyTag("spirit");
Spirit.addEnemyTag("civ");
Spirit.count_as_danger = false;
Spirit.default_kingdom_color = ColorAsset.tryMakeNewColorAsset("#38705C");
AssetManager.kingdoms.add(Spirit);

if (World.world != null && World.world.kingdoms_wild != null)
    GameReflection.newWildKingdom(World.world.kingdoms_wild, Spirit);
```
Clone helpers on `KingdomLibrary`: `clone(string pNew, string pFrom)`,
`cloneAsMiniciv(string pNew, string pFrom, bool pMakeLoveToNeutrals)`, `finish(KingdomAsset)`.
Post-registration: `AssetManager.kingdoms.post_init(); AssetManager.kingdoms.linkAssets();`
(`Mods\TAYFIM_ABYSSFALL\Code\Main.cs:224-227`).

### Kingdom traits
`KingdomTrait` — fields `is_local_tax_trait`, `is_tribute_tax_trait`, `tax_rate`.
Library `AssetManager.kingdoms_traits` (`KingdomTraitLibrary`); groups in
`AssetManager.kingdoms_traits_groups` (`KingdomTraitGroupLibrary`).

### Subspecies (visual variant) traits
`SubspeciesTrait` — fields include `sprite_path`, `texture_asset`, `animation_walk`,
`animation_swim`, `animation_idle`, `phenotype_skin`, `phenotype_egg`, `id_phenotype`,
`id_egg`, `in_mutation_pot_add`, `in_mutation_pot_remove`, `remove_for_zombies`,
`is_diet_related`, `is_mutation_skin`, `shadow`, `shadow_texture*`, `render_heads_for_children`,
`prevent_unconscious_rotation`.
Library: `AssetManager.subspecies_traits` (`SubspeciesTraitLibrary`); groups in
`AssetManager.subspecies_trait_groups`.

---

## 9. Races  →  there is no `Race` / `RaceLibrary`

Verified absent from the 2444 types. In WorldBox a "race" is expressed as:
`ActorAsset` (template) + `Subspecies` (runtime variant) + `SubspeciesTrait` (skin/phenotype).
Use §3 + §8.

---

## 10. Localization

### The game's own loader
`LocalizedTextManager` (singleton `LocalizedTextManager.instance`):
- `getText(string pKey, Text text, bool pForceEnglish)` — main lookup.
- `stringExists(string)`, `loadLocalizedText(string pLocaleID)`, `setLanguage(...)`,
  `updateTexts()`, `getKeys()`, `getAllLanguages()`, `getCurrentCulture()`.
- `loadLocalizedText` loads Unity `Resources` at `"locales/<lang>"` and JSON-parses each
  `TextAsset` into `Dictionary<string,string>` (confirmed in IL:
  `JsonConvert.DeserializeObject<Dictionary<string,string>>`).
- The **key naming convention the game derives from assets**:

| Asset | Locale key | Derivation (IL-verified) |
|---|---|---|
| ActorTrait name | `trait_<id>` | `BaseTrait.getLocaleID()` = `typed_id + "_" + id`; `ActorTrait.get_typed_id()` returns `"trait"` |
| ActorTrait desc 1 | `trait_<id>_info` | `getDescriptionID()` = `typed_id + "_" + id + "_info"` |
| ActorTrait desc 2 | `trait_<id>_info_2` | `getDescriptionID2()` = `... + "_info_2"` |
| Trait group | *(the `name` field itself)* | `BaseCategoryAsset.getLocaleID()` returns the `name` field verbatim |
| GodPower | `Underscore(name)` | `GodPower.getLocaleID()` = `StringExtension.Underscore(name)` |
| GodPower desc | `Underscore(name) + "_description"` | `GodPower.getDescriptionID()` = `getLocaleID() + "_description"` |
| PowerButton | `button_<Underscore(buttonName)>` | `PowerButton.getText()` |
| StatusAsset | *(explicit)* `locale_id` / `locale_description` | fields used verbatim |
| ActorAsset | `actor_<id>` | mod convention (see SCPBOX `Unit()`) |
| Building | `building_<id>` | mod convention (see SCPBOX `Buildings()`) |

`StringExtension.Underscore` converts CamelCase to snake_case; a string that is already
snake_case is (in observed usage) returned unchanged. **UNVERIFIED**: the exact predicate
(`ShouldUnderscore`) was only partially decompiled.

> **Real gotcha**: `worldbox_Data\StreamingAssets\mods\ElementalPowersMod\Powers\CustomPowers.cs:29-30`
> registers `"power_celestial_strike"` / `"power_celestial_strike_info"`, but the game looks
> up `Underscore(name)` = `"celestial_strike"` and `"celestial_strike_description"`.
> Those keys will not resolve. Register the underscored form.

### NML localization API
`NeoModLoader.General.LM`:
```csharp
LM.Get(string key);
LM.Has(string key, string lang);
LM.AddToCurrentLocale(string key, string value);
LM.Add(string language, string key, string value);
LM.ApplyLocale(bool pUpdateTexts);
LM.ApplyLocale(string language, bool pUpdateTexts);
LM.LoadLocales(string pFilePath, char pSep);   // CSV
LM.LoadLocale(string pLanguage, string pFilePath);  // .json
LM.LoadLocale(string pLanguage, Stream pStream);    // .json
```
`NCMS.Utils.Localization` (legacy): `Add`, `AddOrSet`, `Set`, `Get`,
`addLocalization`, `setLocalization`, `getLocalization`.

### Mod locale files
- Folder: `<modFolder>\Locales\<lang>.json` (folder name is exactly `Locales`).
- Loaded automatically by NML **only if the mod implements `ILocalizable`**
  (`GetLocaleFilesDirectory(ModDeclare)`), via
  `ModCompileLoadService.<LoadMod>g__auto_localize`. `BasicMod<T>` already implements it.
- JSON format: flat `{"key": "value", ...}`.
- `default_config.json` in the mod root is the **mod settings** file (different thing).

### Keeping translations alive across language changes
`Mods\SCPBOX_MOD\Code\ScpLocale.cs:256-283` re-applies its strings after every locale reload:
```csharp
[HarmonyPatch(typeof(LocalizedTextManager), "loadLocalizedText")]
public static class Patch_LocalizedTextManager_LoadLocalizedText
{
    public static void Postfix() { ApplyAll(); }
}
```
plus patches on `setLanguage`, `updateTexts`, `getText`, `stringExists`.
`LM.ApplyLocale(false)` re-applies the current locale after you inject strings.

---

## 11. Items / Equipment

**Class** `EquipmentAsset : ItemAsset : BaseAugmentationAsset : BaseUnlockableAsset`.

Fields: `id`, `name_class`, `equipment_type` (`EquipmentType`), `equipment_subtype`,
`quality` (`Rarity`), `path_icon`, `attack_type` (`WeaponType`), `durability`,
`rigidity_rating`, `equipment_value`, `cost_gold`, `cost_resource_1` +
`cost_resource_id_1`, `cost_resource_2` + `cost_resource_id_2`,
`cost_coins_resources`, `material`, `colored`, `mod_rank`, `mod_type`,
`mod_can_be_given`, `translation_key`, `animated`, `pool`, `is_pool_weapon`, `pool_rate`,
`projectile`, `path_slash_animation`, `path_gameplay_sprite`, `gameplay_sprites` (`Sprite[]`),
`item_modifiers` (`ItemModAsset[]`), `item_modifier_ids`, `name_templates`.
`EquipmentAsset` methods: `getSprites()`, `get_is_colored()`, `get_is_animated()`.

### Registration
```csharp
AssetManager.items.add(asset);   // ItemLibrary.add(EquipmentAsset) -> EquipmentAsset
asset.unlock(true);
```
Real usage — `Mods\RAYTRACERX_SHINOBIBOX\Code\ShinobiItems.cs:71`:
```csharp
scythe.group_id = GroupId_ShinobiEquipment;
scythe.quality = Rarity.R3_Legendary;
scythe.is_pool_weapon = false;
scythe.unlock(true);
```
Templates for cloning: `$template_equipment$`, `$template_armor$`, `$template_boots$`,
`$template_helmet$`, `$template_accessory$`, `$template_ring$`, `$template_amulet$`,
`$template_weapon$`, `$template_melee$`, `$template_range$`, `$template_bow$`,
`$template_sword$`, `$template_axe$`, `$template_hammer$`, `$template_spear$`.
Post: `AssetManager.items.linkAssets()`, `loadSprites()`, `post_init()`.

---

## 12. UI (tabs, buttons, windows)

All in `NeoModLoader.General` / `NeoModLoader.General.UI.Tab` (from `NeoModLoader.dll`).

### Tabs
```csharp
// NeoModLoader.General.UI.Tab.TabManager
PowersTab tab = TabManager.CreateTab(
    string name,          // tab id, e.g. "Tab_MyMod"
    string pTitleKey,     // locale key for the tab title
    string pDescKey,      // locale key for the tab description
    Sprite pIcon,
    string pOptionDescKey);
```
`TabManager` also: `GetTab(string)` (on `PowerButtonCreator`), `_checkNewTabs()`,
`_updateTabLayout()`, `_addTabEntry()`, `_savePredefinedOrder()`, `_loadPredefinedOrder()`.
Tab order persists to `tab_order_records.json`.

### Buttons
```csharp
// NeoModLoader.General.PowerButtonCreator
PowerButton b = PowerButtonCreator.CreateGodPowerButton(string pGodPowerId, Sprite pIcon, Transform pParent, Vector2 pLocalPosition);
PowerButton b2 = PowerButtonCreator.CreateWindowButton(string pId, string pWindowId, Sprite pIcon, Transform pParent, Vector2 pLocalPosition);
PowerButton b3 = PowerButtonCreator.CreateSimpleButton(string pId, UnityAction pAction, Sprite pIcon, Transform pParent, Vector2 pLocalPosition);
PowerButton b4 = PowerButtonCreator.CreateToggleButton(string pGodPowerId, Sprite pIcon, Transform pParent, Vector2 pLocalPosition, bool pNoAutoSetToggleAction);
PowerButtonCreator.AddButtonToTab(button, tab, Vector2 position, int? siblingIndex);
PowerButtonCreator.GetTab(string pId);
```
`PowerButton` fields: `godPower`, `open_window_id`, `icon` (`Image`), `_icon_lock` (`Image`).

### Windows
```csharp
// NeoModLoader.General.WindowCreator
ScrollWindow w = WindowCreator.CreateEmptyWindow(string pWindowID, string pWindowTitleKey, string pWindowIcon);
```
Game-side: `ScrollWindow.windowLoaded(string id)`; `StatsWindow` exists.

### Real snippet
`Mods\SCPBOX_MOD\Code\ScpTab.cs:14-22`
```csharp
Tab = TabManager.CreateTab(
    "Tab_ScpBox",
    "ScpBox",
    "scp_tab_desc",
    Sprites.LoadSprite($"{Main.ModFolder}/EmbededResources/UI/Icons/iconScpTab.png")
);
```
`Mods\TRIICKSTR_PLENTY_O_BIOMES\Code\CreatureTab.cs:50`
```csharp
powersTabComponent = TabManager.CreateTab("Tab_Additional_CREATURE", "newTab_CREATURE", "newTab_CREATURE",
    NCMS.Utils.Sprites.LoadSprite($"{Mod.Info.Path}/pepe.png"));
```
Button creation — `Mods\SCPBOX_MOD\Code\ScpPowers.cs:138-141`
```csharp
Transform tab = ScpTab.Tab.transform;
```

### In-game trait UI
Classes exist: `ActorTraitEditorButton`, `ActorTraitsEditor`, `ActorTraitButton`,
`ActorSelectedContainerTraits`, `ActorSelectedMetaBanners`, `ActorAssetWindow`,
`KingdomWindow`, `SubspeciesWindow`. There is **no** `AddActorMenu` and **no** `WorldPanel`.

---

## 13. Sprite / texture pipeline  (VERDICT: Resources-based, NOT atlas-based)

There is **no `SpriteAtlas`** in the assembly. Two independent mechanisms exist.

### (A) `path_icon` on assets → Unity `Resources` path (no extension)
`BaseUnlockableAsset.getSprite()` IL:
```
cached_sprite = SpriteTextureLoader.getSprite(path_icon)
```
`SpriteTextureLoader.getSprite(string pPath)` IL:
```
Resources.Load(pPath, typeof(Sprite))   // cached in _cached_sprites
```
So `path_icon = "ui/Icons/iconKings"` loads the Unity resource `ui/Icons/iconKings`.

**NML makes `Resources.Load` see your mod's files.** `NeoModLoader.utils.ResourcesPatch`
harmony-patches `Resources.Load` / `Resources.LoadAll`
(`Load_Prefix` / `LoadAll_Prefix` / `Load_Postfix` / `LoadAll_Postfix`) and serves assets
from a `ResourceTree` built out of the mod's resource folders. NML's `Paths` constants
include **`ModResourceFolderName = "GameResources"`** (plus `"GameResourcesReplace"`,
`"Resources"`, `"AssetBundles"`, `"EmbededResources"`).

**Rule:** put the PNG at `<ModFolder>/GameResources/<same path as path_icon>.png`.
Verified with a real mod:
- `path_icon = "ui/Icons/godzilla/godzilla_tab"` ↔
  `Mods\AGRICHE_GODZILLA\GameResources\ui\Icons\godzilla\godzilla_tab.png` ✔
- `path_icon = "ui/Icons/iconScp001"` ↔
  `Mods\SCPBOX_MOD\GameResources\ui\Icons\iconScp001.png` ✔
- `path_icon = "actors/scp/Scp001/main/walk_0"` ↔
  `Mods\SCPBOX_MOD\GameResources\actors\scp\Scp001\main\walk_0.png` ✔

`ResourcesPatch.LoadResourceFromFolder(folder, out builders)` walks the folder
recursively and builds the tree with forward slashes, stripping the leading separator.
`LoadAll_Prefix` normalizes `..` segments in the requested path.

**Observed image sizes** (no single mandated size — the game scales):
- Trait / status icons: **64×64** (`godzilla_cage.png`, `k_anguirus.png`, …).
- Tab icons: irregular (147×130 for `godzilla_tab.png`).
- Actor frames: creator-dependent — 15×10, 30×30 and 400×400 all appear for `walk_0.png`.
  Match the vanilla creature you are imitating.

### (B) Direct-from-disk sprite loading (for tab / window icons)
`NCMS.Utils.Sprites`:
```csharp
Sprite LoadSprite(string path, float offsetX, float offsetY);
```
IL: `File.ReadAllBytes(path)` → `ImageConversion.LoadImage(Texture2D)` (aniso 0, filter
`Point`) → `Sprite.Create(texture, new Rect(0,0,w,h), new Vector2(offsetX, offsetY), 1.0f)`.
- `path` is an **OS filesystem path** (e.g. `$"{Main.ModFolder}/EmbededResources/UI/Icons/iconScpTab.png"`,
  `$"{Mod.Info.Path}/pepe.png"`), *not* a Resources path.
- `pixelsPerUnit` is fixed at **1.0**; the pivot is `(offsetX, offsetY)` in pixels.
- Prefer this for custom tab/window icons; prefer (A) for `path_icon` on assets.

### (C) Building / actor sprite atlases
- Buildings: `sprite_path = "buildings/" + id` and
  `atlas_asset = AssetManager.dynamic_sprites_library?.get("buildings")`.
  So a building's frames live under a `buildings/` resource subtree.
- Actors: `new ActorTextureSubAsset("actors/<id>/", false)` → frames under
  `actors/<id>/main/<frame>.png` (see §3 for the full sub-path list).

### Gotchas
- `path_icon` must **not** include `.png`.
- `path_icon` is case-sensitive in Unity Resources — `ui/Icons/...` vs `ui/icons/...` are
  different (real mods use both spellings for *different* assets; match the file exactly).
- A missing icon yields a null `Sprite` → Unity "missing sprite" placeholder, no exception.
  `AssetLibrary.checkSpriteExists(...)` and `BaseAssetLibrary.hasSpriteInResources(path)`
  let you assert presence; `AssetManager.exportAssets()` dumps the asset table for checking.
- `ResourcesPatch` resolves `..` in `Resources.LoadAll` paths — avoid `..` in your own paths.
- `Sprites.LoadSprite` returns a sprite with `pixelsPerUnit = 1`; UI code may scale it oddly.

---

## 14. Settings, save/load, and patching

### Mod settings
`default_config.json` in the mod root, consumed by `ModConfig`:
```csharp
ModConfig cfg = Instance.GetConfig();
ModConfigItem item = cfg.GetItem("kaiju_scale");
```
`NeoModLoader.ui.ModConfigureWindow.ShowWindow(Instance.GetConfig())` opens the settings UI.
Real example: `Mods\AGRICHE_GODZILLA\default_config.json`
```json
{ "godzilla_main": [
  { "Type": "SLIDER", "Id": "kaiju_scale", "IconPath": "ui/Icons/godzilla/godzilla_tab",
    "FloatVal": 4.0, "MinFloatVal": 0.5, "MaxFloatVal": 8.0 } ] }
```
`Type` values observed: `SWITCH`, `SLIDER`, `INT_SLIDER`, plus `BoolVal` / `IntVal` / `FloatVal`
/ `TextVal` / `Min*Val` / `Max*Val` / `Callback` (`"Namespace.Class:Method"`).

### Game options
`PlayerConfig.instance.data` is a `PlayerConfigData`; add an option with
`PlayerConfig.instance.data.add(new PlayerOptionData(pId) { boolVal = pDefaultOn });`
(`Mods\CORE4777_COREBOX\Code\Core\CoreBoxToggles.cs:25`). `PlayerConfig` exposes
`optionBoolEnabled`, `getOptionInt`, `getOptionString`, `setOptionBool/Int/String`,
`saveData()`, `loadData()`.

### Save / load
Harmony-patch the game's save pipeline:
- `SaveManager.saveMapData` (`Mods\AGRICHE_GODZILLA\Code\Persist.cs:131`)
- `SaveManager.loadData` (`Persist.cs:147`)
- `ActorManager.loadObject(ActorData)` (`Persist.cs:167`) — re-attach mod data to actors
  after a load.
Also track `Config.game_loaded` to know when a world became available and to reset state
(`Mods\TAYFIM_ABYSSFALL\Code\Main.cs:373-380`).

### Harmony
- NML's harmony id is `wbom.nml` (`NeoModLoader.constants.Others.harmony_id`).
- Use a unique id per mod: `new Harmony("com.example.mymod")`.
- Attribute style: `[HarmonyPatch(typeof(Actor), nameof(Actor.getHit))]` with static
  `Prefix` / `Postfix`.
- Overload-targeted patch:
  `[HarmonyPatch(typeof(BaseSimObject), nameof(BaseSimObject.addStatusEffect), new[] { typeof(string), typeof(float), typeof(bool) })]`
- Apply with `harmony.PatchAll()` or `harmony.PatchAll(typeof(MyClass))`; undo with
  `harmony.UnpatchSelf()` in `OnUnload`.

---

## 15. `AssetManager` — the registry index

`AssetManager` (singleton, `AssetManager.instance`) holds ~150 libraries. The ones modders
touch:

| Field | Type | Field | Type |
|---|---|---|---|
| `traits` | `ActorTraitLibrary` | `trait_groups` | `ActorTraitGroupLibrary` |
| `powers` | `PowerLibrary` | `status` | `StatusLibrary` |
| `actor_library` | `ActorAssetLibrary` | `buildings` | `BuildingLibrary` |
| `kingdoms` | `KingdomLibrary` | `kingdoms_traits` | `KingdomTraitLibrary` |
| `kingdoms_traits_groups` | `KingdomTraitGroupLibrary` | `subspecies_traits` | `SubspeciesTraitLibrary` |
| `subspecies_trait_groups` | `SubspeciesTraitGroupLibrary` | `clan_traits` / `culture_traits` / `religion_traits` / `language_traits` | matching libraries |
| `items` | `ItemLibrary` | `item_groups` | `ItemGroupLibrary` |
| `effects_library` | `EffectsLibrary` | `base_stats_library` | `BaseStatsLibrary` |
| `tiles` | `TileLibrary` | `top_tiles` | `TopTileLibrary` |
| `drops` | `DropsLibrary` | `spells` | `SpellLibrary` |
| `projectiles` | `ProjectileLibrary` | `dynamic_sprites_library` | `DynamicSpritesLibrary` |
| `power_tab_library` | `PowerTabLibrary` | `window_library` | `WindowLibrary` |
| `biome_library` | `BiomeLibrary` | `terraform` | `TerraformLibrary` |

`AssetLibrary<T>` API (the base of all of them):
```csharp
T add(T pAsset);
T get(string pID);
T getSimple(string pID);
bool has(string pID);
T clone(string pNew, string pFrom);
void clone(out T pNew, T pFrom);
T[] getArray();
IEnumerable<T> getList();
int total_items { get; }
void loadFromFile(); void saveToFile(string pPath);
bool checkSpriteExists(string pVariableID, string pPath, Asset pAsset);
void editorDiagnostic(); void editorDiagnosticLocales();
```

---

## 16. Global gotchas list

1. **Register inside `OnModLoad`.** The game's `AssetManager.init()` has already run, so
   `AssetManager.traits.get(...)` is safe; but anything the game *links* later
   (actor textures, buildings, powers) needs a manual re-link afterwards.
2. **Idempotence.** Always guard with `if (AssetManager.X.get(id) != null) return;` — mods
   reload on game restart and NML may call init twice.
3. **`add()` and `unlock()` are different.** `add()` registers; `unlock(true)` makes the
   asset obtainable and persists it.
4. **Assets are reference types.** Sharing one `BaseStats`/`ActorTrait` instance between
   multiple assets aliases state.
5. **Delegates are fields.** `click_action`, `action_special_effect` etc. are delegate
   fields — use `+=` to compose.
6. **World access requires a loaded world.** `MapBox.instance`, `World.world`,
   `ActorManager`, `World.world.kingdoms_wild` are null before a world exists; null-check.
7. **Locale keys are derived, not free-form**, for traits/powers/buttons (see §10). Status
   keys are free-form.
8. **`path_icon` has no extension** and is a Resources path relative to `GameResources/`.
9. **Mods are recompiled by NML from `Code\*.cs` at game start** — you do not need to ship
   a DLL. (`worldbox_Data\StreamingAssets\mods\ElementalPowersMod\` ships one because it is
   a *native* mod in `StreamingAssets`, which NML loads as a prebuilt assembly.)
10. **Use `LogInfo` / `Debug.Log`**, and wrap each init step in try/catch so one failure
    does not abort the whole mod (see §idioms doc).
```

---

## 17. Deep Decompiled Signatures for Combat, Projectiles, Buildings, Biomes & Windows

Extracted directly from `worldbox_Data\Managed\Assembly-CSharp.dll` (2,444 types, IL-verified):

### 17.1 Combat & Damage Pipeline (`Actor`)
```csharp
// The primary damage entry point
public void getHit(
    float pDamage, 
    bool pFlash, 
    AttackType pAttackType, 
    BaseSimObject pAttacker, 
    bool pSkipIfShake, 
    bool pMetallicWeapon, 
    bool pCheckDamageReduction);

// Physical attack initiation
public bool tryToAttack(
    BaseSimObject pTarget, 
    bool pDoChecks, 
    Action pKillAction, 
    Vector3 pAttackPosition, 
    Kingdom pForceKingdom, 
    WorldTile pTileTarget, 
    float pBonusAreOfEffect);

// Target acquisition AI
public BaseSimObject findEnemyObjectTarget(bool pAttackBuildings);
public void ignoreTarget(BaseSimObject pTarget);
public bool shouldIgnoreTarget(BaseSimObject pTarget);
public void clearIgnoreTargets();
```

### 17.2 Ballistics & Spawning (`ProjectileManager`)
```csharp
// Located at World.world.projectiles
public Projectile spawn(
    BaseSimObject pInitiator, 
    BaseSimObject pTargetObject, 
    string pAssetID, 
    Vector3 pLaunchPosition, 
    Vector3 pTargetPosition, 
    float pTargetZ, 
    float pStartPosZ, 
    Action pKillAction, 
    Kingdom pForcedKingdom);
```

### 17.3 Construction & City Buildings (`BuildingManager` & `BuildingAsset`)
```csharp
// Located at MapBox.instance.buildings
public Building newBuilding(string pID, WorldTile pTile);

// Key BuildingAsset fields:
public BuildingFundament fundament;   // e.g. new BuildingFundament(1, 1, 1, 1)
public ConstructionCost cost;         // e.g. new ConstructionCost(gold, wood, stone)
public bool civ_kingdom;
public bool city_building;
public bool can_be_placed_on_liquid;
public string material;               // "stone", "wood", "gold"
public string sprite_path;            // "buildings/<id>"
```

### 17.4 Warfare & Diplomacy (`DiplomacyManager` & `WarManager`)
```csharp
// Located at World.world.diplomacy
public void startWar(Kingdom pAttacker, Kingdom pDefender, WarTypeAsset pAsset, bool pForced);

// Located at World.world.wars
public War getWar(Kingdom pKingdom1, Kingdom pKingdom2);
public void endWar(War pWar);
```

### 17.5 Native Window System (`ScrollWindow`)
```csharp
// Opens any window registered in ScrollWindow.allWindows
public static void showWindow(string pWindowID);
public static Dictionary<string, ScrollWindow> allWindows; // Map of screen_id to window instance
public static ScrollWindow current_window;
public static bool is_any_window_active;
```
