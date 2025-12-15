extends Node

var player_max_hp = 100
var player_current_hp = 100 # Ini yang akan naik turun saat battle
var player_current_mana = 0  # <--- [BARU] Simpan Mana di sini

var last_player_position = Vector2.ZERO
var last_enemy_position = Vector2.ZERO # [BARU] Simpan posisi musuh sebelum battle
var last_scene_path = ""
var active_enemy_type = "bee"

# --- DATABASE MUSUH ---
var defeated_enemies = [] 
var just_defeated_id = ""     
var current_enemy_id = ""
var just_fled_from_id = ""

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
		"attack_offset": 90.0, # [BARU] Jarak berhenti di depan player (Makin kecil makin dekat)
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
		"attack_offset": 60.0, # [BARU] Slime butuh lebih dekat karena dia pendek
		"question_file": "res://Enemies/Slime/Slime.json"
	}
}

# --- FUNGSI LOAD FILE JSON (TAMBAHKAN DI BAWAH) ---
# --- FUNGSI LOAD FILE JSON (UPDATE DIKIT) ---
func load_question_file(file_path: String) -> Array:
	# [FIX] Kita hapus tambahan "res://Data/" karena sekarang inputnya sudah Full Path
	
	if not FileAccess.file_exists(file_path):
		print("ERROR: File soal tidak ditemukan di path: " + file_path)
		return [{ "q": "Error: File Soal Hilang", "a": ["A", "B", "C", "D"], "c": 0 }]
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		if json.data is Array:
			return json.data
		else:
			print("Error: Format JSON salah (harus dimulai dengan kurung siku [])")
			return []
	else:
		print("JSON Parse Error di file " + file_path + ": ", json.get_error_message())
		return []
