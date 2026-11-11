# Modding Patterns — Verified Recipes

Each recipe is a working pattern taken from a real installed mod or verified against
the live game assembly. Paths are relative to
`C:\Program Files (x86)\Steam\steamapps\common\WorldBox\Mods\`.

---

## 1. Entry class

Two families exist. Prefer **Family A**.

### Family A — `BasicMod<T>` (recommended)

Used by 12 of the 15 installed mods with code.

```csharp
using NeoModLoader.api;

namespace MyMod
{
    public class Main : BasicMod<Main>
    {
        protected override void OnModLoad()
        {
            LogInfo("ready");
        }
    }
}
```

Gives you `LogInfo`/`LogWarning`/`LogError`, persisted config (`GetConfig()`), automatic
`Locales\` loading (it implements `ILocalizable`), and a prefab library.

### Family B — raw `IMod`

```csharp
using NeoModLoader.api;
using UnityEngine;

namespace MyMod
{
    public class Main : MonoBehaviour, IMod
    {
        public void OnLoad(ModDeclare pModDecl, GameObject pGameObject) { }
        public void OnUnload() { }
        public ModDeclare GetDeclaration() => null;
        public GameObject GetGameObject() => gameObject;
        public string GetUrl() => "";
    }
}
```

Use only when you need control NML's lifecycle. You then also implement `ILocalizable`
and return `Path.Combine(pModDeclare.FolderPath, "Locales")` from
`GetLocaleFilesDirectory`, otherwise `Locales\` is not loaded.

### Conventions every working mod shares

- One namespace per mod family, named after the mod's brand — never a generic
  `MyMod`. Seen in the wild: `babiess`, `abox`, `biomes`, `Magic`, `Godzilla`, `Sakuga`,
  `ViltrumEmpire`, `ScpBox`, `InvasionSummoner`, `PowerBox.Code`.
- Usings: `using UnityEngine;` `using NeoModLoader.api;` `using NeoModLoader.General;`
  `using System.Collections.Generic;` — plus `using Newtonsoft.Json;` only when
  persisting JSON.
- Logging: `LogInfo` / `LogWarning` / `LogError` (NML, prefixes the mod name) or
  `Debug.Log("[MyMod] ...")` (Unity, you add the prefix).

---

## 2. Register a trait

```csharp
ActorTrait trait = new ActorTrait();
trait.id = "giant_trait";
trait.group_id = "giant_group";
trait.path_icon = "ui/icons/iconGiant";
AssetManager.traits.add(trait);
trait.base_stats["health"] = 500f;
trait.unlock(true);

LM.AddToCurrentLocale("trait_giant_trait", "Giant");
LM.AddToCurrentLocale("trait_giant_trait_info", "A very large unit.");
```

**Idempotent variant** — the game can reload mods, so guard registration:

```csharp
if (AssetManager.traits.get("giant_trait") == null)
{
    /* create and add */
}
```

---

## 3. Register a trait group (a tab in the trait editor)

```csharp
ActorTraitGroupAsset group = new ActorTraitGroupAsset();
group.id = "giant_group";
group.name = "trait_group_giant_group";   // locale key
group.color = "#ff8c00ff";
AssetManager.trait_groups.add(group);

LM.AddToCurrentLocale("trait_group_giant_group", "Giant Traits");
```

`name` must be `trait_group_<id>`. The colour is a hex string with alpha.

---

## 4. Make a unit look huge and fast

This is where most new mods get the numbers wrong. Three rules, all verified against
the live assembly.

**Rule 1 — a trait's stats are DELTAS.** `BaseStats.mergeStats(other, multiplier)`
computes `this[id] = this[id] + other.get(id) * multiplier`, and
`MetaObjectWithTraits.recalcBaseStats` merges each trait's `base_stats` with multiplier
`1`. So:

```csharp
trait.base_stats["health"] = 500f;   // +500 health, NOT "health = 500"
```

**Rule 2 — `multiplier_*` stats are percentages.** `BaseStats.checkMultipliers()`
computes `main.value = main.value + main.value * multiplier.value`:

```csharp
trait.base_stats["multiplier_speed"] = 0.5f;    // x1.5 speed, NOT "+0.5 speed"
trait.base_stats["multiplier_health"] = 0.5f;   // +50% max health
```

**Rule 3 — `scale` is the visual size, `size` is the hitbox.**
`Actor.updateStats` reads `stats["scale"]` into `target_scale`;
`Actor.updateChangeScale` lerps `actor_scale` toward it each frame;
`Actor.finishScale` applies it to the sprite transform. `size` is used by
`MapBox.checkAttackFor`, `Actor.isInAttackRange`, `Actor.getSlashPosition` and
`QuantumSpriteLibrary.drawUnitSize` — it is combat reach, nothing to do with how big
the sprite looks.

The reference scale is **0.1** — `Actor.getMassKG` computes
`target_scale / 0.1 * stats["mass_2"]`, and the vanilla `$basic_unit$` asset sets
`scale = 0.1`, `size = 0.5`, `speed = 5`.

```csharp
// A unit that looks twice as big and moves 50% faster
trait.base_stats["scale"] = 0.1f;
trait.base_stats["multiplier_speed"] = 0.5f;
```

**Vanilla body traits are the reference values** (from `ActorTraitLibrary::addTraitsBody`):

| Vanilla trait | Stats |
|---|---|
| `giant` | `scale +0.05`, `multiplier_health +0.5`, `multiplier_speed −0.25` |
| `fat` | `scale +0.02` |
| `agile` | `scale −0.01` |
| `tiny` | `scale −0.02` |
| `fast` | `multiplier_speed +0.3` |
| `blessed` | `multiplier_speed +0.5` |

Vanilla `giant` is only **1.5×** visually. A genuinely huge unit wants more.

**Stat ids must be exact.** There are 67 valid ids, listed in `game-api.md` §3. A
misspelling logs `no asset with id: …` in `Player.log` — search for it when a stat
"does nothing".

Also set `trait.type = TraitType.Positive;` so the trait editor buckets it as a buff
rather than a debuff.

---

## 5. Register a god power and put it on a tab

```csharp
GodPower power = new GodPower();
power.id = "giant_power";
power.name = "giant_power";           // locale key, no "power_" prefix
power.path_icon = "ui/icons/iconGiant";

