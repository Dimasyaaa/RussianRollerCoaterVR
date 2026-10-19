extends Node3D

@export var left_door: Node3D 
@export var right_door: Node3D 

@export var open_angle := 90.0
@export var anim_duration := 1.5

var is_open = false

func _ready() -> void:
	pass

func open_gates() -> void:
	if is_open: return
	is_open = true
	
	# Анимация левой створки
	if left_door:
		create_tween().tween_property(left_door, "rotation_degrees:y", -open_angle, anim_duration)
	
	# Анимация правой створки
	if right_door:
		create_tween().tween_property(right_door, "rotation_degrees:y", open_angle, anim_duration)
	
	# Ждем окончания анимации перед снятием коллизий
	await get_tree().create_timer(anim_duration).timeout
	
	# Рекурсивно убираем коллизию у всех детей (чтобы игрок мог пройти)
	disable_collisions(self)

func disable_collisions(node: Node):
	for child in node.get_children():
		if child is CollisionObject3D:
			child.collision_layer = 0
			child.collision_mask = 0
		disable_collisions(child)
