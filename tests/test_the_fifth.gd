extends TestCase
## Day 49 — *The Fifth*. On the salt-row path Hob still keeps the four and looks up the stair. Asked
## up the ladder from the tally-house step (Pell gives back his count-stick), he goes on ahead; on
## the ridge the Lamp tells him he is the fifth and gives him a lantern lit off the Ridge Light. The
## player says go after the four, stay at the bottom of the road, or that it's his to choose.

const LOOK := "You keep looking up at the ridge."
const COME := "Come up the ladder with me, Hob. Ask the Lamp yourself."
const NOT_TODAY := "Not today."
const GO := "Go after them, Hob. You've the light they went looking for."
const STAY := "Stay. Somebody should be at the bottom of the road when they come down."
const CHOOSE := "It's yours to choose, Hob. Not mine."
const BYE := "Goodbye."
const LANDING := "thornwold_landing"
const RIDGE := "thornwold_ridge"
const DRESSING := "res://assets/models/dressing/"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [BYE], offered)
	return offered


## Thornwold lit and Hob come in by daylight; `burned` is what the Ridge Light took.
func _camp(burned: String = "salt_row", pell: bool = true, named: String = "") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_lamp_ladder_told",
			"thornwold_lamp_saw_light", "thornwold_hob_came_in", "thornwold_hob_stick"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("thornwold_" + ("salt_row" if burned == "salt_row" else "boots") + "_away", true)
	state.set_flag("thornwold_pell_landed", pell)
	state.set_flag("thornwold_lamp_name", named)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.complete_quest("a_light_for_thornwold")
	state.complete_quest("salt_for_the_collier")
	return state


## Hob asked up, then the ridge's arrival event played: he stands at the ladder's head.
func _up(pell: bool = true, named: String = "") -> WorldState:
	var state := _camp("salt_row", pell, named)
	_lines(state, "hob", [LOOK, COME])
	var event := RegionEvents.arrival(_content().get_region(RIDGE), state)
	assert_eq(str(event.get("id", "")), "hob_up_the_ladder")
	_lines(state, RegionEvents.fire(event, state))
	return state


## The model basenames of `region`'s props whose `if` holds and sit at `at` (x, z).
func _props_at(state: WorldState, region: String, x: float, z: float) -> Array[String]:
	var shown: Array[String] = []
	for prop: Dictionary in _content().get_region(region)["props"]:
		var p: Array = prop["position"]
		if absf(float(p[0]) - x) < 0.01 and absf(float(p[2]) - z) < 0.01 and Conditions.evaluate(prop.get("if"), state):
			shown.append(str(prop.get("model", "")).get_file().get_basename())
	return shown


