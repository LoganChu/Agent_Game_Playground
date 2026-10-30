extends TestCase
## Day 74 — music and work sounds (systems): a `melody` synth kind (notes by name at a tempo,
## plucked or held), the title theme looping behind the title screen and fading as play begins,
## a rising cue on the Music bus at every beacon's lighting (dialogue `music`), and Hild's scraper
## heard on each stroke (data/audio.json `work`).


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


var _saved_db: ContentDatabase


## The autoloads aren't readied under the test runner: give Content this content for a test
## (and _restore() after, or Content's own load later finds every record twice).
func _use_content() -> void:
	_saved_db = Content.db
	if Content.db.sounds.is_empty():
		Content.db = load_content()


func _restore() -> void:
	Content.db = _saved_db


func test_note_names_are_read_as_pitches() -> void:
	assert_true(is_equal_approx(SoundSynth.note_hz("A4"), 440.0), "A4 is 440 Hz")
	assert_true(is_equal_approx(SoundSynth.note_hz("A3"), 220.0), "an octave down")
	assert_true(absf(SoundSynth.note_hz("C4") - 261.63) < 0.01, "middle C")
	assert_true(absf(SoundSynth.note_hz("F#3") - 185.0) < 0.01, "a sharp")
	assert_true(absf(SoundSynth.note_hz("Bb2") - 116.54) < 0.01, "a flat")
	assert_eq(SoundSynth.note_hz("-"), 0.0, "a rest")
	assert_eq(SoundSynth.note_hz(330), 330.0, "Hz as a number")
	assert_eq(SoundSynth.note_hz("H4"), -1.0, "no such letter")
	assert_eq(SoundSynth.note_hz("D"), -1.0, "no octave")


func test_a_melody_plays_its_notes_in_time() -> void:
	# 120 bpm: a note, a beat's rest, a note — each held half its length.
	var recipe := {"kind": "melody", "tempo": 120, "legato": 0.5, "note_release": 0.01, "note_attack": 0.005,
		"notes": [["A4", 1], ["-", 1], ["E5", 1]], "length": 1.5}
	assert_true(is_equal_approx(SoundSynth.melody_seconds(recipe), 1.5), "three beats at 120 bpm")
	var s := SoundSynth.render(recipe, 1)
	var rate := SoundSynth.MIX_RATE
	assert_true(_energy(s, 0.05, 0.2) > 0.1, "the first note sounds")
	assert_true(_energy(s, 0.3, 0.95) < 0.001, "silence after it lets go, through the rest")
	assert_true(_energy(s, 1.05, 1.2) > 0.1, "the third beat's note")
	assert_eq(s.size(), int(1.5 * rate), "its length")
	# Plucked: the note rings on past its beat.
	var plucked := recipe.duplicate()
	plucked["ring"] = 1.0
	var p := SoundSynth.render(plucked, 1)
	assert_true(_energy(p, 0.6, 0.9) > 0.01, "a plucked note rings through the rest")


func test_the_music_pieces() -> void:
	var db := load_content()
	var title := str(db.audio["music"]["title"])
	var theme: Dictionary = db.sounds[title]
	assert_eq(str(theme["bus"]), "Music", "the theme is on the Music bus")
	assert_true(bool(theme.get("loop", false)), "and loops")
	var s := SoundSynth.render(theme, title.hash())
	var step := absf(s[0] - s[s.size() - 1])
	assert_true(step < 0.05, "the theme wraps without a click (%.3f)" % step)
	var cue: Dictionary = db.sounds["music_lighting"]
	assert_eq(str(cue["bus"]), "Music", "the lighting cue too")
	assert_false(bool(cue.get("loop", false)), "a one-shot")
	for part: Dictionary in theme["parts"] + cue["parts"]:
		if str(part["kind"]) == "melody":
			var length := float(part.get("length", (theme if theme["parts"].has(part) else cue)["length"]))
			assert_true(SoundSynth.melody_seconds(part) <= length + 0.001, "each melody fits its piece")
	assert_true(AudioDirector.cue_sounds(db).has(title), "the theme is rendered at startup")


func test_every_lighting_has_its_music() -> void:
	var db := load_content()
	var lit := 0
	for id: String in db.dialogues:
		for knot: Array in (db.get_dialogue(id).get("knots", {}) as Dictionary).values():
			for step: Variant in knot:
				if step is Dictionary and str((step as Dictionary).get("sound", "")) == "kindle":
					assert_eq(str(step.get("music", "")), "music_lighting", "%s: the cue comes with the beacon catching" % id)
					lit += 1
	assert_eq(lit, 5, "five lightings")
	var state := fresh_state(db)
	var heard: Array[String] = []
	var runner := DialogueRunner.new(db, state)
	runner.effect_applied.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "music":
			heard.append(str(data["music"])))
	runner.apply_effects({"music": "music_lighting"})
	assert_eq(heard, ["music_lighting"], "the runner hands a step's music on")


