extends Node

# --- TUJUAN LOADING SCREEN ---
var next_scene_to_load: String = "res://Scenes/map2.tscn" 

# --- PLAYER STATS (UPDATE) ---
var player_max_hp = 100
var player_current_hp = 100
var player_current_mana = 0

# [BARU] Status Damage Player
var player_damage_min = 10
var player_damage_max = 15
var player_crit_chance = 0.4 # 40% kesempatan critical hit

#PARRY AND POWER UP CHANCE
var player_parry_chance = 1.0 # 20% chance parry
var player_powerup_chance = 1.0 # 50% peluang muncul jika jawaban Perfect

# --- POSISI & NAVIGASI ---
var last_player_position = Vector2.ZERO
var last_enemy_position = Vector2.ZERO
var last_scene_path = ""
var active_enemy_type = "bee"

# --- DATABASE LOGIC ---
var defeated_enemies = [] 
var just_defeated_id = ""     
var current_enemy_id = ""
var just_fled_from_id = ""

# --- BATTLE VISUAL ---
var battle_background_texture: Texture2D = null

# --- DATA MUSUH ---
var enemy_database = {
	"bee": {
		"name": "Bee",
		"hp": 100,
		"damage_min": 1,
		"damage_max": 5,
		"frames": preload("res://Enemies/Bee/Bee.tres"),
		"scale": Vector2(4, 4),
		"animation_name": "fly",
		"should_flip": true,
		"attack_offset": 90.0,
		"question_file": "res://Enemies/Bee/Bee.json"
	},
	"slime": {
		"name": "Slime",
		"hp": 100,
		"damage_min": 5,
		"damage_max": 10,
		"frames": preload("res://Enemies/Slime/Slime.tres"),
		"scale": Vector2(4, 4),
		"animation_name": "idle",
		"should_flip": false,
		"attack_offset": 60.0,
		"question_file": "res://Enemies/Slime/Slime.json"
	}
}

func load_question_file(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		return [{ "q": "Error File", "a": ["A", "B", "C", "D"], "c": 0 }]
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK and json.data is Array:
		return json.data
	return []

# --- FUNGSI LOADING SCREEN ---
func change_scene_with_loading(target_path: String):
	next_scene_to_load = target_path
	get_tree().change_scene_to_file("res://Scenes/LoadingScreen.tscn")
