class_name AudioDirector
extends Node
## The soundscape (Day 46), a child of main beside Atmosphere. Everything plays through the
## Settings buses by name (GameSettings.BUSES) and every sound is a SoundBank id:
##   - region `ambience` layers ([{sound, volume, if}]), crossfaded on arrival and when the
##     story changes them (gulls come back to Saltmarrow once the Gull's Beacon burns);
##   - the player's footsteps on the surface underfoot (Region.footstep_surface);
##   - dialogue voices: a few blips per line in the speaker's `voice` ({sound, pitch});
##   - story sounds from a dialogue step's `sound` (a horn, a beacon catching);
##   - cues for quests and items gained, and a tick for UI buttons;
##   - music (Day 74): the title theme behind the title screen, a dialogue step's `music` cue
##     (each beacon's lighting) — one piece at a time, the last fading out as the next comes in;
##   - the Greying: the Ambience bus muffled with depth and the ember's heartbeat under it,
##     and a sound when the fog turns the player back.
## Config is data/audio.json; see docs/TECH.md "Audio".

## Seconds an ambience layer takes to fade fully in or out.
const FADE := 1.6
## One-shot players (footsteps, voices, cues) taken round-robin.
const POOL_SIZE := 10
## Seconds between a line's voice blips, and the most blips one line gets.
const BLIP_GAP := 0.11
const MAX_BLIPS := 6
## Ambience bus cutoff (Hz) out of the Greying.
const OPEN_CUTOFF := 20000.0
## Recently played one-shot ids, newest last (tests and the smoke run read it).
const HISTORY := 48
## Seconds music takes to come in, and to fade out when it stops or gives way.
const MUSIC_IN := 1.5
const MUSIC_OUT := 2.0

var history: Array[String] = []

var _region_data: Dictionary = {}
## sound id -> AudioStreamPlayer, and the level (linear 0..1) each is at / heading for.
var _layers: Dictionary = {}
var _levels: Dictionary = {}
var _targets: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _heart: AudioStreamPlayer
var _muffle: AudioEffectLowPassFilter
var _depth := 0.0
## Item counts as last seen, so only a gain chimes (resynced on every region load: a load or
## a new game rebuilds the region).
var _last_counts: Dictionary = {}
## Pending voice blips: [seconds until, sound id, pitch].
var _blips: Array[Array] = []
var _rng := RandomNumberGenerator.new()
## The music playing or waiting to be rendered, its player and its level (0..1).
var _music_id := ""
var _music: AudioStreamPlayer
var _music_level := 0.0


func _ready() -> void:
	_rng.randomize()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_heart = AudioStreamPlayer.new()
	_heart.name = "EmberHeart"
	add_child(_heart)
	_muffle = _ambience_filter()
	SoundBank.warm(Content.db, cue_sounds(Content.db))
	var world := GameState.world
	world.quest_changed.connect(_on_quest_changed)
	world.inventory_changed.connect(_on_inventory_changed)
	world.flag_changed.connect(func(_id: String, _value: Variant) -> void: refresh(true))
	world.quest_changed.connect(func(_id: String, _state: String, _stage: String) -> void: refresh(true))
	get_tree().node_added.connect(_on_node_added)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void:
		play(str((Content.db.audio.get("events", {}) as Dictionary).get("ui_focus", "")), 1.0, _rng.randf_range(0.95, 1.05)))


## Quits the game a few frames after silencing every player (a sound still playing at the
## instant the process ends shows as leaked objects at exit). Menus and the smoke run use it.
static func quit_game(tree: SceneTree, code: int = 0) -> void:
	tree.paused = false
	for node in tree.root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in tree.root.find_children("*", "AudioStreamPlayer3D", true, false):
		(node as AudioStreamPlayer3D).stop()
		(node as AudioStreamPlayer3D).set_process(false)
	var director := tree.root.find_child("Audio", true, false)
	if director:
		director.set_process(false)
	for i in 3:
		await tree.process_frame
	tree.quit(code)


