extends Node3D
## Root of the game scene: environment, current region, player and UI.
##
## A plain launch opens on the title screen over the start region. Any of the debug args
## below except --smoke-test skips it (straight into play); --title forces it.
##
## Command-line user args (after `--`):
##   --title               show the title screen even with other debug args (screenshots)
##   --smoke-test          automated playthrough (scripts/debug/smoke_test.gd), exit code = result
##   --screenshot=<png>    save a screenshot after a moment and quit
##   --region=<id>         start in another region (debug)
##   --flags=a=b,c         set flags before play (debug; bare `c` = true, true/false parse)
##   --quest=<id>[:stage]  start a quest at a stage, or complete it without one (debug);
##                         comma-separate several. E.g. screenshots of late-game states:
##                         --flags=intro_seen,saltmarrow_beacon_burned=knot --quest=a_light_for_saltmarrow
##   --act-end=<id>        show that act's end card for the current state (debug/screenshots)
##   --pause-menu[=save|load|chapters|settings|controls]  open the pause menu (on that page) after loading (screenshots)
##   --scenario=<id>       start at a story checkpoint from data/scenarios.json (see README);
##                         --scenario=list prints them and quits

## Radians per second the camera swings round behind the title screen.
const TITLE_DRIFT := 0.05

var region: Region
var player: Player
var hud: Hud
var dialogue_ui: DialogueUI
var journal_ui: JournalUI
var greying: GreyingWalker
var atmosphere: Atmosphere
var audio: AudioDirector
var act_end_card: ActEndCard
var pause_menu: PauseMenu
var title_screen: TitleScreen
## Acts whose end the story had already reached (so a card shows once, when it changes).
var _acts_reached: Dictionary = {}


func _ready() -> void:
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	hud = Hud.new()
	add_child(hud)
	dialogue_ui = DialogueUI.new()
	add_child(dialogue_ui)
	journal_ui = JournalUI.new()
	add_child(journal_ui)
	act_end_card = ActEndCard.new()
	add_child(act_end_card)
	# After the other modals: it sees Esc first, and passes it on while one of them is open.
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	title_screen = TitleScreen.new()
	add_child(title_screen)
	title_screen.new_game_requested.connect(start_new_game)
	title_screen.opened.connect(func() -> void: hud.visible = false)
	title_screen.closed.connect(func() -> void: hud.visible = true)
	pause_menu.title_requested.connect(return_to_title)
	act_end_card.title_requested.connect(return_to_title)
	dialogue_ui.closed.connect(_check_act_end)
	dialogue_ui.line_shown.connect(audio.speak)
	dialogue_ui.runner.effect_applied.connect(audio.on_dialogue_effect)
	player = Player.new()
	add_child(player)
	player.focus_changed.connect(hud.set_focus)
	player.stepped.connect(func() -> void:
		if region:
			audio.footstep(region.footstep_surface(player.global_position)))
	greying = GreyingWalker.new()
	greying.player = player
	greying.hud = hud
	greying.ember_changed.connect(hud.set_ember)
	greying.turned_back.connect(audio.on_turned_back)
	add_child(greying)
	GameState.region_change_requested.connect(_on_region_change_requested)
	GameState.world.flag_changed.connect(_on_world_changed.unbind(2))
	GameState.world.quest_changed.connect(_on_world_changed.unbind(3))
	var fresh := GameState.region_id.is_empty()
	if fresh:
		GameState.new_game()
	var titled := fresh and wants_title(OS.get_cmdline_user_args())
	var scenario := _scenario_arg()
	if not scenario.is_empty():
		if scenario == "list":
			_print_scenarios()
			return
		var resolved := Scenarios.resolve(scenario)
		if resolved.is_empty():
			push_error("--scenario: unknown checkpoint '%s' (try --scenario=list)" % scenario)
		else:
			Scenarios.apply(Content.db, GameState.world, resolved)
			GameState.region_id = str(resolved["region"])
			GameState.spawn_point = str(resolved.get("spawn", "default"))
			fresh = not GameState.world.get_flag("intro_seen")
	load_region(GameState.region_id, GameState.spawn_point)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--flags=") or arg.begins_with("--quest="):
			_apply_debug_state(arg)
	_acts_reached = ActRecap.reached(Content.db, GameState.world)
	var intro := str(Content.db.game.get("intro_dialogue", ""))
	if titled:
		title_screen.open()
	elif fresh and not intro.is_empty() and not GameState.world.get_flag("intro_seen"):
		dialogue_ui.open.call_deferred(intro)
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test":
			add_child(SmokeTest.new())
		elif arg.begins_with("--screenshot="):
			var shot := Screenshot.new()
			shot.path = arg.get_slice("=", 1)
			add_child(shot)
		elif arg.begins_with("--region="):
			GameState.travel(arg.get_slice("=", 1))
		elif arg.begins_with("--lane-map"):
			_open_lane_map.call_deferred(arg.get_slice("=", 1) if arg.contains("=") else "")
		elif arg.begins_with("--journal="):
			_open_journal.call_deferred(arg.get_slice("=", 1))
		elif arg.begins_with("--pause-menu"):
			_open_pause_menu.call_deferred(arg.get_slice("=", 1) if arg.contains("=") else "")
		elif arg.begins_with("--act-end="):
			for act in ActRecap.acts(Content.db):
				if str(act["id"]) == arg.get_slice("=", 1):
					act_end_card.show_act.call_deferred(act, ActRecap.lines(act, GameState.world))


