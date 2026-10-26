class_name SmokeTest
extends Node
## Automated end-to-end playthrough of the loaded region, run with:
##   godot --headless --path . -- --smoke-test
## Talks to every NPC (walking menus option by option), collects every pickup, then
## quicksaves, resets and quickloads, checking state survives. Exits 0 on success.

const MAX_DIALOGUE_STEPS := 200
const PASSES := 9

var _failures: PackedStringArray = []
## Recap text of the end-of-act card, once it has been shown.
var _act_end_recap := ""
## Ferry trips taken by the menu walk ("saltmarrow -> thornwold_landing").
var _sailings: PackedStringArray = []
## Regions the menu walk has stood in.
var _walked: Dictionary = {}


func _ready() -> void:
	# The pause menu check pauses the tree; the run itself must keep going.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Never touch the player's real saves.
	SaveSystem.save_dir = "user://smoke_saves"
	# ...nor their settings: run on defaults, write to a scratch file.
	var settings := GameSettings.current()
	settings.path = "user://smoke_settings.cfg"
	settings.reset_values()
	settings.apply_all()
	_run.call_deferred()


func _run() -> void:
	# Let the main scene finish building (deferred region load, intro dialogue, physics).
	for i in 5:
		await get_tree().physics_frame
	var main := get_parent()
	var ui: DialogueUI = main.get("dialogue_ui")
	await _start_from_title(main)
	_check(ui.is_open(), "intro dialogue plays on new game")
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	_check(player != null and player.find_child("CharacterRig", true, false) != null, "player shows the Wakebearer model")
	_finish_dialogue(ui, "intro")
	await _check_ambience(main)
	await _check_ground(main)
	await _check_greying(main)
	await _check_gates(main, false)
	# Several passes over the reachable regions so quests started on one pass can advance on
	# the next: Saltmarrow's island first (Gull's Head once the token opens its gate), through
	# the beacon, Aldous's confession, the ferry and passage (ending Act I); then the walk
	# casts off for Thornwold, meets Bram, parts the bramble wall, meets Hob, climbs to the Lamp
	# and lights the Ridge Light.
	for pass_index in PASSES:
		# Walk only where a player could be: regions reachable on foot from where the last
		# pass left off (open exits). A sailing or a `travel` effect moves the walk on to the
		# new place and whatever is reachable from there, never back by teleport.
		var visited: Dictionary = {}
		var queue := _reachable((main.get("region") as Region).region_id)
		while not queue.is_empty():
			var region_id: String = queue.pop_front()
			if visited.has(region_id):
				continue
			visited[region_id] = true
			GameState.travel(region_id)
			for i in 3:
				await get_tree().physics_frame
			var region: Region = main.get("region")
			_check(region != null and region.region_id == region_id, "region %s loaded" % region_id)
			_walked[region_id] = true
			if ui.is_open():
				# A region arrival event (the ferry's horn) is playing.
				_finish_dialogue(ui, "arrival event in " + region_id)
				await get_tree().process_frame
			if await _walk_region(main, ui, region, pass_index):
				var here := (main.get("region") as Region).region_id
				queue.clear()
				if not visited.has(here):
					queue.append(here)
				for next: String in _reachable(here):
					if not visited.has(next) and not queue.has(next):
						queue.append(next)
	await _sail_the_fen_lane(main, ui)
	await _carry_the_name_home(main, ui)
	_check(_walked.size() == Content.db.regions.size(), "the walk reached every region (%s)" % ", ".join(PackedStringArray(_walked.keys())))
	await _check_gates(main, true)
	await _check_beacon_lit(main)
	await _check_act_one_close(main)
	await _check_crossing(main)
	await _check_journal(main.get("journal_ui"))
	await _check_pause_menu(main)
	await _check_settings(main)
	await _check_chapter_select(main)
	await _check_return_to_title(main)
	print("Smoke test end state: ", JSON.stringify(GameState.world.to_dict()))
	var before := GameState.world.to_dict()
	_check(SaveSystem.save_game("smoke_test"), "save succeeds")
	GameState.world.load_dict({})
	_check(SaveSystem.load_game("smoke_test"), "load succeeds")
	_check(JSON.stringify(GameState.world.to_dict()) == JSON.stringify(before), "state round-trips through save")
	DirAccess.remove_absolute(SaveSystem.slot_path("smoke_test"))
	for i in 3:
		await get_tree().process_frame
	_check(main.get("region") != null, "region rebuilt after load")
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		AudioDirector.quit_game(get_tree(), 0)
	else:
		printerr("SMOKE TEST FAILED:\n  " + "\n  ".join(_failures))
		AudioDirector.quit_game(get_tree(), 1)


## The soundscape: Shingle Point's surf and wind fade in (no gulls before the burn), and a
## spoken line blips in its speaker's voice.
func _check_ambience(main: Node) -> void:
	var audio: AudioDirector = main.get("audio")
	var guard := 0
	while not (audio.layer_playing("surf") and audio.layer_playing("wind_low")) and guard < 600:
		guard += 1
		await get_tree().process_frame
	_check(audio.layer_playing("surf") and audio.layer_playing("wind_low"), "Shingle Point's surf and wind play")
	_check(not audio.ambience_targets().has("gulls"), "no gulls on Shingle Point before the beacon burns")
	audio.history.clear()
	audio.speak("pell", "Oi! You. Yes, you, with the hand.")
	for i in 30:
		await get_tree().process_frame
	_check(audio.history.count("voice_bright") >= 2, "Pell's line blips in her voice (%s)" % ", ".join(PackedStringArray(audio.history)))


## Regions the player can walk to from `from` right now (itself first): exits whose
## `requires` holds, followed transitively. Ferry lanes and dialogue `travel`s aren't exits.
func _reachable(from: String) -> Array[String]:
	var out: Array[String] = [from]
	var i := 0
	while i < out.size():
		for exit: Dictionary in Content.db.get_region(out[i]).get("exits", []):
			var to := str(exit.get("to", ""))
			if not out.has(to) and Conditions.evaluate(exit.get("requires"), GameState.world):
				out.append(to)
		i += 1
	return out


## True if dialogue `id` can `travel` the player somewhere.
func _can_travel(id: String) -> bool:
	return JSON.stringify(Content.db.dialogues.get(id, {})).contains("\"travel\"")


## Day 29: the fen lane opens only once the Ridge Light is lit, late in the walk, and the passes
## never talk to Oda on Thornwold (the bramble wall moves the walk on first). So sail it here, the
## way a player would: at the landing, ask Oda for Glasswater Fen by name, walk the fen (Hesper,
## the rowboat, Corran; the second time the letting post, now Hesper has told of it), and let Oda
## carry the walk back. Twice.
func _sail_the_fen_lane(main: Node, ui: DialogueUI) -> void:
	for trip in 2:
		_check(str(GameState.world.get_flag("lanes_ferry_at")) == "thornwold", "the ferry lies at Thornwold before sailing to the fen")
		GameState.travel("thornwold_landing")
		for i in 3:
			await get_tree().physics_frame
		if ui.is_open():
			_finish_dialogue(ui, "arrival event at the landing")
			await get_tree().process_frame
		var oda: NpcActor = null
		for node in get_tree().get_nodes_in_group("npcs"):
			if (node as NpcActor).npc_id == "oda" and not node.is_queued_for_deletion():
				oda = node
		_check(oda != null, "Oda on the Thornwold jetty to sail north-about")
		if oda == null:
			return
		oda.interact()
		_check(_sail(ui, "fen"), "Oda sails the fen lane once the Ridge Light is lit")
		_finish_dialogue(ui, "oda (sailing to the fen)")
		for i in 3:
			await get_tree().physics_frame
		var region: Region = main.get("region")
		_check(region.region_id == "glasswater_fen", "Oda sailed to Glasswater Fen")
		if region.region_id != "glasswater_fen":
			return
		_sailings.append("thornwold_landing -> glasswater_fen")
		_walked[region.region_id] = true
		if ui.is_open():
			_finish_dialogue(ui, "arrival event at the fen")
			await get_tree().process_frame
		if trip == 1:
			# Before the walk: it ends with Oda sailing back (the region's nodes go).
			await _check_unmoored_look_away(region)
		await _walk_region(main, ui, region, trip)
		if (main.get("region") as Region).region_id == "heron_mere":
			await _walk_the_heron(main, ui, trip)


