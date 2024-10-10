extends Node2D

const starting_deck : Dictionary = { # <String, int>
	"strike": 12,
	"recall": 4,
	"forget": 4,
	"foretell": 4,
	"rewind": 2,
	"lapse": 8,
	"wit": 6,
}

enum VisMode {
	HIDDEN,
	SERVER,
	CLIENT,
	BOTH
}

enum Phase {
	HOST_TURN,
	CLIENT_TURN,
	HOST_REACTION,
	CLIENT_REACTION,
	RESOLVING,
}

var card_preload : Dictionary = { } # <String, PackedScene>
var deck : Array = [] # <Dictionary<String, Variant>>
var discard_pile : Array = [] # <Dictionary<String, Variant>>
var current_card : Node = null
var dragging_card : Node = null

var phase : int = Phase.HOST_TURN
var server_balance : int = 3
var client_balance : int = 3

var first_meditate : bool = false
var action_lapsed : bool = false
var picking_from_deck : String = "null"

signal card_selected_from_deck(card)
signal finished_reordering_deck

func _ready() -> void:
	if multiplayer.is_server():
		init_deck()
		MultiplayerManager.game_entered_as_server()
		
		update_game()
	else:
		update_state()
	
func _process(delta : float) -> void:
	if !first_meditate and my_turn():
		first_meditate = true
		_on_meditate_button_pressed()
		
func update_game() -> void:
	send_data.rpc(phase, deck, discard_pile, server_balance, client_balance)
	
@rpc("any_peer", "call_local")
func send_data(phase : int, deck : Array, discard : Array, server_balance : int, \
client_balance: int) -> void:
	self.phase = phase
	self.deck = deck
	self.discard_pile = discard
	self.server_balance = server_balance
	self.client_balance = client_balance
	
	if server_balance <= 0:
		server_win_screen()
	elif client_balance <= 0:
		client_win_screen()
		
	update_state()
	
func update_state() -> void:
	$control_layer/deck_size.text = "deck size: " + str(deck.size())
	$control_layer/discard_pile.text = "discard pile: " + str(discard_pile.size())
	$control_layer/server_balance.text = "server balance: " + str(server_balance)
	$control_layer/client_balance.text = "client balance: " + str(client_balance)
	
	var marker_start = $markers/hand_marker_start
	var marker_end = $markers/hand_marker_end
	
	for hand in [%hand, %opponent_hand]:
		var hand_size : int = hand.get_child_count()
		var x : int = marker_start.position.x
		var y : int = marker_end.position.x
		var gap : int = (y - x) / 3
		
		if hand_size > 4:
			gap = (y - x) / (hand_size - 1)
		
		for i in hand.get_child_count():
			var child = hand.get_child(i)
			child.position = Vector2(x + gap * i, marker_start.position.y)
			
		marker_start = $markers/opponent_hand_marker_start
		marker_end = $markers/opponent_hand_marker_end
		
	if my_turn():
		%meditate_button.disabled = false
	else:
		%meditate_button.disabled = true
		%play_button.disabled = true
		
func server_win_screen() -> void:
	pass
	
func client_win_screen() -> void:
	pass
	
func init_deck(without_rewind : bool = false) -> void:
	var rewind_taken_out : bool = true
	
	if without_rewind:
		rewind_taken_out = false
		
	for key in starting_deck.keys():
		for i in range(starting_deck[key]):
			if key == "rewind" and !rewind_taken_out:
				rewind_taken_out = true
			else:
				deck.append(create_card(key))
				
	deck.shuffle()
	
func create_card(card_name : String, caster : String = "null", \
visibility : int = VisMode.HIDDEN) -> Dictionary:
	var card : Dictionary = {
		"name": card_name,
		"caster": caster,
		"visibility": visibility,
	}
	
	return card
	
func load_card(card : Dictionary) -> Node:
	if card_preload.has(card["name"]):
		var card_obj = card_preload[card["name"]].instantiate()
		
		card_obj.scale = Vector2(0.6, 0.6)
		card_obj.main = self
		card_obj.data = card
		card_obj.card_selected.connect(card_selected)
		
		if is_card_visible(card):
			card_obj.modulate.a = 1.0
		else:
			card_obj.modulate.a = 0.5
			
		return card_obj
	else:
		card_preload[card["name"]] = load("res://Game/Cards/{0}.tscn".format([card["name"]]))
		return load_card(card)
		
func my_turn() -> bool:
	return (multiplayer.is_server() and phase == Phase.HOST_TURN) or \
		(!multiplayer.is_server() and phase == Phase.CLIENT_TURN)
		
func my_reaction() -> bool:
	return (multiplayer.is_server() and phase == Phase.HOST_REACTION) or \
		(!multiplayer.is_server() and phase == Phase.CLIENT_REACTION)
		
func my_priority() -> bool:
	if multiplayer.is_server():
		return (phase == Phase.HOST_TURN or phase == Phase.HOST_REACTION)
	else:
		return (phase == Phase.CLIENT_TURN or phase == Phase.CLIENT_REACTION)
		
