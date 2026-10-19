extends XRToolsSnapZone

## Replenishes the practice banknote tray after its note has been taken.
@export var refill_delay := 1.0
var can_ranged_grab := true
var _refill_pending := false
const BANKNOTE = preload("res://Scenes/banknote.tscn")

func _ready() -> void:
	super._ready()
	_refill.call_deferred()

func drop_object() -> void:
	super.drop_object()
	if not _refill_pending:
		_refill_pending = true
		await get_tree().create_timer(refill_delay).timeout
		if is_inside_tree():
			_refill()
		_refill_pending = false

func _refill() -> void:
	if is_instance_valid(picked_up_object):
		return
	var bill: XRToolsPickable = BANKNOTE.instantiate()
	add_child(bill)
	pick_up_object(bill)
