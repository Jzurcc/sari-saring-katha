extends Node

const SAVE_PATH = "user://inventory_save.json"

func save_game(stock_data: Dictionary) -> void:
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        var json_string = JSON.stringify(stock_data)
        file.store_string(json_string)
        print("[SaveManager] Game saved successfully.")

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        print("[SaveManager] No save file found.")
        return {}
    
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file:
        var json_string = file.get_as_text()
        var json = JSON.new()
        var error = json.parse(json_string)
        if error == OK:
            print("[SaveManager] Game loaded successfully.")
            return json.data as Dictionary
        else:
            push_error("[SaveManager] JSON Parse Error: ", json.get_error_message())
    
    return {}

func clear_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        var dir = DirAccess.open("user://")
        dir.remove("inventory_save.json")
        print("[SaveManager] Save file cleared.")
