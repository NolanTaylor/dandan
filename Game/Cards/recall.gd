extends "res://Game/card.gd"

func play() -> void:
	if main.discard_pile.is_empty():
		super()
		return
		
	main.view_deck("discard", true)
	
	var card_selected = await main.card_selected_from_deck
	
	main.add_card_to_hand(card_selected.data, main.get_node("zones/hand"))
	main.remove_card_from_deck(card_selected, "discard")
	
	super()
