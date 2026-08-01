class_name FallBoxConstraint
extends RigidBody3D
## Presentation-only fall body. Clamps to sim-stamped support/impact planes.


var box_size: Vector3 = Vector3(0.18, 0.40, 0.14)
var support_plane: Dictionary = {}
var impact_plane: Dictionary = {}


func configure_planes(support: Dictionary, impact: Dictionary = {}) -> void:
	support_plane = support.duplicate()
	impact_plane = impact.duplicate()


func _box_radius_along_normal(basis: Basis, normal: Vector3) -> float:
	var n := normal.normalized()
	return (
		absf(n.dot(basis.x)) * box_size.x * 0.5
		+ absf(n.dot(basis.y)) * box_size.y * 0.5
		+ absf(n.dot(basis.z)) * box_size.z * 0.5
	)


func transform_for_planes(
	feet: Vector3, basis: Basis,
	support_point: Vector3, support_normal: Vector3,
	impact_point: Vector3, impact_normal: Vector3
) -> Transform3D:
	var center := feet + basis * Vector3(0.0, box_size.y * 0.5, 0.0)
	var support_n := support_normal.normalized()
	if support_n.length_squared() < 0.0001:
		support_n = Vector3.UP
	var support_radius := _box_radius_along_normal(basis, support_n)
	var support_dist := support_n.dot(center - support_point)
	if support_dist < support_radius:
		center += support_n * (support_radius - support_dist)
	if impact_normal.length_squared() > 0.0001:
		var impact_n := impact_normal.normalized()
		var impact_radius := _box_radius_along_normal(basis, impact_n)
		var impact_dist := impact_n.dot(center - impact_point)
		if impact_dist < impact_radius:
			center += impact_n * (impact_radius - impact_dist)
	return Transform3D(basis, center)


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	if freeze or support_plane.is_empty():
		return
	var xf := physics_state.transform
	var support_point: Vector3 = support_plane.point
	var support_normal: Vector3 = support_plane.normal
	var support_radius := _box_radius_along_normal(xf.basis, support_normal)
	var support_dist := support_normal.dot(xf.origin - support_point)
	if support_dist < support_radius:
		xf.origin += support_normal * (support_radius - support_dist)
		physics_state.linear_velocity = physics_state.linear_velocity.slide(support_normal)
	if not impact_plane.is_empty():
		var impact_point: Vector3 = impact_plane.point
		var impact_normal: Vector3 = impact_plane.normal
		var impact_radius := _box_radius_along_normal(xf.basis, impact_normal)
		var impact_dist := impact_normal.dot(xf.origin - impact_point)
		if impact_dist < impact_radius:
			xf.origin += impact_normal * (impact_radius - impact_dist)
			physics_state.linear_velocity = physics_state.linear_velocity.slide(impact_normal)
	physics_state.transform = xf
