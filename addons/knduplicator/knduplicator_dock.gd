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
	create_button.icon = get_theme_icon("Add", "EditorIcons")


func _on_select_button_pressed() -> void:
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
	var error = check()
	if error:
		create_button.disabled = true
		error_label.text = error
		error_label.show()
		return false
	create_button.disabled = false
	error_label.hide()
	return true

func check():
	# print("####")
	transformations_label.text = ""
	# Ensure name is entered
	if text_edit.text.strip_edges() == "":
		return "Please enter a new name"
	# Ensure scene is selected
	if not current_path:
		return "Please select an existing scene"

	var input = text_edit.text.strip_edges()
	var new_filename_base = input.to_lower().validate_filename().to_snake_case()
	var new_node_name = input.to_lower().validate_node_name().to_pascal_case()
	var current_dir = current_path.get_base_dir()
	var parent_dir = current_dir.get_base_dir()
	var destination_dir = "%s/%s" % [parent_dir, new_filename_base]
	var new_scene_path = "%s/%s.tscn" % [destination_dir, new_filename_base]
	var new_script_path = "%s/%s.gd" % [destination_dir, new_filename_base]

	# Ensure destination dir does not exist
	if DirAccess.dir_exists_absolute(destination_dir) or FileAccess.file_exists(destination_dir):
		return "The destination directory already exists"

	# Ensure there are no sub directories
	var sub_directories = DirAccess.get_directories_at(current_dir)
	if sub_directories.size() > 0:
		return "Can't copy from subdirectories"

	var cls = load(current_path)
	var node = cls.instantiate()
	var node_name = node.name
	var script_path = node.get_script().resource_path if node.get_script() else ""

	# Ensure script is in current dir
	if script_path and script_path.get_base_dir() != current_dir:
		return "Script is not in current dir"

	var sub_files = DirAccess.get_files_at(current_dir)
	# print("current_dir: ", current_dir)
	# print("current_path: ", current_path)
	# print("script_path: ", script_path)
	for sub_file in sub_files:
		# print("sub_file: ", sub_file)
		if sub_file == current_path.get_file():
			continue
		if script_path and sub_file == script_path.get_file():
			continue
		var extension = sub_file.get_extension()
		if extension == "tscn" or extension == "scn":
			return "Multiple scenes in directory"
		if extension == "gd":
			return "Multiple scripts in directory"
		# ignoring file
		continue

	if script_path:
		transformations_label.text = "Create %s\nCopy: %s ➝ %s\nCopy: %s ➝ %s\nNode: %s ➝ %s" % [
			destination_dir,
			current_path.get_file(),
			new_scene_path.get_file(),
			script_path.get_file(),
			new_script_path.get_file(),
			node_name,
			new_node_name,
			]
	else:
		transformations_label.text = "Create %s\nCopy: %s ➝ %s\nNode: %s ➝ %s" % [
			destination_dir,
			current_path.get_file(),
			new_scene_path.get_file(),
			# script_path.get_file(),
			# new_script_path.get_file(),
			node_name,
			new_node_name,
			]

	return null



func create():
	var error
	if not update():
		return
	var cls = load(current_path)
	var node = cls.instantiate()

	var input = text_edit.text.strip_edges()
	var new_filename_base = input.to_lower().validate_filename().to_snake_case()
	var new_node_name = input.to_lower().validate_node_name().to_pascal_case()
	var current_dir = current_path.get_base_dir()
	var parent_dir = current_dir.get_base_dir()
	var destination_dir = "%s/%s" % [parent_dir, new_filename_base]
	var new_scene_path = "%s/%s.tscn" % [destination_dir, new_filename_base]
	var new_script_path = "%s/%s.gd" % [destination_dir, new_filename_base]
	var node_name = node.name

	error = DirAccess.make_dir_absolute(destination_dir)
	if error != OK:
		error_label.text = "Could not make dir: %s" % destination_dir
		error_label.show()
		return

	if node.get_script():
		var script_path = node.get_script().resource_path
		# Save script specific properties, so they can be restored after changing the script.
		var properties = []
		for property in node.get_script().get_script_property_list():
			if property["name"] in node:
				properties.push_back([property["name"], node.get(property["name"])])
		# Copy script
		error = DirAccess.copy_absolute(script_path, new_script_path)
		if error != OK:
			error_label.text = "Could not make dir: %s" % destination_dir
			error_label.show()
			return
		var new_script = load(new_script_path)
		if not new_script:
			error_label.text = "Could not load script: %s" % new_script_path
			error_label.show()
			return
		node.set_script(new_script) # Discards exported variables from previous script
		# Restore saved properties
		for property_pair in properties:
			node.set(property_pair[0], property_pair[1])

	node.name = new_node_name

	# Save scene
	var new_scene = PackedScene.new()
	error = new_scene.pack(node)
	if error != OK:
		error_label.text = "Packing scene failed: " + error
		error_label.show()
		return
	error = ResourceSaver.save(new_scene, new_scene_path)
	if error != OK:
		error_label.text = "Saving scene failed: " + error
		error_label.show()
		return

	current_path = ""
	transformations_label.text = ""
	text_edit.text = ""
	create_button.disabled = true





# . Ensure name is entered
# . Ensure scene is selected
#
# . Ensure destination dir does not exist
# . Ensure there are no subdirectories
# . Ensure there is only one tscn file in the folder
# . Ensure there is only one gd script in the folder
# The gd script must reduce to the same name as the scene
# Ensure scenes script is the same as gd file
#
# All other files are ignored
