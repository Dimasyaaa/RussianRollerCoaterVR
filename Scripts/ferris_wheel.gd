extends Node3D

@export var rpm := 20.0 # Оборотов в минуту (медленно, реалистично)
@onready var axle: Node3D = get_node_or_null("Axle")

func _process(delta: float) -> void:
	if axle == null:
		return
	
	var omega := rpm * TAU / 60.0
	# Крутим ось вокруг её локальной Z (так как колесо стоит вертикально)
	axle.rotate_object_local(Vector3(0, 1, 0), omega * delta)