// The default brush is circ_5 - an 11x11 block, NOT a single tile.
// Set force_brush = "circ_0" for exactly one tile.
power.force_brush = "circ_0";

power.click_action = (WorldTile pTile, string pPowerId) =>
{
    if (pTile == null) return false;
    bool any = false;
    foreach (Actor actor in MapBox.instance.units)
    {
        if (actor != null && actor.isAlive() && actor.current_tile == pTile)
        {
            actor.addTrait("giant_trait");
            any = true;
        }
    }
    return any;
};
AssetManager.powers.add(power);

LM.AddToCurrentLocale("giant_power", "Grow Giants");
LM.AddToCurrentLocale("giant_power_description", "Makes units on the tile giant.");
```

**"On the clicked tile" is not one tile by default.** The default brush is `circ_5`,
an **11×11 block** around the cursor. Brush ids are `circ_<n>`; `circ_0` is a single
pixel. Leaving `force_brush` empty means the player can resize the brush in the UI, so
the affected area is player-controlled. Set `force_brush = "circ_0"` for a single tile,
or describe the real area in the description.

Then, once the UI exists:

```csharp
Sprite icon = SpriteTextureLoader.getSprite("ui/icons/iconGiant");
PowersTab tab = TabManager.CreateTab("giant_tab", "giant_tab", "giant_tab_description", icon);
tab.SetLayout(new List<string> { "giant_group" });
tab.AddPowerButton("giant_group", PowerButtonCreator.CreateGodPowerButton("giant_power", icon));
tab.UpdateLayout();
```

Real source: `AGRICHE_GODZILLA\Code\Powers.cs` (tab creation) and
`ElementalPowersMod\Powers\CustomPowers.cs` (power registration).

---

## 6. Register a status effect

```csharp
StatusAsset effect = new StatusAsset();
effect.id = "status_giant_rage";
effect.locale_id = "status_giant_rage";
effect.locale_description = "status_giant_rage_description";
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

LM.AddToCurrentLocale("status_giant_rage", "Giant Rage");
LM.AddToCurrentLocale("status_giant_rage_description", "A short-lived buff.");
```

---

## 7. Apply a trait to every unit in the world

```csharp
foreach (Actor actor in MapBox.instance.units)
{
    if (actor != null && actor.isAlive()) actor.addTrait("giant_trait");
}
```

`MapBox.instance.units` is an `ActorManager` implementing `IEnumerable<Actor>`.

---

## 8. Isolate failures per stage

`OnModLoad` runs top to bottom — one throw disables everything after it.

```csharp
protected override void OnModLoad()
{
    Stage("traits", Traits.Init);
    Stage("powers", Powers.Init);
    Stage("effects", Effects.Init);
    LogInfo("ready");
}

private static void Stage(string pName, System.Action pAction)
{
    try { pAction(); }
    catch (System.Exception e) { LogError($"stage '{pName}' failed: {e}"); }
}
```

This pattern is used by `TRIICKSTR_DEMON_SLAYER_MOD` and is the cheapest way to find
which half of a mod is broken.

---

## 9. Harmony patch

NML ships HarmonyX (`0Harmony.dll`, 2.9.0).

```csharp
using HarmonyLib;
using System.Reflection;

