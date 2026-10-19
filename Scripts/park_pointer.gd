extends XRToolsFunctionPointer

func _ready() -> void:
	# Existing hand overlap areas must not intercept the other hand's UI ray.
	var origin := XRHelpers.get_xr_origin(self)
	if origin:
		for controller in origin.find_children("*", "XRController3D", true, false):
			for collider in controller.find_children("*", "CollisionObject3D", true, false):
				$RayCast.add_exception(collider)