func test_the_director_plays_one_piece_at_a_time() -> void:
	_use_content()
	var audio := AudioDirector.new()
	_root().add_child(audio)
	assert_eq(audio.music_id(), "", "silent to begin with")
	assert_false(audio.play_music("no_such_piece"), "an unknown piece")
	assert_true(audio.play_music("music_title"), "the theme")
	assert_eq(audio.music_id(), "music_title")
	var first := audio._music
	assert_true(first != null and first.volume_db < -60.0, "a player waiting for the render, silent")
	SoundBank.stream(Content.db, "music_title")  # wait for the render
	# (The runner's root isn't in the tree, so nothing actually plays here; the smoke run hears it.)
	audio._update_music(0.5)
	assert_true(audio.play_music("music_title"), "asking again")
	assert_eq(audio._music, first, "doesn't restart it")
	audio.on_dialogue_effect("music", {"music": "music_lighting"})
	assert_eq(audio.music_id(), "music_lighting", "a lighting takes over")
	assert_true(first != audio._music and first.is_queued_for_deletion(), "the theme gives way (silent, so at once)")
	assert_true(audio.history.has("music:music_lighting"), "in the history")
	audio.stop_music(0.0)
	assert_eq(audio.music_id(), "", "stopped")
	assert_true(audio._music == null, "its player let go")
	audio.free()
	_restore()


func test_the_validator_checks_music_and_melodies() -> void:
	var db := load_content()
	db.sounds["bad_pitch"] = {"bus": "Music", "kind": "melody", "length": 2, "notes": [["Q4", 1]]}
	db.sounds["overrun"] = {"bus": "Music", "kind": "melody", "length": 1, "tempo": 60, "notes": [["A4", 2]]}
	db.sounds["bad_note"] = {"bus": "Music", "kind": "melody", "length": 2, "notes": ["A4"]}
	db.sounds["part_overrun"] = {"bus": "Music", "kind": "mix", "length": 1, "parts": [{"kind": "melody", "notes": [["A4", 3]]}]}
	db.audio["music"]["title"] = "pickup"
	db.audio["work"]["juggle"] = {"sound": "scrape_hull"}
	db.audio["work"]["scrape"] = {"sound": "surf"}
	var validator := ContentValidator.new(db)
	validator._validate_audio()
	validator._ref_effects("dialogue test", {"music": "kindle"})
	validator._ref_effects("dialogue test", {"music": "music_title"})
	var report := "\n".join(validator.errors)
	for needle: String in ["pitch 'Q4'", "overrun': the melody runs 2.00 s", "must be [pitch, beats", "part_overrun' part: the melody runs 3.00 s",
			"music 'pickup' must be on the Music bus", "'pickup' must loop", "work 'juggle' is not an idle style", "'surf' loops",
			"music 'kindle' must be on the Music bus", "one-shot cue; 'music_title' loops"]:
		assert_true(report.contains(needle), "caught: %s\n%s" % [needle, report])


func test_scrape_strokes_are_counted_and_signalled() -> void:
	var p := CharacterRig.SCRAPE_PERIOD
	var cycle := p * CharacterRig.SCRAPE_SET + CharacterRig.SCRAPE_BREATHER
	assert_eq(CharacterRig.scrape_stroke_index(0.1), 0, "the first stroke")
	assert_eq(CharacterRig.scrape_stroke_index(p * 4.5), 4, "the fifth")
	assert_eq(CharacterRig.scrape_stroke_index(p * 5.5), -1, "the breather")
	assert_eq(CharacterRig.scrape_stroke_index(cycle + 0.1), CharacterRig.SCRAPE_SET, "the next set counts on")
	var model := CharacterRig.instantiate("res://assets/models/characters/hild_scraping.glb", "scrape")
	var rig := model.find_child("CharacterRig", true, false) as CharacterRig
	rig._ready()
	rig._time = 0.0
	var strokes := [0]
	rig.work_stroke.connect(func() -> void: strokes[0] += 1)
	var t := 0.0
	while t < cycle - 0.2:
		rig._process(0.05)
		t += 0.05
	assert_eq(strokes[0], CharacterRig.SCRAPE_SET, "a stroke heard per push, none in the breather")
	rig.resting = true
	rig.rest = 1.0
	strokes[0] = 0
	t = 0.0
	while t < cycle - 0.2:
		rig._process(0.05)
		t += 0.05
	assert_eq(strokes[0], 0, "no strokes while she talks")
	model.free()


func test_hild_s_scraper_is_heard() -> void:
	_use_content()
	var db := Content.db
	var placed := {}
	for entry: Dictionary in db.get_region("kindleby")["npcs"]:
		if entry.get("npc") == "hild" and str(entry.get("idle", "")) == "scrape":
			placed = entry
			break
	assert_false(placed.is_empty(), "Hild scrapes on Kindleby's shingle")
	var actor := NpcActor.new()
	actor.setup("hild", Region.placed_npc_data(db.get_npc("hild"), placed))
	actor._build_body()  # (the runner's root isn't in the tree: no _ready)
	assert_eq(actor._work_id, "scrape_hull", "her idle's work sound")
	assert_true(actor._work_player != null and actor._work_player.max_distance > 5.0, "heard from where she works")
	SoundBank.stream(Content.db, "scrape_hull")
	actor._rig.work_stroke.emit()
	assert_eq(actor.work_sounds_played, 1, "a stroke, a scrape")
	assert_eq(actor._work_player.stream, SoundBank.stream(Content.db, "scrape_hull"), "the scrape loaded to play")
	actor.free()
	var mara := NpcActor.new()
	mara.setup("mara", db.get_npc("mara"))
	mara._build_body()
	assert_true(mara._work_player == null, "Mara has no work to be heard")
	mara.free()
	_restore()


## Mean absolute sample between `from` and `to` seconds.
func _energy(s: PackedFloat32Array, from: float, to: float) -> float:
	var a := int(from * SoundSynth.MIX_RATE)
	var b := mini(s.size(), int(to * SoundSynth.MIX_RATE))
	var sum := 0.0
	for i in range(a, b):
		sum += absf(s[i])
	return sum / maxf(1.0, b - a)
