extends TestCase
## Audio hooks (Day 46): the procedural synth, the sound bank, data/audio.json and the
## validator's checks, region ambience and footsteps, voices, story sounds.


func test_synth_renders_every_kind_deterministically() -> void:
	var recipes := {
		"noise": {"kind": "noise", "color": "pink", "lowpass": 900, "highpass": 100, "length": 0.5, "decay": 0.1},
		"crackle": {"kind": "crackle", "rate": 40, "length": 0.5},
		"tone": {"kind": "tone", "freq": 220, "harmonics": [1.0, 0.5], "slide": 0.8, "length": 0.3, "decay": 0.1},
		"chirps": {"kind": "chirps", "freq": 1500, "rate": 4, "call": 0.1, "pulses": 2, "length": 1.0},
		"chime": {"kind": "chime", "notes": [523, 659], "gap": 0.1, "ring": 0.4, "length": 0.6},
		"mix": {"kind": "mix", "length": 0.4, "parts": [{"kind": "tone", "freq": 100, "length": 0.2}, {"kind": "noise", "length": 0.4}]},
	}
	for kind: String in SoundSynth.KINDS:
		var recipe: Dictionary = recipes[kind]
		var a := SoundSynth.render(recipe, 7)
		assert_eq(a.size(), SoundSynth.sample_count(recipe), kind + " length")
		assert_true(absf(SoundSynth.peak(a) - 0.8) < 0.01, "%s normalised to its gain (%s)" % [kind, SoundSynth.peak(a)])
		assert_eq(a, SoundSynth.render(recipe, 7), kind + " renders the same twice")
		assert_true(absf(a[a.size() - 1]) < 0.01, "%s fades out at its end (%s)" % [kind, a[a.size() - 1]])
	assert_false(SoundSynth.render(recipes["noise"], 1) == SoundSynth.render(recipes["noise"], 2), "another seed, another noise")


func test_loops_are_seamless() -> void:
	for recipe: Dictionary in [
			{"kind": "noise", "color": "brown", "lowpass": 600, "swell": 1.3, "swell_depth": 0.8, "length": 3.0, "loop": true},
			{"kind": "noise", "color": "pink", "gusts": 0.7, "gust_depth": 0.9, "length": 2.5, "loop": true}]:
		var s := SoundSynth.render(recipe, 3)
		# The wrap from the last sample to the first is no bigger a step than the sound
		# takes anywhere else.
		var biggest := 0.0
		for i in range(1, s.size()):
			biggest = maxf(biggest, absf(s[i] - s[i - 1]))
		assert_true(absf(s[0] - s[s.size() - 1]) <= biggest, "%s loops without a click (wrap %s, steps up to %s)" % [recipe["color"], absf(s[0] - s[s.size() - 1]), biggest])
	var stream := SoundSynth.build({"kind": "noise", "length": 0.5, "loop": true}, 1)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "a loop recipe makes a looping stream")
	assert_eq(stream.loop_end, int(0.5 * SoundSynth.MIX_RATE), "looping over its whole length")
	assert_eq(stream.data.size(), int(0.5 * SoundSynth.MIX_RATE) * 2, "16-bit mono")
	assert_eq(SoundSynth.build({"kind": "tone", "length": 0.1}).loop_mode, AudioStreamWAV.LOOP_DISABLED, "a one-shot doesn't loop")


func test_sound_bank_renders_in_the_background() -> void:
	var db := load_content()
	SoundBank.clear()
	SoundBank.warm(db, ["ui_press", "pickup", "no_such_sound"])
	var stream := SoundBank.stream(db, "pickup")
	assert_true(stream is AudioStreamWAV, "a warmed sound is there when asked for")
	assert_true(SoundBank.is_ready(db, "ui_press") or SoundBank.stream(db, "ui_press") != null, "the other render finishes too")
	assert_true(SoundBank.stream(db, "ui_press") == SoundBank.stream(db, "ui_press"), "rendered once, shared")
	assert_true(SoundBank.stream(db, "no_such_sound") == null, "an unknown sound is null")
	assert_eq(SoundBank.bus(db, "surf"), "Ambience")
	assert_eq(SoundBank.bus(db, "voice_reed"), "Voice")
	SoundBank.clear()


func test_every_sound_in_the_game_renders_within_budget() -> void:
	var db := load_content()
	assert_true(db.sounds.size() >= 30, "data/audio.json has the soundscape (%d sounds)" % db.sounds.size())
	var t0 := Time.get_ticks_msec()
	var total_bytes := 0
	for id: String in db.sounds:
		var recipe: Dictionary = db.sounds[id]
		var samples := SoundSynth.render(recipe, id.hash())
		total_bytes += samples.size() * 2
		assert_true(SoundSynth.peak(samples) > 0.05, "%s is not silent" % id)
		if str(recipe.get("bus", "")) == "Ambience":
			assert_true(bool(recipe.get("loop", false)) and float(recipe["length"]) >= 6.0, "ambience %s is a loop of at least 6 s (no obvious repeat)" % id)
	var took := Time.get_ticks_msec() - t0
	print("    every sound rendered in %d ms, %.1f MB" % [took, total_bytes / 1048576.0])
	assert_true(total_bytes < 16 * 1048576, "all the sounds fit in 16 MB (%d bytes)" % total_bytes)


