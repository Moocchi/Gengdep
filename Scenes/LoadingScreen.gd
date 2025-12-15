extends Control

# --- REFERENSI NODE (PAKAI UNIQUE NAME %) ---
# Tanda % artinya script akan mencari node ini dimanapun dia berada di scene tree
@onready var loading_richtext = %LoadingRichText
@onready var player_walk_anim = %PlayerWalkAnim

var target_scene_path: String = ""
var loading_status = 0
var progress = []

func _ready():
	# 1. SETUP TEKS WAVE
	# height=8, speed=10, limit=20 (sesuai request)
	if loading_richtext:
		loading_richtext.text = "[stiff height=8 speed=10 limit=20]NOW LOADING...[/stiff]"

	# 2. AMBIL TARGET SCENE
	target_scene_path = Global.next_scene_to_load
	
	if target_scene_path == "":
		get_tree().change_scene_to_file("res://Scenes/FirstMenu.tscn") 
		return

	# 3. JALANKAN ANIMASI PLAYER
	if player_walk_anim:
		if player_walk_anim.sprite_frames.has_animation("walk"):
			player_walk_anim.play("walk")
		else:
			print("Warning: Animasi 'walk' tidak ditemukan di PlayerWalkAnim")

	# 4. MULAI LOADING
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(_delta):
	loading_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		await get_tree().create_timer(1.0).timeout 
		on_loading_complete()

func on_loading_complete():
	var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
	
	# Langsung ganti scene tanpa fade (Cut)
	get_tree().change_scene_to_packed(new_scene)
