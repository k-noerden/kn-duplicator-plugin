@tool
extends EditorPlugin

var dock
var dock_button

func _enter_tree() -> void:
	dock = preload("res://addons/knduplicator/knduplicator_dock.tscn").instantiate()
	dock_button = add_control_to_bottom_panel(dock, "Duplicator")



func _exit_tree() -> void:
	remove_control_from_bottom_panel(dock)
	dock.queue_free()
