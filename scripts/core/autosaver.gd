class_name Autosaver
extends Node
## Decides when the game writes the autosave slot (Day 106). Main asks for one on arrival in
## a new region (travel in play) and when a quest starts, moves on or finishes; the save is
## written at the next quiet moment — `is_safe` (no dialogue, menu or card holding input, the
## title closed, the Wakebearer out of the Greying) — so a reload never lands mid-conversation
## or in the fog. Story requests are spaced at least `min_interval_msec` apart (a beat that
## sets several quests writes once); an arrival goes through as soon as it is safe.
##
## Pauses with the tree (the pause menu); Return to title and Quit save directly
## (SaveSystem.autosave). A new game, a loaded save or the title cancel a pending request.

## Emitted after each autosave this node writes.
signal autosaved

## The least time between two story-driven autosaves.
const MIN_INTERVAL_MSEC := 30000

## `func() -> bool`: whether now is a quiet moment to save (set by main).
var is_safe: Callable = func() -> bool: return true
var min_interval_msec := MIN_INTERVAL_MSEC
## Ticks (msec) of the last autosave written; story requests wait until the interval is up.
var last_msec := -MIN_INTERVAL_MSEC
## Saves written by this node (for tests and the smoke run).
var count := 0
var _pending := false
var _urgent := false


## Asks for an autosave at the next quiet moment. `urgent` (an arrival) skips the interval.
func request(urgent: bool = false) -> void:
	_pending = true
	_urgent = _urgent or urgent


## Drops a pending request (the world was reset or replaced).
func cancel() -> void:
	_pending = false
	_urgent = false


func is_pending() -> bool:
	return _pending


func _process(_delta: float) -> void:
	try_now(Time.get_ticks_msec())


## Writes the pending autosave if one is due at `now_msec` and it is safe; true if written.
func try_now(now_msec: int) -> bool:
	if not _pending:
		return false
	if not SaveSystem.autosave_allowed():
		cancel()
		return false
	if not _urgent and now_msec - last_msec < min_interval_msec:
		return false
	if not is_safe.call():
		return false
	cancel()
	if not SaveSystem.autosave():
		return false
	last_msec = now_msec
	count += 1
	autosaved.emit()
	return true
