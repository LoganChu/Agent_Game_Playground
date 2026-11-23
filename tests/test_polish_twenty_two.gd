extends TestCase
## Day 121 — polish pass twenty-two. WalkSurvey lists every pair of one NPC's placements in a region and what a move
## between them does mid-visit (swap / straight / bent / fades, with the reason), for `tools/debug/walk_probe.gd`.
## The test runner has no physics world, so here only the ground decides; the smoke test runs it in the tree.


func _setup() -> ContentDatabase:
	var saved := Content.db
	if Content.db.game.is_empty():
		Content.db = load_content()
	return saved


func _region(id: String) -> Region:
	var region := Region.new()
	region.build(id)
	return region


## Only NPCs placed more than once, every placement in data order.
func test_placements_lists_npcs_placed_more_than_once() -> void:
	var data := {"npcs": [{"npc": "a", "position": [0, 0, 0]}, {"npc": "b", "position": [1, 0, 0]},
		{"npc": "a", "position": [5, 0, 0]}]}
	var by_npc := WalkSurvey.placements(data)
	assert_eq(by_npc.keys(), ["a"], "only a has two placements")
	assert_eq((by_npc["a"] as Array).size(), 2)
	assert_eq(by_npc["a"][1]["position"], [5, 0, 0], "in data order")


## Every pair both ways, and each kind agrees with the rules the region walks by.
func test_every_pair_classified_by_the_walk_rules() -> void:
	var saved := _setup()
	var seen := 0
	for id: String in Content.db.regions:
		var region := _region(id)
		var rows := WalkSurvey.survey(region)
		var by_npc := WalkSurvey.placements(region.data)
		var pairs := 0
		for npc: String in by_npc:
			var n := (by_npc[npc] as Array).size()
			pairs += n * (n - 1)
		assert_eq(rows.size(), pairs, "%s: every ordered pair of placements has a row" % id)
		for row: Dictionary in rows:
			seen += 1
			var label := "%s: %s" % [id, WalkSurvey.describe(row)]
			var distance: float = row["distance"]
			var route: Array = row["route"]
			match str(row["kind"]):
				WalkSurvey.SWAP:
					assert_true(distance <= Region.SWAP_IN_PLACE, label + " — a swap is in place")
				WalkSurvey.STRAIGHT:
					assert_eq(route.size(), 1, label + " — straight goes straight there")
				WalkSurvey.BENT:
					assert_true(route.size() >= 2 and route.size() <= 3, label + " — one or two bends")
					assert_true(Region._flat_length(row["from_pos"], route as Array[Vector3]) <= distance * Region.WALK_ROUTE_STRETCH + 0.01,
						label + " — within the stretch")
				WalkSurvey.FADES:
					assert_true(str(row["reason"]) in ["seated", "circuit", "far", "ground", "blocked", "no ground"], label + " — a reason")
					assert_true(route.is_empty(), label + " — no route")
			if row["kind"] == WalkSurvey.STRAIGHT or row["kind"] == WalkSurvey.BENT:
				assert_true(distance > Region.SWAP_IN_PLACE and distance <= Region.WALK_REACH, label + " — in reach")
				assert_true((route.back() as Vector3).is_equal_approx(row["to_pos"]), label + " — ends at the new spot")
			if str(row["reason"]) == "far":
				assert_true(distance > Region.WALK_REACH, label + " — far is past the reach")
		region.free()
	assert_true(seen > 0, "some region places an NPC more than once")
	Content.db = saved


## The reasons, on real placements: a seated spot never walks off, a circuit fades, the far Lowsong boat fades.
func test_reasons_on_known_placements() -> void:
	var saved := _setup()
	var spire := _region("cindermoor_spire_foot")
	var rows := WalkSurvey.survey(spire)
	var oriel := rows.filter(func(r: Dictionary) -> bool: return r["npc"] == "oriel")
	assert_true(not oriel.is_empty(), "Oriel is placed more than once at the Spire's foot")
	for row: Dictionary in oriel:
		if row["from"] == 1 and row["kind"] != WalkSurvey.SWAP:
			assert_eq(row["reason"], "seated", "Oriel seated on the step fades when she moves (%s)" % WalkSurvey.describe(row))
		if row["from"] == 0 and row["kind"] != WalkSurvey.SWAP:
			assert_eq(row["reason"], "circuit", "Oriel off her circuit fades (%s)" % WalkSurvey.describe(row))
	assert_true(oriel.any(func(r: Dictionary) -> bool: return r["from"] == 2 and r["to"] == 3 and r["kind"] == WalkSurvey.STRAIGHT),
		"Oriel walks between the climb and the own spots")
	spire.free()
	var lowsong := _region("lowsong")
	var far := WalkSurvey.survey(lowsong).filter(func(r: Dictionary) -> bool: return r["reason"] == "far")
	assert_true(not far.is_empty(), "some Lowsong move is too far to walk")
	lowsong.free()
	Content.db = saved


## A line per row, and the tally adds up.
func test_describe_and_tally() -> void:
	var row := {"npc": "mara", "from": 0, "to": 1, "distance": 6.0, "kind": WalkSurvey.BENT, "reason": "",
		"route": [Vector3(2, 0, 3), Vector3(4, 0, 0)] as Array[Vector3]}
	assert_true(WalkSurvey.describe(row).contains("bent 1 via (2.0, 3.0)"), WalkSurvey.describe(row))
	row["kind"] = WalkSurvey.FADES
	row["reason"] = "far"
	assert_true(WalkSurvey.describe(row).ends_with("fades (far)"), WalkSurvey.describe(row))
	var rows: Array[Dictionary] = [row, {"kind": WalkSurvey.SWAP}, {"kind": WalkSurvey.SWAP}]
	assert_eq(WalkSurvey.tally(rows), {"swap": 2, "straight": 0, "bent": 0, "fades": 1})