## Days 45 and 47: with the Lamp's name read in Wrackholm's Book, carry it home the way a player
## would: through the bramble wall, up the Keepers' ladder, say it to the Lamp (which starts *The
## East Stair*), back down by the exits, and Oda's lane home to Saltmarrow, where Aldous hears Wynn
## Sallow kept a coal, counts the novices for Wynn's sake and lays the Wrens' brazier.
func _carry_the_name_home(main: Node, ui: DialogueUI) -> void:
	var world := GameState.world
	_check(world.get_flag("wrackholm_lamp_name_read") == true, "the Lamp's name was read in the Book")
	if not await _arrived(main, ui, "thornwold_landing", "back at the landing to carry the name"):
		return
	_object("thornwold_bramble_wall").interact()
	_check(_choose(ui, "Go through."), "the parted wall lets the walk through again")
	_finish_dialogue(ui, "the bramble wall (going through)")
	if not await _arrived(main, ui, "thornwold_woods", "through the wall to the woods"):
		return
	_object("woods_keeper_ladder").interact()
	_check(_choose(ui, "Climb to the ridge."), "the stood ladder climbed again")
	_finish_dialogue(ui, "the ladder (climbing)")
	if not await _arrived(main, ui, "thornwold_ridge", "up the ladder to the ridge"):
		return
	_npc("lamp").interact()
	_check(_choose(ui, "I read your name. In the Tidewrights' Book, on Wrackholm."), "the Lamp told the Book has its name")
	_check(_choose(ui, "Your name is Wynn Sallow."), "...and said it outright")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "the lamp (its name)")
	_check(world.get_flag("thornwold_lamp_name") == "told" and world.quest_state("paid_twice") == WorldState.QUEST_DONE,
			"the name carried home (Paid Twice)")
	_check(world.quest_stage("the_east_stair") == "ask_the_door_warden", "the Lamp sends the walk to the door-warden")
	if not await _walk_the_old_road(main, ui):
		return
	if not await _take_exit(main, ui, "thornwold_woods", "down from thornwold_ridge"):
		return
	_check(_npc("ottie") != null and _shown_model(main.get("region"), "collier_hut_cold_empty.glb") == 1,
			"Ottie home on his seat in the colliers' clearing")
	_check(_npc("wenna_coll") != null and _npc("abe") != null and _npc("tolly") != null, "the three home in the clearing")
	if not await _walk_the_bend(main, ui):
		return
	_npc("oda").interact()
	_check(_sail(ui, "saltmarrow"), "Oda runs the lane home to Saltmarrow")
	_finish_dialogue(ui, "oda (home to Saltmarrow)")
	if not await _arrived(main, ui, "saltmarrow", "Oda sailed the walk home"):
		return
	_sailings.append("thornwold_landing -> saltmarrow")
	var village: Region = main.get("region")
	_check(_shown_model(village, "brazier_raked.glb") == 1, "the Wrens' ash raked after a full confession")
	_npc("aldous").interact()
	_check(_choose(ui, "Wynn Sallow kept a coal."), "Aldous told Wynn Sallow is alive")
	_check(_choose(ui, "Wynn would want to know who it was."), "...asked for Wynn's sake")
	_check(_choose(ui, "Rest easy, Brother."), "...and left on his bench")
	_finish_dialogue(ui, "aldous (the east stair)")
	await get_tree().process_frame
	_check(world.quest_state("the_east_stair") == WorldState.QUEST_DONE and world.get_flag("saltmarrow_aldous_novice") == "lamp",
			"the east stair counted")
	_check(_shown_model(village, "brazier_laid.glb") == 1 and _shown_model(village, "brazier_raked.glb") == 0, "the brazier laid, not lit")
	print("Smoke: the Lamp named, Aldous counted the seventh ('%s')" % world.get_flag("saltmarrow_aldous_novice"))
	await _check_lanes_tab(main.get("journal_ui"))
	# Day 59: every lane sailed, the lane map takes the long passages light to light and back.
	_npc("oda").interact()
	_check(_sail(ui, "wrackholm"), "the lane map sails Saltmarrow to Wrackholm, three lanes in one")
	_finish_dialogue(ui, "oda (the long passage out)")
	if not await _arrived(main, ui, "wrackholm", "the long passage out"):
		return
	if not await _sail_the_taper(main, ui):
		return
	_npc("oda").interact()
	_check(_sail(ui, "saltmarrow"), "...and the long way home, four lanes in one")
	_finish_dialogue(ui, "oda (the long passage home)")
	if not await _arrived(main, ui, "saltmarrow", "the long passage home"):
		return
	_sailings.append("saltmarrow -> wrackholm -> kindleby -> saltmarrow")


## Day 62: with the Wrack lit, Oda tells of the Taper and sails it south-about to Kindleby: the arrival,
## Brother Tobin at the bell, the Provost and the rite (bowed), the Quiet House; Day 64: the ring held from the
## crown, the chapter's choice (the Boats' Lantern) burned in the Vigil Light. True if the walk is on
## Kindleby with Oda at the quay.
func _sail_the_taper(main: Node, ui: DialogueUI) -> bool:
	var world := GameState.world
	_npc("oda").interact()
	_check(_choose(ui, "Where does the lane go from here?"), "Oda asked where the lane runs on from the Wrack")
	_check(_sail(ui, "kindleby"), "...and sails the Taper")
	_finish_dialogue(ui, "oda (the Taper)")
	if not await _arrived(main, ui, "kindleby", "south-about to Kindleby"):
		return false
	_check(world.get_flag("kindleby_landed") == true and world.quest_stage("a_light_for_kindleby") == "the_candles",
			"landed: the candles, A Light for Kindleby begun")
	var isle: Region = main.get("region")
	_check(_shown_model(isle, "vigil_light.glb") == 1, "the Vigil Light stands dark on the crown")
	for id: String in ["tobin", "provost"]:
		_check(_npc(id) != null and _npc(id).find_child("CharacterRig", true, false) != null, "%s shows its rigged model" % id)
	_npc("tobin").interact()
	_check(_choose(ui, "What are all the candles for?"), "Tobin on the candles")
	_finish_dialogue(ui, "tobin")
	_npc("provost").interact()
	_check(_choose(ui, "What would it take to light the Vigil Light?"), "the Provost asked about the light")
	_check(_choose(ui, "I'll bow to the rite."), "...bowed to the rite")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "the provost (the rite)")
	_check(world.get_flag("kindleby_rite") == "bowed" and world.quest_stage("a_light_for_kindleby") == "the_chapter", "the chapter will sit")
	_object("quiet_house").interact()
	_finish_dialogue(ui, "the Quiet House")
	print("Smoke: Kindleby, the rite '%s'" % world.get_flag("kindleby_rite"))
	# Day 64: the ember holds the ring from the crown while the chapter sits; the chapter's choice burned.
	_npc("provost").interact()
	_check(_choose(ui, "My ember could hold the ring while the chapter sits."), "the ember offered for the ring")
	_check(_choose(ui, "Goodbye."), "...and she sends you up")
	_finish_dialogue(ui, "the provost (the ring)")
	_object("vigil_door").interact()
	_finish_dialogue(ui, "the vigil door (holding the ring)")
	_check(world.get_flag("kindleby_ring_held") == true and world.item_count("boats_lantern") == 1
			and world.quest_stage("a_light_for_kindleby") == "feed_the_light", "the chapter sat and chose; the Boats' Lantern in hand")
	_object("vigil_door").interact()
	_check(_choose(ui, "Set the Boats' Lantern in the cradle."), "the lantern to the cradle")
	_check(_choose(ui, "Burn Kindleby's night of the boats."), "...and burned")
	_finish_dialogue(ui, "the Vigil Light (the burning)")
	await get_tree().process_frame
	_check(world.get_flag("kindleby_beacon_burned") == "boats" and world.quest_state("a_light_for_kindleby") == WorldState.QUEST_DONE,
			"Kindleby's burning")
	_check(_shown_model(isle, "vigil_light.glb") == 0 and _shown_model(isle, "vigil_light_lit.glb") == 1, "the Vigil Light lit on the crown")
	print("Smoke: Kindleby lit ('%s')" % world.get_flag("kindleby_beacon_burned"))
	return true


## Day 53: the old Keepers' road north, walked from the ridge with the Ridge Light lit: meet Ottie at the
## Northing, ask the Lamp for a lantern lit off the Ridge Light, carry it back and hang it on the Northing.
## True if the walk is back on the ridge.
func _walk_the_old_road(main: Node, ui: DialogueUI) -> bool:
	var world := GameState.world
	if not await _take_exit(main, ui, "thornwold_old_road", "along the old road from the ridge"):
		return false
	_check(world.get_flag("thornwold_old_road_reached") == true, "the old road's arrival scene played")
	_npc("ottie").interact()
	_check(_choose(ui, "Goodbye."), "Ottie met at the Northing")
	_finish_dialogue(ui, "ottie (first meeting)")
	_check(world.quest_stage("the_northing") == "a_proper_light", "Ottie keeps a charcoal fire for the three")
	if not await _take_exit(main, ui, "thornwold_ridge", "back along the spine"):
		return false
	_npc("lamp").interact()
	_check(_choose(ui, "One of the four is at the Northing. Ottie Swale."), "the Lamp told of Ottie")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "the lamp (a lantern for Ottie)")
	_check(world.item_count("ridge_lantern") == 1, "the Lamp lit a lantern off the Ridge Light")
	if not await _take_exit(main, ui, "thornwold_old_road", "along the old road with the lantern"):
		return false
	_npc("ottie").interact()
	_check(_choose(ui, "This is for you. The Lamp lit it off the Ridge Light."), "the lantern offered to Ottie")
	_check(_choose(ui, "Hang it on the Northing, Ottie. Go home."), "...and hung on the Northing")
	_finish_dialogue(ui, "ottie (the Northing lit)")
	await get_tree().process_frame
	var road: Region = main.get("region")
	_check(world.get_flag("thornwold_northing") == "lit" and world.quest_state("the_northing") == WorldState.QUEST_DONE, "the Northing lit")
	_check(_shown_model(road, "cresset_lantern.glb") == 1 and _shown_model(road, "cresset_coals.glb") == 0, "the lantern on the hook, the charcoal out")
	_check(_npc("ottie") == null, "Ottie has gone home")
	print("Smoke: the Northing lit, Ottie home")
	if not await _walk_the_far_shore(main, ui):
		return false
	return await _take_exit(main, ui, "thornwold_ridge", "back along the spine to the Ridge Light")


## Day 55: down the Keepers' steps by the Northing's light to the far shore, where Wenna Coll waits on the
## boat-stage for the Spire's boat; tell her to come up, and climb back to the Northing. True if back on the road.
func _walk_the_far_shore(main: Node, ui: DialogueUI) -> bool:
	var world := GameState.world
	_object("keepers_steps").interact()
	_check(_choose(ui, "Go down the Keepers' steps."), "the steps go down with a light at the Northing")
	_finish_dialogue(ui, "the Keepers' steps (going down)")
	if not await _arrived(main, ui, "thornwold_far_shore", "down the Keepers' steps"):
		return false
	_check(world.get_flag("thornwold_far_shore_reached") == true, "the far shore's arrival scene played")
	_npc("wenna_coll").interact()
	_check(_choose(ui, "Come up. Somebody came down for you: me."), "Wenna told to come up")
	_finish_dialogue(ui, "wenna_coll (up)")
	await get_tree().process_frame
	_check(world.get_flag("thornwold_far_shore") == "up" and world.quest_state("the_far_shore") == WorldState.QUEST_DONE,
			"The Far Shore: the three came up")
	_check(_npc("wenna_coll") == null and _npc("abe") == null and _npc("tolly") == null, "the shore's empty")
	print("Smoke: the far shore, the three gone up")
	return await _take_exit(main, ui, "thornwold_old_road", "up the Keepers' steps to the Northing")


