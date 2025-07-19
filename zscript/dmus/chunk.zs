class DMus_Chunk
{
	array<DMus_Track> tracks;
	array<string> high_action;
	const TAG_NOT_FOUND = 1024;

	/* Track selection */
	uint cur_track;
	bool just_switched_track; // hint DMus_Player to actually fade to different track
	bool NextTrack()
	{
		if(cur_track >= tracks.size())
			return false;
		++cur_track;
		just_switched_track = true;
		return true;
	}
	bool PrevTrack()
	{
		if(cur_track == 0)
			return false;
		--cur_track;
		just_switched_track = true;
		return true;
	}
	void RandomTrack()
	{
		cur_track = random(0, tracks.size() - 1);
		just_switched_track = true;
	}
	
	void TrackForLevel(int levelNum)
	{
		int foundTrack = ChooseTrackByLevel(levelNum);
		cur_track = foundTrack ;
		just_switched_track = true;
	}
	
	int ChooseTrackByLevel(int levelNum){
		int foundIndex = TAG_NOT_FOUND;
		for (int trackIndex = 0; trackIndex < tracks.Size(); trackIndex++) 
        {
			DMus_Track track = tracks[trackIndex];
			//If track data has specified level numbers 
			for (int levelTagIndex = 0; levelTagIndex < track.levels.Size(); levelTagIndex++) 
			{
				int levelTag = track.levels[levelTagIndex];
				if(levelTag == levelNum){
					return trackIndex;
				}
			}
		}
		//If not foun load by track index
		if(foundIndex == TAG_NOT_FOUND) { 
			int mode = CVar.GetCVar("dmus_choose_track_submode").GetInt();
			if(mode == 0)
			{
				foundIndex = random(0, tracks.size() - 1);
			}
			else 
			{
				foundIndex = levelNum - 1;
				//If there are not so many tracks,just play the last one of them
				if(foundIndex > tracks.Size()) foundIndex = tracks.Size() - 1;
			}
		}

		//ToDo Maybe Random?
		return foundIndex;
	}

	/* File selection.
	   Based on what's going on in the game around the player.
	   Returns music file and music state (so DMus_Player won't constantly jump between random files of the same category)
	*/
	int min_mnst;
	int min_mnst_high;
	double prox_dist;
	const max_dist = 2048;
	int combat_cooldown;
	int combat_timer;
	
	virtual void UpdateCVars()
	{
		min_mnst = CVar.GetCVar("dmus_combat_min_monsters").GetInt();
		min_mnst_high = CVar.GetCVar("dmus_combat_high_min_monsters").GetInt();
		prox_dist = CVar.GetCVar("dmus_combat_proximity_dist").GetFloat();
		combat_cooldown = CVar.GetCVar("dmus_combat_cooldown").GetInt();
	}

	virtual play string, string SelectFile(PlayerPawn plr)
	{
		if(!tracks.size())
			return "*", "*";
			
		DMus_Track currentTrack = tracks[cur_track];

		// Player is dead
		if(plr.health <= 0)
			if(currentTrack.death.size())
				return currentTrack.death[random(0, currentTrack.death.size() - 1)], "death";				
			else
				return "*", "death";

		int mnst_cnt = 0;
		bool has_boss = false;
		BlockThingsIterator bti = BlockThingsIterator.Create(plr, max_dist);
		while(bti.next())
		{
			Actor a = bti.thing;
			if(a.health > 0 && a.bISMONSTER && a.target is "PlayerPawn"
				&& !a.bJUSTHIT // STRIFE friendly NPCs check
				&& (a.CheckSight(a.target) || a.distance3D(a.target) <= prox_dist)){
				++mnst_cnt;
				if(a.bBOSS)
					has_boss = true;
				if(mnst_cnt >= min_mnst_high)
					break;
			}
		}

		// Player is in combat
		if((mnst_cnt >= min_mnst_high || has_boss) && (high_action.size() || currentTrack.high_action.size())){
			combat_timer = combat_cooldown;
				
			if(currentTrack.high_action.size())
				return currentTrack.high_action[random(0, currentTrack.high_action.size() - 1)], "action";
			else
				return high_action[random(0, high_action.size() - 1)], "action";
		}
		else if(mnst_cnt >= min_mnst || has_boss)
		{
			combat_timer = combat_cooldown;
			if(currentTrack.actions.size())
				return currentTrack.actions[random(0, currentTrack.actions.size() - 1)], "action";
			else
				return "*", "action";
		}

		if(combat_timer > 0){
			--combat_timer;
			return "*", "*"; // dont change track
		}

		// Play normal music
		if(currentTrack.normal.size())
			return currentTrack.normal[random(0, currentTrack.normal.size() - 1)], "normal";
		return "*", "normal";
	}
	
	virtual void Parse(string folder, DMus_Dict source, string tag, array<string> container)
	{
		DMus_Object node = source.Find(tag);
			if(node){ // otherwise it's an empty list of tracks - use level music
				if(node.GetType() == DMus_Object.TYPE_STRING)
				{
					container.push(String.Format("%s%s", folder, DMus_String(node).data));
				}
				else if(node.GetType() == DMus_Object.TYPE_ARRAY)
				{
					DMus_Array _tracks = DMus_Array(node);
					for(uint j = 0; j < _tracks.size(); ++j)
						if(_tracks.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							container.push(String.Format("%s%s", folder, DMus_String(_tracks.data[j]).data));
				}
				else
				{
					DMus_Parser.error_noctx(String.Format("%s category in track is not a string nor an array", tag));
				}
					
			}
	}
	
	virtual void ParseInt(string folder, DMus_Dict source, string tag, array<int> container)
	{
		DMus_Object node = source.Find(tag);
			if(node){ // otherwise it's an empty list of tracks - use level music
				if(node.GetType() == DMus_Object.TYPE_STRING)
				{
					container.push(DMus_String(node).data.ToInt(10));
				}
				else if(node.GetType() == DMus_Object.TYPE_ARRAY)
				{
					DMus_Array _tracks = DMus_Array(node);
					for(uint j = 0; j < _tracks.size(); ++j)
						if(_tracks.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							container.push(DMus_String(_tracks.data[j]).data.ToInt(10));
				}
				else
				{
					DMus_Parser.error_noctx(String.Format("%s category in track is not a string nor an array", tag));
				}
					
			}
	}
	
	/* How a chunk type reads data from DMUSCHNK file */
	virtual void Init(DMus_Dict data)
	{
		cur_track = 0;

		DMus_Object _folder = data.Find("folder");
		string folder;
		if(!_folder)
			folder = "";
		else if(_folder)
			if(_folder.getType() != DMus_Object.TYPE_STRING)
				DMus_Parser.error_noctx("Folder name must be a string");
			else
				folder = DMus_String(_folder).data;

		/* Checking parsed content*/
		
		DMus_Object fileTracksConfig = data.Find("tracks");
		if(!fileTracksConfig){
			DMus_Parser.error_noctx("No tracks in chunk");
			return;
		}
		else if(fileTracksConfig.GetType() != DMus_Object.TYPE_ARRAY){
			DMus_Parser.error_noctx("Tracks in chunk must be an array");
			return;
		}
		
		/* Parsing track line loop*/
		
		DMus_Array fileTrackList = DMus_Array(fileTracksConfig);
		for(uint i = 0; i < fileTrackList.size(); ++i)
		{
			DMus_Track tr = new("DMus_Track");
			DMus_Object trackData = fileTrackList.data[i];
			if(!trackData){
				DMus_Parser.error_noctx("Track cannot be an empty value");
				continue;
			}
			else if(trackData.GetType() != DMus_Object.TYPE_DICT){
				DMus_Parser.error_noctx("Track cannot be a non-dictionary value");
				continue;
			}
			DMus_Dict data = DMus_Dict(trackData);

			Parse(folder, data,"normal",tr.normal);
			Parse(folder, data,"action",tr.actions);
			Parse(folder, data,"death",tr.death);
			Parse(folder, data,"high_action",tr.high_action);
			ParseInt(folder, data,"level",tr.levels);
			
			self.tracks.push(tr);
		}

		/* High-action state*/
		DMus_Object _high_action = data.Find("high_action");
		if(_high_action){
			if(_high_action.GetType() != DMus_Object.TYPE_ARRAY){
				DMus_Parser.error_noctx("High-action music should be an array");
			}
			else{
				DMus_Array high_action = DMus_Array(_high_action);
				for(uint i = 0; i < high_action.size(); ++i){
					if(!high_action.data[i] || (high_action.data[i].GetType() != DMus_Object.TYPE_STRING)){
						DMus_Parser.error_noctx("High-action music array should only contain string objects");
						continue;
					}
					DMus_String ha = DMus_String(high_action.data[i]);
					self.high_action.push(String.Format("%s%s", folder, ha.data));
				}
			}
		}
	}
}

class DMus_Track
{
	array<string> normal;	
	array<string> actions;
	array<string> death;
	array<string> high_action;
	array<int> levels;			//Which levels to play tracks specifically
	//array<string> levelNames;	//ToDo Level Names
}
