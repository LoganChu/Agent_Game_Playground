extends Node3D
## Root of the game scene: environment, current region, player and UI.
##
## Command-line user args (after `--`):
##   --smoke-test          automated playthrough (scripts/debug/smoke_test.gd), exit code = result
##   --screenshot=<png>    save a screenshot after a moment and quit
##   --region=<id>         start in another region (debug)

var region: Region
var player: Player
var hud: Hud
var dialogue_ui: DialogueUI
var journal_ui: JournalUI

var _environment: Environment
var _fog_tween: Tween


func _ready() -> void:
	_build_environment()
	hud = Hud.new()
	add_child(hud)
	dialogue_ui = DialogueUI.new()
	add_child(dialogue_ui)
	journal_ui = JournalUI.new()
	add_child(journal_ui)
	player = Player.new()
	add_child(player)
	player.focus_changed.connect(hud.set_focus)
	GameState.region_change_requested.connect(_on_region_change_requested)
	GameState.world.flag_changed.connect(_on_world_changed.unbind(2))
	GameState.world.quest_changed.connect(_on_world_changed.unbind(3))
	var fresh := GameState.region_id.is_empty()
	if fresh:
		GameState.new_game()
	load_region(GameState.region_id, GameState.spawn_point)
	var intro := str(Content.db.game.get("intro_dialogue", ""))
	if fresh and not intro.is_empty() and not GameState.world.get_flag("intro_seen"):
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
	_apply_region_mood(false)
	hud.show_region_title(str(region.data.get("name", region_id)))


func _on_region_change_requested(region_id: String, spawn: String) -> void:
	# Defer so we never free the region from inside one of its own callbacks.
	load_region.call_deferred(region_id, spawn)


func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = PropFactory.color("silverfog")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = PropFactory.color("silverfog")
	_environment.ambient_light_energy = 0.25
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_light_color = PropFactory.color("silverfog")
	_environment.fog_density = 0.012
	_environment.fog_sky_affect = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = _environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = PropFactory.color("kindle")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)


## Story changes mid-visit (a relit beacon) can thin the fog and show/hide props.
func _on_world_changed() -> void:
	if region == null:
		return
	region.refresh_conditional_props()
	_apply_region_mood(true)


func _apply_region_mood(animate: bool) -> void:
	var fog := RegionMood.fog(region.data, GameState.world)
	var density := float(fog["density"])
	var fog_color := PropFactory.color(str(fog["color"]))
	if _fog_tween:
		_fog_tween.kill()
	if not animate or is_equal_approx(density, _environment.fog_density):
		_environment.fog_density = density
		_environment.fog_light_color = fog_color
		_environment.background_color = fog_color
		return
	# The Greying pulls back slowly, so the player sees it happen.
	_fog_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_fog_tween.tween_property(_environment, "fog_density", density, 4.0)
	_fog_tween.tween_property(_environment, "fog_light_color", fog_color, 4.0)
	_fog_tween.tween_property(_environment, "background_color", fog_color, 4.0)


## Fog density the current region is heading toward (for tests).
func target_fog_density() -> float:
	return float(RegionMood.fog(region.data, GameState.world)["density"]) if region else 0.0