## Day 57: ask Wenna Coll to walk out with her, go down to the landing and back through the wall for first light,
## walk the old bend east with her to Coll's Hearth, hang her light on the bend's waymark, and walk the ruts back;
## then out along them once more to find her breaking out the clamp (Day 58). True if the walk ends at the landing.
func _walk_the_bend(main: Node, ui: DialogueUI) -> bool:
	var world := GameState.world
	_npc("wenna_coll").interact()
	_check(_choose(ui, "Can I walk out with you in the morning?"), "Wenna asked to walk out with her")
	_finish_dialogue(ui, "wenna_coll (asked)")
	_check(world.quest_stage("the_bend_in_the_road") == "first_light", "The Bend in the Road begun")
	if not await _take_exit(main, ui, "thornwold_landing", "down from thornwold_woods"):
		return false
	_object("thornwold_bramble_wall").interact()
	_check(_choose(ui, "Go through."), "back through the wall at first light")
	_finish_dialogue(ui, "the bramble wall (going through)")
	if not await _arrived(main, ui, "thornwold_woods", "through the wall to the woods"):
		return false
	_check(str(world.get_flag("thornwold_bend")) == "morning", "the first-light scene played")
	_npc("wenna_coll").interact()
	_check(_choose(ui, "Show me."), "Wenna shows the old ruts")
	_finish_dialogue(ui, "wenna_coll (the bend)")
	if not await _arrived(main, ui, "thornwold_colls_hearth", "along the bend with Wenna"):
		return false
	_check(world.get_flag("thornwold_colls_hearth_reached") == true, "Coll's Hearth's arrival scene played")
	_npc("wenna_coll").interact()
	_check(_choose(ui, "Hang it on the bend's waymark. Let the road be a road again."), "Wenna's light on the bend")
	_finish_dialogue(ui, "wenna_coll (the road)")
	await get_tree().process_frame
	var hearth: Region = main.get("region")
	_check(world.quest_state("the_bend_in_the_road") == WorldState.QUEST_DONE and _shown_model(hearth, "waymark_lit.glb") == 1,
			"the bend lit, the quest done")
	print("Smoke: the bend in the road, a road again")
	if not await _take_exit(main, ui, "thornwold_woods", "back along the ruts"):
		return false
	_check(_object("woods_old_bend") != null, "the old ruts east from the straight road")
	# Day 58: back along the bend, Wenna's up at her clamp with the rake, breaking it out.
	_object("woods_old_bend").interact()
	_check(_choose(ui, "Follow the ruts east to Coll's Hearth."), "back along the bend")
	_finish_dialogue(ui, "the old ruts")
	if not await _arrived(main, ui, "thornwold_colls_hearth", "along the lit bend"):
		return false
	_check(world.get_flag("thornwold_bend_breaking_out") == true
			and _shown_model(main.get("region"), "clamp_spent_open.glb") == 1, "Wenna breaking out her clamp")
	if not await _take_exit(main, ui, "thornwold_woods", "back along the ruts again"):
		return false
	return await _take_exit(main, ui, "thornwold_landing", "down from thornwold_woods")


## Waits for a travel to land and plays out any arrival scene; true if the walk is in `region_id`.
func _arrived(main: Node, ui: DialogueUI, region_id: String, what: String) -> bool:
	for i in 3:
		await get_tree().physics_frame
	var here := (main.get("region") as Region).region_id
	_check(here == region_id, "%s (in %s)" % [what, here])
	if here != region_id:
		return false
	_walked[here] = true
	if ui.is_open():
		_finish_dialogue(ui, "arrival in " + here)
		await get_tree().process_frame
	return true


## Walks through this region's exit to `target`.
func _take_exit(main: Node, ui: DialogueUI, target: String, what: String) -> bool:
	for node in get_tree().get_nodes_in_group("exits"):
		var exit := node as RegionExit
		if exit.target_region == target and not exit.is_queued_for_deletion():
			exit.interact()
			break
	return await _arrived(main, ui, target, what)


## Day 33: the first fen walk asks Corran to take you out and he sends you for his far trap; the
## second lifts it (a pickup at the end of the long walk), brings it back, and Corran poles the walk
## out to the Heron's legs (a `travel`, which ends the fen's walk). Walk the Foot — the skiff, the
## ladder, the big man at the fog's edge, who goes — let Corran pole back, and let Oda carry the walk
## back to Thornwold as the fen walk would have.
func _walk_the_heron(main: Node, ui: DialogueUI, trip: int) -> void:
	var mere: Region = main.get("region")
	_walked[mere.region_id] = true
	_check(GameState.world.get_flag("fen_punt_out") == true, "out at the Heron in Corran's punt")
	# Day 34: the keeper's skiff is her own prop, with a bare bow until the bell is hung back.
	# Day 35: the cold Heron is conditional too (the lit one waits for the burn).
	_check(mere.shown_conditional_props() == 4, "the cold Heron, the punt, the big man at the fog's edge and the bare-bowed skiff show (%d)" % mere.shown_conditional_props())
	_check(get_tree().get_nodes_in_group("npcs").any(func(n: Node) -> bool: return (n as NpcActor).npc_id == "corran"),
			"Corran waits on the Foot")
	_check(await _walk_region(main, ui, mere, trip), "Corran poles the walk back")
	_check(str(GameState.world.get_flag("fen_dunstan_glimpsed")) in ["called", "watched", "nameless"], "the big man was glimpsed")
	_check(str(GameState.world.get_flag("fen_skiff_bell")) in ["hung", "kept"], "the keeper's bell was hung or kept")
	var fen: Region = main.get("region")
	_check(fen.region_id == "glasswater_fen" and GameState.world.get_flag("fen_punt_out") == false, "back at Corran's landing")
	if fen.region_id != "glasswater_fen":
		return
	await _light_the_heron(main, ui)
	fen = main.get("region")
	if fen.region_id != "glasswater_fen":
		return
	await _sail_to_wrackholm(main, ui)
	fen = main.get("region")
	if fen.region_id != "glasswater_fen":
		return
	for node in get_tree().get_nodes_in_group("npcs"):
		if (node as NpcActor).npc_id == "oda" and not node.is_queued_for_deletion():
			(node as NpcActor).interact()
			_check(_sail(ui, "thornwold"), "Oda runs back to Thornwold from the fen")
			_finish_dialogue(ui, "oda (back to Thornwold)")
	for i in 3:
		await get_tree().physics_frame
	_check((main.get("region") as Region).region_id == "thornwold_landing", "Oda sailed the walk back to Thornwold")


## Day 35: the Heron Light, part two, live: tell Hesper about the trip (her little light on the ladder
## is the reason), have Corran pole the walk out again, climb with him holding the foot, take his
## knot-cord at the legs and burn it in the cradle; the lit Heron replaces the cold one in the
## region, and Corran poles back by its light (no cord to count).
func _light_the_heron(main: Node, ui: DialogueUI) -> void:
	var hesper := _npc("hesper")
	_check(hesper != null, "Hesper on the staithe after the trip out")
	if hesper == null:
		return
	hesper.interact()
	_check(_choose(ui, "I've been out to the Heron."), "Hesper asks about the trip out")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "hesper (the light on the ladder)")
	_check(GameState.world.quest_stage("a_light_for_glasswater") == "up_the_ladder", "a reason to climb")
	var corran := _npc("corran")
	if corran == null:
		_check(false, "Corran at his landing")
		return
	corran.interact()
	_check(_choose(ui, "Pole me out to the Heron again."), "Corran poles out again")
	_finish_dialogue(ui, "corran (out again)")
	for i in 3:
		await get_tree().physics_frame
	var mere: Region = main.get("region")
	_check(mere.region_id == "heron_mere", "out at the legs again")
	if mere.region_id != "heron_mere":
		return
	var ladder := _object("heron_ladder")
	ladder.interact()
	_check(_choose(ui, "Climb."), "Corran holds the foot on a dry day")
	_finish_dialogue(ui, "the climb")
	_check(GameState.world.quest_stage("a_light_for_glasswater") == "feed_the_heron", "the cradle wants something held")
	_npc("corran").interact()
	_check(_choose(ui, "The Heron wants something somebody here still holds."), "Corran asked for his channels")
	_check(_choose(ui, "Give it, Corran. For the light."), "...and gives his cord")
	_check(_choose(ui, "Not yet."), "...and goes on waiting")
	_finish_dialogue(ui, "corran (the cord)")
	# Day 36: the cord given, the Corran on the Foot is the one without it (swapped live, mid-talk).
	var bare := _npc("corran")
	_check(bare != null and str(bare.npc_data.get("model", "")).ends_with("corran_nocord.glb"), "Corran without his cord")
	ladder.interact()
	_check(_choose(ui, "Set Corran's knot-cord in the cradle."), "the cord set in the cradle")
	_check(_choose(ui, "Burn Corran's channels."), "...and burned")
	_finish_dialogue(ui, "the Heron's burning")
	for i in 3:
		await get_tree().process_frame
	_check(GameState.world.quest_state("a_light_for_glasswater") == WorldState.QUEST_DONE, "the Heron Light is lit")
	# Lit: the cold Heron and the big man gone; the lit Heron, its gold on the mere (Day 36), the
	# punt and the skiff show; with Mara's word on the post, her red cord round the sill gull (Day 39).
	var cord := 1 if GameState.world.get_flag("fen_dunstan_word", "") == "mara" else 0
	_check(mere.shown_conditional_props() == 4 + cord, "the lit Heron, its gold, the punt and the skiff show, the cord %d (%d)" % [cord, mere.shown_conditional_props()])
	_check(mere.find_children("*", "OmniLight3D", true, false).size() > 0, "the lit Heron lights the Foot")
	_npc("corran").interact()
	_check(_choose(ui, "Take me back."), "Corran poles back by the light")
	_finish_dialogue(ui, "corran (back by the light)")
	for i in 3:
		await get_tree().physics_frame
	_check((main.get("region") as Region).region_id == "glasswater_fen", "back at the landing, the Heron lit")
	await _find_dunstan(main, ui)


