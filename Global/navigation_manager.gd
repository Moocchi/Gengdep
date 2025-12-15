extends Node

const scene_lobby = preload("res://Scenes/Main.tscn")
const scene_level1 = preload("res://Scenes/map2.tscn")

signal on_trigger_player_spawn

var spawn_door_tag 

func go_to_level(level_tag, destination_tag):
	var scene_to_load 
	
	match level_tag:
		"Main":
			scene_to_load = scene_lobby
		"map2":
			scene_to_load = scene_level1
		
	if scene_to_load != null:
		spawn_door_tag = destination_tag
		# Gunakan call_deferred agar game tidak crash saat tabrakan pintu
		get_tree().call_deferred("change_scene_to_packed", scene_to_load)

func trigger_player_spawn(position : Vector2, direction : String):
	on_trigger_player_spawn.emit(position, direction)
