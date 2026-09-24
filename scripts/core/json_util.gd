class_name JsonUtil
extends RefCounted
## Small helpers for reading JSON content files and converting data arrays.


## Parses a JSON file. Returns the parsed value, or null and appends to `errors` on failure.
static func load_file(path: String, errors: Array[String]) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("%s:%d: JSON parse error: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Lists files with `extension` (without dot) directly inside `dir_path`, sorted.
static func list_files(dir_path: String, extension: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name in dir.get_files():
		# Exported builds may list remapped files; strip the suffix Godot adds.
		var clean := file_name.trim_suffix(".remap")
		if clean.get_extension() == extension:
			out.append(dir_path.path_join(clean))
	out.sort()
	return out


## Converts a JSON array [x, y, z] into a Vector3 (missing components default to 0).
static func to_vector3(value: Variant) -> Vector3:
	if value is Array:
		var arr: Array = value
		return Vector3(
			float(arr[0]) if arr.size() > 0 else 0.0,
			float(arr[1]) if arr.size() > 1 else 0.0,
			float(arr[2]) if arr.size() > 2 else 0.0)
	return Vector3.ZERO


static func from_vector3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
