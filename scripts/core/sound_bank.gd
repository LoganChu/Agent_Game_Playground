class_name SoundBank
extends RefCounted
## The game's sounds by id (data/audio.json "sounds"), rendered once per session and shared
## (Day 46). A recipe renders with SoundSynth (seeded by its id, so it sounds the same every
## run); a `file` entry loads that stream instead. `warm` renders off the main thread
## (WorkerThreadPool) so a region's ambience doesn't hitch the frame it loads; `stream`
## waits for a render in flight, or renders on the spot.

static var _streams: Dictionary = {}  # id -> AudioStream
static var _tasks: Dictionary = {}    # id -> WorkerThreadPool task id
static var _done: Dictionary = {}     # id -> AudioStream, written by worker threads
static var _mutex := Mutex.new()


## The bus a sound plays on (its `bus`, else Effects).
static func bus(db: ContentDatabase, id: String) -> String:
	return str((db.sounds.get(id, {}) as Dictionary).get("bus", "Effects"))


## Starts rendering each of `ids` not rendered or rendering yet, in the background.
static func warm(db: ContentDatabase, ids: Array) -> void:
	for id: String in ids:
		if _streams.has(id) or _tasks.has(id) or not db.sounds.has(id):
			continue
		var entry: Dictionary = db.sounds[id]
		if entry.has("file"):
			_streams[id] = load(str(entry["file"]))
			continue
		_tasks[id] = WorkerThreadPool.add_task(_render_task.bind(id, entry), false, "SoundBank " + id)


## Whether `id` can be played without waiting (rendered, or not a sound at all).
static func is_ready(db: ContentDatabase, id: String) -> bool:
	if _streams.has(id) or not db.sounds.has(id):
		return true
	if not _tasks.has(id):
		return false
	_mutex.lock()
	var finished := _done.has(id)
	_mutex.unlock()
	if finished:
		_collect(id)
	return finished


## The stream for `id` (null if no such sound), waiting for or doing its render.
static func stream(db: ContentDatabase, id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if not db.sounds.has(id):
		return null
	if not _tasks.has(id):
		warm(db, [id])
	if _tasks.has(id):
		_collect(id)
	return _streams.get(id)


## Forgets every rendered sound (tests).
static func clear() -> void:
	for id: String in _tasks.keys():
		_collect(id)
	_streams.clear()


static func _collect(id: String) -> void:
	WorkerThreadPool.wait_for_task_completion(_tasks[id])
	_tasks.erase(id)
	_mutex.lock()
	_streams[id] = _done.get(id)
	_done.erase(id)
	_mutex.unlock()


static func _render_task(id: String, recipe: Dictionary) -> void:
	var rendered := SoundSynth.build(recipe, id.hash())
	_mutex.lock()
	_done[id] = rendered
	_mutex.unlock()