@rpc("any_peer", "call_remote")
func set_action_lapsed() -> void:
	action_lapsed = true
	
func is_card_visible(card : Dictionary) -> bool:
	var vis : int = card["visibility"]
	
	if (multiplayer.is_server() and vis == VisMode.SERVER) or \
	(!multiplayer.is_server() and vis == VisMode.CLIENT) or vis == VisMode.BOTH:
		return true
	else:
		return false
		
func view_deck(deck_name : String, select : bool = false) -> void:
	$zones.hide()
	
	var deck : Array
	
	match deck_name:
		"deck", "library":
			deck = self.deck
		"discard", "discard_pile":
			deck = self.discard_pile
			
	for child in %deck_showcase.get_children():
		%deck_showcase.remove_child(child)
		child.queue_free()
		
	for card in deck:
		var obj : Node = load_card(card)
		var new_panel : Panel = Panel.new()
		
		if select or picking_from_deck == deck_name:
			obj.set_view_state("deck_select")
			picking_from_deck = deck_name
		else:
			obj.set_view_state("deck_view")
			
		new_panel.custom_minimum_size = Vector2(300, 420) * 0.6
		new_panel.add_child(obj)
		
		%deck_showcase.add_child(new_panel)
		
	$control_layer/showcase_panel.show()
	
func reorder_deck() -> void:
	for child in %deck_reorder.get_children():
		%deck_reorder.remove_child(child)
		child.queue_free()
		
	var look : Array = []
	
	for i in 4:
		var data : Dictionary = deck[i]
		
		if multiplayer.is_server():
			data["visibility"] = VisMode.SERVER
		else:
			data["visibility"] = VisMode.CLIENT
			
		look.append(data)
		
	for card in look:
		var obj : Node = load_card(card)
		var new_panel : Panel = Panel.new()
		
		obj.set_view_state("deck_drag")
		
		new_panel.custom_minimum_size = Vector2(300, 420) * 0.6
		new_panel.add_child(obj)
		
		%deck_reorder.add_child(new_panel)
		
	$control_layer/reorder_panel.show()
	
@rpc("any_peer", "call_remote")
func draw_card() -> void:
	if deck.is_empty():
		return
		
	var card : Dictionary = deck.pop_front()
	
	add_card_to_hand(card, %hand)
	
	update_opponent_hand.rpc(card)
	update_game()
	
func discard(card : Node) -> void:
	card.data["visibility"] = VisMode.BOTH
	card.data["caster"] = "null"
	
	discard_pile.push_back(card.data)
	
@rpc("any_peer", "call_remote")
func update_opponent_hand(card : Dictionary, hand_name : String = "op_hand", \
remove : bool = false) -> void:
	var hand : Node = %opponent_hand
	
	if hand_name == "hand":
		hand = %hand
	
	if remove:
		remove_card_from_hand(card, hand)
	else:
		add_card_to_hand(card, hand)
	
func add_card_to_hand(card : Dictionary, hand : Node) -> void:
	var marker_start : Node
	var marker_end : Node
	
	if hand == %hand:
		if multiplayer.is_server():
			card["caster"] = "host"
			card["visibility"] = VisMode.SERVER
		else:
			card["caster"] = "client"
			card["visibility"] = VisMode.CLIENT
	elif hand == %opponent_hand:
		if multiplayer.is_server():
			card["caster"] = "client"
			card["visibility"] = VisMode.CLIENT
		else:
			card["caster"] = "host"
			card["visibility"] = VisMode.SERVER
	else:
		push_error("invalid hand")
		return
		
	var card_obj : Node = load_card(card)
	
	if hand == %opponent_hand:
		card_obj.rotation_degrees = 180
		
	card_obj.set_view_state("hand")
	hand.add_child(card_obj)
	
	update_state()
	
func remove_card_from_hand(card : Variant, hand : Node) -> void:
	for child in hand.get_children():
		if typeof(card) == TYPE_DICTIONARY:
			if child.data == card:
				hand.remove_child(child)
				child.queue_free()
				break
		else:
			if child == card:
				hand.remove_child(child)
				child.queue_free()
				break
				
	update_state()
	
func remove_card_from_deck(card : Variant, deck : Variant) -> void:
	var card_data : Dictionary
	
	if typeof(card) == TYPE_DICTIONARY:
		card_data = card
	else:
		card_data = card.data
		
	if typeof(deck) == TYPE_ARRAY:
		deck.erase(card_data)
	else:
		match deck:
			"deck", "library":
				deck.erase(card_data)
			"discard", "discard_pile":
				discard_pile.erase(card_data)
				
func card_selected(card : Node) -> void:
	deselect_all_cards()
	card.select()
	current_card = card
	
	if card.can_deck_select():
		$control_layer/showcase_panel.hide()
		$zones.show()
		picking_from_deck = "null"
		emit_signal("card_selected_from_deck", card)
	elif (my_turn() and card.type == "action") or (my_reaction() and card.type == "reaction"):
		%play_button.disabled = false
		
func deselect_all_cards() -> void:
	for child in %hand.get_children():
		child.deselect()
		
	%play_button.disabled = true
	
