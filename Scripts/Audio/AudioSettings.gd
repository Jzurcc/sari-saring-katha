class_name AudioSettings
extends RefCounted

## Manages audio bus volumes, background muting, and settings persistence.
## Decouples audio server configuration and OS focus notifications from AudioManager.

const SETTINGS_PATH: String = "user://settings.cfg"

var mute_in_background: bool = false
var master_muted_by_user: bool = false

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var master_val: float = cfg.get_value("audio", "master", 0.8)
		var bgm_val: float = cfg.get_value("audio", "bgm", 0.6)
		var sfx_val: float = cfg.get_value("audio", "sfx", 0.9)
		var voices_val: float = cfg.get_value("audio", "voices", 0.9)
		mute_in_background = cfg.get_value("accessibility", "mute_in_background", false)

		_apply_bus_volume("Master", master_val)
		master_muted_by_user = (master_val <= 0.0)

		_apply_bus_volume("Music", bgm_val)
		_apply_bus_volume("SFX", sfx_val)
		_apply_bus_volume("Voices", voices_val)

func handle_application_focus(what: int) -> void:
	if not mute_in_background:
		return
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return

	match what:
		Node.NOTIFICATION_APPLICATION_FOCUS_OUT:
			AudioServer.set_bus_mute(master_idx, true)
		Node.NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(master_idx, master_muted_by_user)

func update_mute_in_background(value: bool) -> void:
	mute_in_background = value

func update_master_muted_by_user(value: bool) -> void:
	master_muted_by_user = value

func _apply_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val) if linear_val > 0.0 else -80.0)
		AudioServer.set_bus_mute(idx, linear_val <= 0.0)

