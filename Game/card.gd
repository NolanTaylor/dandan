extends Node2D

@export var type : String = "action"

const HIGHLIGHT : Color = Color("ebff9c")
const SELECTED : Color = Color("cde861")

enum ViewState {
	HAND,
	DECK_VIEW,
	DECK_SELECT,
	DECK_DRAG
}

var main : Node = null
var data : Dictionary = {} # <String, Variant>

var highlight : bool = false
var selected : bool = false
var dragging : bool = false
var viewing_state : int = ViewState.HAND
var anchor : Vector2 = Vector2.ZERO

signal card_selected(card : Node)
signal resolve

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	if Input.is_action_pressed("select") and can_drag():
		if not dragging and highlight:
			main.dragging_card = self
			dragging = true
			anchor = get_global_mouse_position()
		elif dragging:
			var box : Node = main.get_node("control_layer/reorder_panel/deck_reorder")
			var new_index : int = 0
			
			global_position.x = get_global_mouse_position().x
			
			for panel in box.get_children():
				if global_position.x > panel.global_position.x + panel.custom_minimum_size.x:
					new_index += 1
					
			if get_parent().get_index() != new_index:
				box.move_child(self.get_parent(), new_index)
	elif highlight and Input.is_action_just_pressed("select") and can_select():
		emit_signal("card_selected", self)
		
	if Input.is_action_just_released("select") and can_drag():
		main.dragging_card = null
		dragging = false
		position = Vector2.ZERO
		
func select() -> void:
	selected = true
	$color_rect.color = SELECTED
	
func deselect() -> void:
	selected = false
	$color_rect.color = Color.WHITE
	
func can_deck_select() -> bool:
	return (viewing_state == ViewState.DECK_SELECT or can_drag())
	
func can_drag() -> bool:
	return (viewing_state == ViewState.DECK_DRAG and \
		(main.dragging_card == self or main.dragging_card == null))
	
func set_view_state(state : Variant) -> void:
	if typeof(state) == TYPE_STRING:
		match state:
			"hand":
				viewing_state = ViewState.HAND
			"deck_view":
				viewing_state = ViewState.DECK_VIEW
			"deck_select":
				viewing_state = ViewState.DECK_SELECT
			"deck_drag":
				viewing_state = ViewState.DECK_DRAG
	else:
		viewing_state = state
		
func can_select() -> bool:
	match viewing_state:
		ViewState.HAND:
			return main.my_priority()
		ViewState.DECK_VIEW:
			return false
		ViewState.DECK_SELECT:
			return true
		ViewState.DECK_DRAG:
			return true
		_:
			return false
			
func play() -> void:
	await get_tree().create_timer(0.2).timeout
	
	emit_signal("resolve")
	
func _on_control_parent_mouse_entered() -> void:
	highlight = true
	
	if !selected and can_select() and (get_parent().name == "hand" or can_deck_select()):
		$color_rect.color = HIGHLIGHT
	
func _on_control_parent_mouse_exited() -> void:
	highlight = false
	
	if !selected and can_select():
		$color_rect.color = Color.WHITE