## Day 37: back on the fen the lantern lit at the fog's foot sits at the end of the long walk
## (arrival scene, For After); Dunstan by it says his name, hears of Mara, and stays.
func _find_dunstan(main: Node, ui: DialogueUI) -> void:
	for i in 3:
		await get_tree().process_frame
	_check(ui.is_open(), "the lantern at the end of the long walk is seen on arriving")
	_finish_dialogue(ui, "the lantern for after")
	_check(GameState.world.get_flag("fen_lantern_seen") == true, "...once")
	_check(GameState.world.quest_state("for_after") == WorldState.QUEST_ACTIVE, "For After begins")
	var dunstan := _npc("dunstan")
	_check(dunstan != null, "Dunstan sits at the end of the long walk")
	if dunstan == null:
		return
	_check(dunstan.prompt == "Talk to The big man", "a big man, not yet named (%s)" % dunstan.prompt)
	var fen: Region = main.get("region")
	var glowing := false
	for halo in fen.find_children("*", "LanternHalo", true, false):
		if (halo as Node3D).global_position.distance_to(dunstan.global_position) < 2.0:
			glowing = true
	_check(glowing, "his lantern glows at the end of the walk")
	dunstan.interact()
	_check(_choose(ui, "She's well. She keeps the harbor, and everyone fed."), "Dunstan asks after Mara")
	_check(_choose(ui, "What's the lantern for?"), "...and says what the lantern's for")
	_check(_choose(ui, "I'll leave you to it."), "...and stays by it")
	_finish_dialogue(ui, "dunstan")
	_check(GameState.world.get_flag("fen_dunstan_met") == true and GameState.world.quest_state("for_after") == WorldState.QUEST_DONE,
			"Dunstan found")
	_check(dunstan.prompt == "Talk to Dunstan Tollen", "named once he's said it (%s)" % dunstan.prompt)


## Day 40: with Dunstan found, Oda says where the lane runs on and sails it east-about to Wrackholm
## (nobody answers her horn; the arrival scene starts A Light for Wrackholm). Walk the island the way
## the passes do — the crew board first (the ember brings the names back), Wenna (the law, the Gannet,
## the names said into the horn), Jory (his brother's name, who called them in), Oda last, who sails
## the walk back to the fen.
func _sail_to_wrackholm(main: Node, ui: DialogueUI) -> void:
	var oda := _npc("oda")
	_check(oda != null, "Oda at the staithe with Dunstan found")
	if oda == null:
		return
	oda.interact()
	_check(_choose(ui, "Where does the lane go from here?"), "Oda says where the lane runs on")
	_check(_sail(ui, "wrackholm"), "...and, done here, sails it")
	_finish_dialogue(ui, "oda (east-about)")
	for i in 3:
		await get_tree().physics_frame
	var holm: Region = main.get("region")
	_check(holm.region_id == "wrackholm", "Oda sailed to Wrackholm")
	if holm.region_id != "wrackholm":
		return
	_sailings.append("glasswater_fen -> wrackholm")
	_walked[holm.region_id] = true
	_check(ui.is_open(), "the yard is seen dark on landing")
	_finish_dialogue(ui, "the Wrackholm arrival")
	await get_tree().process_frame
	_check(GameState.world.quest_stage("a_light_for_wrackholm") == "the_lashed_horn", "A Light for Wrackholm begins")
	_check(await _walk_region(main, ui, holm, 0), "Oda sails the walk back from Wrackholm")
	var world := GameState.world
	_check(world.get_flag("wrackholm_board_read") == true, "the ember brought the Gannet's names back")
	_check(world.quest_state("the_gannets_crew") == WorldState.QUEST_DONE, "Wenna said them into the horn")
	_check(str(world.get_flag("wrackholm_who_answered")) != "", "Jory was told who called them in")
	_check((main.get("region") as Region).region_id == "glasswater_fen", "back at the fen from Wrackholm")
	await _cross_the_teeth(main, ui)


## Day 42: sail east-about again and cross the Teeth the way a player would: Wenna on the white, the
## spring tide waited down at the spit's end, the ember to the first rock, the exit onto the Teeth,
## the crossing, the Wrack's lantern room, back before the flood (Jory, told it was Wenna's answer,
## has gone up to her), then the tide waited down once more (so the end-of-walk gate check finds the
## way open) and Oda back to the fen. The region walk above may already have done some of it.
func _cross_the_teeth(main: Node, ui: DialogueUI) -> void:
	var oda := _npc("oda")
	if oda == null:
		_check(false, "Oda at the staithe to sail east-about again")
		return
	oda.interact()
	_check(_sail(ui, "wrackholm"), "Oda sails east-about again")
	_finish_dialogue(ui, "oda (east-about again)")
	for i in 3:
		await get_tree().physics_frame
	if ui.is_open():
		_finish_dialogue(ui, "arrival event at Wrackholm")
		await get_tree().process_frame
	var world := GameState.world
	_npc("wenna").interact()
	_choose(ui, "What would it take to light the Wrack?")
	_choose(ui, "About the Teeth.")
	_check(_choose(ui, "Goodbye."), "Wenna lets you go")
	_finish_dialogue(ui, "wenna (the white)")
	_check(world.get_flag("wrackholm_teeth_marks_told") == true, "Wenna remembered the white")
	_object("teeth_spit").interact()
	_choose(ui, "Wait for the ebb.")
	_choose(ui, "Hold the ember to the rock.")
	_finish_dialogue(ui, "the spit's end")
	_check(world.get_flag("wrackholm_tide") == "low" and world.get_flag("wrackholm_teeth_marks") == true, "the tide down and the white back")
	await get_tree().process_frame
	var holm: Region = main.get("region")
	_check(holm.shown_conditional_props("rock") == 3, "the marked Teeth stand up off the spit (%d)" % holm.shown_conditional_props("rock"))
	for node in get_tree().get_nodes_in_group("exits"):
		var exit := node as RegionExit
		if exit.target_region == "wrack_teeth" and not exit.is_queued_for_deletion():
			exit.interact()
	for i in 3:
		await get_tree().physics_frame
	var teeth: Region = main.get("region")
	_check(teeth.region_id == "wrack_teeth", "out on the Teeth")
	if teeth.region_id != "wrack_teeth":
		return
	_walked[teeth.region_id] = true
	_check(ui.is_open(), "the crossing on the white")
	_finish_dialogue(ui, "the crossing")
	await get_tree().process_frame
	_object("wrack_door").interact()
	_finish_dialogue(ui, "the Wrack's lantern room")
	_check(world.quest_stage("a_light_for_wrackholm") == "feed_the_wrack", "the Wrack wants feeding")
	_object("teeth_way_back").interact()
	_check(_choose(ui, "Go back across before the flood."), "back across")
	_finish_dialogue(ui, "the way back")
	for i in 3:
		await get_tree().physics_frame
	_check((main.get("region") as Region).region_id == "wrackholm" and world.get_flag("wrackholm_tide") == "", "back up the hard on the flood")
	var up := str(world.get_flag("wrackholm_who_answered")) == "wenna"
	_check(ui.is_open() == up, "Jory goes up to Wenna only if told it was her answer")
	_finish_dialogue(ui, "jory goes up")
	await get_tree().process_frame
	_check(world.get_flag("wrackholm_jory_up") == up, "...and stays by her")
	var jory := _npc("jory")
	_check(jory != null and (jory.position.x > 5.0) == up, "Jory by the horn or at the copper")
	_npc("wenna").interact()
	_check(_choose(ui, "I've been out to the Wrack."), "Wenna hears of the lantern room")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "wenna (the Wrack)")
	await _burn_the_wrack(main, ui)
	if (main.get("region") as Region).region_id != "wrackholm":
		return
	_object("teeth_spit").interact()
	_check(_choose(ui, "Wait for the ebb."), "the tide waited down again, the white already back")
	_finish_dialogue(ui, "the spit's end again")
	_npc("oda").interact()
	_check(_sail(ui, "fen"), "Oda runs back to the fen")
	_finish_dialogue(ui, "oda (back to the fen)")
	for i in 3:
		await get_tree().physics_frame
	_check((main.get("region") as Region).region_id == "glasswater_fen", "back at the fen from the Teeth")
	if (main.get("region") as Region).region_id == "glasswater_fen":
		await _walk_dunstan_back(main, ui)


## Day 51: back on the fen with the Wrack lit, Dunstan's lantern has come halfway in. Walk ahead of
## him with the ember (a `travel` to the staithe), then he asks Hesper for his name and stays to turn
## the long walk's boards (the walk keeps Saltmarrow as it was for the name carried home after).
func _walk_dunstan_back(main: Node, ui: DialogueUI) -> void:
	_check(ui.is_open(), "the light seen halfway in on landing")
	_finish_dialogue(ui, "the fen arrival (the walk back)")
	await get_tree().process_frame
	_check(GameState.world.quest_stage("the_walk_back") == "out_on_the_walk", "The Walk Back begins")
	var dunstan := _npc("dunstan")
	_check(dunstan != null, "Dunstan stands on the long walk")
	if dunstan == null:
		return
	dunstan.interact()
	_check(_choose(ui, "Walk ahead of him with the ember."), "the player walks ahead with the ember")
	_finish_dialogue(ui, "dunstan (the walk in)")
	for i in 3:
		await get_tree().physics_frame
	_check((main.get("region") as Region).region_id == "glasswater_fen", "walked in to the staithe")
	_check(GameState.world.get_flag("fen_dunstan_walk") == "in", "Dunstan at the staithe's foot")
	dunstan = _npc("dunstan")
	if dunstan == null:
		_check(false, "Dunstan by Hesper")
		return
	dunstan.interact()
	_check(_choose(ui, "Stay a while. Till you're sure it's done."), "his name given back, he's asked to stay")
	_finish_dialogue(ui, "dunstan (his name)")
	await get_tree().process_frame
	_check(GameState.world.get_flag("fen_dunstan_walk") == "stayed", "he stays to turn the boards")
	_check(GameState.world.quest_state("the_walk_back") == WorldState.QUEST_DONE, "The Walk Back done")
	_check(_npc("dunstan") != null, "Dunstan at the head of the long walk")


