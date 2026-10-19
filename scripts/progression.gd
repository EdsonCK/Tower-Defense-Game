class_name Progression
extends RefCounted
## Permanent profile, separate from a run. Empty path = isolated in-memory fixture.

const SCHEMA := 1
var diamonds := 0
var unlocked: Array[String] = []
var save_error := ""
var _path: String
var _last_run := ""
var _last_wave := 0
var _primary_valid := false
var _write_blocked := false


func _init(path: String = "user://progression.json") -> void:
	_path = ProjectSettings.globalize_path(path) if not path.is_empty() else ""


func has_skill(id: String) -> bool:
	return unlocked.has(id)


func purchase_error(id: String) -> String:
	if not SkillCatalog.NODES.has(id):
		return "Unknown skill"
	if has_skill(id):
		return "Already unlocked"
	var node: Dictionary = SkillCatalog.NODES[id]
	if not node.requires.is_empty() and not has_skill(node.requires):
		return "Requires " + str(SkillCatalog.NODES[node.requires].title)
	if diamonds < int(node.cost):
		return "Not enough diamonds"
	return ""


func purchase(id: String) -> bool:
	if not purchase_error(id).is_empty():
		return false
	var cost := int(SkillCatalog.NODES[id].cost)
	diamonds -= cost
	unlocked.append(id)
	if not save_profile():
		unlocked.erase(id)
		diamonds += cost
		return false
	return true


func award_wave(run_id: String, wave: int) -> bool:
	if run_id.is_empty() or wave < 1 or (_last_run == run_id and wave <= _last_wave):
		return false
	diamonds += 1
	_last_run = run_id
	_last_wave = wave
	# On a disk failure keep the earned diamond in memory and expose retry status.
	save_profile()
	return true


func gold_reward(base: int) -> int:
	var percent := 100 + (20 if has_skill("salvage") else 0) + (20 if has_skill("gold_mastery") else 0)
	return floori(base * percent / 100.0)


func apply_enemy_nerfs(profile: EnemyProfile) -> void:
	if has_skill("sluggish"):
		profile.speed *= 0.9
	if has_skill("fragile"):
		profile.hit_points = maxi(1, roundi(profile.hit_points * 0.85))
		profile.shield = maxi(0, roundi(profile.shield * 0.85))


func load_profile() -> bool:
	if _path.is_empty():
		return true
	for candidate in [_path, _path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK or not _valid_document(parser.data):
			continue
		var data: Dictionary = parser.data
		diamonds = int(data.diamonds)
		unlocked.assign(data.unlocked)
		_last_run = data.last_run
		_last_wave = int(data.last_wave)
		_primary_valid = candidate == _path
		save_error = "" if _primary_valid else "Recovered profile from backup. Use Retry Save to restore the primary file."
		return true
	if FileAccess.file_exists(_path) or FileAccess.file_exists(_path + ".bak"):
		_write_blocked = true
		save_error = "Profile could not be read. Original files preserved; progress is in memory until the save is repaired."
		return false
	return true


func _valid_document(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if data.get("schema") != SCHEMA or not _whole_number(data.get("diamonds")) or not _whole_number(data.get("last_wave")):
		return false
	if not data.get("last_run") is String or not data.get("unlocked") is Array:
		return false
	var seen: Array[String] = []
	for id in data.unlocked:
		if not id is String or not SkillCatalog.NODES.has(id) or seen.has(id):
			return false
		seen.append(id)
	for id in seen:
		var requirement: String = SkillCatalog.NODES[id].requires
		if not requirement.is_empty() and not seen.has(requirement):
			return false
	return true


func _whole_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1000000000 and floorf(float(value)) == float(value)


func save_profile() -> bool:
	if _path.is_empty():
		save_error = ""
		return true
	if _write_blocked:
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if directory_error != OK:
		save_error = "Cannot create profile directory; progress remains in memory."
		return false
	var file := FileAccess.open(_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "Cannot write profile; progress remains in memory."
		return false
	file.store_string(JSON.stringify({"schema": SCHEMA, "diamonds": diamonds, "unlocked": unlocked, "last_run": _last_run, "last_wave": _last_wave}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		save_error = "Profile write failed; progress remains in memory."
		return false
	if _primary_valid and FileAccess.file_exists(_path):
		if DirAccess.copy_absolute(_path, _path + ".bak") != OK:
			save_error = "Cannot back up profile; progress remains in memory."
			return false
	if DirAccess.rename_absolute(_path + ".tmp", _path) != OK:
		save_error = "Cannot replace profile; progress remains in memory."
		return false
	_primary_valid = true
	save_error = ""
	return true
