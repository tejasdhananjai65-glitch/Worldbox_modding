using NeoModLoader.General;
using NeoModLoader.General.UI.Tab;
using UnityEngine;

namespace WorldBoxModderTemplate
{
    /// <summary>
    /// Registers everything this mod adds to the game.
    ///
    /// Order matters:
    ///   1. register localisation for every asset
    ///   2. create the asset and add it to its AssetManager library
    ///   3. unlock it / attach it to the UI
    ///
    /// AssetManager.traits.add() allocates base_stats if it is still null, so it is
    /// safe to assign stats either before or after the add() call.
    /// </summary>
    public static class Content
    {
        public const string TraitGroupId = "worldboxmoddertemplate_group";
        public const string TraitId = "worldboxmoddertemplate_trait";
        public const string PowerId = "worldboxmoddertemplate_power";
        public const string EffectId = "status_worldboxmoddertemplate_effect";

        public static void Init()
        {
            CreateTraitGroup();
            CreateTrait();
            CreateEffect();
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

            LM.AddToCurrentLocale("trait_group_" + TraitGroupId, "My Mod");
        }

        // --- trait -----------------------------------------------------------------
        // Locale keys: "trait_" + id  and  "trait_" + id + "_info"
        //
        // Stat semantics - get these right or the numbers will not mean what you think:
        //   * a trait's base_stats are DELTAS added to the species base
        //   * "multiplier_*" stats are PERCENTAGES of the current value
        //   * "scale" is the VISUAL size of the sprite (normal reference = 0.1)
        //   * "size"  is the COMBAT hitbox / attack reach, not the visual size
        private static void CreateTrait()
        {
            ActorTrait trait = new ActorTrait();
            trait.id = TraitId;
            trait.group_id = TraitGroupId;
            trait.path_icon = "ui/icons/iconworldboxmoddertemplate";
            trait.type = TraitType.Positive;

            AssetManager.traits.add(trait);

            // +0.1 on top of the base scale of 0.1 => twice as big on screen
            trait.base_stats["scale"] = 0.1f;
            // +50% movement speed
            trait.base_stats["multiplier_speed"] = 0.5f;
            // +250 max health
            trait.base_stats["health"] = 250f;

            trait.unlock(true);

            LM.AddToCurrentLocale("trait_" + TraitId, "My Trait");
            LM.AddToCurrentLocale("trait_" + TraitId + "_info", "A sturdier, faster unit.");
        }

        // --- status effect ----------------------------------------------------------
        // The locale keys are whatever you put in locale_id / locale_description.
        private static void CreateEffect()
        {
            StatusAsset effect = new StatusAsset();
            effect.id = EffectId;
            effect.locale_id = EffectId;
            effect.locale_description = EffectId + "_description";
            effect.duration = 30f;
            effect.path_icon = "ui/icons/iconworldboxmoddertemplate";

            AssetManager.status.add(effect);

            effect.base_stats["multiplier_speed"] = 0.25f;   // +25% speed while active

            // WorldAction: bool (BaseSimObject pTarget, WorldTile pTile)
            effect.action = (BaseSimObject pTarget, WorldTile pTile) =>
            {
                Actor actor = pTarget as Actor;
                if (actor != null && actor.isAlive())
                {
                    actor.restoreHealth(5);
                }
                return true;
            };

            LM.AddToCurrentLocale(EffectId, "My Effect");
            LM.AddToCurrentLocale(EffectId + "_description", "A short-lived buff.");
        }

        // --- god power ---------------------------------------------------------------
        // GodPower.name is the locale key for the title. The description key is
        // <name> + "_description" - there is no "power_" prefix.
        private static void CreatePower()
        {
            GodPower power = new GodPower();
            power.id = PowerId;
            power.name = PowerId;
            power.path_icon = "ui/icons/iconworldboxmoddertemplate";

            // PowerActionWithID: bool (WorldTile pTile, string pPowerId)
            power.click_action = (WorldTile pTile, string pPowerId) =>
            {
                if (pTile == null) return false;

                bool applied = false;
                foreach (Actor actor in MapBox.instance.units)
                {
                    if (actor != null && actor.isAlive() && actor.current_tile == pTile)
                    {
                        actor.addTrait(TraitId);
                        applied = true;
                    }
                }
                return applied;
            };

            AssetManager.powers.add(power);

            LM.AddToCurrentLocale(PowerId, "My Power");
            LM.AddToCurrentLocale(PowerId + "_description", "Grants My Trait to units on the clicked tile.");
        }

        // --- power tab ----------------------------------------------------------------
        // A GodPower on its own is invisible: it needs a PowerButton on a PowersTab.
        // This creates a brand new tab holding the mod's powers.
        // Call this only once the game UI exists - see Main.Update().
        public static void CreatePowerTab()
        {
            Sprite icon = SpriteTextureLoader.getSprite("ui/icons/iconworldboxmoddertemplate");
            if (icon == null) return;

            PowersTab tab = TabManager.CreateTab("worldboxmoddertemplate_tab", "worldboxmoddertemplate_tab", "worldboxmoddertemplate_tab_description", icon);
            tab.SetLayout(new System.Collections.Generic.List<string> { "worldboxmoddertemplate_group" });
            tab.AddPowerButton("worldboxmoddertemplate_group", PowerButtonCreator.CreateGodPowerButton(PowerId, icon));
            tab.UpdateLayout();

            LM.AddToCurrentLocale("worldboxmoddertemplate_tab", "My Mod");
            LM.AddToCurrentLocale("worldboxmoddertemplate_tab_description", "Powers from WorldBoxModderTemplate.");
        }
    }
}
