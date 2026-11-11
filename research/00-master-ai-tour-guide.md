# Master WorldBox Modder Tour Guide: The Comprehensive Blueprint for AI & Engineers

> **Document Type:** Elephant-and-Goldfish Model (EGM) Master Blueprint  
> **Target Platform:** WorldBox (Unity 2022.3.60f1 / Mono runtime, IL2CPP-free)  
> **Mod Loader:** NeoModLoader (NML) 1.2.0.1+ / 1.2.1.1+ (Roslyn C# 4.9.2 runtime compiler)  
> **Verified Ground Truth:** Live install at `C:\Program Files (x86)\Steam\steamapps\common\WorldBox`

---

## 1. System Overview & The Modding Engine Anatomy

### 1.1 How WorldBox Modding Actually Works
WorldBox uses **NeoModLoader (NML)**, an open-source mod loader that compiles C# source files directly into memory at game startup using an embedded Roslyn compiler. 

Unlike traditional Unity modding where developers compile DLLs and inject them via BepInEx:
1. **You ship raw C# source code (`.cs`), not precompiled DLLs.**
2. NML discovers mod folders in `<Game>\Mods\`.
3. Every mod folder MUST contain a valid `mod.json` declaration manifest. If missing or misconfigured, NML logs `[NML]: No mod.json file for folder <path>` and silently ignores the folder.
4. NML compiles the `.cs` files against **187 game and engine assemblies** (including `Assembly-CSharp-Publicized.dll`, `UnityEngine.*`, `0Harmony.dll`, `Newtonsoft.Json`, `Mono.Cecil`, etc.).
5. The compiled output is cached in `worldbox_Data\StreamingAssets\mods\NML\CompiledMods\<GUID>.dll`.
6. NML locates your entry point class (deriving from `NeoModLoader.api.BasicMod<T>`) and invokes its lifecycle methods.

```
<GameInstall>\Mods\<ModFolder>\
├── mod.json                [MANDATORY] Declaration manifest
├── icon.png                [RECOMMENDED] Display icon (64x64 or 128x128 PNG)
├── default_config.json     [OPTIONAL] Config schema auto-rendered in Mod Settings
├── Code\                   [STANDARD] All C# source code files (.cs)
│   ├── Main.cs             Primary entry class deriving from BasicMod<Main>
│   ├── Combat\             Combat logic, smears, hit-stop, damage formulas
│   ├── Content\            Traits, god powers, races, items, status effects
│   ├── UI\                 Windows, tabs, power buttons
│   └── Patches\            Harmony detours
├── Locales\                [RECOMMENDED] en.json, cz.json, ru.json, etc.
└── GameResources\          [OPTIONAL] Sprites, icons, SFX auto-patched into Resources
    ├── actors\             Unit sprites and heads
    ├── effects\            Auras, projectiles, slashes, particles
    └── ui\icons\           Trait, power, and tab button icons
```

---

## 2. The Architectural Differences: Amateur vs. Studio-Grade

Analysis of the top WorldBox mods (`AdeptusAstartes`, `TURBO_SAKUGA / Combat Gods`, `PowerBox`, `Viltrum Empire`, `Cosmic Fear`) reveals the exact design choices separating amateur hobby mods from resilient, studio-grade expansions:

| Feature / Concern | Amateur Pattern (Fragile) | Studio-Grade Pattern (Mastery) |
|---|---|---|
| **Initialization** | Monolithic block inside `OnModLoad()`. One error aborts entire mod. | Resilient `Step("subsystem", Action)` isolation. Errors log diagnostics while remaining features load. |
| **Harmony Patching** | `harmony.PatchAll()`. One broken game method signature disables all patches. | Granular `PatchEach()` with `harmony.CreateClassProcessor(t).Patch()`. One failing patch fails gracefully. |
| **World Lifecycle** | Ignores world unload. GameObjects, timers, and flying VFX leak across worlds. | Hooks `[HarmonyPatch(typeof(MapBox), "clearWorld")]` to purge flying effects, timers, and active state. |
| **Stat Calculations** | Blindly hardcodes stat numbers, causing overflows or stat wipeouts. | Adheres strictly to the 67 valid Stat IDs, delta arithmetic, and percentage multiplier conventions. |
| **Visual Polish & Feel** | Instant, weightless damage numbers. Units stiffly bump into each other. | Procedural weapon smears, hit-stop freeze frames (`HitStop`), localized camera shakes, living auras. |
| **Audio** | Silent, or crashes trying to load missing FMOD Studio sound banks. | Uses native `FMOD.System.createSound` to play raw `.wav` audio with 3D linear rolloff directly from disk. |
| **UI Tab Creation** | Tries to build UI in `OnModLoad()` before game UI exists (crashes). | Checks `Config.game_loaded && MapBox.instance != null` in `Update()` before lazy tab construction. |
| **Localization** | Hardcoded strings in English inside C# code. Shows broken raw keys. | External `Locales/<lang>.json` dictionaries adhering to exact engine key prefixes (`trait_<id>`, `<id>_description`). |
| **Multi-Part Bosses** | Forced to fit inside single 32x32 sprite tile. | Multi-part rigs: base actor controls logic; child rigs & shadows sync in `LateUpdate()`. |

---

## 3. Core Engine Mechanics & System Recipes

### 3.1 Subsystem 1: Resilient Entry Point & Granular Patching
Your entry class must inherit from `NeoModLoader.api.BasicMod<T>`:

```csharp
using System;
using HarmonyLib;
using NeoModLoader.api;
using UnityEngine;

namespace MyMasterMod
{
    public class Main : BasicMod<Main>
    {
        private bool _uiInitialized;

        protected override void OnModLoad()
        {
            LogInfo("Initializing MyMasterMod...");

            // 1. Isolate each subsystem in its own try/catch block
            Step("Settings", Configs.Init);
            Step("Traits", MyTraits.Register);
            Step("Status Effects", MyStatusEffects.Register);
            Step("Items & Weapons", MyItems.Register);
            Step("Races & Units", MyUnits.Register);
            Step("God Powers", MyPowers.Register);
            Step("Localization", MyLocales.Init);

            // 2. Granular Harmony patch registration
            PatchEach(new Harmony("com.mastermod.worldbox"));

            LogInfo("MyMasterMod ready!");
        }

        private void Step(string name, Action action)
        {
            try
            {
                action();
            }
            catch (Exception ex)
            {
                LogError($"[Init Failure] Subsystem '{name}' failed: {ex}");
            }
        }

        private void PatchEach(Harmony harmony)
        {
            foreach (Type t in AccessTools.GetTypesFromAssembly(typeof(Main).Assembly))
            {
                if (t.GetCustomAttributes(typeof(HarmonyPatch), false).Length == 0) continue;
                try
                {
                    harmony.CreateClassProcessor(t).Patch();
                }
                catch (Exception ex)
                {
                    LogError($"[Patch Failure] Patch class '{t.Name}' failed: {ex}");
                }
            }
        }

        private void Update()
        {
            // UI tabs must ONLY be built once the game engine and map are fully active
            if (!_uiInitialized && Config.game_loaded && MapBox.instance != null)
            {
                _uiInitialized = true;
                MyPowers.CreatePowersTab();
            }

            // Real-time combat / aura / frame updates
            if (World.world == null) return;
            MyCombatEngine.Update(Time.deltaTime);
        }

        private void LateUpdate()
        {
            if (World.world == null) return;
            // Multipart transforms & custom shadows must update in LateUpdate after unit movement
            MyMultiPartRigs.LateUpdate();
        }
    }
}
```

---

### 3.2 Subsystem 2: Traits, Stat Arithmetic & BaseStats

#### The 3 Immutable Rules of Stats in WorldBox:
1. **Stats are deltas:** Setting `trait.base_stats["health"] = 500f` **adds 500 health** to the unit's base species value. It does NOT set absolute health to 500.
2. **`multiplier_*` are percentage deltas:** `base_stats["multiplier_speed"] = 0.5f` increases speed by **+50% (×1.5)**.
3. **`scale` is visual; `size` is combat hitbox:** `scale` adjusts the sprite rendering matrix (vanilla human base is `0.1f`). `size` controls physical attack reach.

#### Complete Trait Registration Recipe:
```csharp
public static class MyTraits
{
    public const string TraitWarlord = "warlord_trait";

    public static void Register()
    {
        // 1. Instantiate Trait
        ActorTrait trait = new ActorTrait
        {
            id = TraitWarlord,
            group_id = TraitGroup.Combat,
            path_icon = "ui/icons/iconWarlord", // GameResources/ui/icons/iconWarlord.png (omit extension)
            type = TraitType.Positive
        };

        // 2. Add to library BEFORE assigning base_stats (allocates dictionary)
        AssetManager.traits.add(trait);

        // 3. Configure stats
        trait.base_stats["damage"] = 40f;
        trait.base_stats["armor"] = 15f;
        trait.base_stats["multiplier_health"] = 0.50f; // +50% health
        trait.base_stats["scale"] = 0.04f;             // Slightly larger model
        trait.base_stats["critical_chance"] = 0.25f;

        // 4. Action hooks
        trait.action_attack_target = (pSelf, pTarget, pTile) =>
        {
            if (pTarget != null && pTarget.isAlive())
            {
                pTarget.addStatusEffect("bleeding", 5f);
            }
            return true;
        };

        // 5. Unlock trait in UI library
        trait.unlock(true);
    }
}
```

---

### 3.3 Subsystem 3: Custom God Powers, UI Tabs & Buttons

God Powers appear in the bottom toolbar. To avoid null reference exceptions:
- **Rule:** God powers must be added to `AssetManager.powers` at load time, but their **visual buttons and tabs** must be instantiated in `Update()` after `Config.game_loaded` is true.

```csharp
public static class MyPowers
{
    public const string PowerSummonWarlord = "power_summon_warlord";

    public static void Register()
    {
        GodPower power = new GodPower
        {
            id = PowerSummonWarlord,
            name = PowerSummonWarlord,
            rank = PowerRank.Rank0,
            select_button_action = (pPower) => true,
            click_action = (pTile, pPower) =>
            {
                if (pTile == null) return false;
                Actor unit = World.world.units.createNewUnit("unit_human", pTile);
                if (unit != null)
                {
                    unit.addTrait(MyTraits.TraitWarlord);
                    EffectsLibrary.spawnAt("fx_spawn_flash", pTile.posV3, 0.15f);
                    return true;
                }
                return false;
            }
        };

        AssetManager.powers.add(power);
    }

    public static void CreatePowersTab()
    {
        // NeoModLoader TabManager API
        Sprite tabIcon = SpriteTextureLoader.getSprite("ui/icons/iconTabWarlord");
        PowersTab tab = TabManager.CreateTab("warlord_tab", "warlord_tab", "warlord_tab_description", tabIcon);
        tab.SetLayout(new System.Collections.Generic.List<string> { "warlord_group" });

        // Add button to tab layout
        Sprite btnIcon = SpriteTextureLoader.getSprite("ui/icons/iconWarlord");
        PowerButton btn = PowerButtonCreator.CreateGodPowerButton(PowerSummonWarlord, btnIcon);
        tab.AddPowerButton("warlord_group", btn);

        tab.UpdateLayout();
    }
}
```

---

### 3.4 Subsystem 4: Custom Races, Subspecies & Civilizations

WorldBox does not have a single `RaceAsset`. In WorldBox, a playable civilized race consists of:
1. Adult `ActorAsset` (`unit_<race>`) with `civ = true`.
2. Baby `ActorAsset` (`baby_<race>`) with `grow_into_id = "unit_<race>"`.
3. `Subspecies` genetics profile.
4. `KingdomAsset` civilization rules and architectural style.

#### The Fluent ActorBuilder Pattern (`_VILTRUM_EMPIRE`):
```csharp
public static void CreateCustomRace(string raceId)
{
    string adultId = "unit_" + raceId;
    string babyId = "baby_" + raceId;

    ActorAsset adult = new ActorAsset();
    adult.id = adultId;
    adult.base_stats["health"] = 350f;
    adult.base_stats["damage"] = 30f;
    adult.base_stats["speed"] = 30f;
    adult.base_stats["scale"] = 0.085f;
    adult.civ = true;
    adult.can_have_subspecies = true;
    adult.need_colored_sprite = false;
    adult.use_phenotypes = false;
    adult.texture_path = $"actors/races/{raceId}/";
    adult.has_skin = true;
    adult.has_baby_form = true;
    adult.grow_into_id = "";
    adult.kingdom_id_civilization = raceId;
    adult.kingdom_id_wild = "nomads_human";
    adult.architecture_id = "human";
    adult.name_template_unit = "human_name";
    adult.icon = "icon" + raceId;

    // FMOD sound paths
    adult.sound_spawn = "event:/SFX/UNITS/Human/HumanSpawn";
    adult.sound_attack = "event:/SFX/UNITS/Human/HumanAttack";
    adult.sound_idle = "event:/SFX/UNITS/Human/HumanIdle";
    adult.sound_death = "event:/SFX/UNITS/Human/HumanDeath";

    AssetManager.actor_library.add(adult);

    // Baby form
    ActorAsset baby = new ActorAsset();
    baby.id = babyId;
    baby.base_stats["health"] = 80f;
    baby.base_stats["speed"] = 15f;
    baby.base_stats["scale"] = 0.045f;
    baby.civ = true;
    baby.can_have_subspecies = false;
    baby.has_baby_form = true;
    baby.grow_into_id = adultId;
    baby.texture_path = $"actors/races/{raceId}/";
    baby.name_template_unit = "human_name";
    baby.icon = "icon" + raceId;

    AssetManager.actor_library.add(baby);
}
```

---

### 3.5 Subsystem 5: Combat "Juice", Smears & Hit-Stop

To create anime-level combat feel (`TURBO_SAKUGA` & `AdeptusAstartes`):
1. **Hit-Stop (Impact Frame):** Momentarily freezes time during critical strikes so players feel the weight.
2. **Procedural Smears:** Draw weapon trails dynamically in the direction of the swing.
3. **Screen Shake:** Scales with zoom level.

```csharp
public static class CombatJuice
{
    private static float _hitStopTimer;
    private static float _cooldownTimer;

    public static void TriggerHitStop(float duration = 0.08f)
    {
        if (Time.unscaledTime < _cooldownTimer) return;
        _hitStopTimer = duration;
        _cooldownTimer = Time.unscaledTime + 1.5f; // Prevent micro-stutter loops
    }

    public static void Update(float unscaledDelta)
    {
        if (_hitStopTimer > 0f)
        {
            _hitStopTimer -= unscaledDelta;
            // Freeze simulation clock
            Time.timeScale = 0f;
        }
        else if (Time.timeScale == 0f && Config.time_scale_asset != null)
        {
            // Restore normal simulation clock
            Time.timeScale = Config.time_scale_asset.multiplier;
        }
    }

    public static void ScreenShake(Vector2 position, float duration = 0.2f, float strength = 1.5f)
    {
        if (World.world?.camera == null) return;
        float zoomFactor = Mathf.Clamp(World.world.camera.orthographicSize / 50f, 0.2f, 2.0f);
        World.world.startShake(duration, 0.02f, strength * zoomFactor, true, true);
    }
}
```

---

### 3.6 Subsystem 6: Direct Audio Playback via FMOD Core

WorldBox utilizes FMOD. Instead of requiring complex sound designer toolchains to compile `.bank` files, professional mods load raw `.wav` audio using FMOD's direct core API:

```csharp
using System;
using System.IO;
using FMOD;
using FMODUnity;
using UnityEngine;

public class DirectAudioPlayer
{
    private static FMOD.System _coreSystem;
    private static ChannelGroup _masterChannel;

    public static void Init()
    {
        if (RuntimeManager.StudioSystem.getCoreSystem(out _coreSystem) == RESULT.OK)
        {
            _coreSystem.getMasterChannelGroup(out _masterChannel);
        }
    }

    public static void PlaySound(string wavPath, Vector3 pos, float volume = 0.5f)
    {
        if (!File.Exists(wavPath) || _coreSystem.handle == IntPtr.Zero) return;

        RESULT res = _coreSystem.createSound(wavPath, MODE._3D | MODE._3D_LINEARROLLOFF, out FMOD.Sound sound);
        if (res == RESULT.OK)
        {
            sound.set3DMinMaxDistance(3f, 40f);
            if (_coreSystem.playSound(sound, _masterChannel, true, out Channel channel) == RESULT.OK)
            {
                VECTOR fmodPos = new VECTOR { x = pos.x, y = pos.y, z = pos.z };
                channel.set3DAttributes(ref fmodPos, ref fmodPos);
                channel.setVolume(volume);
                channel.setPaused(false);
            }
        }
    }
}
```

---

### 3.7 Subsystem 7: Localization (`Locales/*.json`)
NML auto-loads JSON files in `Locales/` if your mod entry class derives from `BasicMod<T>`.

#### Exact Key Conventions:
| Asset Type | Name Key | Description Key | Notes |
|---|---|---|---|
| **Trait** | `trait_<id>` | `trait_<id>_info` | Strict prefix `trait_` |
| **Trait Group** | `trait_group_<id>` | *(None)* | Strict prefix `trait_group_` |
| **God Power** | `<id>` | `<id>_description` | **NO `power_` prefix** in locale key |
| **Status Effect** | `effect.locale_id` | `effect.locale_description` | Read from asset fields |
| **World Law** | `<id>_title` | `<id>_description` | Strict suffix `_title` |

`Locales/en.json`:
```json
{
  "trait_warlord_trait": "Warlord",
  "trait_warlord_trait_info": "A fearsome battlefield commander capable of inflicting severe bleeding strikes.",
  "power_summon_warlord": "Summon Warlord",
  "power_summon_warlord_description": "Spawns a human blessed with the Warlord bloodline and battle training.",
  "warlord_tab": "Warlord Armory",
  "warlord_tab_description": "Powers and artifacts of the Supreme Warlords."
}
```

---

## 4. Subsystem 8: Multi-Part Boss Rigs & Transform Syncing (The Titan Pattern)

When creating gargantuan units (e.g. Imperator Titan, Colossal Monsters):
1. Register standard `ActorAsset` with large hitbox (`size = 4f`).
2. Attach visual child GameObjects for arms, turrets, shoulders, and dynamic weapon flashes.
3. Synchronize in `LateUpdate()` so parts follow the root unit sprite smoothly without jitter:

```csharp
[HarmonyPatch(typeof(Actor), nameof(Actor.updatePos))]
internal static class TitanPositionSync
{
    public static void Postfix(Actor __instance)
    {
        if (__instance.asset.id == "unit_titan" && TitanRegistry.TryGetRig(__instance, out TitanRig rig))
        {
            rig.SyncTransforms(__instance.currentPosition, __instance.flip);
        }
    }
}
```

---

## 5. Subsystem 9: Custom Projectiles & Ballistics

WorldBox projectiles are managed by `ProjectileManager` and defined in `AssetManager.projectiles`. Ranged weapons link to them via `ItemAsset.projectile`.

### 5.1 Defining a Custom ProjectileAsset
```csharp
public static class MyProjectiles
{
    public const string ProjectileFireOrb = "projectile_fire_orb";

    public static void Register()
    {
        ProjectileAsset proj = new ProjectileAsset
        {
            id = ProjectileFireOrb,
            texture = "effects/projectiles/fire_orb", // GameResources/effects/projectiles/fire_orb.png
            speed = 18f,
            speed_random = 2f,
            look_at_target = true,
            trail_effect_enabled = true,
            trail_effect_id = "fx_fire_trail",
            trail_effect_timer = 0.05f,
            hit_shake = true,
            shake_intensity = 0.4f,
            shake_duration = 0.15f,
            terraform_option = "fire",
            terraform_range = 1,
            end_effect = "fx_explosion_small",
            sound_launch = "event:/SFX/POWERS/FireSpawn",
            sound_impact = "event:/SFX/EXPLOSIONS/ExplosionSmall",
            can_be_blocked = true,
            trigger_on_collision = true
        };

        // Custom action executed upon hitting the target tile or actor
        proj.impact_actions = (pSelf, pTarget, pTile) =>
        {
            if (pTarget != null && pTarget.isAlive())
            {
                pTarget.getHit(45f, true, AttackType.Fire, pSelf, false, false, true);
                pTarget.addStatusEffect("burning", 4f);
            }
            return true;
        };

        AssetManager.projectiles.add(proj);
    }

    /// <summary>Spawn projectile programmatically from a caster to a target position</summary>
    public static Projectile Launch(BaseSimObject caster, BaseSimObject target, Vector3 startPos, Vector3 targetPos)
    {
        if (World.world?.projectiles == null) return null;
        return World.world.projectiles.spawn(
            pInitiator: caster,
            pTargetObject: target,
            pAssetID: ProjectileFireOrb,
            pLaunchPosition: startPos,
            pTargetPosition: targetPos,
            pTargetZ: 0f,
            pStartPosZ: 0.5f,
            pKillAction: null,
            pForcedKingdom: caster?.kingdom
        );
    }
}
```

---

## 6. Subsystem 10: Combat Engine, Damage Hooks & Evasion Mechanics

WorldBox damage passes through `Actor.getHit(...)`. Intercepting and controlling this method is how professional combat mods (`Combat Gods`, `ShinobiBox`, `AdeptusAstartes`) implement custom shields, elemental resistance, invulnerability phases, or Ultra Instinct-style evasion.

### 6.1 Exact Signature of `Actor.getHit`:
```csharp
public void getHit(
    float pDamage, 
    bool pFlash, 
    AttackType pAttackType, 
    BaseSimObject pAttacker, 
    bool pSkipIfShake, 
    bool pMetallicWeapon, 
    bool pCheckDamageReduction)
```

### 6.2 The Evasion & Damage Redirection Pattern
```csharp
[HarmonyPatch(typeof(Actor), nameof(Actor.getHit))]
public static class Patch_Actor_GetHit
{
    [HarmonyPrefix]
    public static bool Prefix(
        Actor __instance, 
        ref float pDamage, 
        bool pFlash, 
        AttackType pAttackType, 
        BaseSimObject pAttacker, 
        bool pSkipIfShake, 
        bool pMetallicWeapon, 
        bool pCheckDamageReduction)
    {
        if (__instance == null || !__instance.isAlive()) return true;

        // 1. Check for custom trait (e.g. Ultra Instinct / Shadow Step)
        if (__instance.hasTrait("trait_shadow_step"))
        {
            // 35% chance to evade entirely
            if (Toolbox.randomChance(0.35f))
            {
                // Spawn afterimage VFX
                EffectsLibrary.spawnAt("fx_teleport", __instance.currentPosition, 0.1f);
                
                // Reposition 1-2 tiles away
                WorldTile neighbor = __instance.currentTile.neighbours.GetRandom();
                if (neighbor != null && !neighbor.isRuin())
                {
                    __instance.setCurrentTile(neighbor);
                }
                
                // Cancel original damage completely
                return false; 
            }
        }

        // 2. Custom Shield / Damage Absorption
        if (__instance.hasStatusEffect("status_energy_shield"))
        {
            pDamage *= 0.5f; // Absorb 50% damage
            EffectsLibrary.spawnAt("fx_shield_hit", __instance.currentPosition, 0.1f);
        }

        // Return true to allow WorldBox to process remaining damage
        return true; 
    }
}
```

---

## 7. Subsystem 11: Custom Buildings & Village Construction

Buildings in WorldBox are defined in `AssetManager.buildings` and managed by `City` AI and `BuildingManager`.

### 7.1 Defining a Custom BuildingAsset
```csharp
public static class MyBuildings
{
    public const string BuildingWarShrine = "building_war_shrine";

    public static void Register()
    {
        BuildingAsset b = new BuildingAsset
        {
            id = BuildingWarShrine,
            building_type = BuildingType.Temple,
            fundament = new BuildingFundament(1, 1, 1, 1), // Dimensions in tiles
            cost = new ConstructionCost(gold: 25, wood: 40, stone: 20),
            housing = 0,
            civ_kingdom = true,
            city_building = true,
            can_be_placed_on_liquid = false,
            prevent_freeze = true,
            smoke = true,
            sparkle_effect = true,
            material = "stone",
            atlas_id = "buildings",
            sprite_path = "buildings/war_shrine" // GameResources/buildings/war_shrine.png
        };

        // Building aura: buffs friendly units in the city
        b.action = (Building pBuilding, City pCity) =>
        {
            if (pCity == null || pBuilding == null) return;
            foreach (Actor unit in pCity.units)
            {
                if (unit != null && unit.isAlive() && !unit.hasStatusEffect("status_warlord_blessing"))
                {
                    unit.addStatusEffect("status_warlord_blessing", 15f);
                }
            }
        };

        AssetManager.buildings.add(b);
    }

    /// <summary>Spawn building at world tile</summary>
    public static Building SpawnBuilding(WorldTile tile, string buildingId, City city = null)
    {
        if (tile == null || MapBox.instance?.buildings == null) return null;
        Building b = MapBox.instance.buildings.newBuilding(buildingId, tile);
        if (b != null && city != null)
        {
            city.addBuilding(b);
        }
        return b;
    }
}
```

---

## 8. Subsystem 12: Custom Biomes, Vegetation & Map Generation

Biomes are defined in `AssetManager.biome_library` and control tile low/high layers, spontaneous creature/plant spawns, and seed growth.

### 8.1 Complete Biome Registration Recipe
```csharp
public static class MyBiomes
{
    public const string BiomeCrystalline = "biome_crystalline";

    public static void Register()
    {
        BiomeAsset biome = new BiomeAsset
        {
            id = BiomeCrystalline,
            tile_low = "crystal_low",   // References TopTileType
            tile_high = "crystal_high", // References TopTileType
            grow_strength = 4,
            spread_biome = true,
            spread_by_drops_water = true,
            grow_vegetation_auto = true,
            grow_minerals_auto = true,
            pot_spawn_units_auto = true,
            localized_key = "biome_crystalline"
        };

        // Potential spawns in this biome
        biome.pot_trees_spawn = new List<string> { "tree_crystal_1", "tree_crystal_2" };
        biome.pot_plants_spawn = new List<string> { "plant_crystal" };
        biome.pot_minerals_spawn = new List<string> { "mineral_crystal", "mineral_gold" };
        biome.pot_units_spawn = new List<string> { "crystal_golem", "crystal_beetle" };
        biome.pot_sapient_units_spawn = new List<string> { "unit_human", "unit_dwarf" };

        AssetManager.biome_library.add(biome);

        // Add to natural world generation pool
        BiomeLibrary.pool_biomes.Add(biome);
    }
}
```

---

## 9. Subsystem 13: Custom Windows & In-Game UI Architecture

The native UI window engine is driven by `ScrollWindow` and `TabbedWindow`. Mods like `PowerBox` and `ViltrumEmpire` instantiate custom windows by cloning vanilla window prefabs or instantiating `ScrollWindow`:

```csharp
public class MyCustomModWindow : MonoBehaviour
{
    public const string WindowId = "my_custom_window";

    public static void Show()
    {
        // 1. Verify window exists in ScrollWindow dictionary; if missing, construct it
        if (!ScrollWindow.allWindows.ContainsKey(WindowId))
        {
            CreateWindow();
        }

        // 2. Open via native window manager
        ScrollWindow.showWindow(WindowId);
    }

    private static void CreateWindow()
    {
        // Clone an existing base scroll window prefab (e.g. "clan" or "kingdom")
        ScrollWindow basePrefab = ScrollWindow.allWindows["kingdom"];
        GameObject newWindowObj = GameObject.Instantiate(basePrefab.gameObject, basePrefab.transform.parent);
        newWindowObj.name = WindowId;

        ScrollWindow window = newWindowObj.GetComponent<ScrollWindow>();
        window.screen_id = WindowId;

        // Clear default contents from scroll area
        Transform contentTransform = window.content.transform;
        for (int i = contentTransform.childCount - 1; i >= 0; i--)
        {
            GameObject.Destroy(contentTransform.GetChild(i).gameObject);
        }

        // Add custom controls (e.g. Buttons, Text, Unit Avatars)
        AddCustomControls(contentTransform);

        // Register with global window tracker
        ScrollWindow.allWindows[WindowId] = window;
    }

    private static void AddCustomControls(Transform content)
    {
        // Add custom text, buttons, sliders
    }
}
```

---

## 10. Subsystem 14: Kingdom Diplomacy, Wars & Political Plots

WorldBox kingdoms interact through the `DiplomacyManager`, `WarManager`, and `AssetManager.plots_library`.

### 10.1 Triggering Forced Wars & Custom War Types
```csharp
public static class MyWarfare
{
    public static void ForceWar(Kingdom attacker, Kingdom defender)
    {
        if (attacker == null || defender == null || attacker == defender) return;

        // Retrieve war type from library
        WarTypeAsset warType = AssetManager.war_types_library.get("total_war") 
                            ?? AssetManager.war_types_library.get("rebellion");

        // Native war declaration API
        World.world.diplomacy.startWar(attacker, defender, warType, pForced: true);
        
        // Log to world chronicle
        WorldLog.logWarStarted(attacker, defender);
    }

    public static void ForcePeace(Kingdom k1, Kingdom k2)
    {
        if (k1 == null || k2 == null) return;
        War war = World.world.wars.getWar(k1, k2);
        if (war != null)
        {
            World.world.wars.endWar(war);
        }
    }
}
```

---

## 11. System Invariants & Safety Guardrails

| Invariant ID | Rule | Consequence of Violation |
|---|---|---|
| **INV-01** | `mod.json` must be present at mod root. | NML silently skips the mod folder without compiling. |
| **INV-02** | UI elements must NOT be instantiated in `OnModLoad()`. | Immediate `NullReferenceException` crashing the mod loader. |
| **INV-03** | Harmony patches must be processed class-by-class (`PatchEach`). | A single upstream method signature change disables 100% of mod patches. |
| **INV-04** | Flying effects and projectile state must purge in `MapBox.clearWorld`. | Memory leaks and orphaned ghost projectiles crashing new world generation. |
| **INV-05** | Trait stats must only use the 67 recognized stat IDs. | Game outputs `no asset with id: ...` in `Player.log`. |
| **INV-06** | `path_icon` must omit file extensions (`.png`). | Blank/missing white square icons rendered in UI. |
| **INV-07** | Pre-compiled DLLs must NOT be placed in mod root if shipping source. | NML skips compilation and loads outdated DLL binary. |

---

## 6. Verification & Fast Development Workflow

### 6.1 The 2-Second Compile Check (Zero Game Launches)
Never launch the game to test basic C# syntax or reference errors. Run the offline Roslyn compile check:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "<skill-dir>\scripts\compile-mod.ps1" `
  -ModPath "C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\<YourModFolder>"
```
- **Exit Code 0:** Clean compilation against all 187 game assemblies.
- **Exit Code 1:** Compile errors formatted with exact `file(line,col): error CSxxxx`.

### 6.2 Live Runtime Verification
Launch WorldBox and read:
`%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\Player.log`

Verify the 3 milestone log lines:
1. `[NML]: Compile Mod <GUID> - Success`
2. `[NML]: [<YourModName>]: MyMasterMod ready!`
3. Zero exception stack traces following initialization.

---

## 7. Web Distribution & Packaging Standards (GameBanana & Community Releases)

To ensure your mod is rated favorably on GameBanana (Game ID `7245`) and functions out-of-the-box for players without bug reports:

### 7.1 The Zip Nesting Contract
Always wrap your mod folder inside the archive:
```
MyMod_v1.0.0.zip
└── MyMod/
    ├── mod.json                [REQUIRED]
    ├── icon.png                [REQUIRED]
    ├── default_config.json     [OPTIONAL]
    ├── Locales/                [REQUIRED]
    │   └── en.json
    ├── GameResources/          [OPTIONAL]
    └── Code/                   [REQUIRED]
        └── *.cs
```
> **Warning:** If you zip the files directly (`MyMod_v1.0.0.zip -> mod.json, Code/...`), players unzipping into `<WorldBox>\Mods\` will extract loose files directly into the root, and NML will skip loading with zero errors.

### 7.2 The Sanitization Pass
Before packaging:
1. Delete any `.git/`, `.vs/`, `.vscode/`, `bin/`, `obj/`, `*.csproj`, or `*.sln` directories.
2. Confirm no leftover `.dll` files sit in the mod root. If NML detects a `.dll`, it disables Roslyn runtime compilation and treats the mod as pre-compiled.

### 7.3 GameBanana Submission Best Practices
1. **Highlight Experimental Mode:** Mention prominently that players MUST enable `Settings -> Experimental Mode` in WorldBox.
2. **Explicit Version Matrix:** Specify compatible game version (e.g. `WorldBox 0.51.2 Build 719`) and NML loader version (`NML 1.2.0.1+` / `1.2.1.1+`).
3. **Dependencies:** Clearly link any prerequisites (e.g., `TRIICKSTR_PLENTY_O_BIOMES`) in the GameBanana download description.

