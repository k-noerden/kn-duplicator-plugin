@tool
extends Control

@onready var text_edit: TextEdit = $HBoxContainer/VBoxContainer/TextEdit
@onready var select_button: Button = $HBoxContainer/VBoxContainer/SelectButton
@onready var create_button: Button = $HBoxContainer/VBoxContainer/CreateButton
@onready var error_label: Label = $HBoxContainer/VBoxContainer/ErrorLabel
@onready var transformations_label: Label = $HBoxContainer/VBoxContainer2/TransformationsLabel

var current_path: String = ""

func _ready() -> void:
	select_button.icon = get_theme_icon("FileDialog", "EditorIcons")



func _on_select_button_pressed() -> void:
	# var dialog := ConfirmationDialog.new()
	# dialog.dialog_text = "Hej"
	# dialog.dialog_hide_on_ok = true
	# dialog.confirmed.connect(func() :
	# 	print(":)")
	# 	dialog.hide()
	# )
	# EditorInterface.popup_dialog_centered(dialog)
	# await dialog.visibility_changed
	# dialog.queue_free()
	# print("done")
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FileMode.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.Access.ACCESS_RESOURCES
	dialog.add_filter("*.tscn, *.scn", "Scenes")
	dialog.title = "Select a scene"
	add_child(dialog)
	dialog.popup_file_dialog()
	await dialog.visibility_changed
	dialog.queue_free()
	if dialog.current_file != "":
		current_path = dialog.current_path
	update()

func update():
	print("####")
	if text_edit.text == "":
		create_button.disabled = true
		error_label.text = "Please enter a new name"
		error_label.show()
		return
	var input = text_edit.text.strip_edges()
	var new_filename_base = input.to_lower().validate_filename().to_snake_case()
	var new_node_name = input.to_lower().validate_node_name().to_pascal_case()
	# print("new_filename_base: ", new_filename_base)
	# print("new_node_name: ", new_node_name)

	if not current_path:
		create_button.disabled = true
		error_label.text = "Please select an existing scene"
		error_label.show()
		return

	var current_base = current_path.get_file().get_basename().to_lower().validate_filename().to_snake_case()
	# print("current_base: ", current_base)
	var current_dir = current_path.get_base_dir()
	var parent_dir = current_dir.get_base_dir()
	var new_dir = "%s/%s" % [parent_dir, new_filename_base]
	var sub_directories = DirAccess.get_directories_at(current_dir)
	var sub_files = DirAccess.get_files_at(current_dir)
	if sub_directories.size() > 0:
		create_button.disabled = true
		error_label.text = "Can't copy subdirectories"
		error_label.show()
		return
	var transformations_strings = []
	transformations_strings.push_back("Create: " + new_dir)
	var transformations = {}
	for sub_file in sub_files:
		var sub_file_basename = sub_file.get_basename().to_lower().validate_filename().to_snake_case()
		# print("sub_file_basename: ", sub_file_basename)
		if sub_file_basename == current_base:
			# var new_name = "%s/%s.%s" % [new_dir, new_filename_base, sub_file.get_extension()]
			var new_name = "%s.%s" % [new_filename_base, sub_file.get_extension()]
			if transformations.has(new_name):
				create_button.disabled = true
				error_label.text = "Multiple files will be named " + new_name
				error_label.show()
				return
			transformations_strings.push_back("%s ➝ %s" % [sub_file, new_name])
			transformations[new_name] = true
		else:
			transformations_strings.push_back("%s" % [sub_file])
			transformations[sub_file] = true
	transformations_label.text = "\n".join(transformations_strings)
	# print(sub_directories)
	# print(sub_files)
	# var new_scene = "%s/%s" [current_dir, new_filename_base, extension]
	error_label.hide()
	create_button.disabled = false

func create():
	print("create")
	print(current_path)
	var cls := load(current_path)
	var node = cls.instantiate()
	var new_scene = PackedScene.new()
	var script_path = node.get_script().resource_path
	print("script path: ", script_path)
	# Save script specific properties, so they can be restored after changing the script.
	var properties = []
	for property in node.get_script().get_script_property_list():
		if property["name"] in node:
			properties.push_back([property["name"], node.get(property["name"])])
	node.name = "New"
	# node.set_script("res://test/new.gd") # Sets `script = "res://test/new.gd"` with no references to resource
	# node.set_script(node.get_script().duplicate()) # Subresource pointing to internal source code string
	# node.get_script().resource_path = load("res://test/new.gd")
	var new_script_path = "res://test/new.gd"
	node.set_script(load(new_script_path)) # This is it, but discards custom variables
	# Restore saved properties
	for property_pair in properties:
		node.set(property_pair[0], property_pair[1])

	# print("script path: ", node.get_script().resource_path)
	# Save scene
	var pack_result = new_scene.pack(node)
	if pack_result != OK:
		print("Pack failed: ", pack_result)
		return
	var save_result = ResourceSaver.save(new_scene, "res://test/new.tscn")
	if save_result != OK:
		print("Save failed: ", save_result)
	return


# func convert(dry_run: bool):
# 	var cls := load(current_path)
# 	var node = cls.instantiate()
# 	var new_scene = PackedScene.new()


# Ensure destination dir does not exist
# Ensure there are no subdirectories
# Ensure there is only one tscn file in the folder
# Ensure there is only one gd script in the folder
# The gd script must reduce to the same name as the scene
# All other files are ignored
# Ensure scenes script is the same as gd file
