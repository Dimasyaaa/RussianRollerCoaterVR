extends XRToolsSnapZone

## Actual pickable notes are stored, not copied when deposited or withdrawn.
signal banknote_count_changed(count: int)

@export_range(1, 20, 1) var capacity := 8
@export_range(1, 20, 1) var starting_banknotes := 3

var can_ranged_grab := true
var _reserve: Array[XRToolsPickable] = []
var _issuing := false
const BANKNOTE = preload("res://Scenes/banknote.tscn")

func _initial_object_check() -> void:
	super._initial_object_check()
	add_banknotes(maxi(0,starting_banknotes-banknote_count()))
	_update_counter()

func banknote_count() -> int:
	_reserve = _reserve.filter(func(bill): return is_instance_valid(bill))
	return _reserve.size() + (1 if is_instance_valid(picked_up_object) else 0)

## Public refill API. Returns the number added; capacity is always respected.
func add_banknotes(amount: int = 1) -> int:
	var added := 0
	for i in range(maxi(0,mini(amount,capacity-banknote_count()))):
		var bill: XRToolsPickable = BANKNOTE.instantiate()
		get_parent().add_child(bill)
		if deposit_bill(bill):
			added += 1
		else:
			bill.queue_free()
	return added

func deposit_bill(target: Node3D) -> bool:
	if not enabled or not is_instance_valid(target) or not target is XRToolsPickable:
		return false
	var bill := target as XRToolsPickable
	if not bill.is_in_group("money") or bill.is_picked_up():
		return false
	if bill == picked_up_object or _reserve.has(bill) or banknote_count() >= capacity:
		return false
	# The original large cash model can also be stored, with wallet-size geometry.
	_fit_banknote(bill)
	if not is_instance_valid(picked_up_object) and not _issuing:
		super.pick_up_object(bill)
	else:
		bill.reparent(get_parent())
		bill.top_level = false
		bill.position = Vector3.ZERO
		bill.freeze = true
		bill.enabled = false
		bill.collision_layer = 0
		bill.collision_mask = 0
		bill.visible = false
		_reserve.append(bill)
	_update_counter()
	return true

func drop_object() -> void:
	super.drop_object()
	_update_counter()
	# Let the grab driver finish transferring the withdrawn note to the hand.
	_issue_next.call_deferred()

func _on_target_dropped(target: Node3D) -> void:
	# Deferred drop events may arrive after a note has left the wallet area.
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= grab_distance+0.04:
		deposit_bill(target)

func _issue_next() -> void:
	if _issuing or not is_inside_tree() or is_instance_valid(picked_up_object):
		return
	_issuing = true
	while not _reserve.is_empty():
		var bill: XRToolsPickable = _reserve.pop_front()
		if not is_instance_valid(bill):
			continue
		bill.enabled = true
		bill.visible = true
		bill.top_level = true
		bill.collision_layer = 4
		bill.collision_mask = 3
		super.pick_up_object(bill)
		break
	_issuing = false
	_update_counter()

func _fit_banknote(bill: XRToolsPickable) -> void:
	bill.scale = Vector3.ONE
	bill.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	bill.release_mode = XRToolsPickable.ReleaseMode.UNFROZEN
	bill.picked_up_layer = 65536
	var mesh := bill.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		mesh.mesh = mesh.mesh.duplicate()
		(mesh.mesh as BoxMesh).size = Vector3(0.14,0.003,0.10)
	var collision := bill.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		collision.shape = BoxShape3D.new()
		(collision.shape as BoxShape3D).size = Vector3(0.14,0.01,0.10)
	var stripe := bill.get_node_or_null("MeshInstance3D2") as MeshInstance3D
	if stripe:
		stripe.transform = Transform3D(Basis.from_scale(Vector3(0.135,0.04756756,0.02873869)),Vector3(-0.00098887,0.00094647,0.01783575))

func _update_counter() -> void:
	var count := banknote_count()
	var label := get_parent().get_node_or_null("BanknoteCount") as Label3D
	if label:
		label.text = "КУПЮРЫ: %d/%d" % [count,capacity]
	banknote_count_changed.emit(count)
