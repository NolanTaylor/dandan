extends "res://Game/card.gd"

func play() -> void:
	main.reorder_deck()
	
	await main.finished_reordering_deck
	main.draw_card()
	
	super()
