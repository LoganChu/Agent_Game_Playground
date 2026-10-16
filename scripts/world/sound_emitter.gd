class_name SoundEmitter
extends AudioStreamPlayer3D
## A prop's looping `sound` (Day 46): a lit beacon's fire, a charcoal clamp's embers. Plays
## once SoundBank has rendered it (renders are warmed when the region builds).
##
##   "sound": {"id": "fire", "offset": [0, 3.2, 0], "range": 16, "volume": 1.0}

const RANGE := 14.0

var sound_id := ""


static func build(spec: Dictionary) -> SoundEmitter:
	var emitter := SoundEmitter.new()
	emitter.name = "Sound"
	emitter.sound_id = str(spec.get("id", ""))
	emitter.position = JsonUtil.to_vector3(spec.get("offset", [0, 1, 0]))
	emitter.max_distance = float(spec.get("range", RANGE))
	emitter.unit_size = emitter.max_distance * 0.25
	emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	emitter.volume_db = linear_to_db(maxf(0.0001, float(spec.get("volume", 1.0))))
	emitter.bus = SoundBank.bus(Content.db, emitter.sound_id)
	return emitter


func _exit_tree() -> void:
	stop()
	stream = null


func _process(_delta: float) -> void:
	if not SoundBank.is_ready(Content.db, sound_id):
		return
	stream = SoundBank.stream(Content.db, sound_id)
	if stream:
		var length := stream.get_length()
		# Start somewhere in the loop, so two fires never crackle in step.
		play(fmod(float(get_instance_id() % 997) * 0.37, maxf(length, 0.01)))
	set_process(false)