## Whether a launch with these user args opens on the title screen: yes for a plain launch
## (and the smoke run, which starts from it), no when a debug arg asks for a particular
## state or screen — unless --title asks for it anyway.
static func wants_title(args: PackedStringArray) -> bool:
	for arg in args:
		if arg == "--title":
			return true
	for arg in args:
		for skip: String in ["--scenario=", "--region=", "--flags=", "--quest=", "--act-end=", "--pause-menu", "--journal=", "--screenshot="]:
			if arg.begins_with(skip):
				return false
	return true


## New game from the title: the world back to the start, the start region rebuilt, and the
## waking narration (once the region is in).
func start_new_game() -> void:
	GameState.new_game()
	GameState.travel(GameState.region_id, GameState.spawn_point)
	var intro := str(Content.db.game.get("intro_dialogue", ""))
	if not intro.is_empty():
		dialogue_ui.open.call_deferred(intro)


## "Return to title" (pause menu, act-end card): the world reset to a fresh start behind the
## title screen, as at launch. Deferred: the menu that asked unlocks input on a deferred
## call of its own, which must land before the title locks it again.
func return_to_title() -> void:
	GameState.new_game()
	GameState.travel(GameState.region_id, GameState.spawn_point)
	title_screen.open.call_deferred()


func _scenario_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			return arg.get_slice("=", 1)
	return ""


func _print_scenarios() -> void:
	for scenario in Scenarios.all():
		print("%-18s %s — %s\n%-18s %s" % [scenario["id"], scenario["act"], scenario["title"], "", scenario["description"]])
	get_tree().quit()


