extends TestCase
## Day 91 — polish pass fourteen. A walking NPC's place round its circle is kept (saved, and found again on a
## return), and an NPC whose placement a conversation moves waits for the box to close before coming, going or
## moving (the Provost used to appear on the niche step while the answer at the east stair door was still talking).

const FOOT := "cindermoor_spire_foot"

var _saved_world: Dictionary = {}
var _saved_db: ContentDatabase


func _begin(scenario: String) -> void:
	_saved_db = Content.db
	if Content.db.regions.is_empty():
		Content.db = load_content()
	_saved_world = GameState.world.to_dict()
	Scenarios.apply(Content.db, GameState.world, Scenarios.resolve(scenario))


func _end() -> void:
	GameState.world.load_dict(_saved_world)
	Content.db = _saved_db


func _region(id: String) -> Region:
	var region := Region.new()
	region.build(id)
	return region


func _actors(region: Region, npc: String) -> Array[NpcActor]:
	var out: Array[NpcActor] = []
	for child in region.get_children():
		if child is NpcActor and (child as NpcActor).npc_id == npc and not child.is_queued_for_deletion():
			out.append(child as NpcActor)
	return out


func test_world_state_keeps_a_walkers_place_on_the_same_circle_only() -> void:
	var world := WorldState.new()
	var circuit := {"center": [0, -6], "radius": 7.4}
	assert_eq(world.walker_angle("oriel", circuit), null, "never walked")
	world.note_walker("oriel", circuit, 1.25)
	assert_eq(world.walker_angle("oriel", circuit), 1.25)
	assert_eq(world.walker_angle("oriel", {"center": [0, -6], "radius": 5.0}), null, "another circle")
	assert_eq(world.walker_angle("oriel", {"center": [3, -6], "radius": 7.4}), null, "another centre")
	assert_eq(world.walker_angle("hild", circuit), null, "someone else")
	var reloaded := WorldState.new()
	reloaded.load_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	assert_true(absf(float(reloaded.walker_angle("oriel", circuit)) - 1.25) < 0.0001, "survives a save file")
	reloaded.load_dict({})
	assert_eq(reloaded.walker_angle("oriel", circuit), null, "a new game forgets it")


func test_oriel_is_where_she_was_after_a_reload() -> void:
	_begin("the_eighth_boat")
	var region := _region(FOOT)
	var walking := _actors(region, "oriel").filter(func(a: NpcActor) -> bool: return a.walks_circuit())
	assert_eq(walking.size(), 1, "she walks the ring path")
	if walking.size() == 1:
		var oriel: NpcActor = walking[0]
		var placed := oriel.position
		for i in 10:
			oriel.step_circuit(0.5)
		var got_to := oriel.position
		assert_true(placed.distance_to(got_to) > 2.0, "she walked on (%s → %s)" % [placed, got_to])
		var save: Dictionary = JSON.parse_string(JSON.stringify(GameState.world.to_dict()))
		region.free()
		GameState.world.load_dict(save)
		region = _region(FOOT)
		var again := _actors(region, "oriel").filter(func(a: NpcActor) -> bool: return a.walks_circuit())
		assert_eq(again.size(), 1)
		if again.size() == 1:
			assert_true((again[0] as NpcActor).position.distance_to(got_to) < 0.05,
				"picked up where she was: %s vs %s" % [(again[0] as NpcActor).position, got_to])
	region.free()
	_end()


func test_the_provost_comes_up_when_the_box_closes() -> void:
	_begin("the_nearest_voice")
	var region := _region(FOOT)
	var before := _actors(region, "provost").size()
	GameState.world.set_flag("cindermoor_choir_answered", "named")
	region.refresh_conditional(false, true)
	assert_eq(_actors(region, "provost").size(), before, "not while the answer's still talking")
	assert_true(region.held_npc_moves >= 1, "held")
	region.refresh_conditional(false)
	assert_eq(region.held_npc_moves, 0)
	var shown := _actors(region, "provost")
	assert_eq(shown.size(), 1, "on the niche step once it closes")
	if shown.size() == 1:
		assert_true(Vector2(shown[0].position.x - 10.8, shown[0].position.z + 8.6).length() < 0.05, str(shown[0].position))
	region.free()
	_end()


func test_a_swap_in_place_is_not_held() -> void:
	var region := Region.new()
	var flag := "test_polish_fourteen_swap"
	GameState.world.flags[flag] = false
	var stand := {"npc": "corran", "position": [2, 0, 3], "if": "!flag:" + flag}
	var swap := {"npc": "corran", "position": [2.3, 0, 3], "if": "flag:" + flag}
	var away := {"npc": "hild", "position": [0, 0, 0], "if": "!flag:" + flag}
	var there := {"npc": "hild", "position": [8, 0, 0], "if": "flag:" + flag}
	for entry: Dictionary in [stand, swap, away, there]:
		region._conditional.append({"kind": "npc", "data": entry, "node": null})
	region.refresh_conditional(false)
	assert_eq(_actors(region, "corran").size(), 1)
	GameState.world.flags[flag] = true
	region.refresh_conditional(false, true)
	assert_eq(region.held_npc_moves, 1, "only Hild's walk across is held")
	var corran := _actors(region, "corran")
	assert_eq(corran.size(), 1, "Corran swapped at once")
	if corran.size() == 1:
		assert_true(absf(corran[0].position.x - 2.3) < 0.01, "on his new placement")
	var hild := _actors(region, "hild")
	assert_true(hild.size() == 1 and hild[0].position.x < 1.0, "Hild still where she was")
	region.refresh_conditional(false)
	hild = _actors(region, "hild")
	assert_true(hild.size() == 1 and hild[0].position.x > 7.0, "and over there once it closes")
	GameState.world.flags.erase(flag)
	region.free()