protected override void OnModLoad()
{
    new Harmony("com.example.mymod").PatchAll(Assembly.GetExecutingAssembly());
}
```

`Assembly.GetExecutingAssembly()` is **not optional** — without it `PatchAll()` scans
whatever assembly it was called from.

```csharp
[HarmonyPatch(typeof(Actor), "updateStats")]
public static class Patch_Actor_UpdateStats
{
    [HarmonyPostfix]
    public static void AddSwiftSpeed(Actor __instance)
    {
        if (__instance == null || !__instance.hasTrait("swift_trait")) return;
        __instance.stats["speed"] += 20f;
    }
}
```

**Rules that matter**

- Magic parameter names: `__instance`, `__result` (Postfix only, `ref` to change),
  `___someField` (**three** underscores for a private field — the game prefixes its own
  `_`, so `_hover_timer` becomes `____hover_timer`), `__state`.
- A Prefix returning `bool` decides whether the game's code runs at all. `false` skips
  it **for everybody**.
- Adjust rather than assign: `__result = 12f` throws away other mods' work; use
  `__result += …` or `Mathf.Min`.
- Two overloads of the target → `AmbiguousMatchException`. Disambiguate with
  `new[] { typeof(string), typeof(bool) }`.
- Use the string form for the target name when the method is private or internal
  (`MapBox.Update`, `Actor.updateStats`, `Actor.die`).
- **Threading:** `Actor.updateStats` runs as a parallel job. Inside its Postfix, touch
  only that unit's own numbers. Never call Unity API, the game's `Randy`, or write a
  shared list from there.
- Common patch targets: `City.update(float)`, `MapBox.Update()`, `Actor.updateStats()`,
  `Actor.getHit(...)`, `Actor.die(...)`, `DiplomacyManager.startWar(...)`,
  `WarManager.newWar(...)`, `Kingdom.setKing(Actor, bool pFromLoad)` (also runs during
  save load — check `pFromLoad`), `ActorManager.createNewUnit(...)`.

---

## 10. Persist a setting

`default_config.json` at the mod root, merged into the player's saved config:

```json
{
  "mymod": [
    { "Id": "strike_radius", "Type": "INT_SLIDER", "IntVal": 25,
      "MinIntVal": 5, "MaxIntVal": 100, "Callback": "MyMod.Settings:SetStrikeRadius" },
    { "Id": "tint_by_mood", "Type": "SWITCH", "BoolVal": true }
  ]
}
```

- Outer key = the group id = one settings tab.
- `Type` ∈ `SWITCH`, `SLIDER` (float), `INT_SLIDER`, `TEXT`, `SELECT`.
- `Callback` is `Namespace.Type:MethodName`; changes land when the window closes.
- Read with `GetConfig()["mymod"]["strike_radius"].IntVal`.
- Player values live in
  `%USERPROFILE%\AppData\LocalLow\mkarpenko\WorldBox\mods_config\<GUID>.config`.
  Delete that file to reset to defaults.
- Mod settings rows also need locale entries: the group id, the item id, and
  `"<id> Description"` — **with a space and a capital D**.

---

## 11. React to a game event

`NeoModLoader.General.Event` exposes listener/handler pairs: actor attack, city / clan /
culture / kingdom / family creation, war start and end, alliance, plot start, world log
message. Register a listener in `OnModLoad` and remove it in `OnUnload`.

A listener that fails to construct logs `Failed to construct listener instance` — that is
a scoped failure, it does not mean every NML event is broken.

---

## 12. Load a custom sprite

```csharp
Sprite sprite = SpriteTextureLoader.getSprite("ui/icons/iconGiant");
```

The PNG must live at `GameResources\ui\icons\iconGiant.png` inside the mod folder, and
the path used is `ui/icons/iconGiant` — relative path, **no extension**.

---

## 13. Frame loop safety

```csharp
public void Update()
{
    if (!global::Config.game_loaded) return;
    if (World.world == null || World.world.units == null) return;
    if (MapBox.instance == null) return;
}
```

`OnModLoad` runs before there is a world at all. Never dereference `MapBox.instance`
unguarded.

---

## 14. What the scaffold ships — and what to delete

`templates/minimal-mod` deliberately contains one of everything, so it doubles as a
reference. A scaffolded mod therefore starts with **demo content you did not ask for**:

| Shipped | What it is | What to do |
|---|---|---|
| trait group `my_mod_group` | a trait-editor tab | keep or delete |
| trait `my_trait` | a stat-only trait | delete unless you want it |
| god power `my_power` | applies that trait to the clicked tile | rewrite |
| status effect `my_effect` | a 30 s heal-over-time buff | **delete unless you need it** — it is dead content otherwise, and it registers a `status_*` locale key nobody asked for |
| power tab `my_mod_tab` | a new tab in the powers panel | delete if you are not adding a new tab |

`new-mod.ps1` rewrites every placeholder id (`my_mod_group`, `my_trait`, `my_power`,
`my_effect`, `my_mod_tab`, `iconModderDemo`, `MyMod`) to your namespace, so two
scaffolded mods can never collide on an asset id.

Delete what you do not need rather than leaving it registered — every registered asset
shows up in the game's asset browser and in `AssetManager`, and unused locale keys show
up as `missing text:` noise in `Player.log`.
