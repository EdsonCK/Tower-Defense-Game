class_name ProgressStore
extends RefCounted
## Saves and loads permanent progress (diamonds, unlocked skills) and player settings so
## they survive restarts and game relaunches. Stored as JSON; unreadable or tampered
## files fall back to safe defaults. Tests set `save_path` to "" to stay in memory.

static var save_path: String = GameConfig.PROGRESS_SAVE_PATH


## Returns {"diamonds": int, "unlocked": Array, "auto_start": bool}.
static func load_progress() -> Dictionary:
	var progress: Dictionary = {"diamonds": 0, "unlocked": [], "auto_start": false}
	if save_path == "" or not FileAccess.file_exists(save_path):
		return progress
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK or not json.data is Dictionary:
		push_warning("Progress file %s is unreadable; starting fresh." % save_path)
		return progress
	var data: Dictionary = json.data
	var diamonds: Variant = data.get("diamonds", 0)
	if diamonds is float or diamonds is int:
		progress["diamonds"] = maxi(0, int(diamonds))
	var unlocked: Array = []
	var saved_ids: Variant = data.get("unlocked", [])
	if saved_ids is Array:
		for id: Variant in saved_ids:
			if id is String and SkillTree.SKILLS.has(id):
				unlocked.append(id)
	progress["unlocked"] = unlocked
	var auto_start: Variant = data.get("auto_start", false)
	progress["auto_start"] = auto_start is bool and auto_start
	return progress


static func save_progress(diamonds: int, unlocked: Array, auto_start: bool) -> void:
	if save_path == "":
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress to %s" % save_path)
		return
	file.store_string(JSON.stringify({"diamonds": diamonds, "unlocked": unlocked, "auto_start": auto_start}, "\t"))
