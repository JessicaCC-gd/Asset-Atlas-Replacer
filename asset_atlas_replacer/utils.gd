@tool
extends Node

func get_type_files(path: String, atlas_path : String, file_ext := "", files : Array[String] = []):
	var dir : = DirAccess.open(path)
	if file_ext.begins_with("."): # get rid of starting dot if we used, for example ".tscn" instead of "tscn"
		file_ext = file_ext.substr(1,file_ext.length()-1)
	atlas_path = atlas_path.trim_suffix("/")
	
	if DirAccess.get_open_error() == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if dir.get_current_dir() +"/"+ file_name == atlas_path:
					file_name = dir.get_next()
					continue
				# recursion
				files = get_type_files(dir.get_current_dir() +"/"+ file_name, atlas_path, file_ext, files)
			else:
				if file_ext and file_name.get_extension() != file_ext:
					file_name = dir.get_next()
					continue
				
				files.append(dir.get_current_dir() +"/"+ file_name)
			file_name = dir.get_next()
	else:
		print("[get_type_files()] An error occurred when trying to access %s." % path)
	return files


func find_dups(files : PackedStringArray, what : String = "file"):
	console_print("Searching for duplicate %s names" %what)
	var file_names = []
	for f in files:
		file_names.append(f.get_file())
	var dups := 0
	var n := 0
	while true:
		var amount = file_names.count(file_names[n])
		if amount > 1:
			dups += amount
			console_print("More than one %s with the same name: \"%s\". Files were not replaced" %[what, file_names[n]],  Color.DARK_RED)
			var file_name = file_names[n]
			while true:
				var idx = file_names.find(file_name)
				if idx == -1:
					break
				file_names.remove_at(idx)
				files.remove_at(idx)
		else:
			n = n + 1
		if n >= file_names.size():
			break
	console_print("Searching for duplicate %s names completed. Found %d duplicates" %[what, dups])
	return files


func console_print(text : String, color : Color = Color.WHITE):
	var line : String = "[%s] " % Time.get_time_string_from_system()
	line += text
	var current_line = $console.get_line_count() - 1
	$console.insert_line_at(current_line, line)
	if color != Color.WHITE:
		$console.set_line_background_color(current_line, color)
	
func clear_console():
	$console.clear()
	
func get_text():
	return $console.get_text()
