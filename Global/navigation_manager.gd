extends Node

# Path Scene
const SCENE_LOBBY_PATH = "res://Scenes/Main.tscn"
const SCENE_LEVEL1_PATH = "res://Scenes/map2.tscn"
const SCENE_LEVEL2_PATH = "res://Scenes/map3.tscn"
const SCENE_LEVEL3_PATH = "res://Scenes/map4.tscn"

signal on_trigger_player_spawn

var spawn_door_tag 

func go_to_level(level_tag, destination_tag):
	var scene_path_to_load = ""
	
	match level_tag:
		"Main":
			scene_path_to_load = SCENE_LOBBY_PATH
		"map2":
			scene_path_to_load = SCENE_LEVEL1_PATH
		"map3":
			scene_path_to_load = SCENE_LEVEL2_PATH
		"map4": # <--- Add this block!
			scene_path_to_load = SCENE_LEVEL3_PATH
		
	if scene_path_to_load != "":
		spawn_door_tag = destination_tag
		# Panggil Loading Screen via Global
		Global.change_scene_with_loading(scene_path_to_load)
	else:
		print("Error: Level Tag '" + level_tag + "' tidak ditemukan di NavigationManager!")

func trigger_player_spawn(position : Vector2, direction : String):
	on_trigger_player_spawn.emit(position, direction)