## The session's rendered sounds go with the game (a static cache outliving the tree shows
## as leaked objects at exit).
func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
	SoundBank.clear()


## Every non-ambience sound the game may play at any moment (footsteps, voices, cues), so
## they're rendered before they're wanted.
static func cue_sounds(db: ContentDatabase) -> Array:
	var ids: Array = []
	for id: Variant in (db.audio.get("footsteps", {}) as Dictionary).get("surfaces", {}).values():
		ids.append(str(id))
	for id: Variant in (db.audio.get("events", {}) as Dictionary).values():
		ids.append(str(id))
	var greying: Dictionary = db.audio.get("greying", {})
	for key: String in ["heart", "turn_back"]:
		if greying.has(key):
			ids.append(str(greying[key]))
	var music: Dictionary = db.audio.get("music", {})
	if music.has("title"):
		ids.append(str(music["title"]))
	var voice: Dictionary = db.audio.get("player_voice", {})
	if voice.has("sound"):
		ids.append(str(voice["sound"]))
	for npc: Dictionary in db.npcs.values():
		if npc.get("voice") is Dictionary:
			ids.append(str(npc["voice"].get("sound", "")))
	return ids


## The region's ambience layers whose `if` holds: sound id -> volume (the loudest entry of a
## sound wins when two hold).
static func ambience_layers(region_data: Dictionary, world: WorldState) -> Dictionary:
	var layers := {}
	for entry: Dictionary in region_data.get("ambience", []):
		if Conditions.evaluate(entry.get("if"), world):
			var id := str(entry.get("sound", ""))
			layers[id] = maxf(float(layers.get(id, 0.0)), float(entry.get("volume", 1.0)))
	return layers


## A new region: its layers fade in (a layer the last region shared carries on).
func enter_region(region_data: Dictionary) -> void:
	_region_data = region_data
	_last_counts = GameState.world.inventory.duplicate()
	refresh(true)


## Re-reads the region's layers against the story (live: a beacon lit mid-visit).
func refresh(animate: bool = true) -> void:
	_targets = ambience_layers(_region_data, GameState.world)
	SoundBank.warm(Content.db, _targets.keys())
	for id: String in _targets:
		if not _layers.has(id):
			var player := AudioStreamPlayer.new()
			player.name = "Ambience_" + id
			player.bus = SoundBank.bus(Content.db, id)
			player.volume_db = linear_to_db(0.0001)
			add_child(player)
			_layers[id] = player
			_levels[id] = 0.0
	if not animate:
		for id: String in _layers:
			_levels[id] = float(_targets.get(id, 0.0))


## Ambience layers playing (or waiting to) and their target volumes (tests).
func ambience_targets() -> Dictionary:
	return _targets.duplicate()


## Whether layer `id` is audible now (started and above silence; tests).
func layer_playing(id: String) -> bool:
	var player: AudioStreamPlayer = _layers.get(id)
	return player != null and player.playing and float(_levels.get(id, 0.0)) > 0.0


## The Greying around the player (0..1): muffles the Ambience bus and brings up the ember's
## heartbeat. Called every frame by main.
func follow_greying(depth: float) -> void:
	_depth = clampf(depth, 0.0, 1.0)
	var muffled := float((Content.db.audio.get("greying", {}) as Dictionary).get("muffle_cutoff", 500.0))
	if _muffle:
		_muffle.cutoff_hz = OPEN_CUTOFF * pow(muffled / OPEN_CUTOFF, _depth)
	var heart := str((Content.db.audio.get("greying", {}) as Dictionary).get("heart", ""))
	if _depth > 0.05 and not heart.is_empty():
		if not _heart.playing and SoundBank.is_ready(Content.db, heart):
			_heart.stream = SoundBank.stream(Content.db, heart)
			_heart.bus = SoundBank.bus(Content.db, heart)
			_heart.play()
		_heart.volume_db = linear_to_db(maxf(0.0001, _depth))
	elif _heart.playing:
		_heart.stop()


