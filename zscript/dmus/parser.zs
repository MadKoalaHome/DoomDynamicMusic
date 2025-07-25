class DMus_Parser
{
	const CHUNK_LUMP_NAME = "DMUSCHNK";
	const LEGACY_LUMP_NAME = "DMUSDESC";
	const LEGACY_LUMP_NAME_HIGH = "DMUSHIGH";
	const LEVEL_TRACK_NOT_SPECIFIED = 1024;		//I think, there's no wad with 1024 levels
	const SKIPPING_WHITESPACE = 0;
	const READING_FIELD = 1;
	
	void Parse(out array<DMus_Chunk> chnk_arr)
	{
		for(int hndl = Wads.FindLump(CHUNK_LUMP_NAME, 0, Wads.ANYNAMESPACE);
			hndl != -1; hndl = Wads.FindLump(CHUNK_LUMP_NAME, hndl+1, Wads.ANYNAMESPACE)){
			String data = Wads.ReadLump(hndl);
			let ctx = new("DMus_ParserContext");
			ctx.data = data;
			ctx.cur = 0;
			ctx.line = 1;

			for(; ctx.cur < data.length(); ++ctx.cur, ctx.CheckLine())
				if(data.ByteAt(ctx.cur) == ch("["))
					break;
			if(ctx.cur == data.length()){
				error(ctx, "Cannot find the beginning of music chunks array");
				continue;
			}

			++ctx.cur;
			DMus_Array arr = ParseArray(ctx);
			for(uint i = 0; i < arr.size(); ++i){
				DMus_Chunk chnk;
				if(arr.data[i].GetType() != DMus_Object.TYPE_DICT){
					error_noctx(string.format("Chunk #%u has a non-dictionary type", i));
					continue;
				}
				DMus_Object chnk_type = DMus_Dict(arr.data[i]).Find("type");
				if(!chnk_type)
					chnk = new("DMus_Chunk");
				else if(chnk_type.GetType() != DMus_Object.TYPE_STRING){
					error_noctx(string.format("Chunk #%u has a non-string type", i));
					continue;
				}
				else{
					error_noctx(string.format("Unknown chunk type \"%s\" of chunk %u", DMus_String(chnk_type).data, i));
					continue;
				}
					
				chnk.Init(DMus_Dict(arr.data[i]));
				chnk_arr.push(chnk);
			}
		}
	}
	
	bool IsDigit(int c)
	{
		return c >= ch("0") && c <= ch("9");
	}
	
	/* Parser for legacy file format (DMUSDESC and DMUSHIGH chunks) */
	/*That's so overcomplicated, so files can contain empty spaces in names*/
	void ParseLegacy(out array<DMus_Chunk> chnk_arr)
	{
		Array<String> mnames_normal;
		Array<String> mnames_action;
		Array<String> mnames_death;
		Array<String> mnames_high;
		Array<int> level_tags;

		//LUMP LOOP
		for(int hndl = Wads.FindLump(LEGACY_LUMP_NAME, 0, Wads.ANYNAMESPACE);
			hndl != -1;
			hndl = Wads.FindLump(LEGACY_LUMP_NAME, hndl+1, Wads.ANYNAMESPACE))
		{
			//Current lump
			String wdat = Wads.ReadLump(hndl);
			
			String nbuf = ""; 			// track name buffer
			
			int parserState = SKIPPING_WHITESPACE;			// 0 - skipping whitespaces
															// 1 - reading a track name
			int currentFieldIndex = 0;						// 0 - reading normal track name
															// 1 - reading action track name
															// 2 - reading death track name
															// 3 - reading map levelnum binding
			uint line = 1;  								// line number
			int inquote = 0; 								// if the parser is currently inside a quote

			//Reading file by letters loop
			for(int i = 0; i < wdat.Length(); ++i)
			{
				//Current char
				int c = wdat.ByteAt(i);

				//Checking new line 
				if(c == ch("\0")) break;
				if(c == ch("\n")) { 
					++line;
					currentFieldIndex = 0;
					//If level tag is absent in line, fill it with zero
					//So tag can be optional
					if(level_tags.size() < mnames_normal.size()){
						level_tags.push(0);
					}
				}
				
				//Checkiung in quote state
				if(c == ch("\"")){
					inquote = !inquote;
					continue;
				}

				//Checking skipping whitespaces
				if(parserState == SKIPPING_WHITESPACE && !IsSpace(c))
				{
					parserState = READING_FIELD; 
					i--;		//why?
				}
				
				else if(parserState == READING_FIELD)
				{
					// Check for special symbols as soon as we have at least one character
					if(nbuf.Length() == 1 && nbuf.ByteAt(0) == ch("*"))
					{
						// Handle * symbol (copy previous field)
						if(i < wdat.Length() - 1 && wdat.ByteAt(i+1) == ch("*"))
						{
							// Handle ** (skip remaining fields)
							nbuf.appendCharacter(ch("*"));
							i++; // Skip the second *
							
							// Skip remaining fields in this line
							while(i < wdat.Length() && wdat.ByteAt(i) != ch("\n"))
								i++;
							
							// Push the ** marker and break to next line
							switch(currentFieldIndex)
							{
								case 0: mnames_normal.push(nbuf); break;
								case 1: mnames_action.push(nbuf); break;
								case 2: mnames_death.push(nbuf);  break;
								case 3: level_tags.push(0); break; // Default value for skipped tag
							}
							
							// Force line break processing
							c = ch("\n");
							continue;
						}
						else if(i < wdat.Length() - 1 && IsDigit(wdat.ByteAt(i+1)))
						{
							// Handle *0 or *1
							int refIndex = wdat.ByteAt(i+1) - ch("0");
							i++; // Skip the digit
							
							String refValue;
							switch(refIndex)
							{
								case 0: refValue = mnames_normal[mnames_normal.Size()-1]; break;
								case 1: refValue = mnames_action[mnames_action.Size()-1]; break;
								default: error_noctx(String.Format("Invalid reference index \"*%d\" at line %u", refIndex, line));
							}
							
							// Push the referenced value
							switch(currentFieldIndex)
							{
								case 0: mnames_normal.push(refValue); break;
								case 1: mnames_action.push(refValue); break;
								case 2: mnames_death.push(refValue);  break;
								case 3: level_tags.push(refValue.ToInt(10)); break;
							}
							
							currentFieldIndex++;
							nbuf = "";
							parserState = SKIPPING_WHITESPACE;
							continue;
						}
						else
						{
							// Handle standalone * (copy previous field of same type)
							String refValue;
							switch(currentFieldIndex)
							{
								case 0: refValue = mnames_normal.Size() > 0 ? mnames_normal[mnames_normal.Size()-1] : ""; break;
								case 1: refValue = mnames_action.Size() > 0 ? mnames_action[mnames_action.Size()-1] : ""; break;
								case 2: refValue = mnames_death.Size() > 0 ? mnames_death[mnames_death.Size()-1] : ""; break;
								case 3: level_tags.push(level_tags.Size() > 0 ? level_tags[level_tags.Size()-1] : 0); break;
							}
							
							if(currentFieldIndex < 3)
							{
								switch(currentFieldIndex)
								{
									case 0: mnames_normal.push(refValue); break;
									case 1: mnames_action.push(refValue); break;
									case 2: mnames_death.push(refValue); break;
								}
							}
							
							currentFieldIndex++;
							nbuf = "";
							parserState = SKIPPING_WHITESPACE;
							continue;
						}
					}

					// Normal field processing
					if((IsSpace(c) && !inquote) || i == wdat.Length() - 1)
					{
						// Push the current field
						switch(currentFieldIndex)
						{
							case 0: mnames_normal.push(nbuf); break;
							case 1: mnames_action.push(nbuf); break;
							case 2: mnames_death.push(nbuf);  break;
							case 3: level_tags.push(nbuf.ToInt(10)); break;
						}
						
						// If we're at the end of the line and missing fields, fill them
						if((c == ch("\n") || i == wdat.Length() - 1) && currentFieldIndex < 3)
						{
							// Get the last normal music name
							String lastNormal = mnames_normal[mnames_normal.Size()-1];
							
							// Fill missing action music (field 1)
							if(currentFieldIndex < 1)
							{
								mnames_action.push(lastNormal);
								currentFieldIndex = 1;
							}
							
							// Fill missing death music (field 2)
							if(currentFieldIndex < 2)
							{
								mnames_death.push(lastNormal);
								currentFieldIndex = 2;
							}
							
							// Fill missing level tag (field 3) with 0
							if(currentFieldIndex < 3)
							{
								level_tags.push(0);
								currentFieldIndex = 3;
							}
						}
						
						currentFieldIndex++;
						nbuf = "";
						parserState = SKIPPING_WHITESPACE;
					}
					else
					{
						nbuf.appendCharacter(c);
					}
				}
			}
		}

		// Load high-action music descriptions
		for(int hndl = Wads.FindLump(LEGACY_LUMP_NAME_HIGH, 0, Wads.ANYNAMESPACE);
			hndl != -1;
			hndl = Wads.FindLump(LEGACY_LUMP_NAME_HIGH, hndl+1, Wads.ANYNAMESPACE))
		{
			String wdat = Wads.ReadLump(hndl);
			String nbuf = ""; // track name buffer

			int parserState = SKIPPING_WHITESPACE;	// 0 - skipping whitespaces
							// 1 - reading a track name
			int inquote = 0; // if the parser is currently inside a quote

			for(int i = 0; i < wdat.Length(); ++i)
			{
				int c = wdat.ByteAt(i);

				if(c == ch("\0")) break;
				if(c == ch("\"")){
					inquote = !inquote;
					continue;
				}

				if(parserState == SKIPPING_WHITESPACE && !IsSpace(c)){
					parserState = READING_FIELD; i--;
				}
				else if(parserState == READING_FIELD)
				{
					if((IsSpace(c) && !inquote) || i == wdat.Length() - 1){
						mnames_high.push(nbuf);
						nbuf = "";
						parserState = SKIPPING_WHITESPACE;
					}
					else
						nbuf.appendCharacter(c);
				}
			}
		}

		//Creating music chunk from parsed data
		
		DMus_Chunk chnk = new("DMus_Chunk");
		uint min_idx = mnames_normal.size();
		if(mnames_action.size() < min_idx) min_idx = mnames_action.size();
		if(mnames_death.size() < min_idx) min_idx = mnames_death.size();
		for(uint i = 0; i < min_idx; ++i){
			DMus_Track tr = new("DMus_Track");
			tr.normal.push(mnames_normal[i]);
			tr.actions.push(mnames_action[i]);
			tr.death.push(mnames_death[i]);
			tr.levels.push(level_tags[i]);
			chnk.tracks.push(tr);
		}
		for(uint i = 0; i < mnames_high.size(); ++i)
			chnk.high_action.push(mnames_high[i]);
		if(chnk.tracks.size())
			chnk_arr.push(chnk);
	}

	/* Object parsing functions */
	DMus_Object ParseObject(DMus_ParserContext ctx)
	{
		for(; ctx.cur < ctx.data.length(); ++ctx.cur, ctx.CheckLine())
			if(!IsSpace(ctx.CurByte()))
				break;
		if(ctx.cur == ctx.data.length()){
			error(ctx, "Expected an object, got an EOF");
			return null;
		}
		int c = ctx.CurByte();
		if(c == ch("[")){
			++ctx.cur;
			return ParseArray(ctx);
		}
		else if(c == ch("{")){
			++ctx.cur;
			return ParseDict(ctx);
		}
		return ParseString(ctx);
	}

	// All functions below assume they start at 1st character of object being parsed (array after '[', dictionary after '{', string at 1st character)
	DMus_String ParseString(DMus_ParserContext ctx)
	{
		DMus_String str = new("DMus_String");
		bool quotes = false;
		for(; ctx.cur < ctx.data.length(); ++ctx.cur, ctx.CheckLine()){
			int c = ctx.CurByte();
			if(quotes){
				if(c == ch("\"")){
					quotes = false;
					continue;
				}
			}
			else{
				if(c == ch("\"")){
					quotes = true;
					 continue;
				}
				else if(IsSpace(c) || IsNotString(c))
					return str;
			}
			str.data.AppendCharacter(c);
		}
		error(ctx, "Unexpected EOF while parsing a string");
		return null;
	}

	DMus_Array ParseArray(DMus_ParserContext ctx)
	{
		DMus_Array arr = new("DMus_Array");
		bool wait_for_comma = false;
		for(; ctx.cur < ctx.data.length(); ++ctx.cur, ctx.CheckLine()){
			int c = ctx.CurByte();
			if(wait_for_comma && c != ch("]")){
				if(c == ch(","))
					wait_for_comma = false;
			}
			else if(c == ch("]")){
				++ctx.cur; ctx.CheckLine();
				return arr;
			}
			else if(IsSpace(c))
				continue;
			else{
				DMus_Object obj = ParseObject(ctx);
				if(obj)
					arr.Push(obj);
				ctx.RewindLine(); --ctx.cur;
				wait_for_comma = true;
			}
		}
		error(ctx, "Unexpected EOF while parsing an array");
		return null;
	}

	DMus_Dict ParseDict(DMus_ParserContext ctx)
	{
		DMus_Dict dict = new("DMus_Dict");
		dict.Init();
		uint _state = 0;
		// 0 - waiting for key / dictionary end
		// 1 - waiting for colon
		// 2 - waiting for value
		// 3 - waiting for comma / dictionary end
		string key; DMus_Object value;
		bool multkey_err = true;
		for(; ctx.cur < ctx.data.length(); ++ctx.cur, ctx.CheckLine()){
			int c = ctx.CurByte();
			switch(_state){
				case 0:
					if(!IsSpace(c)){
						if(c == ch("}")){
							++ctx.cur; ctx.CheckLine();
							return dict;
						}
						DMus_Object obj = ParseObject(ctx);
						if(!obj){
							error(ctx, "Key cannot be null");
							continue;
						}
						else if(obj.GetType() != DMus_Object.TYPE_STRING){
							error(ctx, "Key cannot be something other than string");
							continue;
						}
						key = DMus_String(obj).data;
						ctx.RewindLine(); --ctx.cur;
						_state = 1; multkey_err = true;
					}
					break;
				case 1:
					if(c == ch(":"))
						_state = 2;
					else if(!IsSpace(c)){
						error(ctx, "Multiple keys cannot be defined for one value");
						multkey_err = false;
					}
					break;
				case 2:
					if(!IsSpace(c)){
						if(c == ch("}")){
							error(ctx, "Dictionary ended before value definition");
							return null;
						}
						DMus_Object obj = ParseObject(ctx);
						if(!obj){
							error(ctx, "Value cannot be null");
							continue;
						}
						value = obj;
						dict.Insert(key, value);
						ctx.RewindLine(); --ctx.cur;
						_state = 3; multkey_err = true;
					}
					break;
				case 3:
					if(c == ch("}")){
						++ctx.cur; ctx.CheckLine();							
						return dict;
					}
					else if(c == ch(","))
						_state = 0;
					else if(!IsSpace(c)){
						error(ctx, "Multiple values cannot be defined for one key");
						multkey_err = false;
					}
					break;
			}
		}
		error(ctx, "Unexpected EOF while parsing a dictionary");
		return null;
	}

	/* Helper functions */
	static int ch(String s) { return s.ByteAt(0); }
	static bool IsSpace(int c) { return c == ch("\t") || c == ch(" ") || c == ch("\v") || c == ch("\r") || c == ch("\n"); }
	static bool IsNotString(int c) { return c == ch(",") || c == ch("]") || c == ch(":") || c == ch("}"); }

	/* Debug functions */
	static void error(DMus_ParserContext ctx, String message)
	{
		Console.Printf("\x1b[31m"
					   "<DoomDynMus>[ERROR] '%s'\n"
					   "                     On line %u"
					   "\x1b[0m", message, ctx.line);
	}
	static void error_noctx(String message)
	{
		Console.Printf("\x1b[31m"
					   "<DoomDynMus>[ERROR] '%s'\n"
					   "\x1b[0m", message);

	}
}

