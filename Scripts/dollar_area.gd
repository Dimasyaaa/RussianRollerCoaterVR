extends Area3D

@onready var dollar_area: Area3D = $"."

func _ready():
	dollar_area.add_to_group("cash")
	dollar_area.name = "cash_area"