func _hob_in(state: WorldState, region: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if str(placement["npc"]) == "hob" and Conditions.evaluate(placement.get("if"), state):
			out.append(placement)
	return out


func _rake(state: WorldState) -> bool:
	return _props_at(state, LANDING, -5.72, 1.45) == (["clamp_rake"] as Array[String])


func test_only_while_hob_keeps_the_four() -> void:
	assert_true(_offered(_camp(), "hob").has(LOOK), "salt row burned: Hob still looks up the stair")
	assert_false(_offered(_camp("boots"), "hob").has(LOOK), "boots burned: nobody to look for")
	var early := _camp()
	early.set_flag("thornwold_hob_came_in", false)
	assert_false(_offered(early, "hob").has(LOOK), "only from the step, in by daylight")
	var state := _camp()
	assert_true(_lines(state, "hob", [LOOK, NOT_TODAY, BYE]).contains("It'll stand."))
	assert_eq(state.get_flag("thornwold_hob_ladder"), "", "not today leaves him on the step")
	assert_false(_rake(state))
	var text := _lines(_camp(), "hob", [LOOK, COME])
	assert_true(text.contains("It isn't yours to tell him. It's the Lamp's."), "the player knows; the Lamp tells")


func test_hob_goes_on_ahead_with_his_stick() -> void:
	var state := _camp()
	assert_eq(_hob_in(state, LANDING).size(), 1)
	var text := _lines(state, "hob", [LOOK, COME])
	assert_true(text.contains("Finders keep FOR."), "Pell gives the count-stick back")
	assert_true(state.get_flag("thornwold_hob_stick_back"))
	assert_eq(state.get_flag("thornwold_hob_ladder"), "going")
	assert_eq(state.quest_stage("the_fifth"), "up_the_ladder")
	assert_empty(_hob_in(state, LANDING), "off the step")
	assert_empty(_hob_in(state, RIDGE), "not up yet: the scene puts him there")
	assert_true(_rake(state), "his rake leaned on the bench")
	var alone := _camp("salt_row", false)
	assert_false(_lines(alone, "hob", [LOOK, COME]).contains("Finders keep FOR."), "no Pell on Thornwold")
	assert_false(alone.get_flag("thornwold_hob_stick_back"))


func test_the_lamp_tells_him() -> void:
	var state := _camp()
	_lines(state, "hob", [LOOK, COME])
	var event := RegionEvents.arrival(_content().get_region(RIDGE), state)
	assert_eq(str(event.get("id", "")), "hob_up_the_ladder")
	var text := _lines(state, RegionEvents.fire(event, state))
	assert_true(text.contains("After Ottie I put the ladder down. So there'd be no fifth."))
	assert_true(text.contains("You're the fifth, Hob."))
	assert_true(text.contains("finishes the half notch"), "Pell's stick: what he was counting")
	assert_true(text.contains("A light of your own."))
	assert_false(text.contains("You've a face."), "the hood stays up when the name was left")
	assert_eq(state.get_flag("thornwold_hob_ladder"), "up")
	assert_eq(state.quest_stage("the_fifth"), "his_word")
	assert_true(RegionEvents.arrival(_content().get_region(RIDGE), state).is_empty(), "told once")
	var hob := _hob_in(state, RIDGE)
	assert_eq(hob.size(), 1, "at the ladder's head")
	assert_eq(str(hob[0]["model"]).get_file(), "hob_lantern.glb")
	assert_true(_lines(state, "lamp", [BYE]).contains("He's waiting on you, not me."))
	var named := _camp("salt_row", false, "told")
	_lines(named, "hob", [LOOK, COME])
	var seen := _lines(named, RegionEvents.fire(RegionEvents.arrival(_content().get_region(RIDGE), named), named))
	assert_true(seen.contains("You've a face.") and seen.contains("Lamp. I'll say Lamp. I'm old."), "Wynn, hood back")
	assert_false(seen.contains("finishes the half notch"), "no stick without Pell")


func test_go_after_them() -> void:
	var state := _up()
	var text := _lines(state, "hob", [GO])
	assert_true(text.contains("He can come down for them himself."))
	assert_true(text.contains("Five. Then he goes on."), "a fifth notch")
	assert_true(text.contains("I'll hang one on the second mark."))
	assert_eq(state.get_flag("thornwold_hob_ladder"), "gone")
	assert_eq(state.quest_state("the_fifth"), WorldState.QUEST_DONE)
	assert_empty(_hob_in(state, RIDGE), "gone up the road")
	assert_empty(_hob_in(state, LANDING), "and not back on the step")
	assert_eq(_props_at(state, RIDGE, 20.5, -20.5), ["waymark_lit"] as Array[String], "the second mark lit")
	assert_true(_rake(state), "the rake stays where he leaned it")
	assert_true(_lines(state, "lamp", [BYE]).contains("Five on it, now."))
	assert_true(_lines(state, "pell").contains("He's got his stick back."))
	assert_true(_lines(state, "bram", ["The old collier from your step went up the ridge.", BYE]).contains("a thing you don't move"))
	assert_false(_offered(state, "bram").has("The old collier from your step went up the ridge."), "told once")


func test_his_to_choose() -> void:
	var state := _up(false)
	assert_eq(_props_at(state, RIDGE, 20.5, -20.5), ["waymark"] as Array[String], "bare until he's gone")
	var text := _lines(state, "hob", [CHOOSE])
	assert_true(text.contains("Ottie never waited to be told a thing in his life."))
	assert_false(text.contains("Five. Then he goes on."), "no stick, no notch")
	assert_eq(state.get_flag("thornwold_hob_ladder"), "gone", "he doesn't wait to be told either")
	state.set_flag("thornwold_pell_landed", true)  # Pell off the boat after: no stick to give back
	assert_true(_lines(state, "pell").contains("It's not lost, it's left."))


func test_stay_at_the_bottom_of_the_road() -> void:
	var state := _up()
	var text := _lines(state, "hob", [STAY])
	assert_true(text.contains("Bram Kettle doesn't know mine."))
	assert_true(text.contains("One at each end."))
	assert_eq(state.get_flag("thornwold_hob_ladder"), "stayed")
	assert_eq(state.quest_state("the_fifth"), WorldState.QUEST_DONE)
	assert_eq(_hob_in(state, LANDING).size(), 1, "back on the step")
	assert_empty(_hob_in(state, RIDGE))
	assert_false(_rake(state), "the rake back across his knees")
	assert_eq(_props_at(state, LANDING, -4.9, 3.5), ["waymark_lit"] as Array[String], "a mark at the bottom of the road")
	assert_eq(_props_at(state, RIDGE, 20.5, -20.5), ["waymark"] as Array[String])
	assert_true(_lines(state, "hob", [BYE]).contains("Somebody's got to be at it, and it's me."))
	assert_false(_offered(state, "hob").has(LOOK), "asked once")
	assert_true(_lines(state, "bram_tally_board").contains("four notches cut deep"), "on the bare SALT pegs")
	assert_true(_lines(state, "bram", ["The old collier built a mark by your step.", BYE]).contains("they were for coming down"))
	assert_true(_lines(state, "lamp", [BYE]).contains("Two ends to a road."))
	assert_true(_lines(state, "pell").contains("Hob built a MARK."))