class DMus_ParserContext
{
	string data;
	uint cur;
	uint line;

	int CurByte() { return data.ByteAt(cur); }
	void CheckLine() { if(CurByte() == DMus_Parser.ch("\n")) ++line; }
	void RewindLine() { if(CurByte() == DMus_Parser.ch("\n")) --line; }
}

/*Most abstract parsed object*/

class DMus_Object
{
	virtual uint GetType() { return TYPE_NONE; }
	virtual void Print(uint depth = 0) { console.printf("none"); }
	const TYPE_NONE = 0;
	const TYPE_STRING = 1;
	const TYPE_ARRAY = 2;
	const TYPE_DICT = 3;
}

/* Parsed string */

class DMus_String : DMus_Object
{
	override uint GetType() { return TYPE_STRING; }
	override void Print() { console.printf("'%s'", data); }
	string data;
}

/* Parsed array*/

class DMus_Array : DMus_Object
{
	override uint GetType() { return TYPE_ARRAY; }
	override void Print()
	{
		console.printf("[");
		for(uint i = 0; i < data.size(); ++i)
			data[i].Print();
		console.printf("]");
	}
	array<DMus_Object> data;

	void Push(DMus_Object obj) { data.push(obj); }
	uint Size() { return data.size(); }
}

/*Parsed dictionary*/

