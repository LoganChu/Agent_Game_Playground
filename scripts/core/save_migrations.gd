class_name SaveMigrations
extends RefCounted
## Brings an old save's data up to the current SaveSystem.SAVE_VERSION, one version at a time
## (Day 109). Each step is a pure function `Dictionary -> Dictionary` registered in `_step`
## under the version it upgrades *from*; it must set nothing but what that version changed and
## must never fail on a well-formed save of its own version.
##
## History:
##   1 → 2 (Day 109): `play_seconds` (0: time before Day 109 wasn't counted) and `playthrough`
##          ("": unknown — the autosave never mistakes a legacy save for the current story).
##
## To change the save format: bump SaveSystem.SAVE_VERSION, add a `_from_<n>` step and a line
## above, and a case in tests/test_save_migrations.gd with a real save of the old version.

## The oldest version that can still be upgraded.
const OLDEST := 1


## {ok: bool, data: Dictionary (upgraded, a copy), from: int, error: String}. A save from a
## newer build, or with no or a too-old version, is refused (ok false, error says why).
static func migrate(save: Dictionary, current: int) -> Dictionary:
	var version := int(save.get("version", 0))
	var result := {"ok": false, "data": {}, "from": version, "error": ""}
	if version > current:
		result["error"] = "made by a newer version of the game"
		return result
	if version < OLDEST:
		result["error"] = "too old or not a save"
		return result
	var data: Dictionary = save.duplicate(true)
	while version < current:
		var step := _step(version)
		if not step.is_valid():
			result["error"] = "no upgrade from version %d" % version
			return result
		data = step.call(data)
		version += 1
		data["version"] = version
	result["ok"] = true
	result["data"] = data
	return result


static func _step(from_version: int) -> Callable:
	match from_version:
		1:
			return _from_1
	return Callable()


static func _from_1(data: Dictionary) -> Dictionary:
	data["play_seconds"] = 0.0
	data["playthrough"] = ""
	return data
