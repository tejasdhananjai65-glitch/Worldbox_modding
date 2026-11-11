using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using UnityEngine;

namespace GiantPower
{
    /// <summary>
    /// Registers everything this mod adds to the game:
    ///
    ///   1. a trait group (shows up as a tab in the trait editor)
    ///   2. the "giant" trait
    ///   3. the god power that hands that trait out
    ///   4. a powers tab that hosts the god power button
    ///
    /// Order matters:
    ///   1. create the asset and add it to its AssetManager library
    ///   2. fill in the stats
    ///   3. unlock it / attach it to the UI
    ///
    /// AssetManager.traits.add() allocates base_stats if it is still null, so it is
    /// safe to assign stats either before or after the add() call.
    /// </summary>
    public static class Content
    {
        public const string TraitGroupId = "giantpower_group";
        public const string TraitId = "giantpower_trait";
        public const string PowerId = "giantpower_power";
        public const string TabId = "giantpower_tab";
        public const string IconPath = "ui/icons/icongiantpower";

        public static void Init()
        {
            CreateTraitGroup();
            CreateTrait();
            CreatePower();
        }

        // --- trait group ------------------------------------------------------------
        // The trait group shows up as a new tab in the trait editor.
        // The locale key is "trait_group_" + group id.
        private static void CreateTraitGroup()
        {
            ActorTraitGroupAsset group = new ActorTraitGroupAsset();
            group.id = TraitGroupId;
            group.name = "trait_group_" + TraitGroupId;
            group.color = "#ff8c00ff";
            AssetManager.trait_groups.add(group);

            LM.AddToCurrentLocale("trait_group_" + TraitGroupId, "Giant Power");
        }

        // --- trait -----------------------------------------------------------------
        // Locale keys: "trait_" + id  and  "trait_" + id + "_info"
        private static void CreateTrait()
        {
            ActorTrait trait = new ActorTrait();
            trait.id = TraitId;
            trait.group_id = TraitGroupId;
            trait.path_icon = IconPath;
            trait.type = TraitType.Positive;

            AssetManager.traits.add(trait);

            // "scale" is the absolute sprite scale of the unit. A plain villager sits at
            // 0.1 (the $basic_unit$ template), and the trait stat is ADDED to that, so
            // +0.1 makes the unit exactly twice as tall as it was. The vanilla "giant"
            // trait only adds 0.05 (1.5x), so this one is deliberately bigger.
            trait.base_stats["scale"] = 0.1f;

            // "multiplier_speed" is multiplicative: the game computes
            // speed = speed * (1 + multiplier_speed). 0.5 means +50% movement speed,
            // the same value the vanilla "blessed" trait uses.
            trait.base_stats["multiplier_speed"] = 0.5f;

            // Same convention as the vanilla "giant" trait: giants are tougher too.
            trait.base_stats["multiplier_health"] = 0.5f;

            trait.unlock(true);

            LM.AddToCurrentLocale("trait_" + TraitId, "Giant");
            LM.AddToCurrentLocale("trait_" + TraitId + "_info", "Enormous and blisteringly fast.");
        }

        // --- god power ---------------------------------------------------------------
        // GodPower.name is the locale key for the title. The description key is
        // <name> + "_description" - there is no "power_" prefix.
        private static void CreatePower()
        {
            GodPower power = new GodPower();
            power.id = PowerId;
            power.name = PowerId;
            power.path_icon = IconPath;

            // PowerActionWithID: bool (WorldTile pTile, string pPowerId)
            power.click_action = (WorldTile pTile, string pPowerId) =>
            {
                if (pTile == null) return false;

                bool applied = false;
                foreach (Actor actor in MapBox.instance.units)
                {
                    if (actor != null && actor.isAlive() && actor.current_tile == pTile)
                    {
                        if (actor.addTrait(TraitId))
                        {
                            applied = true;
                        }
                    }
                }
                return applied;
            };

            AssetManager.powers.add(power);

            LM.AddToCurrentLocale(PowerId, "Become Giants");
            LM.AddToCurrentLocale(PowerId + "_description", "Turns every unit on the clicked tile into a huge, fast giant.");
        }

        // --- power tab ----------------------------------------------------------------
        // A GodPower on its own is invisible: it needs a PowerButton on a PowersTab.
        // This creates a brand new tab holding the mod's powers.
        // Call this only once the game UI exists - see Main.Update().
        public static void CreatePowerTab()
        {
            Sprite icon = SpriteTextureLoader.getSprite(IconPath);
            if (icon == null) return;

            PowersTab tab = TabManager.CreateTab(TabId, TabId, TabId + "_description", icon);
            tab.SetLayout(new System.Collections.Generic.List<string> { TraitGroupId });
            tab.AddPowerButton(TraitGroupId, PowerButtonCreator.CreateGodPowerButton(PowerId, icon));
            tab.UpdateLayout();

            LM.AddToCurrentLocale(TabId, "Giant Power");
            LM.AddToCurrentLocale(TabId + "_description", "Powers from GiantPower.");
        }
    }
}
