extends Node3D

@export var waist_offset := Vector3(0.38, 0.0, -0.32)
@export var height_below_head := 0.70

@onready var origin: XROrigin3D = get_parent()
@onready var camera: XRCamera3D = origin.get_node("XRCamera3D")

func _ready() -> void:
	_update_belt()

func _process(_delta: float) -> void:
	_update_belt()

func _update_belt() -> void:
	var forward: Vector3 = -origin.global_basis.z
	forward.y = 0.0
	var belt_basis := global_basis
	if forward.length_squared() > 0.001:
		belt_basis = Basis.looking_at(forward.normalized(), Vector3.UP)
	var height := maxf(camera.global_position.y - height_below_head, origin.global_position.y + 0.05)
	var waist := Vector3(camera.global_position.x, height, camera.global_position.z)
	global_transform = Transform3D(belt_basis, waist + belt_basis * waist_offset)
