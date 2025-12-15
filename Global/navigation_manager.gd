extends Node

# Ubah dari preload() ke String path agar bisa dikirim ke Global
const SCENE_LOBBY_PATH = "res://Scenes/Main.tscn"
const SCENE_LEVEL1_PATH = "res://Scenes/map2.tscn"

signal on_trigger_player_spawn

var spawn_door_tag 

func go_to_level(level_tag, destination_tag):
	var scene_path_to_load = ""
	
	match level_tag:
		"Main":
			scene_path_to_load = SCENE_LOBBY_PATH
		"map2":
			scene_path_to_load = SCENE_LEVEL1_PATH
		
	if scene_path_to_load != "":
		spawn_door_tag = destination_tag
		
		# [UPDATE] Panggil Loading Screen via Global
		Global.change_scene_with_loading(scene_path_to_load)

func trigger_player_spawn(position : Vector2, direction : String):
	on_trigger_player_spawn.emit(position, direction)
