extends "res://Game/card.gd"

func play() -> void:
	var hand : Node = main.get_node("zones/hand")
	var op_hand : Node = main.get_node("zones/opponent_hand")
	
	for card in hand.get_children():
		main.remove_card_from_hand(card, hand)
		main.update_opponent_hand.rpc(card.data, "op_hand", true)
		
	for card in op_hand.get_children():
		main.remove_card_from_hand(card, op_hand)
		main.update_opponent_hand.rpc(card.data, "hand", true)
		
	main.discard_pile.clear()
	main.deck.clear()
	main.init_deck(true)
	
	for i in 4:
		main.draw_card()
		
	for i in 4:
		main.draw_card.rpc()
		
	super()
