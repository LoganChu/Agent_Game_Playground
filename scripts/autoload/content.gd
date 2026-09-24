extends Node
## Autoload "Content": the single loaded ContentDatabase for the running game.

var db := ContentDatabase.new()


func _ready() -> void:
	db.load_all()
	if OS.is_debug_build():
		var validator := ContentValidator.new(db)
		if not validator.validate():
			push_error("Content validation failed:\n" + validator.report())