## Debug: opens the pause menu, optionally on a page (use with --flags=intro_seen: it won't
## open over a dialogue).
func _open_pause_menu(page: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	pause_menu.open()
	if page == "save":
		pause_menu.press("Save game")
	elif page == "load":
		pause_menu.press("Load game")
	elif page == "chapters":
		pause_menu.press("Chapter select")
	elif page == "settings" or page == "controls":
		pause_menu.press("Settings")
		if page == "controls":
			pause_menu.press("Controls")


## Debug: talks to Oda and opens her lane map, focus on `port` if given (use with a scenario or
## --flags= that has the ferry in and the first crossing made).
func _open_lane_map(port: String) -> void:
	await _read_through_arrival()
	dialogue_ui.open("oda")
	for _i in 40:
		if dialogue_ui.current_event.get("type") != "line":
			break
		dialogue_ui.advance()
	var options: Array = dialogue_ui.current_event.get("options", [])
	for i in options.size():
		if str((options[i] as Dictionary).get("text", "")) == "Where can you take me?":
			dialogue_ui.select(i)
	if not port.is_empty() and dialogue_ui.lane_map.visible:
		await get_tree().process_frame
		dialogue_ui.lane_map.focus_port(port)


## Debug: opens the journal on a tab (`journal`, `satchel` or `lanes`); with `--remember`, plays
## the first satchel entry's memory (Day 70).
func _open_journal(which: String) -> void:
	await _read_through_arrival()
	var index := JournalUI.TAB_ACTIONS.find({"satchel": "inventory"}.get(which, which))
	journal_ui.open(maxi(index, 0) as JournalUI.Tab)
	if "--remember" in OS.get_cmdline_user_args():
		journal_ui.remember()


## Debug: an arrival scene may hold the dialogue box; reads it through (last option each time).
func _read_through_arrival() -> void:
	for _i in 6:
		await get_tree().process_frame
	for _i in 200:
		if not dialogue_ui.is_open():
			break
		if dialogue_ui.current_event.get("type") == "choices":
			dialogue_ui.select((dialogue_ui.current_event["options"] as Array).size() - 1)
		else:
			dialogue_ui.advance()
	await get_tree().process_frame


## Debug-only world setup from `--flags=` / `--quest=` (see the header comment).
func _apply_debug_state(arg: String) -> void:
	var world := GameState.world
	var is_flags := arg.begins_with("--flags=")
	for entry: String in arg.substr(arg.find("=") + 1).split(",", false):
		if is_flags:
			var id := entry.get_slice("=", 0)
			var value: Variant = entry.substr(id.length() + 1) if entry.contains("=") else "true"
			if value == "true" or value == "false":
				value = value == "true"
			if not Content.db.flags.has(id):
				push_warning("--flags: unknown flag '%s'" % id)
			world.set_flag(id, value)
		else:
			var id := entry.get_slice(":", 0)
			if not Content.db.quests.has(id):
				push_warning("--quest: unknown quest '%s'" % id)
				continue
			if entry.contains(":"):
				world.start_quest(id, entry.get_slice(":", 1))
				world.set_quest_stage(id, entry.get_slice(":", 1))
			else:
				world.complete_quest(id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save") and not GameState.input_locked:
		SaveSystem.save_game()
	elif event.is_action_pressed("quick_load") and not GameState.input_locked:
		SaveSystem.load_game()


func load_region(region_id: String, spawn: String) -> void:
	if region:
		remove_child(region)
		region.queue_free()
	region = Region.new()
	region.build(region_id)
	add_child(region)
	var pos: Variant = GameState.pending_player_position
	GameState.pending_player_position = null
	player.place_at(pos if pos is Vector3 else region.spawn_position(spawn))
	greying.enter_region(region)
	audio.enter_region(region.data)
	_apply_region_mood(false)
	hud.show_region_title(str(region.data.get("name", region_id)))
	# A load can jump the story anywhere; only acts ended *in play* get a card.
	_acts_reached = ActRecap.reached(Content.db, GameState.world)
	_fire_arrival_event.call_deferred()


## Region `events`: on arrival, the first event whose `if` holds sets its flags (which
## switch it off — validated) and plays its dialogue (e.g. the ferry's horn heard from the
## beach). Waits for any open dialogue to finish first.
func _fire_arrival_event() -> void:
	if region == null or RegionEvents.arrival(region.data, GameState.world).is_empty():
		return
	if title_screen.is_open():
		await title_screen.closed
		_fire_arrival_event.call_deferred()
		return
	if dialogue_ui.is_open():
		await dialogue_ui.closed
		_fire_arrival_event.call_deferred()
		return
	var event := RegionEvents.arrival(region.data, GameState.world)
	if not event.is_empty():
		dialogue_ui.open(RegionEvents.fire(event, GameState.world))


## After each conversation: if it just ended an act, show that act's end card.
func _check_act_end() -> void:
	var now := ActRecap.reached(Content.db, GameState.world)
	for act in ActRecap.acts(Content.db):
		var id := str(act["id"])
		if now.has(id) and not _acts_reached.has(id):
			# Deferred: the closing dialogue unlocks input on a deferred call of its own.
			act_end_card.show_act.call_deferred(act, ActRecap.lines(act, GameState.world))
			break
	_acts_reached = now


func _on_region_change_requested(region_id: String, spawn: String) -> void:
	# Defer so we never free the region from inside one of its own callbacks.
	load_region.call_deferred(region_id, spawn)


## Story changes mid-visit (a relit beacon) can thin the fog and show/hide conditional
## props, NPCs, pickups and objects.
func _on_world_changed() -> void:
	if region == null:
		return
	region.refresh_conditional()
	_apply_region_mood(true)


func _apply_region_mood(animate: bool) -> void:
	var world := GameState.world
	# The Greying pulls back slowly when the story changes it, so the player sees it happen.
	atmosphere.apply_mood(RegionMood.fog(region.data, world), RegionMood.light(region.data, world), animate)


## Standing in the Greying thickens the fog around the player and drains the colour.
## The title screen's camera drifts slowly round the Wakebearer on the beach.
func _process(delta: float) -> void:
	atmosphere.follow_greying(greying.depth, delta)
	audio.follow_greying(greying.depth)
	if title_screen.is_open():
		player.turn_camera(TITLE_DRIFT * delta)


## Fog density the current region is heading toward (for tests).
func target_fog_density() -> float:
	return float(RegionMood.fog(region.data, GameState.world)["density"]) if region else 0.0