## The Ambience bus's cutoff right now (Hz; tests).
func ambience_cutoff() -> float:
	return _muffle.cutoff_hz if _muffle else OPEN_CUTOFF


func is_heart_playing() -> bool:
	return _heart.playing


## Plays one-shot `id` on its bus. Returns false if there's no such sound.
func play(id: String, volume: float = 1.0, pitch: float = 1.0) -> bool:
	var stream := SoundBank.stream(Content.db, id)
	if stream == null:
		return false
	var player := _pool[_next_voice]
	_next_voice = (_next_voice + 1) % _pool.size()
	player.stream = stream
	player.bus = SoundBank.bus(Content.db, id)
	player.volume_db = linear_to_db(maxf(0.0001, volume))
	player.pitch_scale = maxf(0.05, pitch)
	player.play()
	history.append(id)
	if history.size() > HISTORY:
		history.pop_front()
	return true


## A footfall on `surface` (a key of data/audio.json footsteps.surfaces), a little varied.
func footstep(surface: String) -> void:
	var surfaces: Dictionary = (Content.db.audio.get("footsteps", {}) as Dictionary).get("surfaces", {})
	var id := str(surfaces.get(surface, surfaces.get(str((Content.db.audio.get("footsteps", {}) as Dictionary).get("default", "")), "")))
	if not id.is_empty():
		play(id, _rng.randf_range(0.75, 1.0), _rng.randf_range(0.9, 1.1))


## A line of dialogue in its speaker's voice: a blip every few words (none for the narrator
## or a speaker without a `voice`). A new line cuts off the last one's blips.
func speak(speaker: String, text: String) -> void:
	_blips.clear()
	var voice := voice_of(Content.db, speaker)
	if voice.is_empty():
		return
	var count := blip_count(text)
	var base := float(voice.get("pitch", 1.0))
	for i in count:
		_blips.append([i * BLIP_GAP, str(voice["sound"]), base * _rng.randf_range(0.88, 1.12)])


## A speaker's voice ({sound, pitch}): the player's from data/audio.json, an NPC's `voice`;
## {} for the narrator and anyone without one.
static func voice_of(db: ContentDatabase, speaker: String) -> Dictionary:
	var voice: Variant = db.audio.get("player_voice", {}) if speaker == "player" else db.get_npc(speaker).get("voice", {})
	return voice if voice is Dictionary and (voice as Dictionary).has("sound") else {}


## Blips for a line: one per three words, 1..MAX_BLIPS.
static func blip_count(text: String) -> int:
	return clampi(ceili(text.split(" ", false).size() / 3.0), 1, MAX_BLIPS)


## Pending voice blips (tests).
func pending_blips() -> int:
	return _blips.size()


## The dialogue runner's effects: a step's `sound` plays, and its `music`.
func on_dialogue_effect(kind: String, data: Dictionary) -> void:
	if kind == "sound":
		play(str(data.get("sound", "")))
	elif kind == "music":
		play_music(str(data.get("music", "")))


## Starts music `id` (a sound on the Music bus): it comes in over MUSIC_IN once rendered, and
## whatever was playing fades out. A loop plays until stopped; a cue until it ends. Returns
## false if there's no such sound.
func play_music(id: String) -> bool:
	if not Content.db.sounds.has(id):
		return false
	if id == _music_id:
		return true
	_fade_out_music(MUSIC_OUT)
	_music_id = id
	SoundBank.warm(Content.db, [id])
	_music = AudioStreamPlayer.new()
	_music.name = "Music_" + id
	_music.bus = SoundBank.bus(Content.db, id)
	_music.volume_db = linear_to_db(0.0001)
	_music.finished.connect(_on_music_finished.bind(_music))
	add_child(_music)
	_music_level = 0.0
	history.append("music:" + id)
	if history.size() > HISTORY:
		history.pop_front()
	return true


## Fades the music out over `fade` s (0 = at once).
func stop_music(fade: float = MUSIC_OUT) -> void:
	_fade_out_music(fade)
	_music_id = ""