## Day 43: the Wrack's burning, live: Wenna gives her answer (with Jory, if he came up, his pot too),
## the tide waited down and the Teeth crossed again, the answer burned in the cradle (the lit Wrack
## replaces the dark one, and lights the reef), back on the flood; Wenna unlashes the horn and it's
## sounded (the open horn shows), the Book opened, and the friend-of-the-lanes oath taken if offered.
func _burn_the_wrack(main: Node, ui: DialogueUI) -> void:
	var world := GameState.world
	_npc("wenna").interact()
	_check(_choose(ui, "The Wrack wants something somebody here holds."), "Wenna asked what Wrackholm holds")
	if not world.get_flag("wrackholm_jory_up") == true:
		_check(_choose(ui, "Give me your answer, Wenna."), "...and gives her answer")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "wenna (her answer)")
	_check(world.item_count("wennas_answer") == 1, "Wenna's answer in the satchel")
	_object("teeth_spit").interact()
	_check(_choose(ui, "Wait for the ebb."), "the tide waited down for the burning")
	_finish_dialogue(ui, "the spit's end (the burning)")
	await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("exits"):
		var exit := node as RegionExit
		if exit.target_region == "wrack_teeth" and not exit.is_queued_for_deletion():
			exit.interact()
	for i in 3:
		await get_tree().physics_frame
	var teeth: Region = main.get("region")
	_check(teeth.region_id == "wrack_teeth", "out on the Teeth again")
	if teeth.region_id != "wrack_teeth":
		return
	_check(not ui.is_open(), "the crossing scene played only the once")
	_object("wrack_door").interact()
	_check(_choose(ui, "Set Wenna's answer in the cradle."), "her answer set in the cradle")
	_check(_choose(ui, "Burn Wenna's answer."), "...and burned")
	_finish_dialogue(ui, "the Wrack's burning")
	for i in 3:
		await get_tree().process_frame
	_check(world.quest_state("a_light_for_wrackholm") == WorldState.QUEST_DONE and world.get_flag("wrackholm_beacon_burned") == "answer",
			"the Wrack Light is lit")
	_check(_shown_model(teeth, "wrack_light_lit.glb") == 1 and _shown_model(teeth, "wrack_light.glb") == 0, "the lit Wrack replaces the dark one")
	_check(teeth.find_children("*", "OmniLight3D", true, false).size() > 0, "...and lights the reef")
	_object("teeth_way_back").interact()
	_check(_choose(ui, "Go back across before the flood."), "back across by the Wrack's light")
	_finish_dialogue(ui, "the way back (lit)")
	for i in 3:
		await get_tree().physics_frame
	var holm: Region = main.get("region")
	_check(holm.region_id == "wrackholm", "back on the hard, the Wrack lit")
	if holm.region_id != "wrackholm":
		return
	if ui.is_open():
		_finish_dialogue(ui, "arrival event (lit)")
	_npc("wenna").interact()
	_check(_choose(ui, "The Wrack's lit. Answer it."), "Wenna unlashes the horn")
	_check(_choose(ui, "Show me the Book."), "...opens the Book")
	if world.get_flag("wrackholm_wenna_offer") == true:
		_check(_choose(ui, "Swear me a friend of the lanes."), "...offers the oath")
		_check(_choose(ui, "Swear it."), "...sworn")
	_check(_choose(ui, "Goodbye."), "...and lets you go")
	_finish_dialogue(ui, "wenna (the horn, the Book)")
	await get_tree().process_frame
	_check(world.get_flag("wrackholm_horn_sounded") == true and world.get_flag("wrackholm_book_opened") == true, "the horn sounded, the Book opened")
	_check(_shown_model(holm, "answering_horn_open.glb") == 1 and _shown_model(holm, "answering_horn.glb") == 0, "the horn stands open")
	_check(_shown_model(holm, "wrack_light_lit.glb") == 1, "the Wrack burns across the Teeth from the hard")
	print("Smoke: Wrackholm burned %s, horn sounded, sworn '%s'" % [world.get_flag("wrackholm_beacon_burned"), world.get_flag("wrackholm_sworn")])


## How many of `region`'s conditional props of the model file `file` are shown now.
func _shown_model(region: Region, file: String) -> int:
	var n := 0
	for entry: Dictionary in region._conditional:
		if entry["kind"] == "prop" and str(entry["data"].get("model", "")).get_file() == file and is_instance_valid(entry["node"]):
			n += 1
	return n


func _npc(id: String) -> NpcActor:
	for node in get_tree().get_nodes_in_group("npcs"):
		if (node as NpcActor).npc_id == id and not node.is_queued_for_deletion():
			return node
	return null


func _object(id: String) -> Inspectable:
	for node in get_tree().get_nodes_in_group("inspectables"):
		if (node as Inspectable).object_id == id and not node.is_queued_for_deletion():
			return node
	return null


## Day 31: the Unmoored by the pools turn their faces from a bare ember, live (the rig reads the
## world and finds the player itself). Cupped, then bare for a moment to see them turn, then the
## walk's own answer back.
func _check_unmoored_look_away(region: Region) -> void:
	var rig: CharacterRig = null
	var spot := Vector3.ZERO
	var water := float(region.data.get("water_level", -INF))
	for node in region.get_children():
		var found := node.get_node_or_null("CharacterRig") as CharacterRig
		if found == null or found.avert_if == null or rig != null:
			continue
		# Somewhere in front of them or beside them on dry ground (most of them face a pool).
		for offset: Vector3 in [Vector3(0.8, 0, 2.5), Vector3(2.5, 0, 0.8), Vector3(-2.5, 0, 0.8)]:
			var at := (node as Node3D).global_transform * offset
			if region.ground_y(at.x, at.z) > water + 0.1:
				rig = found
				spot = at
				break
	_check(rig != null, "an Unmoored figure in the fen that would look away")
	if rig == null:
		return
	var player: Player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	var came_in := player.global_position
	player.place_at(Vector3(spot.x, region.ground_y(spot.x, spot.z) + 0.2, spot.z))
	var answer: Variant = GameState.world.get_flag("fen_ember")
	GameState.world.flags["fen_ember"] = "cupped"
	await get_tree().create_timer(1.2).timeout
	_check(rig.avert_amount() == 0.0, "with the ember cupped the Unmoored don't turn away (%.2f)" % rig.avert_amount())
	GameState.world.flags["fen_ember"] = "bare"
	await get_tree().create_timer(1.2).timeout
	_check(rig.avert_amount() > 0.5, "with the ember bare they turn their faces away (%.2f)" % rig.avert_amount())
	GameState.world.flags["fen_ember"] = answer
	# Back where the walk came in, and out of Stillhithe's thin Greying long enough for the
	# screen's grey to ease off (later checks read the fog exactly).
	player.place_at(came_in)
	await get_tree().create_timer(1.5).timeout


## Advances an open dialogue to its next menu and picks the option reading `text`.
## Opens Oda's lane map and sails for `port` from it (the map showing that port first).
func _sail(ui: DialogueUI, port: String) -> bool:
	if not _choose(ui, "Where can you take me?") or ui.current_event.get("type") != "lane_map":
		return false
	if not ui.lane_map.visible or not ui.lane_map.port_ids().has(port):
		return false
	ui.lane_map.press_port(port)
	return ui.current_event.get("type") != "lane_map"


func _choose(ui: DialogueUI, text: String) -> bool:
	var steps := 0
	while ui.is_open() and steps < MAX_DIALOGUE_STEPS:
		if ui.current_event.get("type") == "choices":
			var options: Array = ui.current_event["options"]
			for i in options.size():
				if str((options[i] as Dictionary).get("text", "")) == text:
					ui.select(i)
					return true
			return false
		ui.advance()
		steps += 1
	return false


## Talks to every NPC, examines every object and takes every pickup in `region`. Returns
## true if a dialogue moved the player elsewhere (Oda sailed, the bramble wall let them
## through), which ends this region's walk: its nodes are gone.
func _walk_region(main: Node, ui: DialogueUI, region: Region, pass_index: int) -> bool:
	var region_id := region.region_id
	# Whoever and whatever can move the player on (Oda's ferry, the bramble wall) comes last,
	# after the pickups, so the rest of the region gets its turn first.
	var stay: Array[Node] = []
	var movers: Array[Node] = []
	# Objects before people among the movers: the ferry (Oda) is the very last thing.
	for node in get_tree().get_nodes_in_group("inspectables") + get_tree().get_nodes_in_group("npcs"):
		var dialogue := str((node as NpcActor).npc_data.get("dialogue", "")) if node is NpcActor else (node as Inspectable).dialogue_id
		(movers if _can_travel(dialogue) else stay).append(node)
	for node in stay:
		await _visit(main, ui, node, pass_index)
	for node in get_tree().get_nodes_in_group("pickups"):
		if not node.is_queued_for_deletion():
			(node as Pickup).interact()
	await get_tree().process_frame
	for node in movers:
		await _visit(main, ui, node, pass_index)
		if main.get("region") != region:
			# Oda sailed or the bramble wall let the player through (a `travel` effect):
			# this region's nodes are gone.
			_sailings.append("%s -> %s" % [region_id, (main.get("region") as Region).region_id])
			if ui.is_open():
				_finish_dialogue(ui, "arrival event after travelling")
				await get_tree().process_frame
			return true
	return false


