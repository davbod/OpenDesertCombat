## Test Desert Map Scene Generator
## Run this in the Godot editor or as a tool script to generate the test scene.
## For now, we create the .tscn file directly.

## This is the main test map scene — a flat desert terrain with a helicopter,
## player spawn, sun, and basic environment.

@tool
extends Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	print("OpenDesertCombat v0.1.0 — Test Desert Map Loaded")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
