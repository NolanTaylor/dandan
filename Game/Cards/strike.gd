extends "res://Game/card.gd"

func play() -> void:
	if data["caster"] == "host":
		main.client_balance -= 1
	else:
		main.server_balance -= 1
		
	super()
