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
	
	virtual void UpdateCVars()
	{
		min_mnst = CVar.GetCVar("dmus_combat_min_monsters").GetInt();
		min_mnst_high = CVar.GetCVar("dmus_combat_high_min_monsters").GetInt();
		prox_dist = CVar.GetCVar("dmus_combat_proximity_dist").GetFloat();
		combat_cooldown = CVar.GetCVar("dmus_combat_cooldown").GetInt();
	}

	int combat_timer;
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
				return currentTrack.high_action[random(0, currentTrack.high_action.size() - 1)];
			else
				return high_action[random(0, high_action.size() - 1)];
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

			/*Ambient tracks*/

			DMus_Object normal = data.Find("normal");
			if(normal){ // otherwise it's an empty list of tracks - use level music
				if(normal.GetType() == DMus_Object.TYPE_STRING)
					tr.normal.push(String.Format("%s%s", folder, DMus_String(normal).data));
				else if(normal.GetType() == DMus_Object.TYPE_ARRAY){
					DMus_Array _normal = DMus_Array(normal);
					for(uint j = 0; j < _normal.size(); ++j)
						if(_normal.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							tr.normal.push(String.Format("%s%s", folder, DMus_String(_normal.data[j]).data));
				}
				else
					DMus_Parser.error_noctx("normal category in track is not a string nor an array");
			}
			
			/*Action tracks*/
			
			DMus_Object actionContainer = data.Find("action");
			if(actionContainer){
				if(actionContainer.GetType() == DMus_Object.TYPE_STRING)
					tr.actions.push(String.Format("%s%s", folder, DMus_String(actionContainer).data));
				else if(actionContainer.GetType() == DMus_Object.TYPE_ARRAY){
					DMus_Array actions = DMus_Array(actionContainer);
					for(uint j = 0; j < actions.size(); ++j)
						if(actions.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							tr.actions.push(String.Format("%s%s", folder, DMus_String(actions.data[j]).data));
				}
				else
					DMus_Parser.error_noctx("action category in track is not a string nor an array");
			}
			
			/*Death tracks*/
			
			DMus_Object death = data.Find("death");
			if(death){
				if(death.GetType() == DMus_Object.TYPE_STRING)
					tr.death.push(String.Format("%s%s", folder, DMus_String(death).data));
				else if(death.GetType() == DMus_Object.TYPE_ARRAY){
					DMus_Array _death = DMus_Array(death);
					for(uint j = 0; j < _death.size(); ++j)
						if(_death.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							tr.death.push(String.Format("%s%s", folder, DMus_String(_death.data[j]).data));
				}
				else
					DMus_Parser.error_noctx("death category in track is not a string nor an array");
			}
			
			/*Map level number bindings*/
			
			DMus_Object levelNumTag = data.Find("level");
			if(levelNumTag){
				if(levelNumTag.GetType() == DMus_Object.TYPE_STRING)
					tr.levels.push(DMus_String(levelNumTag).data.ToInt(10));
				else if(levelNumTag .GetType() == DMus_Object.TYPE_ARRAY){
					DMus_Array levelNumTags = DMus_Array(levelNumTag);
					for(uint j = 0; j < levelNumTags.size(); ++j)
						if(levelNumTags.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							tr.levels.push(DMus_String(levelNumTags.data[j]).data.ToInt(10));
				}
				else
					DMus_Parser.error_noctx("Level tag category in track is not a string nor an array");
			}
			
			/*High action */
			
			DMus_Object high_action = data.Find("high_action");
			if(high_action){
				if(high_action.GetType() == DMus_Object.TYPE_STRING)
					tr.high_action.push(String.Format("%s%s", folder, DMus_String(high_action).data));
				else if(high_action.GetType() == DMus_Object.TYPE_ARRAY){
					DMus_Array _high_action = DMus_Array(high_action);
					for(uint j = 0; j < _high_action.size(); ++j)
						if(_high_action.data[j].GetType() != DMus_Object.TYPE_STRING)
							DMus_Parser.error_noctx("File name in track is not a string");
						else
							tr.high_action.push(String.Format("%s%s", folder, DMus_String(_high_action.data[j]).data));
				}
				else
					DMus_Parser.error_noctx("high action category in track is not a string nor an array");
			}

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
