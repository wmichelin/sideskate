extends RefCounted
## 2D / 3D level twins must stay byte-identical (renderer chosen by directory).


func run() -> bool:
	var dir2 := DirAccess.open("res://levels")
	var dir3 := DirAccess.open("res://levels_3d")
	if dir2 == null or dir3 == null:
		push_error("levels or levels_3d missing")
		return false
	var names_2d: PackedStringArray = []
	dir2.list_dir_begin()
	var n := dir2.get_next()
	while n != "":
		if not dir2.current_is_dir() and n.ends_with(".ssk"):
			names_2d.append(n)
		n = dir2.get_next()
	dir2.list_dir_end()
	names_2d.sort()
	for file_name in names_2d:
		var p2 := "res://levels/%s" % file_name
		var p3 := "res://levels_3d/%s" % file_name
		if not FileAccess.file_exists(p3):
			push_error("missing 3D twin: %s" % p3)
			return false
		var a := FileAccess.get_file_as_string(p2)
		var b := FileAccess.get_file_as_string(p3)
		if a != b:
			push_error("twin drift: %s" % file_name)
			return false
	return true
