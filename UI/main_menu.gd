extends Control

var main_scene : PackedScene = preload("res://Game/main.tscn")

var lobby_name : String = ""
var client_name : String = ""

func _ready() -> void:
	if OS.has_environment("USERNAME"):
		client_name = OS.get_environment("USERNAME")
	else:
		var desktop_path = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		client_name = desktop_path[desktop_path.size() - 2]
		
func _process(delta: float) -> void:
	if $players.get_child_count() == 2:
		%ready_button.disabled = false
		
@rpc("call_local")
func start_game() -> void:
	get_tree().change_scene_to_packed(main_scene)
	
func disable_buttons() -> void:
	$host_button.disabled = true
	$join_button.disabled = true
	
func enable_buttons() -> void:
	$host_button.disabled = false
	$join_button.disabled = false
	
func _on_host_button_pressed() -> void:
	$host_popup.popup()
	disable_buttons()
	
func _on_join_button_pressed() -> void:
	$join_popup.popup()
	disable_buttons()
	MultiplayerManager.join_as_player()
	
func _on_confirm_button_pressed() -> void:
	if %lobby_name.text == "":
		$host_popup/name_empty_error_popup.popup()
	else:
		$host_popup.hide()
		lobby_name = %lobby_name.text
		$lobby_popup.popup()
		MultiplayerManager.become_host()
	
func _on_cancel_button_pressed() -> void:
	$host_popup.hide()
	enable_buttons()
	
func _on_host_popup_close_requested() -> void:
	$host_popup.hide()
	enable_buttons()
	
func _on_name_empty_error_confirm_button_pressed() -> void:
	$host_popup/name_empty_error_popup.hide()
	
func _on_name_empty_error_popup_close_requested() -> void:
	$host_popup/name_empty_error_popup.hide()
	
func _on_name_empty_error_popup_focus_exited() -> void:
	$host_popup/name_empty_error_popup.hide()
	
func _on_lobby_popup_close_requested() -> void:
	$lobby_popup.hide()
	enable_buttons()
	
func _on_ready_button_pressed() -> void:
	start_game.rpc()
	
func _on_join_popup_close_requested() -> void:
	$join_popup.hide()
	enable_buttons()
