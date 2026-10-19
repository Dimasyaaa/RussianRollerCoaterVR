extends Node3D

@export var light_energy := 2.4
@export var bulb_energy := 3.0

var _materials: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []

func _ready() -> void:
	for node in find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh
		if node is MultiMeshInstance3D:
			mesh = node.multimesh.mesh
		elif node is MeshInstance3D:
			mesh = node.mesh
		if mesh is PrimitiveMesh and mesh.material is StandardMaterial3D:
			var material := mesh.material as StandardMaterial3D
			if material.emission_enabled:
				material = material.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				node.material_override = material
				_materials.append(material)
	for light in find_children("*", "OmniLight3D", true, false):
		_lights.append(light)
	set_night_strength(0.0)

func set_night_strength(strength: float) -> void:
	for material in _materials:
		material.emission_energy_multiplier = bulb_energy * strength
	for light in _lights:
		light.light_energy = light_energy * strength
