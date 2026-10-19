extends Node3D

@export var cycle_path: NodePath = "../DayNightCycle"

var _cycle: Node3D

func _ready() -> void:
	_cycle = get_node_or_null(cycle_path)
	if not _cycle:
		return
	$Day.activated.connect(func(): _cycle.set_time(12.0))
	$Night.activated.connect(func(): _cycle.set_time(0.0))
	$Auto.activated.connect(_cycle.resume_cycle)
	_cycle.time_changed.connect(_update_clock)
	_update_clock(_cycle.hour, _cycle.night_strength)

func _update_clock(hour: float, night: float) -> void:
	var minutes := floori(hour * 60.0)
	var period := "Ночь" if night > 0.95 else ("День" if night < 0.05 else "Сумерки")
	$Clock.text = "%s · %02d:%02d" % [period, minutes / 60, minutes % 60]
	$Mode.text = "Автоматически" if _cycle.automatic else "Время остановлено"