## Talks to an NPC or examines an object, walking its dialogue's menus to the end.
func _visit(main: Node, ui: DialogueUI, node: Node, pass_index: int) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is Inspectable:
		var object := node as Inspectable
		object.interact()
		_check(ui.is_open(), "dialogue opens for object " + object.object_id)
		_finish_dialogue(ui, object.object_id)
		await get_tree().process_frame
		return
	var npc := node as NpcActor
	if pass_index == 0 and npc.npc_data.has("model"):
		_check(npc.find_child("CharacterRig", true, false) != null, "npc %s shows its rigged model" % npc.npc_id)
	npc.interact()
	_check(ui.is_open(), "dialogue opens for " + npc.npc_id)
	if pass_index == 0 and npc.npc_id == "mara":
		# Mara looks out over the harbor; talking, she turns to the player (west of her).
		for i in 30:
			await get_tree().process_frame
		_check(npc.body_yaw() < -0.5, "mara turns to face the player (yaw %.2f)" % npc.body_yaw())
		_check(not (main.get("hud") as Hud).is_key_hint_shown(), "key hint hides during dialogue")
	_finish_dialogue(ui, npc.npc_id)
	await get_tree().process_frame
	await _close_act_end_card(main)


## Checks every gated exit in every region: locked exits refuse travel, open ones allow it.
func _check_gates(main: Node, expect_open: bool) -> void:
	# Come back to where the walk was afterwards (the passes start from here; Day 42: Wrackholm's
	# gate to the Teeth sorts after Saltmarrow's, so the walk would otherwise begin on Wrackholm).
	var home := (main.get("region") as Region).region_id
	for region_id: String in Content.db.regions:
		for exit_data: Dictionary in Content.db.get_region(region_id).get("exits", []):
			if not exit_data.has("requires"):
				continue
			GameState.travel(region_id)
			for i in 3:
				await get_tree().physics_frame
			var exit: RegionExit = null
			for node in get_tree().get_nodes_in_group("exits"):
				var candidate := node as RegionExit
				if not candidate.is_queued_for_deletion() and candidate.target_region == str(exit_data["to"]):
					exit = candidate
			_check(exit != null, "gated exit %s -> %s exists" % [region_id, exit_data["to"]])
			if exit == null:
				continue
			var target := exit.target_region
			_check(exit.is_locked() != expect_open, "exit %s -> %s is %s" % [region_id, target, "open" if expect_open else "locked"])
			exit.interact()
			for i in 3:
				await get_tree().physics_frame
			var now: Region = main.get("region")
			var arrived := now != null and now.region_id == target
			_check(arrived == expect_open, "exit %s -> %s %s travel" % [region_id, target, "allows" if expect_open else "refuses"])
	GameState.travel(home)
	for i in 3:
		await get_tree().physics_frame


## Sculpted ground: the player lands on it at every region's spawn, NPCs stand on it, the
## Gull's Head ramp can be walked up with real input and physics, the shore wall stops
## the player wading out to sea, and the Saltmarrow dock can be walked out onto.
func _check_ground(main: Node) -> void:
	var player: Player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	for region_id: String in Content.db.regions:
		GameState.travel(region_id)
		for i in 30:
			await get_tree().physics_frame
		var region: Region = main.get("region")
		if region.field == null:
			continue
		var p := player.global_position
		_check(player.is_on_floor() and absf(p.y - region.ground_y(p.x, p.z)) < 0.25, "player stands on the ground at %s spawn" % region_id)
		for node in get_tree().get_nodes_in_group("npcs"):
			var npc := node as NpcActor
			_check(absf(npc.position.y - region.ground_y(npc.position.x, npc.position.z)) < 0.01, "npc %s stands on the ground" % npc.npc_id)
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	var camera_yaw: Node3D = player.get("_camera_yaw")
	camera_yaw.rotation.y = 0.0  # move_forward = -Z: from the lofts up the ramp to the beacon
	player.place_at(Vector3(0, region.ground_y(0, 0) + 0.2, 0))
	var audio: AudioDirector = main.get("audio")
	audio.history.clear()
	await _hold("move_forward", 150)
	_check(audio.history.any(func(id: String) -> bool: return id.begins_with("step_")), "walking plays footsteps (%s)" % ", ".join(PackedStringArray(audio.history)))
	var top := player.global_position
	print("Smoke: ramp walk reached ", top)
	_check(top.z < -8.0 and top.y > 2.3, "player walks up the Gull's Head ramp (reached %s)" % top)
	player.place_at(Vector3(0, region.ground_y(0, 15) + 0.2, 15))
	await _hold("move_back", 120)  # +Z: straight out to sea
	var shore := player.global_position
	print("Smoke: sea walk reached ", shore)
	_check(shore.y > region.ground_y(0, 15) - 0.6 and shore.z < 22.0, "shore wall stops the player wading out (reached %s)" % shore)
	# The Saltmarrow dock is a pier: walkable out over the harbor, walled at its sides.
	GameState.travel("saltmarrow")
	for i in 3:
		await get_tree().physics_frame
	region = main.get("region")
	player.place_at(Vector3(6, region.ground_y(6, 8) + 0.2, 8))
	audio.history.clear()
	await _hold("move_back", 150)  # +Z: down the walkway and out along the dock
	_check(audio.history.has("step_boards"), "footsteps on the dock sound as boards (%s)" % ", ".join(PackedStringArray(audio.history)))
	var dock := player.global_position
	print("Smoke: dock walk reached ", dock)
	_check(dock.z > 16.5 and absf(dock.y - region.ground_y(dock.x, dock.z)) < 0.2, "player walks out along the Saltmarrow dock (reached %s)" % dock)
	await _hold("move_right", 90)  # +X: off the side of the dock
	var side := player.global_position
	print("Smoke: dock side walk reached ", side)
	_check(side.x < 7.6 and side.y > 0.0, "the dock's sides are walled (reached %s)" % side)
	camera_yaw.rotation.y = 0.0


## The Greying before the burn: walking up into the Gull's Head fog drains the ember and
## shows the meter; when it runs out the player is turned back to clear ground, refilled.
func _check_greying(main: Node) -> void:
	var player: Player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	var walker: GreyingWalker = main.get("greying")
	var hud: Hud = main.get("hud")
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_greying() > 0, "Gull's Head shows Greying fog before the burn")
	var camera_yaw: Node3D = player.get("_camera_yaw")
	camera_yaw.rotation.y = 0.0
	player.place_at(Vector3(0, region.ground_y(0, 6) + 0.2, 6))
	for i in 10:
		await get_tree().physics_frame
	walker.meter.refill()
	await _hold("move_forward", 240)
	print("Smoke: walked into the Greying to ", player.global_position, " depth ", walker.depth, " ember ", walker.meter.ember)
	_check(walker.depth > 0.5, "the headland lies deep in the Greying (depth %s)" % walker.depth)
	_check(walker.meter.ember < 0.95, "the Greying drains the ember (%s)" % walker.meter.ember)
	_check(hud.is_meter_shown(), "ember meter shows in the Greying")
	var audio: AudioDirector = main.get("audio")
	_check(audio.ambience_cutoff() < 4000.0 and audio.is_heart_playing(), "the Greying muffles the ambience (%d Hz) and the ember's heart beats" % audio.ambience_cutoff())
	audio.history.clear()
	walker.meter.drain_scale = 60.0
	var guard := 0
	while not walker.turning_back and guard < 300:
		guard += 1
		await get_tree().physics_frame
	_check(walker.turning_back and GameState.input_locked, "an empty ember turns the player back")
	await walker.turned_back
	_check(audio.history.has("turn_back"), "turning back has its sound")
	walker.meter.drain_scale = 1.0
	for i in 5:
		await get_tree().physics_frame
	var p := player.global_position
	print("Smoke: turned back to ", p)
	_check(region.greying_depth(p.x, p.z) < Greying.CLEAR_DEPTH and p.z > 3.0, "turned back to clear ground (%s)" % p)
	_check(walker.meter.ember > 0.99 and not GameState.input_locked, "ember refilled and input returned")


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
	Input.action_release(action)
	for i in 10:
		await get_tree().physics_frame


## By the end of pass two the menu walk has fed the Gull's Beacon: check the quest, the
## burn flag, the lantern-room light and that the fog thinned.
func _check_beacon_lit(main: Node) -> void:
	var world := GameState.world
	_check(world.quest_state("a_light_for_saltmarrow") == WorldState.QUEST_DONE, "the Gull's Beacon is relit")
	_check(str(world.get_flag("saltmarrow_beacon_burned")) in ["pebble", "knot", "gull"], "a Remnant was burned")
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_conditional_props("beacon_light") == 1, "beacon light shows once lit")
	_check(region.greying_depth(0, -13) < Greying.CLEAR_DEPTH and region.shown_greying() > 0, "the Greying leans back off the headland, pockets remain")
	var base := float((region.data.get("fog", {}) as Dictionary).get("density", 0.0))
	var target: float = main.call("target_fog_density")
	_check(target < base, "fog override thins Gull's Head")
	var atmosphere: Atmosphere = main.get("atmosphere")
	_check(is_equal_approx(atmosphere.environment.fog_density, target), "fog applied on region load")
	var light := RegionMood.light(region.data, world)
	_check(is_equal_approx(atmosphere.sun.light_energy, float(light["sun_energy"])), "region light applied on region load")
	var audio: AudioDirector = main.get("audio")
	_check(audio.ambience_targets().has("gulls") and float(audio.ambience_targets().get("wind_high", 1.0)) < 1.0, "the gulls come back to the lit headland and the wind drops")
	var fire: SoundEmitter = null
	for node in region.find_children("Sound", "SoundEmitter", true, false):
		fire = node as SoundEmitter
	_check(fire != null and fire.sound_id == "fire", "the lit beacon's fire has its sound")


