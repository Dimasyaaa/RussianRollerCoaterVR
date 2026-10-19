extends Node3D

signal time_changed(hour: float, night_strength: float)

@export_range(60.0, 1800.0, 10.0) var cycle_seconds := 240.0
@export_range(0.0, 24.0, 0.1) var start_hour := 9.0
@export var automatic := true
var hour := 9.0
var night_strength := 0.0
var _tick := 0.0
var _transition: Tween
var _lighting: Array[Node] = []
var _sun: DirectionalLight3D
var _legacy_fill: OmniLight3D
var _legacy_energy := 16.0

@onready var environment: Environment = $WorldEnvironment.environment
@onready var moon: DirectionalLight3D = $Moon

func _ready() -> void:
	_sun = get_parent().get_node_or_null("DirectionalLight3D")
	_legacy_fill = get_parent().get_node_or_null("OmniLight3D")
	if _legacy_fill:
		_legacy_energy = _legacy_fill.light_energy
	environment = environment.duplicate(true)
	$WorldEnvironment.environment = environment
	_lighting = get_tree().get_nodes_in_group("park_night_lights")
	hour = start_hour
	_apply_lighting()

func _process(delta: float) -> void:
	if automatic:
		hour = fposmod(hour+delta*24.0/maxf(cycle_seconds,60.0),24.0)
	_tick += delta
	if _tick>=0.1:
		_tick = 0.0
		_apply_lighting()

func set_time(value: float, pause_cycle := true, animate := true) -> void:
	if _transition:
		_transition.kill()
	automatic = not pause_cycle
	var destination := fposmod(value,24.0)
	if animate:
		var end := hour+fposmod(destination-hour,24.0)
		_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_method(_set_transition_hour,hour,end,3.0)
	else:
		hour = destination
		_apply_lighting()

func resume_cycle() -> void:
	if _transition:
		_transition.kill()
	automatic = true
	_apply_lighting()

func _set_transition_hour(value: float) -> void:
	hour = fposmod(value,24.0)
	_apply_lighting()

func _apply_lighting() -> void:
	var angle := (hour-6.0)*PI/12.0
	var elevation := sin(angle)
	var daylight := smoothstep(-0.07,0.22,elevation)
	night_strength = 1.0-smoothstep(-0.12,0.20,elevation)
	if _sun:
		_sun.rotation = Vector3(-angle,-0.6,0)
		_sun.light_energy = daylight*(0.25+1.3*maxf(0.0,elevation))
		_sun.light_color = Color(1.0,0.48,0.20).lerp(Color(1.0,0.96,0.89),smoothstep(0.03,0.8,elevation))
	moon.light_energy = 0.40*night_strength
	if _legacy_fill:
		_legacy_fill.light_energy = _legacy_energy*daylight
	environment.ambient_light_color = Color(0.34,0.43,0.65).lerp(Color(0.77,0.85,1.0),daylight)
	environment.ambient_light_energy = lerpf(0.60,0.72,daylight)
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(0.012,0.025,0.075).lerp(Color(0.16,0.40,0.73),daylight)
	sky.sky_horizon_color = Color(0.07,0.09,0.15).lerp(Color(0.75,0.82,0.9),daylight)
	var twilight := (1.0-absf(daylight*2.0-1.0))*0.45
	sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color(0.85,0.35,0.16),twilight)
	sky.ground_bottom_color = Color(0.015,0.02,0.035).lerp(Color(0.17,0.20,0.14),daylight)
	sky.ground_horizon_color = sky.sky_horizon_color
	for lighting in _lighting:
		lighting.set_night_strength(night_strength)
	time_changed.emit(hour,night_strength)
