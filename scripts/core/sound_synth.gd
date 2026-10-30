class_name SoundSynth
extends RefCounted
## Procedural placeholder sound (Day 46): renders a small JSON recipe (data/audio.json
## "sounds") into an AudioStreamWAV, so the game has a soundscape without committing audio
## files. Deterministic for a given recipe and seed. Pure: no nodes, usable from tests.
##
## Recipe kinds (every kind takes `length` s, `gain` 0..1 peak, and, unless it loops, an
## envelope: `attack` s linear rise, `decay` s exponential fall (0 = hold), `release` s fade
## at the end):
##   noise    `color` white|pink|brown, `lowpass`/`highpass` Hz, `swell` s (a slow rise
##            and fall, the sea) with `swell_depth` 0..1, `gusts` s (random slow surges, the
##            wind) with `gust_depth` 0..1
##   crackle  pops: `rate` per second, `pop` s each, `lowpass` Hz, `bed` 0..1 of brown noise
##   tone     `freq` Hz, `harmonics` [amp of 1st, 2nd…], `slide` (end freq factor),
##            `vibrato` Hz with `vibrato_depth` (fraction), `noise` 0..1 breath mixed in
##   chirps   calls scattered over the length: `rate` per second, `freq` Hz (±`spread`),
##            `call` s each, `slide`, `pulses` (calls per burst, e.g. a gull's kee-kee)
##   chime    `notes` [Hz…] struck `gap` s apart, each ringing `ring` s
##   melody   `notes` [[pitch, beats]…] played in turn at `tempo` bpm (Day 74, the music): a
##            pitch is a name ("D4", "F#3", "Bb2"), Hz, or "-" for a rest; each note comes in
##            over `note_attack` s, then rings down over `ring` s (plucked, may overlap the
##            next) or, with no `ring`, holds `legato` of its length and lets go over
##            `note_release` s (bowed, blown); `harmonics`, `vibrato`/`vibrato_depth`, `lowpass`
##   mix      `parts` [recipes], summed (each at its own gain), then the whole at `gain`
## A recipe with `loop: true` is rendered a little long and its tail crossfaded into its
## head, so it repeats without a seam.

