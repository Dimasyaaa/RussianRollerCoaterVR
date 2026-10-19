extends Node3D

signal ride_started
signal ride_finished

enum RideState { WAITING, COUNTDOWN, RIDING, BRAKING, UNLOADING }

const WHEEL_RADIUS := 0.23

@export var countdown_seconds := 3.0
@export var maximum_speed := 20.0
@export var boarding_distance := 2.8
@export_group("Ride effects")
@export_range(0.0, 15.0, 0.5) var maximum_bank_degrees := 7.0
@export_range(0.5, 6.0, 0.1) var bank_response := 2.4
@export_range(1.0, 20.0, 0.5) var bank_rate_degrees := 7.0

var state: RideState = RideState.WAITING
var speed := 0.0
var ticket_available := false
var route_length := 0.0
var _clock := 0.0
var _last_count := -1
var _wheels: Array[Node3D] = []
var _saved_process_mode: Node.ProcessMode
var _saved_body_layer := 0
var _saved_body_mask := 0
var _saved_body_enabled := true
var _park_player: Node3D
var _park_origin: XROrigin3D
var _park_camera: XRCamera3D
var _kiosk: Node3D
var _station_message: Label3D
var _simulator_startup_saved := false
var _startup_left := Transform3D.IDENTITY
var _startup_right := Transform3D.IDENTITY
var bank_angle := 0.0

@onready var path: Path3D = $TrackPath
@onready var follow: PathFollow3D = $TrackPath/Carriage
@onready var cart: Node3D = $TrackPath/Carriage/Cart
@onready var seat: Marker3D = $TrackPath/Carriage/Cart/SeatEye
@onready var seated_origin: XROrigin3D = $TrackPath/Carriage/Cart/SeatedPlayer
@onready var seated_camera: XRCamera3D = $TrackPath/Carriage/Cart/SeatedPlayer/XRCamera3D
@onready var ride_message: Label3D = $TrackPath/Carriage/Cart/RideMessage
@onready var exit_point: Marker3D = $ExitPoint
@onready var rolling_sound: AudioStreamPlayer3D = $TrackPath/Carriage/Cart/RollingSound
@onready var wind_sound: AudioStreamPlayer = $TrackPath/Carriage/Cart/WindSound

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var simulator := get_node_or_null("/root/XrSimulator")
	var player := get_parent().get_node_or_null("Player")
	if simulator and simulator.enabled and player:
		# Save the park poses before the simulator sees the second rig's
		# controllers and applies its initial horizontal offsets again.
		_startup_left = player.get_node("XROrigin3D/Left").transform
		_startup_right = player.get_node("XROrigin3D/Right").transform
		_simulator_startup_saved = true

func _ready() -> void:
	route_length = path.curve.get_baked_length()
	_cache_wheels()
	_station_message = $Station/Instructions
	_set_cart_progress(0.0)
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_prepare_audio_loop(rolling_sound)
	_prepare_audio_loop(wind_sound)
	_park_player = get_parent().get_node_or_null("Player")
	_kiosk = get_parent().get_node_or_null("Kiosk")
	if not _park_player or not _kiosk or route_length < 300.0:
		push_error("Coaster: player, kiosk, or a route of at least 300 metres is missing")
		set_physics_process(false)
		return
	_park_origin = _park_player.get_node("XROrigin3D")
	_park_camera = _park_origin.get_node("XRCamera3D")
	seated_origin.current = false
	seated_camera.current = false
	_park_origin.current = true
	_park_camera.make_current()
	_kiosk.ticket_purchased.connect(_on_ticket_purchased)
	ticket_available = _kiosk.is_paid
	# The simulator binds the last added XR nodes, including an inactive rig.
	# Explicitly bind the active player on startup and on every camera switch.
	if _simulator_startup_saved:
		_park_origin.get_node("Left").transform = _startup_left
		_park_origin.get_node("Right").transform = _startup_right
	_bind_simulator(_park_origin)
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		get_viewport().use_xr = true
		var simulator := get_node_or_null("/root/XrSimulator")
		if simulator:
			simulator.enabled = false
			simulator.set_process_input(false)
	_update_waiting_message()

