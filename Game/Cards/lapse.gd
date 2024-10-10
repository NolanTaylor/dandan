extends "res://Game/card.gd"

func play() -> void:
	main.set_action_lapsed.rpc()
	
	super()