const MIX_RATE := 22050
const KINDS: Array[String] = ["noise", "crackle", "tone", "chirps", "chime", "melody", "mix"]
const NOISE_COLORS: Array[String] = ["white", "pink", "brown"]
## Seconds of a loop's tail crossfaded into its head.
const LOOP_FADE := 0.4
## Longest recipe allowed (memory: 20 s mono 16-bit at MIX_RATE is ~0.9 MB).
const MAX_LENGTH := 20.0
## Seconds faded at a one-shot's very end so it never clicks off.
const TAIL := 0.005
## Semitones above C of each note letter (melody pitches).
const NOTE_STEPS := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## The stream for `recipe`: 16-bit mono at MIX_RATE, looping forward if the recipe loops.
static func build(recipe: Dictionary, seed_value: int = 0) -> AudioStreamWAV:
	var samples := render(recipe, seed_value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	stream.data = bytes
	if bool(recipe.get("loop", false)):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


## The recipe's samples (-1..1), seamless if it loops.
static func render(recipe: Dictionary, seed_value: int = 0) -> PackedFloat32Array:
	var count := sample_count(recipe)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + int(recipe.get("seed", 0))
	if not bool(recipe.get("loop", false)):
		return _render(recipe, count, rng, true)
	var fade := int(LOOP_FADE * MIX_RATE)
	var long := _render(recipe, count + fade, rng, false)
	var out := long.slice(0, count)
	for i in fade:
		var t := float(i) / fade
		out[i] = long[i] * t + long[count + i] * (1.0 - t)
	return out


## Samples in one play of `recipe` (its loop length, for a loop).
static func sample_count(recipe: Dictionary) -> int:
	return maxi(1, int(clampf(float(recipe.get("length", 1.0)), 0.01, MAX_LENGTH) * MIX_RATE))


## Renders `count` samples, applies the envelope (one-shots) and normalizes to `gain`.
static func _render(recipe: Dictionary, count: int, rng: RandomNumberGenerator, shaped: bool) -> PackedFloat32Array:
	var out: PackedFloat32Array
	match str(recipe.get("kind", "noise")):
		"noise":
			out = _noise(recipe, count, rng)
		"crackle":
			out = _crackle(recipe, count, rng)
		"tone":
			out = _tone(recipe, count, rng)
		"chirps":
			out = _chirps(recipe, count, rng)
		"chime":
			out = _chime(recipe, count, rng)
		"melody":
			out = _melody(recipe, count)
		"mix":
			out = PackedFloat32Array()
			out.resize(count)
			for part: Dictionary in recipe.get("parts", []):
				var sub := _render(part, count if not part.has("length") else mini(count, sample_count(part)), rng, true)
				for i in sub.size():
					out[i] += sub[i]
		_:
			out = PackedFloat32Array()
			out.resize(count)
	if shaped:
		_envelope(out, recipe)
	_normalize(out, float(recipe.get("gain", 0.8)))
	return out


static func _noise(recipe: Dictionary, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _colored_noise(str(recipe.get("color", "white")), count, rng)
	_filter(out, float(recipe.get("lowpass", 0.0)), float(recipe.get("highpass", 0.0)))
	var swell := float(recipe.get("swell", 0.0))
	if swell > 0.0:
		# Whole cycles over the loop length, so the swell lines up with itself.
		var cycles := maxf(1.0, roundf(float(count) / MIX_RATE / swell))
		var depth := clampf(float(recipe.get("swell_depth", 0.5)), 0.0, 1.0)
		for i in count:
			var s := 0.5 - 0.5 * cos(TAU * cycles * i / count)
			out[i] *= 1.0 - depth + depth * s * s
	var gusts := float(recipe.get("gusts", 0.0))
	if gusts > 0.0:
		var curve := _slow_curve(count, gusts, rng)
		var depth := clampf(float(recipe.get("gust_depth", 0.5)), 0.0, 1.0)
		for i in count:
			out[i] *= 1.0 - depth + depth * curve[i]
	return out


static func _crackle(recipe: Dictionary, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := _colored_noise("brown", count, rng)
	var bed := clampf(float(recipe.get("bed", 0.15)), 0.0, 1.0)
	var chance := float(recipe.get("rate", 8.0)) / MIX_RATE
	var fall := exp(-1.0 / maxf(1.0, float(recipe.get("pop", 0.004)) * MIX_RATE))
	var env := 0.0
	for i in count:
		if rng.randf() < chance:
			env = maxf(env, rng.randf_range(0.3, 1.0))
		env *= fall
		out[i] = out[i] * bed * 0.3 + rng.randf_range(-1.0, 1.0) * env
	_filter(out, float(recipe.get("lowpass", 4000.0)), float(recipe.get("highpass", 0.0)))
	return out


static func _tone(recipe: Dictionary, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	_add_tone(out, 0, count, float(recipe.get("freq", 440.0)), recipe, rng)
	var breath := clampf(float(recipe.get("noise", 0.0)), 0.0, 1.0)
	if breath > 0.0:
		var hiss := _colored_noise("pink", count, rng)
		_filter(hiss, float(recipe.get("lowpass", 3000.0)), float(recipe.get("highpass", 200.0)))
		_normalize(hiss, 1.0)
		for i in count:
			out[i] = out[i] * (1.0 - breath) + hiss[i] * breath * 0.6
	return out


static func _chirps(recipe: Dictionary, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var rate := maxf(0.01, float(recipe.get("rate", 0.5)))
	var call_len := int(maxf(0.01, float(recipe.get("call", 0.2))) * MIX_RATE)
	var pulses := maxi(1, int(recipe.get("pulses", 1)))
	var spread := float(recipe.get("spread", 0.1))
	var shape := {"harmonics": recipe.get("harmonics", [1.0, 0.25]), "slide": recipe.get("slide", 1.0),
		"vibrato": recipe.get("vibrato", 0.0), "vibrato_depth": recipe.get("vibrato_depth", 0.0)}
	var t := rng.randf_range(0.2, 1.0) / rate
	while true:
		var start := int(t * MIX_RATE)
		if start + call_len * pulses >= count:
			break
		var freq := float(recipe.get("freq", 1200.0)) * rng.randf_range(1.0 - spread, 1.0 + spread)
		var loud := rng.randf_range(0.4, 1.0)
		for p in pulses:
			_add_tone(out, start + int(p * call_len * 1.3), call_len, freq * (1.0 - 0.04 * p), shape, rng, loud, true)
		t += rng.randf_range(0.4, 1.6) / rate
	return out


static func _chime(recipe: Dictionary, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var gap := int(float(recipe.get("gap", 0.12)) * MIX_RATE)
	var ring := int(float(recipe.get("ring", 0.6)) * MIX_RATE)
	var shape := {"harmonics": recipe.get("harmonics", [1.0, 0.0, 0.3]), "ring_decay": float(recipe.get("ring", 0.6)) * 0.35}
	var notes: Array = recipe.get("notes", [880.0])
	for n in notes.size():
		var start := n * gap
		if start < count:
			_add_tone(out, start, mini(ring, count - start), float(notes[n]), shape, rng)
	return out


static func _melody(recipe: Dictionary, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var beat := beat_seconds(recipe)
	var t := 0.0
	for note: Variant in recipe.get("notes", []):
		var pitch: Variant = note[0] if note is Array and not (note as Array).is_empty() else note
		var beats := float(note[1]) if note is Array and (note as Array).size() > 1 else 1.0
		var hz := note_hz(pitch)
		if hz > 0.0:
			_add_note(out, int(t * MIX_RATE), hz, beats * beat, recipe)
		t += beats * beat
	_filter(out, float(recipe.get("lowpass", 0.0)), float(recipe.get("highpass", 0.0)))
	return out


## Seconds per beat of a melody.
static func beat_seconds(recipe: Dictionary) -> float:
	return 60.0 / maxf(1.0, float(recipe.get("tempo", 60.0)))


## Seconds from a melody's first note to the end of its last (rests included).
static func melody_seconds(recipe: Dictionary) -> float:
	var beats := 0.0
	for note: Variant in recipe.get("notes", []):
		beats += float(note[1]) if note is Array and (note as Array).size() > 1 else 1.0
	return beats * beat_seconds(recipe)


## Hz of a melody pitch: a note name ("A4" = 440, "F#3", "Bb2"), a number of Hz, 0 for a rest
## ("-" or ""), -1 if it can't be read.
static func note_hz(pitch: Variant) -> float:
	if pitch is float or pitch is int:
		return float(pitch) if float(pitch) >= 0.0 else -1.0
	var text := str(pitch).strip_edges()
	if text.is_empty() or text == "-":
		return 0.0
	var letter := text.substr(0, 1).to_upper()
	if not NOTE_STEPS.has(letter):
		return -1.0
	var semis: int = NOTE_STEPS[letter]
	var rest := text.substr(1)
	if rest.begins_with("#"):
		semis += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semis -= 1
		rest = rest.substr(1)
	if not rest.is_valid_int():
		return -1.0
	var midi := (int(rest) + 1) * 12 + semis
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## One melody note of `seconds` at `start`: plucked (rings down over the recipe's `ring`) or
## held (`legato` of its length, then `note_release`).
static func _add_note(out: PackedFloat32Array, start: int, hz: float, seconds: float, recipe: Dictionary) -> void:
	# Only the sounding partials: [multiple, amplitude].
	var partials: Array[Vector2] = []
	var harmonics: Array = recipe.get("harmonics", [1.0, 0.3])
	for k in harmonics.size():
		if float(harmonics[k]) != 0.0:
			partials.append(Vector2(k + 1, float(harmonics[k])))
	var attack := maxf(0.001, float(recipe.get("note_attack", 0.02))) * MIX_RATE
	var ring := float(recipe.get("ring", 0.0))
	var release := maxf(0.005, float(recipe.get("note_release", 0.15))) * MIX_RATE
	var held := clampf(float(recipe.get("legato", 0.9)), 0.05, 1.0) * seconds * MIX_RATE
	var vib_rate := float(recipe.get("vibrato", 0.0))
	var vib_depth := float(recipe.get("vibrato_depth", 0.0))
	# A plucked note is cut once it has rung down to ~0.3 %.
	var length := int(ring * 2.0 * MIX_RATE) if ring > 0.0 else int(held + release)
	var fall := exp(-1.0 / (ring * 0.35 * MIX_RATE)) if ring > 0.0 else 1.0
	var env := 1.0
	var phase := 0.0
	for i in length:
		var at := start + i
		if at >= out.size():
			break
		var f := hz
		if vib_rate > 0.0:
			# The vibrato comes in after the note has spoken.
			f *= 1.0 + vib_depth * minf(1.0, i / (0.25 * MIX_RATE)) * sin(TAU * vib_rate * i / MIX_RATE)
		phase += TAU * f / MIX_RATE
		var v := 0.0
		for partial in partials:
			v += partial.y * sin(phase * partial.x)
		var shape := minf(1.0, i / attack)
		if ring > 0.0:
			shape *= env
			env *= fall
		elif i > held:
			shape *= maxf(0.0, 1.0 - (i - held) / release)
		out[at] += v * shape


## Adds a tone of `length` samples at `start` (phase-continuous; `slide`, `vibrato`, its own
## `ring_decay` s, or a sine bump over its length when `bump`).
static func _add_tone(out: PackedFloat32Array, start: int, length: int, freq: float, shape: Dictionary, _rng: RandomNumberGenerator, loud: float = 1.0, bump: bool = false) -> void:
	var harmonics: Array = shape.get("harmonics", [1.0])
	var slide := float(shape.get("slide", 1.0))
	var vib_rate := float(shape.get("vibrato", 0.0))
	var vib_depth := float(shape.get("vibrato_depth", 0.0))
	var decay := float(shape.get("ring_decay", 0.0))
	var fall := exp(-1.0 / (decay * MIX_RATE)) if decay > 0.0 else 1.0
	var env := 1.0
	var phase := 0.0
	for i in length:
		var at := start + i
		if at >= out.size():
			break
		var u := float(i) / length
		var f := freq * lerpf(1.0, slide, u)
		if vib_rate > 0.0:
			f *= 1.0 + vib_depth * sin(TAU * vib_rate * i / MIX_RATE)
		phase += TAU * f / MIX_RATE
		var v := 0.0
		for k in harmonics.size():
			v += float(harmonics[k]) * sin(phase * (k + 1))
		if bump:
			v *= sin(PI * u)
		out[at] += v * env * loud
		env *= fall


static func _colored_noise(color: String, count: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in count:
		var w := rng.randf_range(-1.0, 1.0)
		match color:
			"pink":
				# Paul Kellet's economy pink filter.
				b0 = 0.99765 * b0 + w * 0.0990460
				b1 = 0.96300 * b1 + w * 0.2965164
				b2 = 0.57000 * b2 + w * 1.0526913
				out[i] = (b0 + b1 + b2 + w * 0.1848) * 0.2
			"brown":
				b0 = (b0 + 0.02 * w) / 1.02
				out[i] = b0 * 3.5
			_:
				out[i] = w
	return out


## Two-pole low-pass and one-pole high-pass in place (0 Hz = off).
static func _filter(out: PackedFloat32Array, lowpass: float, highpass: float) -> void:
	if lowpass > 0.0:
		var a := 1.0 - exp(-TAU * lowpass / MIX_RATE)
		var y1 := 0.0
		var y2 := 0.0
		for i in out.size():
			y1 += a * (out[i] - y1)
			y2 += a * (y1 - y2)
			out[i] = y2
	if highpass > 0.0:
		var a := 1.0 - exp(-TAU * highpass / MIX_RATE)
		var low := 0.0
		for i in out.size():
			low += a * (out[i] - low)
			out[i] -= low


## A smooth random 0..1 curve with a new value every ~`period` s (cosine-eased), wrapping so
## its end meets its start.
static func _slow_curve(count: int, period: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var steps := maxi(2, int(roundf(float(count) / MIX_RATE / period)))
	var points: Array[float] = []
	for s in steps:
		points.append(rng.randf())
	var out := PackedFloat32Array()
	out.resize(count)
	var per := float(count) / steps
	for i in count:
		var f := i / per
		var k := int(f)
		var u := 0.5 - 0.5 * cos(PI * (f - k))
		out[i] = lerpf(points[k % steps], points[(k + 1) % steps], u)
	return out


static func _envelope(out: PackedFloat32Array, recipe: Dictionary) -> void:
	var attack := int(float(recipe.get("attack", 0.0)) * MIX_RATE)
	var decay := float(recipe.get("decay", 0.0))
	var fall := exp(-1.0 / (decay * MIX_RATE)) if decay > 0.0 else 1.0
	var release := maxi(int(float(recipe.get("release", 0.0)) * MIX_RATE), int(TAIL * MIX_RATE))
	var n := out.size()
	var env := 1.0
	for i in n:
		var a := float(i) / attack if i < attack else 1.0
		if i >= attack:
			env *= fall
		var r := float(n - 1 - i) / release if n - 1 - i < release else 1.0
		out[i] *= a * env * r


static func _normalize(out: PackedFloat32Array, gain: float) -> void:
	var peak := 0.0
	for v in out:
		peak = maxf(peak, absf(v))
	if peak > 0.0:
		var k := clampf(gain, 0.0, 1.0) / peak
		for i in out.size():
			out[i] *= k


## Peak absolute sample (tests).
static func peak(samples: PackedFloat32Array) -> float:
	var p := 0.0
	for v in samples:
		p = maxf(p, absf(v))
	return p