func _track_transform(distance: float) -> Transform3D:
	var p := path.curve.sample_baked(clampf(distance, 0.0, route_length), true)
	var before := path.curve.sample_baked(fposmod(distance - 0.3, route_length), true)
	var after := path.curve.sample_baked(fposmod(distance + 0.3, route_length), true)
	return Transform3D(Basis.looking_at((after - before).normalized(), Vector3.UP), p)

func _cache_wheels() -> void:
	_wheels.clear()
	for wheel in cart.find_children("Wheel*", "Node3D", false, false):
		_wheels.append(wheel as Node3D)

func _on_ticket_purchased() -> void:
	ticket_available = true
	_update_waiting_message()

func _update_waiting_message() -> void:
	_station_message.text = "Билет оплачен. Проходите на посадку" if ticket_available else "Оплатите билет в кассе"
	ride_message.text = "ПОСАДКА" if ticket_available else "НУЖЕН БИЛЕТ"

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _park_camera:
		return
	match state:
		RideState.WAITING:
			var distance := Vector2(_park_camera.global_position.x-cart.global_position.x,_park_camera.global_position.z-cart.global_position.z).length()
			var p := to_local(_park_camera.global_position)
			var on_platform := p.x > -51.1 and p.x < -46.85 and p.z > -201.6 and p.z < -190.4
			if ticket_available and on_platform and distance < boarding_distance and absf(_park_camera.global_position.y-cart.global_position.y) < 3.0:
				_board()
		RideState.COUNTDOWN:
			_clock -= delta
			var count := ceili(maxf(_clock,0.0))
			if count != _last_count:
				_last_count = count
				ride_message.text = "СТАРТ ЧЕРЕЗ %d" % count
			if _clock <= 0.0:
				state = RideState.RIDING
				ride_started.emit()
		RideState.RIDING, RideState.BRAKING:
			var remaining := route_length-follow.progress
			var tangent := -_track_transform(follow.progress).basis.z
			var desired := clampf(12.0-tangent.y*16.0,6.0,maximum_speed)
			if remaining < maxf(30.0,speed*speed/(2.0*1.8)+4.0):
				state = RideState.BRAKING
				desired = minf(desired,maxf(0.6,sqrt(2.0*1.8*remaining)))
			speed = move_toward(speed,desired,delta*2.0)
			var movement := minf(speed*delta,remaining)
			_set_cart_progress(follow.progress+movement)
			for wheel in _wheels:
				wheel.rotate_x(-movement/WHEEL_RADIUS)
			ride_message.text = "СКОРОСТЬ %d км/ч" % roundi(speed*3.6)
			if remaining <= movement+0.001:
				speed = 0.0
				state = RideState.UNLOADING
				_clock = 1.5
				ride_message.text = "ПОЕЗДКА ЗАВЕРШЕНА"
		RideState.UNLOADING:
			_clock -= delta
			if _clock <= 0.0:
				_unboard()
	_update_ride_effects(delta)

func _prepare_audio_loop(player: Node) -> void:
	if player.stream is AudioStreamWAV:
		player.stream = player.stream.duplicate()
		player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream.loop_begin = 0
		player.stream.loop_end = roundi(player.stream.get_length()*player.stream.mix_rate)

func _target_bank(distance: float, velocity: float) -> float:
	# Signed horizontal curvature gives lateral acceleration v²/r. Use it to
	# bank the cart parent, leaving the headset's tracked local pose untouched.
	var before := -_track_transform(distance-2.0).basis.z
	var after := -_track_transform(distance+2.0).basis.z
	before.y = 0.0
	after.y = 0.0
	if before.length_squared() < 0.001 or after.length_squared() < 0.001:
		return 0.0
	before = before.normalized()
	after = after.normalized()
	var curvature := atan2(before.cross(after).y,before.dot(after))/4.0
	var limit := deg_to_rad(maximum_bank_degrees)
	return clampf(atan(velocity*velocity*curvature/9.81),-limit,limit)