func test_audio_config_names_real_sounds() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	validator._validate_audio()
	assert_empty(validator.errors, "data/audio.json is valid")
	var surfaces: Dictionary = db.audio["footsteps"]["surfaces"]
	for region_id: String in db.regions:
		var region: Dictionary = db.get_region(region_id)
		assert_true(surfaces.has(str(region.get("footsteps", ""))), "%s names its footsteps surface" % region_id)
		assert_false((region.get("ambience", []) as Array).is_empty(), "%s has ambience" % region_id)
		validator._validate_region_audio("region " + region_id, region)
	for npc_id: String in db.npcs:
		assert_false(AudioDirector.voice_of(db, npc_id).is_empty(), "%s has a voice" % npc_id)
	assert_empty(validator.errors, "every region's audio is valid")
	assert_true(AudioDirector.voice_of(db, "narrator").is_empty(), "the narrator is silent")
	assert_eq(str(AudioDirector.voice_of(db, "player")["sound"]), "voice_soft", "the Wakebearer's voice")


func test_validator_catches_audio_mistakes() -> void:
	var db := load_content()
	db.sounds["bad_kind"] = {"bus": "Effects", "kind": "kazoo", "length": 1}
	db.sounds["bad_bus"] = {"bus": "Radio", "kind": "tone", "length": 1}
	db.sounds["too_long"] = {"bus": "Effects", "kind": "tone", "length": 60}
	db.sounds["bad_mix"] = {"bus": "Effects", "kind": "mix", "length": 1, "parts": [{"kind": "noise", "color": "plaid"}]}
	db.sounds["no_file"] = {"bus": "Effects", "file": "res://assets/audio/missing.ogg"}
	db.audio["footsteps"]["surfaces"]["ice"] = "step_ice"
	var validator := ContentValidator.new(db)
	validator._validate_audio()
	var report := "\n".join(validator.errors)
	for needle: String in ["bad_kind': kind", "bad_bus' bus", "too_long': length", "plaid", "missing.ogg", "unknown sound 'step_ice'"]:
		assert_true(report.contains(needle), "caught: %s\n%s" % [needle, report])
	validator = ContentValidator.new(db)
	var region := {"ambience": [{"sound": "pickup"}, {"sound": "nothing_here"}, {"sound": "surf", "volume": 3}], "footsteps": "lava",
		"props": [{"model": "x.glb", "sound": {"id": "quest_done"}}]}
	validator._validate_region_audio("region test", region)
	report = "\n".join(validator.errors)
	for needle: String in ["'pickup' must loop", "unknown sound 'nothing_here'", "ambience volume", "footsteps 'lava'", "'quest_done' must loop"]:
		assert_true(report.contains(needle), "caught: %s\n%s" % [needle, report])
	validator = ContentValidator.new(db)
	validator._ref_effects("dialogue test", {"sound": "surf"})
	validator._ref_effects("dialogue test", {"sound": "nope"})
	validator._check_voice("npc test", {"sound": "voice_reed", "pitch": 9})
	report = "\n".join(validator.errors)
	for needle: String in ["plays once; 'surf' loops", "unknown sound 'nope'", "pitch must be"]:
		assert_true(report.contains(needle), "caught: %s\n%s" % [needle, report])


func test_the_world_sounds_different_after_a_burn() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var salt := AudioDirector.ambience_layers(db.get_region("saltmarrow"), state)
	var head := AudioDirector.ambience_layers(db.get_region("gulls_head"), state)
	assert_false(salt.has("gulls"), "no gulls over Saltmarrow while the Gull's Beacon is dark")
	assert_eq(float(head["wind_high"]), 1.0, "the dark headland is all wind")
	state.complete_quest("a_light_for_saltmarrow")
	salt = AudioDirector.ambience_layers(db.get_region("saltmarrow"), state)
	head = AudioDirector.ambience_layers(db.get_region("gulls_head"), state)
	assert_true(salt.has("gulls") and head.has("gulls"), "the gulls come back once it burns")
	assert_true(float(head["wind_high"]) < 1.0, "and the wind drops on the headland")
	for pair: Array in [["thornwold_woods", "a_light_for_thornwold", "woods_birds"], ["glasswater_fen", "a_light_for_glasswater", "fen_frogs"], ["wrackholm", "a_light_for_wrackholm", "gulls"]]:
		var fresh := fresh_state(db)
		assert_false(AudioDirector.ambience_layers(db.get_region(pair[0]), fresh).has(pair[2]), "%s: no %s before" % [pair[0], pair[2]])
		fresh.complete_quest(pair[1])
		assert_true(AudioDirector.ambience_layers(db.get_region(pair[0]), fresh).has(pair[2]), "%s: %s after" % [pair[0], pair[2]])


