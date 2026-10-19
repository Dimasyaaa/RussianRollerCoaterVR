extends XRToolsInteractableArea

signal activated
signal deactivated

@export var caption := "КНОПКА"
@export var enabled := true
var _pressing: Dictionary = {}
var _hovering: Dictionary = {}
var _material: StandardMaterial3D

@onready var face: MeshInstance3D = $Face
@onready var label: Label3D = $Face/Caption

func _ready() -> void:
	label.text = caption
	_material = face.mesh.material.duplicate()
	face.material_override = _material
	pointer_event.connect(_on_pointer_event)

func _process(_delta: float) -> void:
	# A controller disabled during boarding must not leave a button held.
	for pointer in _pressing.keys():
		if not is_instance_valid(pointer) or not pointer.can_process():
			_release(pointer)

func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.ENTERED:
			_hovering[event.pointer] = true
		XRToolsPointerEvent.Type.EXITED:
			_hovering.erase(event.pointer)
			_release(event.pointer)
		XRToolsPointerEvent.Type.PRESSED:
			if not enabled or not is_instance_valid(event.pointer):
				return
			if event.pointer.global_position.distance_to(global_position)>4.2:
				return
			var pickup = event.pointer.get_parent().get_node_or_null("FunctionPickup")
			# Trigger on an object in the hand performs that object's action.
			if pickup and is_instance_valid(pickup.picked_up_object):
				return
			if not _pressing.has(event.pointer):
				var first := _pressing.is_empty()
				_pressing[event.pointer] = true
				if first:
					activated.emit()
		XRToolsPointerEvent.Type.RELEASED:
			_release(event.pointer)
	_refresh()

func _release(pointer) -> void:
	if _pressing.has(pointer):
		_pressing.erase(pointer)
		if _pressing.is_empty():
			deactivated.emit()
	_refresh()

func _refresh() -> void:
	if not is_instance_valid(face):
		return
	face.position.z = -0.012 if not _pressing.is_empty() else 0.0
	_material.albedo_color = Color(0.48,0.35,0.19) if not _hovering.is_empty() else Color(0.30,0.21,0.11)