## Opens both journal tabs via the real input actions and checks they mirror world state.
func _check_journal(journal: JournalUI) -> void:
	# Parsed input is flushed at the start of the next frame; resuming from a physics
	# frame can mean that is two process frames away, so always wait two.
	_press("journal")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.is_open() and journal.tab == JournalUI.Tab.JOURNAL, "J opens the journal")
	_check(GameState.input_locked, "journal locks player input")
	var quests := JournalModel.quest_entries(Content.db, GameState.world)
	_check(journal.entry_count() == quests.size() and quests.size() > 0, "journal lists started quests")
	_press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.is_open() and journal.tab == JournalUI.Tab.SATCHEL, "I switches to the satchel")
	var items := JournalModel.item_entries(Content.db, GameState.world)
	_check(journal.entry_count() == items.size(), "satchel lists carried items")
	if not items.is_empty():
		_check(journal.detail_text().contains(str(items[0]["description"])), "satchel shows item description")
	_press("lanes")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.tab == JournalUI.Tab.LANES and journal.chart_shown() == Lanes.chart_known(Content.db, GameState.world),
			"L shows the Lanes tab (the chart once the first crossing is made)")
	_press("tab_right")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.tab == JournalUI.Tab.JOURNAL, "the next-tab button wraps round to the journal")
	_press("tab_left")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.tab == JournalUI.Tab.LANES, "and back")
	_press("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not journal.is_open() and not GameState.input_locked, "Esc closes the journal and unlocks input")


## Day 65: after the crossings, L shows Oda's chart in the journal, read-only — every known
## port on it, pressing one tells of it and sails nowhere; Esc closes as on the other tabs.
func _check_lanes_tab(journal: JournalUI) -> void:
	var world := GameState.world
	var at := str(world.get_flag(Lanes.FLAG, ""))
	_press("lanes")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.chart_shown(), "L opens the chart in the journal after the crossing")
	var chart := journal.lane_chart()
	var ports := chart.port_ids()
	ports.sort()
	var known: Array = Lanes.known_ports(Content.db, world)
	known.sort()
	_check(ports == known, "the journal's chart shows every known port (%s)" % [ports])
	chart.press_port("thornwold")
	_check(journal.is_open() and str(world.get_flag(Lanes.FLAG, "")) == at and chart.info_text().contains("Oda can sail you there"),
			"pressing a port on the journal's chart tells of it and sails nowhere")
	_press("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not journal.is_open() and not GameState.input_locked, "Esc closes the chart")


## Esc pauses; saving into a slot (overwrite asks twice) and loading it back through the
## menu restores the state; Esc backs out of a page, then resumes.
func _check_pause_menu(main: Node) -> void:
	var menu: PauseMenu = main.get("pause_menu")
	var hud: Hud = main.get("hud")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.is_open() and get_tree().paused and GameState.input_locked, "Esc opens the pause menu and pauses")
	_check(not hud.is_key_hint_shown(), "key hint hides under the pause menu")
	_check(menu.press("Save game") and menu.page == MenuScreen.Page.SAVE, "pause menu opens the save page")
	_check(menu.press("Slot 1") and SaveSystem.has_save("slot1"), "saving into slot 1")
	var saved := JSON.stringify(GameState.world.to_dict())
	_check(menu.press("Slot 1") and menu.press("Slot 1"), "overwriting slot 1 takes a second press")
	_check(menu.buttons()[0].text.contains(str(main.get("region").data.get("name"))), "slot 1 names the region")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.is_open() and menu.page == MenuScreen.Page.MAIN, "Esc backs out to the main page")
	GameState.world.set_flag("intro_seen", false)
	_check(menu.press("Load game") and menu.page == MenuScreen.Page.LOAD, "pause menu opens the load page")
	_check(menu.buttons()[0].disabled, "empty quicksave can't be loaded")
	_check(menu.press("Slot 1"), "loading slot 1")
	_check(not menu.is_open() and not get_tree().paused, "loading closes the menu and unpauses")
	for i in 3:
		await get_tree().physics_frame
	_check(JSON.stringify(GameState.world.to_dict()) == saved, "slot 1 restores the saved state")
	_check(not GameState.input_locked, "input unlocked after loading from the menu")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not menu.is_open() and not get_tree().paused and not GameState.input_locked, "Esc resumes")
	DirAccess.remove_absolute(SaveSystem.slot_path("slot1"))


## Settings through the menu: a volume slider moves its bus; Controls rebinds the journal to
## K with a real key press (the HUD hint follows, K opens the journal's action); Esc backs
## out page by page and leaving saves the file. Back to defaults afterwards.
func _check_settings(main: Node) -> void:
	var menu: PauseMenu = main.get("pause_menu")
	var hud: Hud = main.get("hud")
	var settings := GameSettings.current()
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.press("Settings") and menu.page == MenuScreen.Page.SETTINGS, "pause menu opens Settings")
	var master := menu.slider("Master volume")
	_check(master != null, "Settings has a master volume slider")
	if master:
		master.value = 50.0
		_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "the master slider sets the Master bus")
	_check(menu.press("Controls") and menu.page == MenuScreen.Page.CONTROLS, "Settings opens Controls")
	_check(menu.press("Journal"), "picking the journal to rebind")
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(settings.key_for("journal") == KEY_K and menu.capturing.is_empty(), "a key press rebinds the journal to K")
	_check(InputMap.event_is_action(key, "journal"), "K is the journal key now")
	_check(not InputMap.event_is_action(key, "move_forward") and menu.page == MenuScreen.Page.CONTROLS, "and nothing else; still on Controls")
	_check((hud.get("_keys") as Label).text.begins_with("[K] Journal"), "the HUD hint follows the binding")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.page == MenuScreen.Page.SETTINGS, "Esc backs out of Controls to Settings")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.page == MenuScreen.Page.MAIN and FileAccess.file_exists(settings.path), "leaving Settings saves them")
	menu.close()
	await get_tree().process_frame
	settings.reset()
	_check(settings.key_for("journal") == KEY_J and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(GameSettings.DEFAULT_VOLUME)), "reset to defaults")
	DirAccess.remove_absolute(settings.path)


## Debug builds: the pause menu's Chapter select jumps to a story checkpoint (Thornwold
## Landing): the menu closes, the world resets to that point and its region loads.
func _check_chapter_select(main: Node) -> void:
	var menu: PauseMenu = main.get("pause_menu")
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.press("Chapter select") and menu.page == MenuScreen.Page.CHAPTERS, "pause menu opens Chapter select")
	_check(menu.buttons().size() == Scenarios.all().size() + 1, "every checkpoint is listed")
	_check(menu.press("Thornwold Landing"), "jumping to the Thornwold checkpoint")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	var world := GameState.world
	_check(region != null and region.region_id == "thornwold_landing", "the checkpoint's region loads")
	_check(world.get_flag("lanes_ferry_at") == "thornwold" and world.quest_state("a_light_for_thornwold") == WorldState.QUEST_INACTIVE, "the world is reset to the checkpoint")
	_check(not menu.is_open() and not get_tree().paused and not GameState.input_locked, "jumping closes the menu")


## The game opens on the title screen over the start region (the HUD hidden, input held,
## the camera drifting, no waking yet); New game closes it and the waking plays.
func _start_from_title(main: Node) -> void:
	var title: TitleScreen = main.get("title_screen")
	var hud: Hud = main.get("hud")
	var ui: DialogueUI = main.get("dialogue_ui")
	var player: Player = main.get("player")
	_check(title.is_open() and GameState.input_locked and not hud.visible, "the game opens on the title screen")
	_check(not ui.is_open(), "the waking waits for New game")
	_check((main.get("region") as Region).region_id == str(Content.db.game["start_region"]), "the start region behind the title")
	_check(title.heading().begins_with(str(Content.db.game["title"])), "the title screen shows the game's name")
	var yaw := player.camera_yaw()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_equal_approx(player.camera_yaw(), yaw), "the camera drifts behind the title")
	# The page was built before this run moved the saves aside; rebuild it on the scratch dir.
	title._show_page(MenuScreen.Page.MAIN)
	_check(title.buttons()[0].text == "New game" and title.buttons()[1].disabled, "no saves: New game first, Load greyed")
	_check(title.press("New game"), "pressing New game")
	for i in 3:
		await get_tree().physics_frame
	_check(not title.is_open() and hud.visible, "New game closes the title")


## Pause menu → Return to title (twice: unsaved progress) resets the world behind the title;
## Continue then loads the latest save (a slot saved after the quicksave).
func _check_return_to_title(main: Node) -> void:
	var menu: PauseMenu = main.get("pause_menu")
	var title: TitleScreen = main.get("title_screen")
	_check(SaveSystem.save_game("slot2"), "saving to slot 2 before returning to the title")
	var saved := JSON.stringify(GameState.world.to_dict())
	var saved_region := (main.get("region") as Region).region_id
	_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(menu.press("Return to title") and menu.is_open(), "Return to title asks for a second press")
	_check(menu.press("Return to title"), "returning to the title")
	for i in 3:
		await get_tree().physics_frame
	_check(title.is_open() and not menu.is_open() and not get_tree().paused and GameState.input_locked, "the title screen is up (and holds input)")
	_check((main.get("region") as Region).region_id == str(Content.db.game["start_region"]) and not GameState.world.get_flag("intro_seen"), "the world is back at the start")
	_check(title.buttons()[0].text.begins_with("Continue") and title.buttons()[0].text.contains("Slot 2"), "Continue offers the latest save")
	_check(title.press("Continue"), "pressing Continue")
	for i in 3:
		await get_tree().physics_frame
	_check(not title.is_open() and not GameState.input_locked, "Continue closes the title")
	_check((main.get("region") as Region).region_id == saved_region and JSON.stringify(GameState.world.to_dict()) == saved, "Continue restores the save")
	DirAccess.remove_absolute(SaveSystem.slot_path("slot2"))


## The end-of-act card shows (deferred) after the dialogue that ends an act: record it and
## close it the way a player would.
func _close_act_end_card(main: Node) -> void:
	await get_tree().process_frame
	var card: ActEndCard = main.get("act_end_card")
	if card.is_open():
		_check(GameState.input_locked, "the act-end card holds input")
		_act_end_recap = card.recap_text()
		card.close()
		await get_tree().process_frame