func test_every_lit_beacon_and_clamp_has_a_sound() -> void:
	var db := load_content()
	var lit := 0
	for region_id: String in db.regions:
		for prop: Dictionary in db.get_region(region_id).get("props", []):
			var model := str(prop.get("model", "")).get_file()
			if model.ends_with("_lit.glb") and (model.contains("beacon") or model.contains("light")):
				lit += 1
				assert_eq(str(prop.get("sound", {}).get("id", "")), "fire", "%s %s crackles" % [region_id, model])
			if model == "charcoal_clamp.glb":
				assert_eq(str(prop.get("sound", {}).get("id", "")), "embers", "%s clamp smoulders audibly" % region_id)
	assert_true(lit >= 5, "the lit beacons are found (%d)" % lit)
	var region := Region.new()
	var emitter_parent := Node3D.new()
	var emitter := SoundEmitter.build({"id": "fire", "offset": [0, 4, 0], "range": 20})
	emitter_parent.add_child(emitter)
	assert_eq(emitter.position, Vector3(0, 4, 0), "the emitter sits at its offset")
	assert_eq(emitter.max_distance, 20.0, "heard out to its range")
	assert_eq(emitter.sound_id, "fire")
	assert_eq(SoundBank.bus(db, emitter.sound_id), "Ambience", "a fire plays on the Ambience bus")
	assert_eq(Region.prop_sounds(db.get_region("thornwold_woods")), ["embers", "fire"], "a region's prop sounds, once each")
	emitter_parent.free()
	region.free()


func test_footsteps_follow_the_ground() -> void:
	var db := load_content()
	var data: Dictionary = db.get_region("saltmarrow")
	var region := Region.new()
	region.data = data
	region.field = TerrainField.from_data(data["ground"], float(data["water_level"]))
	var pier: Dictionary = (data["ground"]["piers"] as Array)[0]
	var on_pier := _inside(pier)
	var deck := float(pier.get("deck", 0.0))
	assert_eq(region.footstep_surface(Vector3(on_pier.x, deck, on_pier.y)), "boards", "the dock is boards")
	var land := Vector3(0, 0, 0)
	land.y = region.field.height_at(land.x, land.z)
	assert_eq(region.footstep_surface(land), "grass", "Saltmarrow's ground is its own surface")
	assert_eq(region.footstep_surface(land + Vector3(0, 1.0, 0)), "boards", "anything built well above the ground is boards")
	# Somewhere shallow: just under the water line.
	var wet := Vector2.INF
	for x in range(-30, 31):
		for z in range(-30, 31):
			var h := region.field.height_at(x, z)
			if h < region.field.water_level - 0.05 and h > region.field.water_level - 0.3 and region.field.pier_deck(x, z) == -INF:
				wet = Vector2(x, z)
				break
		if wet != Vector2.INF:
			break
	assert_true(wet != Vector2.INF, "found a shallow")
	assert_eq(region.footstep_surface(Vector3(wet.x, region.field.height_at(wet.x, wet.y), wet.y)), "wade", "the shallows wade")
	region.data = db.get_region("wrack_teeth")
	region.field = TerrainField.from_data(region.data["ground"], float(region.data["water_level"]))
	var high := Vector3(0, region.field.height_at(0, 0) + 1.0, 0)
	assert_eq(region.footstep_surface(high), "stone", "the Teeth's slabs are rock, not boards")
	region.free()


func test_voices_blip_with_the_line() -> void:
	assert_eq(AudioDirector.blip_count("No."), 1)
	assert_eq(AudioDirector.blip_count("one two three four five six seven"), 3)
	assert_eq(AudioDirector.blip_count("   "), 1, "even a pause gets one")
	var long := " ".join(PackedStringArray(range(40).map(func(i: int) -> String: return "word%d" % i)))
	assert_eq(AudioDirector.blip_count(long), AudioDirector.MAX_BLIPS, "a long line stops at the cap")


func test_story_sounds_play_from_dialogue() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var heard: Array[String] = []
	var runner := DialogueRunner.new(db, state)
	runner.effect_applied.connect(func(kind: String, data: Dictionary) -> void:
		if kind == "sound":
			heard.append(str(data["sound"])))
	var ev := runner.start("ferry_horn")
	assert_eq(str(ev.get("type")), "line")
	assert_eq(heard, ["horn_far"], "the ferry's horn sounds with its line")
	var used := {}
	for id: String in db.dialogues:
		_collect_sounds(db.get_dialogue(id), used)
	for needed: String in ["kindle", "horn_far", "horn_near"]:
		assert_true(used.has(needed), "the story plays %s" % needed)
	assert_eq(int(used.get("kindle", 0)), 4, "every beacon catches with a sound")


func _collect_sounds(node: Variant, out: Dictionary) -> void:
	if node is Dictionary:
		if (node as Dictionary).has("sound"):
			out[str(node["sound"])] = int(out.get(str(node["sound"]), 0)) + 1
		for value: Variant in (node as Dictionary).values():
			_collect_sounds(value, out)
	elif node is Array:
		for value: Variant in node:
			_collect_sounds(value, out)


## The middle of a pier's rect [x0, z0, x1, z1].
func _inside(pier: Dictionary) -> Vector2:
	var r: Array = pier["rect"]
	return Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
