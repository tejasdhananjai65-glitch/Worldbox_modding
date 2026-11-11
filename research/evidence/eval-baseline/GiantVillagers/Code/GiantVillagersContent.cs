using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using System.Collections.Generic;
using UnityEngine;

namespace GiantVillagers
{
    /// <summary>
    /// Registers everything this mod adds to the game:
    ///   - a trait group ("Giants")
    ///   - a trait that makes a unit huge and fast
    ///   - a god power that hands that trait to every unit on the clicked tile
    ///   - a powers tab so the god power is actually reachable in the UI
    ///
    /// Stat notes (verified against Assembly-CSharp-Publicized.dll):
    ///   - "scale" is the size stat. The base actor template uses 0.1, which is
    ///     100% of normal size (the stat asset shows it as a percentage with a
    ///     x1000 display multiplier). Trait stats are merged additively into the
    ///     actor's stats, so a trait bonus of +0.2 turns a villager into 300%.
    ///   - "multiplier_speed" is a percentage-style multiplier (+0.5 == +50% speed)
    ///     and is what the base game traits use.
    ///   - Actor.addTrait() marks the actor's stats dirty, so Actor.updateStats()
    ///     recomputes target_scale and the actor visibly grows.
    /// </summary>
    public static class GiantVillagersContent
    {
        public const string TraitGroupId = "giants_group";
        public const string TraitId = "giant_villager";
        public const string PowerId = "giant_villager_power";
        public const string TabId = "giants_tab";

        /// <summary>Vanilla icon of the base game "giant" trait - always present.</summary>
        public const string IconPath = "ui/Icons/actor_traits/iconGiant";

        /// <summary>Vanilla tab icon used if <see cref="IconPath"/> cannot be loaded.</summary>
        public const string FallbackIconPath = "ui/Icons/power_tabs/icon_tab_creatures";

        /// <summary>+0.2 on top of the base 0.1 == 300% of normal size.</summary>
        public const float ScaleBonus = 0.2f;

        /// <summary>+50% movement speed.</summary>
        public const float SpeedBonus = 0.5f;

        public static void Init()
        {
            CreateTraitGroup();
            CreateTrait();
            CreatePower();
        }

        // --- trait group ------------------------------------------------------------
        // A trait needs a group; the group shows up as a tab in the trait editor.
        // The locale key for a group is "trait_group_" + group id.
        private static void CreateTraitGroup()
        {
            if (AssetManager.trait_groups.get(TraitGroupId) != null)
            {
                return;
            }

            ActorTraitGroupAsset group = new ActorTraitGroupAsset();
            group.id = TraitGroupId;
            group.name = "trait_group_" + TraitGroupId;
            group.color = "#7fd4ffff";
            AssetManager.trait_groups.add(group);

            LM.AddToCurrentLocale("trait_group_" + TraitGroupId, "Giants");
        }

        // --- trait -----------------------------------------------------------------
        // Locale keys: "trait_" + id and "trait_" + id + "_info".
        private static void CreateTrait()
        {
            if (AssetManager.traits.get(TraitId) != null)
            {
                return;
            }

            ActorTrait trait = new ActorTrait();
            trait.id = TraitId;
            trait.group_id = TraitGroupId;
            trait.path_icon = IconPath;
            trait.type = TraitType.Positive;
            trait.rarity = Rarity.R1_Rare;

            // AssetManager.traits.add() allocates base_stats / base_stats_meta when
            // they are still null, so the stats have to be set after the add() call.
            AssetManager.traits.add(trait);

            trait.base_stats["scale"] = ScaleBonus;
            trait.base_stats["multiplier_speed"] = SpeedBonus;

            trait.unlock(true);

            LM.AddToCurrentLocale("trait_" + TraitId, "Giant");
            LM.AddToCurrentLocale("trait_" + TraitId + "_info", "Huge and fast.");
        }

        // --- god power ---------------------------------------------------------------
        // GodPower.name is the locale key of the title, the description key is
        // <name> + "_description".
        private static void CreatePower()
        {
            if (AssetManager.powers.get(PowerId) != null)
            {
                return;
            }

            GodPower power = new GodPower();
            power.id = PowerId;
            power.name = PowerId;
            power.path_icon = IconPath;
            power.rank = PowerRank.Rank0_free;

            // Config._current_brush defaults to "circ_5" (an 11x11 circle), and the
            // click action is invoked once per tile of the active brush. "circ_0" is
            // the single-tile brush (its BrushData.pos holds exactly one pixel at
            // offset 0,0), so the power only ever touches the tile that was clicked.
            power.force_brush = "circ_0";

            // PowerActionWithID: bool (WorldTile pTile, string pPowerId)
            power.click_action = (WorldTile pTile, string pPowerId) =>
            {
                if (pTile == null)
                {
                    return false;
                }

                bool applied = false;

                pTile.doUnits(actor =>
                {
                    if (actor == null || !actor.isAlive())
                    {
                        return;
                    }

                    if (actor.hasTrait(TraitId))
                    {
                        return;
                    }

                    // false == do not remove opposing traits, just refuse if one is present.
                    if (actor.addTrait(TraitId, false))
                    {
                        applied = true;
                    }
                });

                return applied;
            };

            AssetManager.powers.add(power);

            LM.AddToCurrentLocale(PowerId, "Turn Into Giants");
            LM.AddToCurrentLocale(PowerId + "_description",
                "Turns every unit on the clicked tile into a huge, fast giant.");
        }

        // --- power tab ----------------------------------------------------------------
        // A GodPower on its own is invisible: it needs a PowerButton on a PowersTab.
        // The tab can only be built once the game UI exists - see Main.Update().
        public static void CreatePowerTab()
        {
            Sprite icon = SpriteTextureLoader.getSprite(IconPath);
            if (icon == null)
            {
                // Fall back to a vanilla tab icon so the power stays reachable even
                // if the giant trait icon is ever renamed.
                icon = SpriteTextureLoader.getSprite(FallbackIconPath);
            }

            if (icon == null)
            {
                Main.LogError("GiantVillagers: no usable icon found (" + IconPath + ")");
                return;
            }

            PowersTab tab = TabManager.CreateTab(TabId, TabId, TabId + "_description", icon);
            tab.SetLayout(new List<string> { TraitGroupId });
            tab.AddPowerButton(TraitGroupId, PowerButtonCreator.CreateGodPowerButton(PowerId, icon));
            tab.UpdateLayout();

            LM.AddToCurrentLocale(TabId, "Giants");
            LM.AddToCurrentLocale(TabId + "_description", "Powers from GiantVillagers.");
        }
    }
}