## Act I's close: Aldous has confessed (either way), Mara has hung the ferry signal lantern,
## the horn sounded, the Slow Mercy is at the Saltmarrow dock with Oda and Pell on it, and
## taking passage ended the act with a recap of the player's choices.
func _check_act_one_close(main: Node) -> void:
	var world := GameState.world
	_check(str(world.get_flag("saltmarrow_aldous_confessed")) in ["full", "grudging"], "Aldous confessed")
	_check(world.get_flag("saltmarrow_ferry_arrived") == true, "the ferry's horn sounded")
	_check(world.get_flag("saltmarrow_ferry_passage") == true, "Oda gave passage")
	_check(world.quest_stage("across_the_grey") == "evening_tide", "ferry quest waits for the evening tide")
	_check(str(world.get_flag("saltmarrow_pell_crossing")) in ["aboard", "stayed", "let_down"], "Pell's crossing settled")
	_check(not _act_end_recap.is_empty(), "the Act I end card showed a recap")
	_check(_act_end_recap.contains("Gull's Beacon burns"), "the recap names the burn")
	GameState.travel("saltmarrow")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_conditional_props("signal_lantern") == 1, "ferry signal lantern shows at the dock")
	var names: Array = get_tree().get_nodes_in_group("npcs").map(func(n: Node) -> String: return (n as NpcActor).npc_id)
	var ferry_home := str(world.get_flag("lanes_ferry_at")) != "thornwold"
	_check(names.has("oda") == ferry_home, "Oda on the Saltmarrow dock exactly while the ferry is there")
	_check(names.has("pell") != (world.get_flag("thornwold_pell_landed") == true), "Pell on the Saltmarrow dock unless they crossed")
	# Saltmarrow after the burn: nets are out drying, and the dressing matches the burn.
	var burned := str(world.get_flag("saltmarrow_beacon_burned"))
	_check(region.shown_conditional_props("net_frame") == (2 if burned == "knot" else 0), "net frames only after the knot burn")
	_check(region.shown_conditional_props("net_rack") == (0 if burned == "knot" else 2), "whole nets drying unless the knot burned")
	_check(region.shown_conditional_props("cups") == (1 if burned == "gull" else 0), "two cups only after the gull burn")
	await _check_live_refresh(region)


## The crossing: the menu walk cast off with Oda (a `travel` effect carried the player to
## Thornwold landing, where the landing scene played), *Across the Grey* is done, Bram has
## given *A Light for Thornwold*, and the Slow Mercy and Oda lie wherever the lane left them.
func _check_crossing(main: Node) -> void:
	var world := GameState.world
	print("Smoke: sailings ", _sailings)
	print("Smoke: Thornwold burned ", world.get_flag("thornwold_beacon_burned"), ", Hob came in ", world.get_flag("thornwold_hob_came_in"))
	_check(_sailings.has("saltmarrow -> thornwold_landing"), "Oda carried the player to Thornwold")
	_check(_sailings.has("thornwold_landing -> thornwold_woods"), "the ember parted the bramble wall and the player went through")
	_check(world.quest_state("across_the_grey") == WorldState.QUEST_DONE, "the crossing completed Across the Grey")
	_check(world.get_flag("thornwold_landed") == true, "the landing scene played")
	_check(world.get_flag("thornwold_met_bram") == true and world.quest_state("a_light_for_thornwold") != WorldState.QUEST_INACTIVE, "Bram gave A Light for Thornwold")
	_check(world.get_flag("thornwold_met_hob") == true, "met Hob in the colliers' clearing")
	_check(world.quest_state("salt_for_the_collier") == WorldState.QUEST_DONE, "carried Bram's salt to Hob (Salt for the Collier)")
	# Day 25: the ladder stood and climbed (an inspectable's `travel`), the Lamp met, a lantern
	# for the stair (the walk takes the first answer, a new sliver) hung, Ottie's cap to Hob.
	_check(_sailings.has("thornwold_woods -> thornwold_ridge"), "the Keepers' ladder was stood and climbed to the ridge")
	_check(world.get_flag("thornwold_ridge_reached") == true, "the ridge arrival scene played")
	_check(world.get_flag("thornwold_met_lamp") == true, "met the Lamp")
	_check(world.quest_state("a_lantern_for_the_stair") == WorldState.QUEST_DONE, "hung a lantern on the stair (%s)" % world.get_flag("thornwold_stair_light"))
	_check(world.get_flag("thornwold_hob_has_cap") == true, "gave Ottie's cap to Hob")
	# Day 27: Thornwold's burning. The Lamp says what the Ridge Light wants; the walk asks Hob
	# (objects first, then people — Hob's offer is the first Remnant it meets) and burns it; back
	# at the landing Hob, paid, comes in by daylight.
	_check(world.quest_state("a_light_for_thornwold") == WorldState.QUEST_DONE, "the Ridge Light is lit (A Light for Thornwold done)")
	_check(str(world.get_flag("thornwold_beacon_burned")) in ["boots", "salt_row"], "a Thornwold Remnant was burned (%s)" % world.get_flag("thornwold_beacon_burned"))
	_check(world.get_flag("thornwold_hob_came_in") == true, "Hob came in by daylight")
	var at := str(world.get_flag("lanes_ferry_at"))
	_check(at in ["thornwold", "saltmarrow", "fen"], "the ferry lies at a lit end of a lane (%s)" % at)
	# Day 29: the fen lane. Oda sails north-about once the Ridge Light is lit; at the fen the walk
	# meets Hesper (cups the ember, asks after the rowboat), Corran (the Heron Light), and on a
	# later pass leaves Mara's word (or its own) on the letting post.
	_check(_sailings.has("thornwold_landing -> glasswater_fen"), "Oda sailed north-about to Glasswater Fen")
	_check(_sailings.has("glasswater_fen -> thornwold_landing"), "Oda sailed back from the fen to Thornwold")
	_check(world.get_flag("fen_landed") == true, "the fen arrival scene played")
	_check(world.get_flag("fen_met_hesper") == true and str(world.get_flag("fen_ember")) in ["cupped", "bare"], "met Hesper and answered her about the ember (%s)" % world.get_flag("fen_ember"))
	_check(world.get_flag("fen_met_corran") == true, "met Corran Teal")
	_check(world.quest_state("a_light_for_glasswater") == WorldState.QUEST_DONE, "the Heron Light lit (A Light for Glasswater, %s)" % world.get_flag("fen_beacon_burned"))
	_check(world.quest_state("the_letting_post") == WorldState.QUEST_DONE, "left word (or nothing) on the letting post (%s)" % world.get_flag("fen_dunstan_word"))
	GameState.travel("thornwold_landing")
	for i in 3:
		await get_tree().physics_frame
	var names: Array = get_tree().get_nodes_in_group("npcs").map(func(n: Node) -> String: return (n as NpcActor).npc_id)
	_check(names.has("bram"), "Bram at Thornwold landing")
	_check(names.has("oda") == (at == "thornwold"), "Oda on the Thornwold jetty exactly while the ferry is there")
	_check(names.has("pell") == (world.get_flag("thornwold_pell_landed") == true), "Pell at the camp only if they crossed")
	_check(names.has("hob") == (world.get_flag("thornwold_hob_came_in") == true), "Hob on the tally-house step once he's come in")


## Conditional NPCs, pickups and objects appear/disappear live when a flag changes mid-visit
## (via main.gd's world-changed hook). Probes are added with a scratch condition, then
## removed again so the rest of the run is unaffected.
func _check_live_refresh(region: Region) -> void:
	var world := GameState.world
	var flag := "saltmarrow_pell_lent_pebble"
	var before: Variant = world.get_flag(flag)
	world.set_flag(flag, false)
	var probes: Array[Dictionary] = [
		{"kind": "npc", "data": {"npc": "pell", "position": [2, 0, 4], "if": "flag:" + flag}, "node": null},
		{"kind": "pickup", "data": {"id": "smoke_probe", "item": "harbor_token", "position": [3, 0, 4], "if": "flag:" + flag}, "node": null},
		{"kind": "object", "data": {"id": "smoke_probe", "dialogue": "mara", "position": [4, 0, 4], "if": "flag:" + flag}, "node": null},
	]
	region._conditional.append_array(probes)
	var groups := ["npcs", "pickups", "inspectables"]
	var counts := groups.map(func(g: String) -> int: return _live_in_group(g))
	world.set_flag(flag, true)
	await get_tree().process_frame
	for i in groups.size():
		_check(_live_in_group(groups[i]) == counts[i] + 1, "live refresh adds a conditional %s" % groups[i])
	world.set_flag(flag, false)
	await get_tree().process_frame
	for i in groups.size():
		_check(_live_in_group(groups[i]) == counts[i], "live refresh removes a conditional %s" % groups[i])
	for probe in probes:
		region._conditional.erase(probe)
	world.set_flag(flag, before)


func _live_in_group(group: String) -> int:
	return get_tree().get_nodes_in_group(group).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


## Clicks through an open dialogue. Picks option 0 the first time a menu is seen, then 1,
## and so on, so hub menus that loop back eventually reach their last ("goodbye") option.
func _finish_dialogue(ui: DialogueUI, who: String) -> void:
	var steps := 0
	var seen: Dictionary = {}
	while ui.is_open() and steps < MAX_DIALOGUE_STEPS:
		if ui.current_event.get("type") == "choices":
			var options: Array = ui.current_event["options"]
			var key := JSON.stringify(options)
			var visits: int = seen.get(key, 0)
			seen[key] = visits + 1
			ui.select(mini(visits, options.size() - 1))
		elif ui.current_event.get("type") == "lane_map":
			# The walk sails on as the old per-lane options did: to the first neighbouring port.
			var next_port := ""
			for id in Lanes.known_ports(Content.db, GameState.world):
				var voyage := Lanes.voyage(Content.db, GameState.world, id)
				if next_port.is_empty() and bool(voyage.get("ok", false)) and (voyage["route"] as Array).size() == 2:
					next_port = id
			if next_port.is_empty():
				ui.sail_to("")
			else:
				ui.lane_map.press_port(next_port)
		else:
			ui.advance()
		steps += 1
	_check(not ui.is_open(), "dialogue with %s finishes" % who)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