## The music playing or about to (rendering), "" for none (tests).
func music_id() -> String:
	return _music_id


## Whether music is audible now (tests).
func is_music_playing() -> bool:
	return _music != null and _music.playing


func _fade_out_music(fade: float) -> void:
	if _music == null:
		return
	var old := _music
	_music = null
	if fade <= 0.0 or not old.playing:
		old.stop()
		old.queue_free()
		return
	var tween := old.create_tween()
	tween.tween_property(old, "volume_db", linear_to_db(0.0001), fade)
	tween.tween_callback(func() -> void:
		old.stop()
		old.queue_free())


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if player == _music:
		_music = null
		_music_id = ""
	player.queue_free()


func _update_music(delta: float) -> void:
	if _music == null:
		return
	if not _music.playing:
		if not SoundBank.is_ready(Content.db, _music_id) or not _music.is_inside_tree():
			return
		_music.stream = SoundBank.stream(Content.db, _music_id)
		_music.play()
	_music_level = move_toward(_music_level, 1.0, delta / MUSIC_IN)
	_music.volume_db = linear_to_db(maxf(0.0001, _music_level))


## The Greying turned the player back.
func on_turned_back() -> void:
	play(str((Content.db.audio.get("greying", {}) as Dictionary).get("turn_back", "")))


func _process(delta: float) -> void:
	_update_music(delta)
	for id: String in _layers.keys():
		var player: AudioStreamPlayer = _layers[id]
		var target := float(_targets.get(id, 0.0))
		var level := move_toward(float(_levels[id]), target, delta / FADE)
		if not player.playing:
			if target <= 0.0:
				level = 0.0
			elif SoundBank.is_ready(Content.db, id):
				player.stream = SoundBank.stream(Content.db, id)
				# Somewhere into the loop, so the same layer never starts on the same swell.
				player.play(_rng.randf_range(0.0, maxf(0.01, player.stream.get_length() - 0.1)) if player.stream else 0.0)
			else:
				level = 0.0
		_levels[id] = level
		player.volume_db = linear_to_db(maxf(0.0001, level))
		if level <= 0.0 and target <= 0.0:
			player.queue_free()
			_layers.erase(id)
			_levels.erase(id)
	var i := 0
	while i < _blips.size():
		_blips[i][0] = float(_blips[i][0]) - delta
		if float(_blips[i][0]) <= 0.0:
			play(str(_blips[i][1]), 1.0, float(_blips[i][2]))
			_blips.remove_at(i)
		else:
			i += 1


func _on_quest_changed(id: String, state: String, stage: String) -> void:
	var events: Dictionary = Content.db.audio.get("events", {})
	match state:
		WorldState.QUEST_ACTIVE:
			var stages: Array = Content.db.get_quest(id).get("stages", [])
			var first := str((stages[0] as Dictionary).get("id", "")) if not stages.is_empty() else ""
			play(str(events.get("quest_start" if stage == first else "quest_update", "")))
		WorldState.QUEST_DONE:
			play(str(events.get("quest_done", "")))


func _on_inventory_changed(_item_id: String, count: int) -> void:
	# Only gains chime (a count going down is a Remnant given or burned).
	if count > int(_last_counts.get(_item_id, 0)):
		play(str((Content.db.audio.get("events", {}) as Dictionary).get("item_gained", "")))
	_last_counts[_item_id] = count



## Every button made anywhere (menus, dialogue choices, the journal) ticks when pressed.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(func() -> void:
			play(str((Content.db.audio.get("events", {}) as Dictionary).get("ui_press", ""))))


## The low-pass on the Ambience bus the Greying closes (added once, kept for the session).
static func _ambience_filter() -> AudioEffectLowPassFilter:
	var index := GameSettings.ensure_bus("Ambience")
	for e in AudioServer.get_bus_effect_count(index):
		var effect := AudioServer.get_bus_effect(index, e)
		if effect is AudioEffectLowPassFilter:
			return effect
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = OPEN_CUTOFF
	AudioServer.add_bus_effect(index, filter)
	return filter
