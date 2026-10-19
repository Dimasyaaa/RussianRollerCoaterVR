extends XRToolsPickable

@export_range(0.0, 1.0, 0.01) var fill_level := 0.0
var _drinking := false

func _ready() -> void:
	super._ready()
	action_pressed.connect(func(_cup): _drinking = true)
	action_released.connect(func(_cup): _drinking = false)
	_update_water()

func _process(delta: float) -> void:
	if _drinking and is_picked_up() and get_picked_up_by_controller():
		fill_level = maxf(0.0,fill_level-delta*0.55)
	else:
		_drinking = false
	_update_water()

func add_water(amount: float) -> void:
	fill_level = clampf(fill_level+amount,0.0,1.0)
	_update_water()

func _update_water() -> void:
	if not has_node("Water"):
		return
	$Water.visible = fill_level>0.005
	$Water.scale.y = maxf(0.001,fill_level)
	$Water.position.y = 0.012+fill_level*0.055
	$Amount.text = "%d мл" % roundi(fill_level*250.0)
