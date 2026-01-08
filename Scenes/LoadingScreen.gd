extends Control

# --- REFERENSI NODE (UNIQUE NAME %) ---
@onready var loading_richtext = %LoadingRichText
@onready var player_walk_anim = %PlayerWalkAnim
@onready var tips_label = %TipsLabel    # Teks utama tips

# --- CONFIG DATA ---
var tips_file_path = "res://LoadingScreen/tips_and_trick.json"

var target_scene_path: String = ""
var loading_status = 0
var progress = []

func _ready():
	# 1. SETUP TEKS LOADING
	if loading_richtext:
		loading_richtext.text = "[stiff height=8 speed=10 limit=20]NOW LOADING...[/stiff]"

	# 2. AMBIL TARGET SCENE
	target_scene_path = Global.next_scene_to_load
	
	if target_scene_path == "":
		get_tree().change_scene_to_file("res://Scenes/Main.tscn") 
		return

	# 3. TAMPILKAN TIPS SESUAI MAP
	show_random_tip()

	# 4. JALANKAN ANIMASI PLAYER
	setup_random_animation()

	# 5. MULAI LOADING THREADED
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(_delta):
	loading_status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if loading_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		# Beri waktu 1.5 detik agar pemain sempat membaca tips
		await get_tree().create_timer(1.5).timeout 
		on_loading_complete()

# --- LOGIKA: RANDOM TIPS BERDASARKAN MAP ---
func show_random_tip():
	if tips_label == null: return

	# 1. Tentukan peluang (0.0 sampai 1.0)
	var roll = randf()
	
	# 2. Jika roll < 0.4 (40% peluang), tampilkan tips humor khusus
	if roll < 0.4:
		var humor_tips = [
			"Kalau capek ngoding istirahat main Fesnuk !!",
			"Belajar coding itu menyenangkan bukan, BUKAN !!!"
		]
		tips_label.text = humor_tips[randi() % humor_tips.size()]
		return # Keluar dari fungsi agar tidak menimpa dengan tips JSON

	# 3. Sisa 60% peluang: Ambil dari file JSON (Tips Teknis)
	if FileAccess.file_exists(tips_file_path):
		var json_text = FileAccess.get_file_as_string(tips_file_path)
		var tips_data = JSON.parse_string(json_text)
		
		if tips_data is Dictionary:
			var category = "default"
			if tips_data.has(target_scene_path):
				category = target_scene_path
			
			var current_tips_list = tips_data.get(category, [])
			if current_tips_list.size() > 0:
				tips_label.text = current_tips_list[randi() % current_tips_list.size()]
	else:
		tips_label.text = "Tips: Indeks awal pada array selalu dimulai dari angka 0."

func setup_random_animation():
	if player_walk_anim and player_walk_anim.sprite_frames:
		var anim_list = player_walk_anim.sprite_frames.get_animation_names()
		if anim_list.size() > 0:
			var random_anim = anim_list[randi() % anim_list.size()]
			player_walk_anim.play(random_anim)

func on_loading_complete():
	var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
	get_tree().change_scene_to_packed(new_scene)