class DMus_Dict : DMus_Object
{
	override uint GetType() { return TYPE_DICT; }
	override void Print()
	{
		console.printf("{");
		for(uint i = 0; i < keys.size(); ++i){
			if(keys[i] != ""){
				console.printf("'%s':", keys[i]);
				values[i].Print();
			}
		}
		console.printf("}");
	}

	/* Based on hash tables. */
	array<DMus_Object> values;
	array<string> keys;
	uint filled;

	const initial_size = 16;
	void Init()
	{
		values.Resize(initial_size);
		keys.Resize(initial_size);
	}

	protected uint Hash(string key)
	{
		uint h = 0;
		for(uint i = 0; i < key.length(); ++i)
			h = (h * 256 + key.ByteAt(i)) % keys.size(); // keys.size() should be much lower than UINT_MAX anyway
		return h;
	}

	bool ShouldResize() { return filled >= values.size() * 2/3; }
	void Resize()
	{
		array<DMus_Object> old_values; old_values.copy(values);
		array<string> old_keys; old_keys.copy(keys);
		values.resize(values.size() * 2);
		keys.resize(keys.size() * 2);
		filled = 0;
		for(uint i = 0; i < keys.size(); ++i){
			keys[i] = "";
			values[i] = null;
		}
		for(uint i = 0; i < old_keys.size(); ++i)
			if(old_keys[i] != "")
				Insert(old_keys[i], old_values[i]);
	}

	DMus_Object Find(string key)
	{
		uint h = Hash(key), sz = values.size();
		for(uint i = h; i < sz; ++i)
			if(key == keys[i])
				return values[i];
			else if(keys[i] == "")
				return null;
		for(uint i = 0; i < h; ++i)
			if(key == keys[i])
				return values[i];
			else if(keys[i] == "")
				return null;
		return null;
	}

	bool Insert(string key, DMus_Object value)
	{
		if(key == "") /* Empty string marks unallocated space */
			return false;
		if(ShouldResize())
			Resize();

		uint h = Hash(key); uint sz = keys.size();
		for(uint i = h; i < sz; ++i)
			if(keys[i] == ""){
				keys[i] = key;
				values[i] = value;
				++filled;
				return true;
			}
		for(uint i = 0; i < h; ++i)
			if(keys[i] == ""){
				keys[i] = key;
				values[i] = value;
				++filled;
				return true;
			}
		return false;
	}
}
