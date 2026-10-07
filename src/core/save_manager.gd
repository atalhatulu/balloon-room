extends Node

const SAVE_PATH: String = "user://balloon_room_save.json"
const SAVE_TMP: String = "user://balloon_room_save.json.tmp"
const SAVE_BAK: String = "user://balloon_room_save.json.bak"

func has_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BAK):
		var state = load_full_state()
		return not state.is_empty()
	return false

func delete_save() -> bool:
	var deleted = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		deleted = true
	if FileAccess.file_exists(SAVE_BAK):
		DirAccess.remove_absolute(SAVE_BAK)
		deleted = true
	if FileAccess.file_exists(SAVE_TMP):
		DirAccess.remove_absolute(SAVE_TMP)
	return deleted

func save_full_state(state: Dictionary) -> bool:
	if state.is_empty():
		return false
		
	var json_string = JSON.stringify(state, "\t")
	
	# 1. Write to temporary file first
	var file = FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(json_string)
	file.flush()
	file.close()
	
	# 2. Verify temporary file before touching primary save
	var verify = _try_load(SAVE_TMP)
	if verify.is_empty():
		DirAccess.remove_absolute(SAVE_TMP)
		return false
		
	# 3. Create/update backup from current valid save
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BAK):
			DirAccess.remove_absolute(SAVE_BAK)
		DirAccess.copy_absolute(SAVE_PATH, SAVE_BAK)
		DirAccess.remove_absolute(SAVE_PATH)
		
	# 4. Atomic rename .tmp -> .json
	var err = DirAccess.rename_absolute(SAVE_TMP, SAVE_PATH)
	if err != OK:
		# Fallback if filesystem blocks atomic rename
		DirAccess.copy_absolute(SAVE_TMP, SAVE_PATH)
		DirAccess.remove_absolute(SAVE_TMP)
		
	return FileAccess.file_exists(SAVE_PATH)

func load_full_state() -> Dictionary:
	# 1. Try primary save file
	var state = _try_load(SAVE_PATH)
	if not state.is_empty():
		return state
		
	# 2. If primary is corrupted or missing, fallback to backup
	if FileAccess.file_exists(SAVE_BAK):
		push_warning("Primary save file corrupted or missing, restoring from backup...")
		state = _try_load(SAVE_BAK)
		if not state.is_empty():
			# Restore backup as primary save
			DirAccess.copy_absolute(SAVE_BAK, SAVE_PATH)
			return state
			
	return {}

func _try_load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
		
	var content = file.get_as_text()
	file.close()
	
	if content.strip_edges().is_empty():
		return {}
		
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result == OK and json.data is Dictionary:
		return json.data
		
	return {}
