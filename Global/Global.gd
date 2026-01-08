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
var player_crit_chance = 1.0 # 40% kesempatan critical hit

#PARRY AND POWER UP CHANCE
var player_parry_chance = 1.0 # 20% chance parry
var player_powerup_chance = 1.0 # 40% peluang muncul jika jawaban Perfect

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
		"question_file": "res://Enemies/Bee/Bee.json",
		"is_boss":false
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
		"question_file": "res://Enemies/Slime/Slime.json",
		"is_boss":false
	},
	"nightborn": {
		"name": "Nightborn",
		"hp": 150,
		"damage_min": 10,
		"damage_max": 15,
		"frames": preload("res://Enemies/Nightborn/Nightborn.tres"),
		"scale": Vector2(5, 5),
		"animation_name": "idle",
		"should_flip": true,
		"player_attack_offset": 110.0, #makin gede makin jauh dari musuh
		"attack_offset": 100.0, #makin gede makin jauh dari player
		"y_offset": -55.0, # <--- TAMBAHKAN INI (Sesuaikan angkanya sampai pas)
		"question_file": "res://Enemies/Nightborn/Nightborn.json",
		"is_boss": true
	},
	"soul_harbinger": {
		"name": "Soul Harbinger",
		"hp": 10, # Darah Phase 1
		"damage_min": 10,
		"damage_max": 12,
		"frames": preload("res://Enemies/SoulHarbinger/SoulHarbinger.tres"),
		"scale": Vector2(4, 4), 
		"animation_name": "idle",
		"should_flip": true,
		"is_boss": true,
		"y_offset": -30.0,
		"player_attack_offset": 120.0,
		"attack_offset": 100.0,
		"max_charge": 5,
		"summon_scale": Vector2(0.2, 0.2),
		"max_summons": 5,
		
		# --- SISTEM SOAL DINAMIS ---
		"question_file": "res://Enemies/SoulHarbinger/SoulHarbinger.json", # Soal Phase 1 (Normal)
		"phase_two_question_file": "res://Enemies/SoulHarbinger/PhaseTwo.json", # <--- TAMBAHKAN INI (Soal Lebih Sulit)
		
		# --- LOGIKA REVIVE PHASE 2 ---
		"has_phase_two": true,
		"is_phase_2": false,
		"phase_two_hp": 450, 
		"phase_two_bonus_atk": 3 
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
