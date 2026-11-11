using NeoModLoader.api;
using UnityEngine;

namespace WorldBoxModderTemplate
{
    /// <summary>
    /// Entry point. NeoModLoader picks the first non-abstract MonoBehaviour that
    /// implements IMod, so this class must be the only such class in the assembly.
    /// </summary>
    public class Main : BasicMod<Main>
    {
        private bool _tabCreated;

        protected override void OnModLoad()
        {
            LogInfo("WorldBoxModderTemplate loading");
            Content.Init();
            LogInfo("WORLDBOX_MODDER_TEMPLATE_MARKER loaded");
            LogInfo("WorldBoxModderTemplate ready");
        }

        /// <summary>
        /// The power tab needs the game UI to exist, and OnModLoad runs before there is
        /// a world at all. Create it on the first frame where the UI is ready.
        /// </summary>
        private void Update()
        {
            if (_tabCreated) return;
            if (!global::Config.game_loaded) return;
            if (MapBox.instance == null) return;

            _tabCreated = true;
            try
            {
                Content.CreatePowerTab();
                LogInfo("WorldBoxModderTemplate power tab created");
            }
            catch (System.Exception e)
            {
                LogError("failed to create power tab: " + e);
            }
        }
    }
}
