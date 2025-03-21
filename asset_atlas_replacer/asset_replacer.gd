@tool
extends EditorPlugin

var scene: Node = preload("res://addons/asset_atlas_replacer/asset_replacer.tscn").instantiate()


const text_types : PackedStringArray = ["tscn", "tres", "gd"]
const img_types : PackedStringArray = ["svg", "png", "jpg", "jpeg", "webp", "bmp"]
const atlas_types : PackedStringArray = ["tres", "res"]

var button : Button
var atlas_path_node : TextEdit
var delete_button : CheckButton
var compare_button : CheckButton
var export_button : CheckButton
var utils : Node

var img_files : PackedStringArray = []
var text_files : PackedStringArray = []
var atlas_files : PackedStringArray = []
var files_to_delete : PackedStringArray = []

var godot_version : float

var atlas_path : String
var atlas_dir : DirAccess

func _enter_tree():
	EditorInterface.get_editor_main_screen().add_child(scene)
	button = scene.get_node("VBoxContainer/replace")
	atlas_path_node = scene.get_node("VBoxContainer/atlas_path")
	utils = scene.get_node("VBoxContainer")
	delete_button = scene.get_node("VBoxContainer/toggles/delete_images")
	compare_button = scene.get_node("VBoxContainer/toggles/compare_size")
	export_button = scene.get_node("VBoxContainer/toggles/export_log")
	button.button_up.connect(start_replacing)
	_make_visible(false)

func _exit_tree():
	if scene:
		scene.queue_free()

func _has_main_screen():
	return true

func _make_visible(visible):
	if scene:
		scene.visible = visible

func _get_plugin_name():
	return "Asset Replacer"

func _get_plugin_icon():
	return EditorInterface.get_editor_theme().get_icon("Image", "EditorIcons")


func start_replacing():
	reset()
	atlas_path = atlas_path_node.get_text()
	atlas_dir = DirAccess.open(atlas_path)
	if !atlas_dir or atlas_path == "":
		utils.console_print("Invalid path")
		return
	utils.console_print("Valid path")
	get_files()
	find_matches()
	if delete_button.button_pressed: delete_files()
	utils.console_print("Execution complete!", Color.DARK_GREEN)
	if export_button.button_pressed: export_log()

func reset():
	utils.clear_console()
	img_files = []
	text_files = []
	atlas_files = []
	files_to_delete = []

func get_files():
	get_atlas_res()
	get_images()
	get_text_files()
	
func get_text_files():
	utils.console_print("Searching for text files")
	for text_type in text_types:
		text_files = utils.get_type_files("res://", atlas_path, text_type, text_files)
	utils.console_print("Search for text files completed. Found %d files" %text_files.size())
	#utils.console_print("Filtering for AtlasTexture files")
	#for file in text_files:
		#if file.ends_with(".tres"):
			#var resource = ResourceLoader.load(file)
			#if resource is AtlasTexture:
				#text_files.remove_at(text_files.find(file))
	#utils.console_print("Filtering for AtlasTexture files completed. Text files: %d" % text_files.size())

func get_images():
	utils.console_print("Searching for image files")
	for img_type in img_types:
		img_files = utils.get_type_files("res://", atlas_path, img_type, img_files)
	utils.console_print("Search for image files completed. Found %d files" %img_files.size())
	img_files = utils.find_dups(img_files, "image")


func get_atlas_res():
	utils.console_print("Searching for AtlasTexture files")
	for type in atlas_types:
		atlas_files = utils.get_type_files(atlas_path, atlas_path, type, atlas_files)
	utils.console_print("Search for AtlasTexture files completed. Found %d files" % atlas_files.size())
	if atlas_files.size() > 1:
		atlas_files = utils.find_dups(atlas_files, "atlas file")


func find_matches():
	utils.console_print("Searching for image and atlas file matches")
	var matches := 0
	for a in atlas_files.size():
		var atlas_name =  atlas_files[a].get_file().trim_suffix("." + atlas_files[a].get_extension())
		var found_match := false
		for i in img_files.size():
			var img_name =  img_files[i].get_file().trim_suffix("." + img_files[i].get_extension())
			if atlas_name == img_name:
				if size_compare(img_files[i], atlas_files[a]) != OK: return 1
				matches += 1
				replace(img_files[i], atlas_files[a])
				found_match = true
				break
		if !found_match:
			utils.console_print("Didn't find a match for AtlasTexture \"%s\"" %atlas_files[a], Color.DARK_RED)
	utils.console_print("Search for image and atlas file matches completed. Matched %d pairs" %matches)


func size_compare(img_path : String, res_path : String):
	if compare_button.button_pressed:
		var img_file = ResourceLoader.load(img_path)
		var res_file := ResourceLoader.load(res_path)
		if img_file.get_size() != res_file.get_size():
			utils.console_print("Found name matches, but dimentions didn't match. File \"%s\" not replaced" %res_path, Color.DARK_RED)
			return 1
	return OK

func replace(before : String, after : String):
	var edited_files : PackedStringArray = []
	var b_uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(before))
	var a_uid = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(after))
	for text_file in text_files:
		var file := FileAccess.open(text_file, FileAccess.READ)
		if !file:
			utils.console_print("Failed to open \"%s\"" %text_file, Color.DARK_RED)
			continue
		var content = file.get_as_text()
		var edits := 0
		if content.contains(before):
			content = content.replace(before, after)
			edits += 1
		if content.contains(b_uid):
			content = content.replace(b_uid, a_uid)
			edits += 1
		file.close()
		if edits:
			file = FileAccess.open(text_file, FileAccess.WRITE)
			file.store_string(content)
			file.close()
			edited_files.append(text_file)
	
	if edited_files:
		utils.console_print("Replaced \"%s\" in the following files: %s" %[before, edited_files])
	if delete_button.button_pressed:
		files_to_delete.append(before)

func delete_files():
	var dir = DirAccess.open("res://")
	
	for file in files_to_delete:
		if dir.remove(file) == OK:
			utils.console_print("Deleted " + file, Color.DARK_SLATE_BLUE)
		else: utils.console_print("Failed to delete " + file, Color.DARK_GOLDENROD)
		
		if dir.file_exists(file + ".import"):
			if dir.remove(file + ".import") == OK:
				utils.console_print("Deleted " + file + ".import", Color.DARK_SLATE_BLUE)
			else: utils.console_print("Failed to delete " + file, Color.DARK_GOLDENROD)
			
		if dir.file_exists(file + ".uid"):
			if dir.remove(file + ".uid") == OK:
				utils.console_print("Deleted " + file + ".uid", Color.DARK_SLATE_BLUE)
			else: utils.console_print("Failed to delete " + file, Color.DARK_GOLDENROD)
		

func export_log():
	var content = utils.get_text()
	var save_path = "user://godot_asset_replacer_log.txt"
	var file : FileAccess
	file = FileAccess.open(save_path, FileAccess.WRITE)
	if !file:
		utils.console_print("Failed to overwrite log file " + save_path, Color.DARK_RED)
		return
	file.store_string(content)
	file.close()
	DirAccess.make_dir_absolute(save_path)
	utils.console_print("Log file saved at " + OS.get_user_data_dir() + "/" + save_path.trim_prefix("user://"), Color.DARK_GREEN)
