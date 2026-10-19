extends Node3D

const OUTLINE := [
	Vector3(-76.6,0,-226.1),Vector3(90,0,-226.1),
	Vector3(90,0,85),Vector3(-145,0,85),
	Vector3(-145,0,-105),Vector3(-76.6,0,-105),
	Vector3(-76.6,0,-149.1),Vector3(-76.6,0,-170.3)
]

var enclosed_area := 64825.26
var panel_count := 0

func _ready() -> void:
	panel_count = $FencePanels.multimesh.instance_count
	var old_fence = get_parent().get_node_or_null("FenceAll")
	if old_fence:
		_disable_old_collisions(old_fence)

func _disable_old_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_old_collisions(child)

func contains_point(point: Vector3) -> bool:
	var polygon := PackedVector2Array()
	for p in OUTLINE:
		polygon.append(Vector2(p.x,p.z))
	return Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon)
