class DMus_EventHandler : StaticEventHandler
{
	DMus_Player plr;
	bool plr_init;

	override void OnRegister()
	{
		plr = new("DMus_Player");
		let parser = new("DMus_Parser");
		parser.Parse(plr.chnk_arr);
		parser.ParseLegacy(plr.chnk_arr);
	}

	override void WorldLoaded(WorldEvent e)
	{
		if(!e.isSaveGame) {
			
			int mode = CVar.GetCVar("dmus_choose_track_mode").GetInt();
			
			if(mode == 0){
				int shuffle = CVar.GetCVar("dmus_shuffle_behaviour").GetInt();
				if(shuffle > 0) {
					plr.dont_announce_fade = true;
					plr.fade_instantly = true;
					plr.RandomTrack();
				}
			}
					
			if(mode == 1){
				plr.dont_announce_fade = true;
				plr.fade_instantly = true;
				int levelnum = level.LevelNum;
				plr.TrackForLevel(levelnum);
			}
		}
	}

	override void WorldTick()
	{
		uint i = 0; for(; i < MAXPLAYERS; ++i)
			if(playeringame[i])
				break;
		if(i < MAXPLAYERS){
			if(!plr_init){
				plr.Init(players[i].mo);
				plr_init = true;
			}
			plr.WatchFile(players[i].mo);
			plr.DoFade();
		}
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if(e.name == "dmus_random"){
			plr.dont_announce_fade = true;
			plr.fade_instantly = true;
			plr.RandomTrack();
		}
	}
}
