# Sprites and Resources

Verified against `NeoModLoader.utils.ResourcesPatch` (NML 1.2.0.1) and the live game's
`resources.assets`.

---

## 1. Folder conventions inside a mod

| Folder | Purpose | Read by |
|---|---|---|
| `GameResources\` | PNGs and other resources patched into the game's `Resources` tree | NML, at mod load |
| `GameResourcesReplace\` | NCMS-style override of an existing resource | NML |
| `EmbededResources\` | embedded as manifest resources `<ModName>.Resources.<dotted.path>` (the typo `EmbededResources` is intentional and shared with NCMS) | NML |
| `AssetBundles\` | Unity asset bundles | NML |
| `Assemblies\` | third-party DLLs — **also added as compile references** and loaded at runtime | NML |
| `Locales\` | `en.json` / `ru.csv` etc | NML, before `OnModLoad` |

Never put a third-party DLL in the mod root — only in `Assemblies\`.

---

## 2. The path rule

> `GameResources/<path>/<name>.png` becomes the resource path `<path>/<name>`
> — **no file extension**.

So:

```
GameResources/ui/icons/iconGiant.png   ->   resource path  ui/icons/iconGiant
```

Use it as:

```csharp
Sprite sprite = SpriteTextureLoader.getSprite("ui/icons/iconGiant");
```

or in an asset field:

```csharp
trait.path_icon = "ui/icons/iconGiant";
```

`path_icon` on a trait, god power, status effect or building takes the same
extension-less path.

**Gotcha:** `Resources.Load<Sprite>` and `SpriteTextureLoader.getSprite` agree on the
path, but Unity's own `Resources` folder is case-sensitive on Linux/macOS builds of
the game. Copy the exact casing of the asset you reference.

---

## 3. Icons vs frame trees

Two different rules, and it is easy to conflate them.

**Icons** (trait icon, god power icon, status icon, `path_icon`) follow the plain path
rule: the lookup path is the file's path under `GameResources` **without the extension**.

```
GameResources/ui/icons/iconGiant.png   ->   ui/icons/iconGiant
```

```csharp
trait.path_icon = "ui/icons/iconGiant";
```

**Creature frame trees** are different — an `ActorTextureSubAsset` takes a *base path
with a trailing slash* and derives the `main`, `king`, `heads`, `male_1`, … sub-paths
from it. That is the only case where a trailing slash appears. See §6.

| Asset | Where the file goes | What the lookup wants |
|---|---|---|
| Trait icon (`path_icon`) | `GameResources/<folder>/<name>.png` | `<folder>/<name>` — no extension |
| God power icon (`path_icon`) | `GameResources/<folder>/<name>.png` | `<folder>/<name>` — no extension |
| Status effect icon (`path_icon`) | `GameResources/<folder>/<name>.png` | `<folder>/<name>` — no extension |
| Item / building icon | `GameResources/<folder>/<name>.png` | `<folder>/<name>` — no extension |
| Creature frames | `GameResources/actors/<id>/main/walk_0.png` | base path `actors/<id>/` **with** trailing slash |
| `SpriteAtlasUI` sprites | `GameResources/ui/special/<spriteName>.png` | `ui/special/<spriteName>` |
| Mod list icon (`iconPath` in `mod.json`) | `<mod folder>/icon.png` | relative to the mod folder, e.g. `"icon.png"` |

---

## 4. Known-good vanilla icon paths

Verified by scanning the 20 installed mods for `path_icon` values that render:

```
ui/icons/eight_gates
ui/Icons/iconKings
ui/Icons/iconLeaders
ui/Icons/items/icon_helmet_sun
ui/Icons/actor_traits/iconGiant
ui/Extras/hiddenEvil
metaIcons/iconBookBurn
creatureIcons/iconEternalInvincibility
```

`ui/Icons/actor_traits/iconGiant` is the base game's own icon for the vanilla `giant`
trait — a safe, known-good path for a "make things bigger" trait.

Note the casing inconsistency in the shipped game itself: `ui/Icons/` (capital I) and
`ui/icons/` (lowercase) both exist. Match the exact casing.

---

## 5. Getting the vanilla art

To reuse a vanilla sprite, do not copy it — reference it directly by path.

To *extract* the game's art for reference or for other loaders, use **AssetRipper**:
point it at the folder containing `worldbox_Data`, export, and take the `Resources`
folder out of the exported Unity project. The path rule is the same: the location under
`Resources`, without the file extension.

Other tools named in the community sources: dnSpy, ILSpy, DotPeek, AssetStudio.

---

## 6. Creature sprite frames

A custom species needs a whole frame tree, not one icon. `ActorTextureSubAsset` takes a
base path **with a trailing slash** and derives the sub-paths from it:

```csharp
a.texture_asset = new ActorTextureSubAsset("actors/mymod/" + pId + "/", false);
a.animation_walk = ActorAnimationSequences.walk_0_2;
a.animation_swim = ActorAnimationSequences.swim_0_2;
a.animation_idle  = ActorAnimationSequences.walk_0;
a.has_sprite_renderer = false;
```

Derived sub-paths: `main`, `king`, `leader`, `warrior_1`, `zombie`, `heads`,
`heads_male`, `heads_female`, `head_king`, `head_warrior`, `head_old_male`,
`head_old_female`, `male_1`, `female_1`, `child`, `unitShadow_2`, `unitShadow_4`,
`unitShadow_5`.

So the walk frames live at `GameResources/actors/<id>/main/walk_0.png`,
`walk_1.png`, `walk_2.png` — **with the `.png` extension on disk**, while the resource
path used in code drops it.

`ActorAnimationSequences` supplies the ready-made frame lists: `walk_0`, `walk_0_1` …
`walk_0_5`, `swim_0` … `swim_0_5`, `idle_0_3`.

---

## 7. Status effect sprites

A status effect shows one icon (`path_icon`, same extension-less rule) or a sprite
sheet. For the sheet path use `StatusAsset.sprite_list` (`Sprite[]`), `texture`,
`animated`, `animation_speed`, `scale`, `offset_x`, `offset_y`. The single
`path_icon` route is the simple one and is enough for most effects.

---

## 8. Sprite sizes

The game's sprites are small. A 64×64 PNG is a safe default for a trait or power icon;
the UI scales them down. Very large images waste memory in the atlas and can look
blurry, so keep icons near the vanilla size.

---

## 9. Verifying a sprite actually loaded

```csharp
Sprite s = SpriteTextureLoader.getSprite("ui/icons/iconGiant");
if (s == null)
{
    LogError("icon missing: ui/icons/iconGiant");
}
```

A null sprite usually means one of:

- the PNG is not under `GameResources\` at the matching path,
- the path still has a `.png` extension,
- the case does not match.

---

## 10. Third-party libraries

Put the DLL in `Assemblies\`:

```
MyMod/
├── mod.json
├── Assemblies/
│   └── MyLibrary.dll
└── Code/
```

NML adds `Assemblies\*.dll` to the compile reference set *and* loads them into the
runtime, so `using MyLibrary;` works in your mod code with no extra setup.

Never ship `Assembly-CSharp.dll`, `Assembly-CSharp-Publicized.dll`, `NeoModLoader.dll`
or any Unity DLL from `Managed\` — the game already has them.
