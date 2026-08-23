extends Node

const SAVE_PATH: String = "user://balloon_room_save.json"

func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var state = load_full_state()
	return not state.is_empty()

func delete_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		return true
	return false

func save_full_state(state: Dictionary) -> bool:
	var json_string = JSON.stringify(state, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		return true
	return false

func load_full_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
		
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(content)
	if parse_result == OK and json.data is Dictionary:
		return json.data
	return {}
