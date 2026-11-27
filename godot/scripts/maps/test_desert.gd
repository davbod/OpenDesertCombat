## Test desert map (the main scene): flat 8 km desert, two main bases, two neutral flags and
## the vehicle spawns. The layout lives in test_desert.tscn; this script only starts the map.

@tool
extends Node3D
class_name TestDesertMap

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	print("OpenDesertCombat v%s — Test Desert Map Loaded" % version)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
