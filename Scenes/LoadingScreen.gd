extends Control

# --- REFERENSI NODE (PAKAI UNIQUE NAME %) ---
@onready var loading_richtext = %LoadingRichText
@onready var player_walk_anim = %PlayerWalkAnim

var target_scene_path: String = ""
var loading_status = 0
var progress = []

func _ready():
	# 1. SETUP TEKS WAVE
	if loading_richtext:
		loading_richtext.text = "[stiff height=8 speed=10 limit=20]NOW LOADING...[/stiff]"

	# 2. AMBIL TARGET SCENE
	target_scene_path = Global.next_scene_to_load
	
	if target_scene_path == "":
		# Fallback jika tidak ada target
		get_tree().change_scene_to_file("res://Scenes/Main.tscn") 
		return

	# 3. JALANKAN ANIMASI PLAYER (RANDOM)
	if player_walk_anim and player_walk_anim.sprite_frames:
		# Ambil semua nama animasi yang ada (walk, swordraise, walkshield, dll)
		var anim_list = player_walk_anim.sprite_frames.get_animation_names()
		
		if anim_list.size() > 0:
			# Pilih satu secara acak
			var random_anim = anim_list[randi() % anim_list.size()]
			player_walk_anim.play(random_anim)
			print("Loading Screen Animasi: " + random_anim) # Debug info
		else:
			print("Warning: Tidak ada animasi di SpriteFrames!")

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
	get_tree().change_scene_to_packed(new_scene)
