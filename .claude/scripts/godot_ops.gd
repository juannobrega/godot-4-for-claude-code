# Scene and resource operations the headless CLI cannot do on its own.
#
#   godot --headless --path <project> --script .claude/scripts/godot_ops.gd \
#         <operation> '<json params>'
#
# Operations:
#   build_scene          build a .tscn from a declarative node contract
#   export_mesh_library  build a MeshLibrary from a 3D scene's children
#
# Exit 0 on success, 1 on failure, and every failure prints why. The engine
# exits 0 after a script error on its own, so this script decides its own code.
#
# Derived from godot_operations.gd in github.com/Coding-Solo/godot-mcp,
# MIT, Copyright (c) 2025 Solomon Elias. Changed here:
#   - one declarative pass instead of a process per node, so a scene is built
#     from a committed contract rather than a sequence of calls
#   - unique_name_in_owner is set, which the original never did: without it
#     %NodeName does not resolve and the failure surfaces at runtime
#   - the root node takes its name from the contract instead of being "root"
#   - duplicate node names are rejected, since a unique name must be unique
extends SceneTree

var _failed: bool = false


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var script_index: int = args.find("--script")
	if script_index == -1 or args.size() <= script_index + 2:
		_fail("usage: --script godot_ops.gd <operation> <json params>")
		quit(1)
		return

	var operation: String = args[script_index + 2]
	var raw: String = args[script_index + 3] if args.size() > script_index + 3 else "{}"

	var json := JSON.new()
	if json.parse(raw) != OK:
		_fail("params are not valid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		quit(1)
		return
	var params: Dictionary = json.data if json.data is Dictionary else {}

	match operation:
		"build_scene": _build_scene(params)
		"export_mesh_library": _export_mesh_library(params)
		_: _fail("unknown operation: " + operation)

	quit(1 if _failed else 0)


func _fail(message: String) -> void:
	printerr("godot_ops: " + message)
	_failed = true


## Builds a scene from a declarative contract, in one pass.
##
## {"path": "res://scenes/player.tscn",
##  "root": {"name": "Player", "type": "CharacterBody2D",
##           "properties": {...}, "groups": [...], "children": [...]}}
func _build_scene(params: Dictionary) -> void:
	if not params.has("path") or not params.has("root"):
		_fail("build_scene needs 'path' and 'root'")
		return

	var names: Dictionary = {}
	var root: Node = _build_node(params["root"], names)
	if root == null:
		return

	var packed := PackedScene.new()
	# Freed below once packing and saving are done, so the engine does not
	# report leaked RIDs at exit and bury the real output in warnings.
	# pack() only keeps nodes whose owner is the root, which is why _build_node
	# sets owner after add_child rather than before.
	var error: int = packed.pack(root)
	if error != OK:
		_fail("could not pack the scene: error %d" % error)
		root.free()
		return

	var path: String = _res_path(String(params["path"]))
	if not _ensure_directory_for(path):
		return

	error = ResourceSaver.save(packed, path)
	if error != OK:
		_fail("could not save %s: error %d" % [path, error])
		return
	if not FileAccess.file_exists(path):
		_fail("save reported success but %s does not exist" % path)
		return

	root.free()
	if not _ensure_uid(path):
		return
	print("built %s with %d node(s)" % [path, names.size()])


func _build_node(spec: Dictionary, names: Dictionary, parent: Node = null,
		root: Node = null) -> Node:
	if not spec.has("name") or not spec.has("type"):
		_fail("every node needs 'name' and 'type'")
		return null

	var name_of_node: String = String(spec["name"])
	if names.has(name_of_node):
		# A unique name must be unique within the owner, so a duplicate would
		# make %Name ambiguous. Caught here rather than at runtime.
		_fail("duplicate node name '%s': %%%s would be ambiguous" % [name_of_node, name_of_node])
		return null
	names[name_of_node] = true

	var node: Node = _instantiate(String(spec["type"]))
	if node == null:
		return null
	node.name = name_of_node

	if spec.has("properties") and not _apply_properties(node, spec["properties"]):
		node.free()
		return null

	for group in spec.get("groups", []):
		# persistent, or the group is not written into the .tscn
		node.add_to_group(String(group), true)

	var owner_node: Node = root if root != null else node
	if parent != null:
		parent.add_child(node)
		# owner must be set after add_child, or pack() drops the node silently
		node.owner = owner_node
	# The root is left without an owner on purpose: Godot asserts when a node
	# owns itself, and pack() already treats the root as the tree's owner.

	# %Name is what the constitution requires over node paths, and it only
	# resolves when this flag is set.
	node.unique_name_in_owner = bool(spec.get("unique", true))

	for child_spec in spec.get("children", []):
		if _build_node(child_spec, names, node, owner_node) == null:
			# Only the subtree built so far exists; freeing this node takes its
			# children with it, so the failure path leaves nothing behind.
			if parent == null:
				node.free()
			return null

	return node


func _apply_properties(node: Node, properties: Dictionary) -> bool:
	for property in properties:
		var value: Variant = properties[property]
		if typeof(value) == TYPE_STRING and String(value).begins_with("res://"):
			var resource: Resource = load(String(value))
			if resource == null:
				_fail("could not load %s for property %s" % [value, property])
				return false
			value = resource
		node.set(String(property), value)
	return true


## Builds a MeshLibrary from a 3D scene's direct children, for GridMap.
func _export_mesh_library(params: Dictionary) -> void:
	if not params.has("scene_path") or not params.has("output_path"):
		_fail("export_mesh_library needs 'scene_path' and 'output_path'")
		return

	var scene_path: String = _res_path(String(params["scene_path"]))
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		_fail("could not load scene " + scene_path)
		return
	var root: Node = packed.instantiate()
	if root == null:
		_fail("could not instantiate " + scene_path)
		return

	var wanted: Array = params.get("mesh_item_names", [])
	var library := MeshLibrary.new()
	var item_id: int = 0

	for child in root.get_children():
		if wanted.size() > 0 and not (child.name in wanted):
			continue
		var mesh_instance: MeshInstance3D = _find_mesh(child)
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		library.create_item(item_id)
		library.set_item_name(item_id, child.name)
		library.set_item_mesh(item_id, mesh_instance.mesh)
		# No set_item_preview: it takes a Texture2D, not a Mesh. Passing the
		# mesh fails to parse on 4.7.2, and the preview is only an editor
		# thumbnail, so there is nothing to supply here.
		var shape: Shape3D = _find_shape(child)
		if shape != null:
			library.set_item_shapes(item_id, [shape])
		item_id += 1

	# Saving an empty library and reporting success is the false-green this
	# project exists to avoid.
	if item_id == 0:
		_fail("no meshes in %s: a MeshLibrary needs MeshInstance3D nodes with a mesh" % scene_path)
		return

	var output_path: String = _res_path(String(params["output_path"]))
	if not _ensure_directory_for(output_path):
		return
	var error: int = ResourceSaver.save(library, output_path)
	if error != OK:
		_fail("could not save %s: error %d" % [output_path, error])
		return

	print("exported %d item(s) to %s" % [item_id, output_path])
	root.free()


## Writes a uid into the scene header.
##
## ResourceSaver does not write one for a PackedScene built in memory, and
## ResourceUID.add_id only registers it in the project's cache, which a fresh
## clone does not have. Without the header the scene can only be referenced by
## path, losing the rename safety that uids exist for.
##
## Editing a .tscn as text is otherwise forbidden here. It is safe in this one
## place because the file was written microseconds ago by this script, nothing
## references it yet, and only the first line is touched.
func _ensure_uid(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("could not reopen %s to assign a uid" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	var newline: int = text.find("\n")
	if newline == -1:
		_fail("%s has no header line" % path)
		return false
	var header: String = text.substr(0, newline)
	if header.contains("uid="):
		return true

	var id: int = ResourceUID.create_id()
	ResourceUID.add_id(id, path)
	var uid_text: String = ResourceUID.id_to_text(id)
	header = header.replace("[gd_scene ", "[gd_scene uid=\"%s\" " % uid_text)

	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not rewrite the header of %s" % path)
		return false
	file.store_string(header + text.substr(newline))
	file.close()
	return true


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
	return null


func _find_shape(node: Node) -> Shape3D:
	for child in node.get_children():
		if child is CollisionShape3D and child.shape != null:
			return child.shape
	return null


func _instantiate(name_of_class: String) -> Node:
	if not ClassDB.class_exists(name_of_class):
		_fail("no such class: " + name_of_class)
		return null
	if not ClassDB.can_instantiate(name_of_class):
		_fail("class cannot be instantiated: " + name_of_class)
		return null
	var instance: Variant = ClassDB.instantiate(name_of_class)
	if not (instance is Node):
		_fail(name_of_class + " is not a Node")
		return null
	return instance


func _res_path(path: String) -> String:
	return path if path.begins_with("res://") else "res://" + path.trim_prefix("/")


func _ensure_directory_for(path: String) -> bool:
	var directory: String = path.get_base_dir()
	if DirAccess.dir_exists_absolute(directory):
		return true
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		_fail("could not create directory " + directory)
		return false
	return true
