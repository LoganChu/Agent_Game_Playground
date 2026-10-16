extends SceneTree
## Renders the game's procedural sounds to .wav files for listening (audio review):
##   godot --headless --path . -s res://tools/debug/export_sounds.gd -- /abs/out_dir [ids…]
## Every sound in data/audio.json by default; loops are written as a single pass.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: … -s res://tools/debug/export_sounds.gd -- /abs/out_dir [ids…]")
		quit(2)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var db := ContentDatabase.new()
	db.load_all()
	var only := args.slice(1)
	for id: String in db.sounds:
		if not only.is_empty() and id not in only:
			continue
		var recipe: Dictionary = db.sounds[id]
		if recipe.has("file"):
			continue
		var stream := SoundSynth.build(recipe, id.hash())
		stream.save_to_wav(out_dir.path_join(id + ".wav"))
		print("%-14s %5.2f s  %s" % [id, stream.get_length(), recipe.get("bus", "")])
	quit()
