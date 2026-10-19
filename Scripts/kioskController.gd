extends Node3D

signal ticket_purchased

@export var payment_zone: Area3D 
@export var gate_path: NodePath = "../Gate" # Путь к воротам

var is_paid := false
var _gate_warning_shown := false

@onready var tray_highlight: MeshInstance3D = get_node_or_null("PaymentZone/TrayHighlight")
@onready var payment_message: Label3D = get_node_or_null("PaymentZone/PaymentMessage")
@onready var payment_sound: AudioStreamPlayer3D = get_node_or_null("PaymentZone/PaymentSound")

func _ready() -> void:
	if payment_zone == null:
		push_error("Kiosk: Не назначена зона PaymentZone!")
		set_process(false)
		set_physics_process(false)
	else:
		# Слои: существующие деньги (1), предметы XR Tools (3), предмет в руке (17).
		payment_zone.collision_mask |= 65541
		payment_zone.body_entered.connect(_on_body_entered, CONNECT_DEFERRED)

func _process(_delta: float) -> void:
	if is_paid:
		return
	
	# Area3D не рисуется: подсвечиваем отдельную поверхность лотка.
	var player_cam: Node3D = get_viewport().get_camera_3d()
	if player_cam == null:
		player_cam = get_tree().get_first_node_in_group("xr_camera") as Node3D
	if player_cam == null:
		player_cam = get_tree().get_first_node_in_group("camera") as Node3D
	var nearby := false
	if player_cam:
		nearby = payment_zone.global_position.distance_to(player_cam.global_position) < 8.0
	if tray_highlight:
		tray_highlight.visible = nearby
	if payment_message:
		payment_message.visible = nearby

func _physics_process(_delta: float) -> void:
	if is_paid or payment_zone == null:
		return
	# При отпускании внутри зоны body_entered может не повториться.
	# Проверяем перекрытия, чтобы этот случай тоже приводил к оплате.
	for body in payment_zone.get_overlapping_bodies():
		_on_body_entered(body)
		if is_paid:
			break

func _on_body_entered(body: Node3D) -> void:
	if is_paid or not is_instance_valid(body):
		return
	
	# ПРОВЕРКА ЧЕРЕЗ ГРУППУ (Надежно!)
	if body.is_in_group("money"):
		process_payment(body)

func process_payment(item: Node3D) -> void:
	if is_paid or not is_instance_valid(item) or not item.is_in_group("money"):
		return
	# Положить в лоток означает отпустить предмет, а не пронести его в руке.
	if item.has_method("is_picked_up") and item.is_picked_up():
		return
	var gates := get_node_or_null(gate_path)
	if gates == null or not gates.has_method("open_gates"):
		if not _gate_warning_shown:
			push_warning("Kiosk: Ворота не найдены или нет метода open_gates()")
			_gate_warning_shown = true
		return
	is_paid = true
	print("=== ОПЛАТА ПРИНЯТА ===")
	
	# 1. Сообщаем пользователю (можно использовать Label3D или AudioStreamPlayer)
	show_welcome_message()
	if payment_sound:
		payment_sound.play()
	
	# 2. Кошелёк сохраняем. Отдельная купюра по-прежнему расходуется.
	if not item.is_in_group("wallet"):
		if item.has_method("drop_and_free"):
			item.drop_and_free()
		else:
			item.queue_free()
	
	# 3. Открываем ворота
	gates.open_gates()
	ticket_purchased.emit()

func prepare_next_payment() -> void:
	is_paid = false
	if payment_message:
		payment_message.text = "Положите купюру в лоток"
		payment_message.modulate = Color.WHITE

func show_welcome_message():
	if tray_highlight:
		tray_highlight.visible = false
	if payment_message:
		payment_message.text = "Оплачено. Проходите!"
		payment_message.modulate = Color(0.2, 1.0, 0.3, 1.0)
		payment_message.visible = true
	print("Добро пожаловать в парк аттракционов!")