func _update_ride_effects(delta: float) -> void:
	var moving := (state == RideState.RIDING or state == RideState.BRAKING) and speed > 0.1
	var target := _target_bank(follow.progress,speed) if moving else 0.0
	var smooth := lerp_angle(bank_angle,target,1.0-exp(-bank_response*delta))
	bank_angle = move_toward(bank_angle,smooth,deg_to_rad(bank_rate_degrees)*delta)
	cart.rotation.z = bank_angle
	if moving:
		var intensity := clampf(speed/maxf(maximum_speed,0.1),0.0,1.0)
		rolling_sound.volume_db = lerpf(-26.0,-13.0,intensity)
		rolling_sound.pitch_scale = lerpf(0.65,1.5,intensity)
		wind_sound.volume_db = lerpf(-34.0,-14.0,intensity)
		if not rolling_sound.playing:
			rolling_sound.play()
		if not wind_sound.playing:
			wind_sound.play()
	else:
		rolling_sound.stop()
		wind_sound.stop()

func _set_cart_progress(distance: float) -> void:
	follow.progress = clampf(distance,0.0,route_length)
	follow.basis = _track_transform(follow.progress).basis

func _board() -> void:
	if state != RideState.WAITING or not ticket_available:
		return
	ticket_available = false
	_saved_process_mode = _park_player.process_mode
	var body = _park_origin.get_node("PlayerBody")
	_saved_body_layer = body.collision_layer
	_saved_body_mask = body.collision_mask
	_saved_body_enabled = body.is_physics_processing()
	# Drop held items before disabling their grab driver.
	for controller_name in ["Left","Right"]:
		var pickup = _park_origin.get_node(controller_name+"/FunctionPickup")
		pickup.drop_object()
		seated_origin.get_node(controller_name).transform = _park_origin.get_node(controller_name).transform
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_physics_process(false)
	seated_camera.transform = _park_camera.transform
	var head_forward := -_park_camera.basis.z
	head_forward.y = 0.0
	var head_yaw := Basis.looking_at(head_forward.normalized(),Vector3.UP) if head_forward.length_squared() > 0.001 else Basis.IDENTITY
	seated_origin.basis = head_yaw.inverse()
	seated_origin.position = seat.position-seated_origin.basis*_park_camera.position
	_park_origin.current = false
	_park_camera.current = false
	_park_player.visible = false
	_park_player.process_mode = Node.PROCESS_MODE_DISABLED
	seated_origin.process_mode = Node.PROCESS_MODE_INHERIT
	seated_origin.visible = true
	seated_origin.current = true
	seated_camera.make_current()
	_bind_simulator(seated_origin)
	state = RideState.COUNTDOWN
	_clock = countdown_seconds
	_last_count = -1
	_station_message.text = "Вагонетка на маршруте"
	speed = 0.0

func _unboard() -> void:
	seated_origin.current = false
	seated_camera.current = false
	seated_origin.visible = false
	seated_origin.process_mode = Node.PROCESS_MODE_DISABLED
	_park_player.process_mode = _saved_process_mode
	_park_player.visible = true
	_park_origin.current = true
	_park_camera.make_current()
	_bind_simulator(_park_origin)
	var body = _park_origin.get_node("PlayerBody")
	body.velocity = Vector3.ZERO
	body.teleport(exit_point.global_transform)
	body.collision_layer = _saved_body_layer
	body.collision_mask = _saved_body_mask
	body.set_physics_process(_saved_body_enabled)
	# Keep the wallet accessible when returning to the walking player.
	var wallet = _park_origin.get_node("WalletBelt/Wallet")
	var holster = _park_origin.get_node("WalletBelt/WalletHolster")
	if is_instance_valid(wallet) and not wallet.is_picked_up():
		holster.pick_up_object(wallet)
	bank_angle = 0.0
	cart.rotation.z = 0.0
	_set_cart_progress(0.0)
	state = RideState.WAITING
	_kiosk.prepare_next_payment()
	_update_waiting_message()
	ride_finished.emit()

func _bind_simulator(origin: XROrigin3D) -> void:
	var simulator := get_node_or_null("/root/XrSimulator")
	if not simulator or not simulator.enabled:
		return
	simulator.camera = origin.get_node("XRCamera3D")
	simulator.left_controller = origin.get_node("Left")
	simulator.right_controller = origin.get_node("Right")
	if simulator.left_tracker:
		simulator.left_tracker.set_pose(simulator.left_controller.pose,simulator.left_controller.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	if simulator.right_tracker:
		simulator.right_tracker.set_pose(simulator.right_controller.pose,simulator.right_controller.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
