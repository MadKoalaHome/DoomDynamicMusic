## Original mod

A simple yet sometimes astonishing mod that adds a dynamic music system to Doom. Originally was created by [cyber_cool](https://github.com/jankespro12/DoomDynMus).

## Features

* Customizable fade-in and fade-out between tracks.
* Tracks are grouped - each group contains an ambient track, a combat track and a death track.
* A flexible lump format that groups music tracks together.
* Load any kind of music pack others or you made, and even mix them.
* Keybinds for changing currently playing track.
* High-action combat music playing on specific, dangerous occasions.

### Fork features

* Ability to bind a track group to a specific level by its number

## Using

### Config formats

- #### Modern format

Lumps that DoomDynMus uses to recognize and group music files are called DMUSCHNK (music chunks). They look like simplified JSON files. There are 3 basic objects in DMUSCHNK:
String - a sequence of characters. You can include whitespaces or special characters (",", "]", "}", etc.) in a string by surrounding it with quotes.

- String - a sequence of characters. You can include whitespaces or special characters (",","]","}", etc.) in a string by surrounding it with quotes.
```javascript
string_example
"You know, what a string is!"
```
- Array - a sequence of objects separated by commas and surrounded with [square brackets].
```javascript
[an, array, "of items", [which, "can be", nested, [with, great], {what: depth, how_much: 100ft}], "for real"]
```
- Dictionary - a sequence of pairs "key: value", surrounded with {curly brackets}.
```javascript
{ type: normal,
	sizes: [1, 2, 3, 10, chicken, -1],
	name: "a normal dictionary"
}
```

A simple music chunk file looks like this:
```javascript
[
	{
		folder: "music/",
		tracks:
		[
			{normal: ["1-08 UNATCO.mp3", "1-17 NYC Streets.mp3"], action: "1-10 UNATCO Action.mp3", death: "1-11 UNATCO Death.mp3", high_action: "04_Anna_Combat.ogg"},
			{normal: "2-01 Majestic 12 Labs.mp3", action: "2-03 Majestic 12 Action.mp3", death: "2-04 Majestic 12  Death.mp3", level: "28"}
		],
		high_action: ["04_Gunther_CombatIntro.ogg", "05_Anna_Combat.ogg"]
	}
]
```
Here, you NEED to put everything between an opening and a closing square brackets - DoomDynMus expects every music chunk file to be an array at it's top level.
In this array, you put one or more dictionaries - music chunks - which group together music files, while also providing some configuration options.
The whole list of attributes a music chunk can have is listed below:

- tracks - mandatory attribute which describes a list of track groups. Each track group is a dictionary, which in turn has 3 attributes:
  - normal (ambient music, no or low amount of enemies directly attacking the player - can be configured through CVars)
  - action
  - death
  - high_action (same as high_action in track options, but tied to a track group and preferred over the former)
  - level (binding a whole track group with normal, action, death e.t.c. to certain map by its level number)

- high_action - attribute which describes an array of music tracks which play when a player is fighting a boss or a large amount of monsters (amount of monsters is configurable through cvars). A track is selected randomly from this array, and it doesn't depend on tracks attribute.

- folder - a string which is prepended to each track name in the music chunk. You can only define it once per chunk, though, but it's handy if you put your music into a separate folder or even multiple folders (create multiple chunks on that occasion).

Upon selecting a random track (whether by a keybind, map change, or on game launcing) DoomDynMus picks a random chunk first (from any music chunk file loaded), then it picks a random track inside this chunk, according to current state of the game (ambient/action/death/high action). Each chunk has an equal chance of getting picked, no matter how much tracks does it have.

- #### Legacy format

Lump format is called DMUSDESC (exactly that file name, or with an extension).
It's basic structure is described as follows:

```javascript
"/music/ambient1.mp3" "/music/combat1.mp3" *0
"/music/ambient2.mp3" "/music/combat2.mp3" "/music/death2.mp3"
```

Each group has 3 tracks, one following other. They are separated by any kind of white space: spacebars, new lines, tabulations, etc. If a name of a track contains spaces, it can be encapsulated in quotes (but not necessary).
To avoid unnecessary duplication, you can use &#42;N to duplicate a track from the same group from other category (i.e. &#42;0 to duplicate ambient track and &#42;1 to duplicate action track). You can't duplicate tracks before providing their names.
You can also keep the level music for any track category by typing &#42;&#42;.
There is also a separate category "high-action" combat music. 
It is placed in a separate lump called DMUSHIGH. It doesn't support duplication, just file names. The amount of music tracks is not limited and not tied to DMUSDESC lump (they are chosen randomly instead being tied to a track group). If no such lump is present, normal combat music will play instead:

```javascript
"music/boss1.mp3"
"music/boss2.mp3"
```

### Loading order

Load any music packs before the mod.
