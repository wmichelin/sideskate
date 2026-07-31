class_name MeshPart
extends RefCounted
## CPU-side triangle soup shared by visuals, collision, and debug lattices.
## `faces` is triples of world-space vertices (meters via WorldSpace).

var faces: PackedVector3Array = PackedVector3Array()
var material_key: String = "floor"
var layer: int = 0
## Surface identity for physics contacts / policy helpers.
var meta: Dictionary = {}


func is_empty() -> bool:
	return faces.is_empty()


func triangle_count() -> int:
	return int(faces.size() / 3)


func append_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	faces.append(a)
	faces.append(b)
	faces.append(c)


func append_faces(other_faces: PackedVector3Array) -> void:
	faces.append_array(other_faces)


func append_part(other: MeshPart) -> void:
	if other == null or other.is_empty():
		return
	faces.append_array(other.faces)


func append_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	## Two triangles a-c-b and a-d-c (WorldSpace X-mirror winding).
	append_tri(a, c, b)
	append_tri(a, d, c)


func to_array_mesh() -> ArrayMesh:
	if faces.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in faces:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func to_concave_shape() -> ConcavePolygonShape3D:
	if faces.is_empty():
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func aabb() -> AABB:
	if faces.is_empty():
		return AABB()
	var box := AABB(faces[0], Vector3.ZERO)
	for i in range(1, faces.size()):
		box = box.expand(faces[i])
	return box


static func make(
	material_key_: String,
	layer_: int,
	meta_: Dictionary = {},
) -> MeshPart:
	var p := MeshPart.new()
	p.material_key = material_key_
	p.layer = layer_
	p.meta = meta_.duplicate(true)
	return p
