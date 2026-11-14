extends TestCase
## Day 104 — polish pass seventeen. A checkpoint is applied without a toast per quest (the stack used to run off the
## screen), and the toast stack never shows more than Hud.TOAST_MAX; the nameplate hangs lower over someone seated; the
## lantern room's swung-back door leaf has a collider (the lifted camera passed through it from the spawn); and the
## Hearthspire's lit ending warms Gull's Head, Shingle Point and the Heron's mere as it does their islands' harbors.

const LIT := "flag:cindermoor_cradle_choice=lit"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_a_checkpoint_is_applied_quietly() -> void:
	var saved_db := Content.db
	var saved := GameState.world.to_dict()
	Content.db = load_content()
	var heard: Array[String] = []
	var listen := func(text: String) -> void: heard.append(text)
	GameState.toast.connect(listen)
	# The test runner's autoloads never ran _ready: wire the world's signals as the game does.
	var wired := not GameState.world.quest_changed.is_connected(GameState._on_quest_changed)
	if wired:
		GameState.world.quest_changed.connect(GameState._on_quest_changed)
		GameState.world.inventory_changed.connect(GameState._on_inventory_changed)
	GameState.apply_scenario(Scenarios.resolve("the_homecoming"))
	assert_true(GameState.world.quest_state("a_light_for_saltmarrow") == WorldState.QUEST_DONE, "the checkpoint applied")
	assert_eq(heard.size(), 0, "no toasts while a checkpoint applies: %s" % [heard])
	# Afterwards play toasts again.
	GameState.world.add_item("aldous_letter", 1)
	assert_eq(heard.size(), 1, "an item picked up after it still toasts")
	GameState.toast.disconnect(listen)
	if wired:
		GameState.world.quest_changed.disconnect(GameState._on_quest_changed)
		GameState.world.inventory_changed.disconnect(GameState._on_inventory_changed)
	GameState.world.load_dict(saved)
	Content.db = saved_db


func test_the_toast_stack_keeps_only_the_newest() -> void:
	var hud := Hud.new()
	_root().add_child(hud)
	if hud.get("_toasts") == null:
		hud._ready()
	for i in 12:
		hud.show_toast("Toast %d" % i)
	var toasts := hud.get("_toasts") as VBoxContainer
	var shown := toasts.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_eq(shown.size(), Hud.TOAST_MAX, "at most TOAST_MAX on screen")
	assert_eq((shown[shown.size() - 1] as Label).text, "Toast 11", "the newest stays")
	assert_eq((shown[0] as Label).text, "Toast %d" % (12 - Hud.TOAST_MAX), "the oldest went first")
	_root().remove_child(hud)
	hud.free()


func test_the_nameplate_hangs_lower_over_someone_seated() -> void:
	var db := load_content()
	var bench: Dictionary = {}
	for entry: Dictionary in db.get_region("saltmarrow").get("npcs", []):
		if entry.get("npc") == "aldous":
			bench = entry
	var aldous := NpcActor.new()
	aldous.setup("aldous", Region.placed_npc_data(db.get_npc("aldous"), bench))
	var mara := NpcActor.new()
	mara.setup("mara", db.get_npc("mara"))
	assert_eq(aldous.nameplate_height(), NpcActor.NAMEPLATE_SEATED_HEIGHT, "Aldous on his bench")
	assert_eq(mara.nameplate_height(), NpcActor.NAMEPLATE_HEIGHT, "Mara stands")
	assert_true(NpcActor.NAMEPLATE_SEATED_HEIGHT < NpcActor.NAMEPLATE_HEIGHT)
	aldous._build_body()
	var label := aldous.find_children("*", "Label3D", true, false)[0] as Label3D
	assert_true(is_equal_approx(label.position.y, NpcActor.NAMEPLATE_SEATED_HEIGHT), "the built label uses it")
	aldous.free()
	mara.free()


func test_the_lantern_rooms_door_leaf_is_solid_and_the_doorway_clear() -> void:
	var db := load_content()
	var shell: Dictionary = {}
	for prop: Dictionary in db.get_region("cindermoor_lantern_room").get("props", []):
		if str(prop.get("model", "")).ends_with("/lantern_room.glb"):
			shell = prop
	var leaf: Dictionary = {}
	for box: Dictionary in shell.get("colliders", []):
		if float((box["offset"] as Array)[0]) > 4.0:
			leaf = box
	assert_false(leaf.is_empty(), "a collider by the east door")
	var z := float((leaf["offset"] as Array)[2])
	var depth := float((leaf["size"] as Array)[2])
	# The doorway (jambs at z ±0.85) keeps at least 1.3 m clear.
	assert_true(z + depth * 0.5 <= -0.65, "the leaf stays beside the doorway (to z %.2f)" % (z + depth * 0.5))
	assert_true(float((leaf["size"] as Array)[1]) >= 2.4, "full height, so the camera can't pass over it low")


func test_the_lit_ending_warms_the_rest_of_saltmarrow_and_the_mere() -> void:
	var db := load_content()
	var state := fresh_state(db)
	for id: String in ["gulls_head", "shingle_point", "heron_mere"]:
		var region: Dictionary = db.regions[id]
		var first_light: Dictionary = (region["light"]["overrides"] as Array)[0]
		var first_fog: Dictionary = (region["fog"]["overrides"] as Array)[0]
		assert_eq(first_light.get("if"), LIT, id + ": the lit light goes first")
		assert_eq(first_fog.get("if"), LIT, id + ": the lit fog goes first")
		state.set_flag("cindermoor_cradle_choice", "")
		var before := RegionMood.light(region, state)
		state.set_flag("cindermoor_cradle_choice", "lit")
		var lit := RegionMood.light(region, state)
		assert_eq(str(lit.get("sky_horizon", "")), "#DCC29A", id + ": a gold horizon")
		assert_true(str(before.get("sky_horizon", "")) != "#DCC29A", id + ": not before")
		for ending: String in ["released", "dark"]:
			state.set_flag("cindermoor_cradle_choice", ending)
			assert_true(str(RegionMood.light(region, state).get("sky_horizon", "")) != "#DCC29A", id + " / " + ending)