@rpc("any_peer", "call_remote")
func prompt_reaction(card_data : Dictionary) -> void:
	card_data["visibility"] = VisMode.BOTH
	
	var card_obj = load_card(card_data)
	
	card_obj.position = $markers/play_marker.position
	
	%action.add_child(card_obj)
	
	$control_layer/resolve_button.show()
	
@rpc("any_peer", "call_remote")
func display_reaction(card_data : Dictionary) -> void:
	card_data["visibility"] = VisMode.BOTH
	
	var card_obj = load_card(card_data)
	
	card_obj.position = $markers/response_marker.position
	
	%reaction.add_child(card_obj)
	
func pass_turn() -> void:
	if phase == Phase.HOST_TURN or phase == Phase.CLIENT_REACTION:
		phase = Phase.CLIENT_TURN
	else:
		phase = Phase.HOST_TURN
		
	update_game()
	
func pass_priority() -> void:
	if phase == Phase.HOST_TURN:
		phase = Phase.CLIENT_REACTION
	elif phase == Phase.CLIENT_TURN:
		phase = Phase.HOST_REACTION
		
	update_game()
	
@rpc("any_peer", "call_remote")
func resolve() -> void:
	phase = Phase.RESOLVING
	update_game()
	
	if %reaction.get_child_count() > 0:
		var card = %reaction.get_child(0)
		var tween = get_tree().create_tween()
		
		send_stack_away.rpc("reaction")
		tween.tween_property(card, "position", Vector2(0, 0), 1.0)
		tween.tween_property(card, "scale", Vector2(0, 0), 1.0)
		
		await tween.finished
		
		card.play()
		await card.resolve
		discard(card)
		update_game()
		%reaction.remove_child(card)
		card.queue_free()
		
		resolve.rpc()
	elif %action.get_child_count() > 0:
		var card = %action.get_child(0)
		
		if (multiplayer.is_server() and card.data["caster"] == "host") or \
		(!multiplayer.is_server() and card.data["caster"] == "client"):
			var tween = get_tree().create_tween()
			
			send_stack_away.rpc("action")
			tween.tween_property(card, "position", Vector2(0, 0), 1.0)
			tween.tween_property(card, "scale", Vector2(0, 0), 1.0)
			
			await tween.finished
			
			if action_lapsed:
				action_lapsed = false
				card.data["visibility"] = VisMode.BOTH
				deck.push_front(card.data)
			else:
				card.play()
				await card.resolve
				discard(card)
				
			update_game()
			%action.remove_child(card)
			card.queue_free()
			
			if multiplayer.is_server():
				phase = Phase.CLIENT_TURN
			else:
				phase = Phase.HOST_TURN
				
			update_game()
		else:
			resolve.rpc()
			
@rpc("any_peer", "call_remote")
func send_stack_away(heap : String) -> void:
	var parent : Node
	
	if heap == "action":
		parent = %action
	elif heap == "reaction":
		parent = %reaction
	else:
		return
		
	var card = parent.get_child(0)
	var tween = get_tree().create_tween()
	
	tween.tween_property(card, "position", Vector2(0, 0), 1.0)
	tween.tween_property(card, "scale", Vector2(0, 0), 1.0)
	
	await tween.finished
	
	parent.remove_child(card)
	card.queue_free()
	
func _on_global_button_pressed() -> void:
	deselect_all_cards()
	
func _on_meditate_button_pressed() -> void:
	for child in %hand.get_children():
		deck.push_back(child.data)
		child.queue_free()
		update_opponent_hand.rpc(child.data, "op_hand", true)
		await child.tree_exited
		
	for i in range(4):
		draw_card()
		
	pass_turn()
	
func _on_play_button_pressed() -> void:
	if current_card == null:
		return
		
	if my_turn():
		current_card.position = $markers/play_marker.position
		%hand.remove_child(current_card)
		%action.add_child(current_card)
		update_opponent_hand.rpc(current_card.data, "op_hand", true)
		
		prompt_reaction.rpc(current_card.data)
		pass_priority()
	elif my_priority():
		current_card.position = $markers/response_marker.position
		%hand.remove_child(current_card)
		%reaction.add_child(current_card)
		update_opponent_hand.rpc(current_card.data, "op_hand", true)
		
		$control_layer/resolve_button.hide()
		display_reaction.rpc(current_card.data)
		resolve()
		
func _on_view_deck_pressed() -> void:
	view_deck("deck")
	
func _on_view_discard_pressed() -> void:
	view_deck("discard")
	
func _on_exit_showcase_button_pressed() -> void:
	$control_layer/showcase_panel.hide()
	$zones.show()
	
func _on_resolve_button_pressed() -> void:
	$control_layer/resolve_button.hide()
	resolve()
	
func _on_reorder_done_button_pressed() -> void:
	for i in 4:
		deck.pop_front()
		
	for i in range(3, -1, -1):
		var card : Node = %deck_reorder.get_child(i).get_child(0)
		deck.push_front(card.data)
		
	$control_layer/reorder_panel.hide()
	emit_signal("finished_reordering_deck")
