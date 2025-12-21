extends Control

# --- CONFIG ---
var max_time = 10.0
var current_time = 0.0
var battle_active = true
var is_waiting_next_turn = false
var is_confirming_flee = false 
var is_performing_action = false 
var powerup_hits = 0             

# --- ULTIMATE SYSTEM ---
var max_mana = 100
var current_mana = 0 

# --- STATUS ---
var player_hp = 100 
var enemy_hp = 100
var enemy_data = {} 

# --- POSISI & ANIMASI ---
var original_player_pos = Vector2.ZERO
var original_enemy_pos = Vector2.ZERO 
var enemy_idle_anim_name = "default" 

# --- NAVIGASI ---
var current_btn_index = 0
var buttons = []

# --- DATA SOAL ---
var question_bank = [] 
var current_correct_index = 0
var current_question_data = {}

# --- REFERENSI SCENE ---
var floating_text_scene = preload("res://Scenes/FloatingText.tscn")

# --- REFERENSI NODE UI ---
@onready var timer_label = $TimerUI/TimerLabel
@onready var timer_bar = $TimerUI/TimerBar
@onready var question_label = $ActionPanel/QuestionBox/QuestionLabel
@onready var player_info = $TopBar/PlayerInfo
@onready var enemy_info = $TopBar/EnemyInfo
@onready var buttons_grid = $ActionPanel/ButtonsGrid

# UI ULTIMATE & EXIT
@onready var ult_progress = $UltCircle        
@onready var ult_button = $UltCircle/UltButton 
@onready var exit_button = $ExitButton

# PARRY AND POWERUP
@onready var parry_qte_system = $ParryQTE
@onready var powerup_qte = $PowerupQTE

# ANIMASI & WORLD
@onready var player_anim = $BattleArea/PlayerAnim
@onready var enemy_anim = $BattleArea/EnemyAnim
@onready var camera = $Camera2D 
@onready var background = $Background 

# TOMBOL JAWABAN
@onready var btn1 = $ActionPanel/ButtonsGrid/Button1
@onready var btn2 = $ActionPanel/ButtonsGrid/Button2
@onready var btn3 = $ActionPanel/ButtonsGrid/Button3
@onready var btn4 = $ActionPanel/ButtonsGrid/Button4

func _ready():
	buttons = [btn1, btn2, btn3, btn4]
	
	btn1.pressed.connect(func(): check_answer(0))
	btn2.pressed.connect(func(): check_answer(1))
	btn3.pressed.connect(func(): check_answer(2))
	btn4.pressed.connect(func(): check_answer(3))
	
	if ult_button:
		ult_button.pressed.connect(perform_ultimate)
		ult_button.focus_mode = Control.FOCUS_NONE 
	
	if exit_button:
		exit_button.pressed.connect(ask_to_flee)
		exit_button.focus_mode = Control.FOCUS_NONE
	
	# [SETUP PARRY SYSTEM]
	if parry_qte_system:
		parry_qte_system.parry_finished.connect(_on_parry_completed)
		parry_qte_system.visible = false
	
	# [FIX] Mana & HP kembali normal
	player_hp = Global.player_current_hp
	current_mana = Global.player_current_mana 
	
	load_enemy_data()
	setup_player_anim()
	update_mana_ui()
	
	if Global.battle_background_texture != null:
		if has_node("Background"):
			$Background.texture = Global.battle_background_texture
	
	await get_tree().process_frame
	original_player_pos = player_anim.position
	original_enemy_pos = enemy_anim.position
	
	if question_bank.size() > 0:
		update_ui()
		start_new_turn()
	else:
		question_label.text = "ERROR: Soal tidak ditemukan!"
		set_buttons_enabled(false)

func _process(delta):
	# [FIX] Hentikan semua update timer dan input jika sedang melakukan aksi (QTE/Animasi)
	if is_performing_action: 
		return

	if battle_active and not is_waiting_next_turn:
		handle_gamepad_input()

		current_time -= delta
		timer_bar.value = current_time
		timer_label.text = "%.2fs" % current_time
		
		if current_time <= 3.0:
			var alpha = (sin(Time.get_ticks_msec() * 0.015) + 1.0) / 2.0
			timer_label.modulate = Color(1, 1, 1).lerp(Color(1, 0, 0), alpha)
		else:
			timer_label.modulate = Color(1, 1, 1)
		
		if current_time <= 0:
			handle_timeout()

# --- INPUT HANDLING (Parry & Menu) ---
func _input(event):
	pass

func handle_gamepad_input():
	if parry_qte_system and parry_qte_system.is_active: return

	if is_confirming_flee:
		if Input.is_action_just_pressed("arrow_right"): change_selection(1)
		elif Input.is_action_just_pressed("arrow_left"): change_selection(-1)
		if Input.is_action_just_pressed("confirm_button"): check_answer(current_btn_index)
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("back_button"): cancel_flee()
			
	else:
		if Input.is_action_just_pressed("arrow_right"): change_selection(1)
		elif Input.is_action_just_pressed("arrow_left"): change_selection(-1)
		elif Input.is_action_just_pressed("arrow_down"): change_selection(2)
		elif Input.is_action_just_pressed("arrow_up"): change_selection(-2)
		
		if Input.is_action_just_pressed("confirm_button"): check_answer(current_btn_index)
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("back_button"): ask_to_flee()
		
		if Input.is_action_just_pressed("ultimate_attack"):
			perform_ultimate()

func handle_timeout():
	if is_waiting_next_turn or not battle_active: return
	set_buttons_enabled(false)
	is_waiting_next_turn = true
	question_label.text = "⌛ WAKTU HABIS!\nGiliranmu terlewat..."
	await get_tree().create_timer(1.5).timeout
	enemy_turn()

# =========================================
# --- SISTEM MUSUH & PARRY (LOGIKA BARU) ---
# =========================================

func enemy_turn():
	if not battle_active: return
	
	# 1. Musuh MAJU ke depan Player
	await enemy_move_to_player()
	
	# 2. TEPAT SEBELUM MENYERANG: Cek Kesempatan Parry
	var roll = randf()
	
	if roll < Global.player_parry_chance:
		# --- YES: PARRY MODE DIMULAI ---
		Engine.time_scale = 0.1 # Slow Motion Dramatis
		
		# Hitung posisi muncul QTE (Depan-Atas Player)
		var center_pos = player_anim.global_position
		var random_x = randf_range(10, 120)
		var random_y = randf_range(-120, -40)
		var spawn_pos = center_pos + Vector2(random_x, random_y)
		
		# Panggil QTE dengan Durasi Cepat (0.6 detik)
		parry_qte_system.start_qte(spawn_pos, 0.6)
		
		# KITA STOP DULU DI SINI. Nanti dilanjut di _on_parry_completed
		return
		
	else:
		# --- NO: NORMAL HIT (Tidak ada kesempatan parry) ---
		# Lanjutkan animasi serangan
		await enemy_play_attack_anim()
		
		# Hitung dan terapkan damage
		var min_dmg = enemy_data.get("damage_min", 1)
		var max_dmg = enemy_data.get("damage_max", 5)
		var damage = randi_range(min_dmg, max_dmg)
		finish_enemy_attack(damage)
		
		# Musuh mundur
		await enemy_return_to_pos()

# Fungsi Callback saat Parry Selesai (Sukses/Gagal)
# Fungsi Callback saat Parry Selesai (Sukses/Gagal)
func _on_parry_completed(is_success: bool):
	# Kembalikan waktu normal INSTAN
	Engine.time_scale = 1.0 
	
	if is_success:
		# --- PARRY SUKSES ---
		
		# 1. Player Pasang Badan Dulu (Block/Parry)
		if player_anim.sprite_frames.has_animation("block"):
			player_anim.play("block")
		elif player_anim.sprite_frames.has_animation("parry"):
			player_anim.play("parry")
		
		# 2. Musuh TETAP MENYERANG (Secara Visual)
		# Kita panggil ini supaya lebahnya maju/nyengat ke arah perisai player
		await enemy_play_attack_anim()
		
		# 3. Munculkan Efek Tabrakan / Perfect Block Tepat Setelah Serangan Selesai
		spawn_floating_text(player_anim, "PERFECT PARRY!!", Color(0, 1, 0)) # Teks Hijau
		
		# Efek Flash Putih di Player
		var flash_tween = get_tree().create_tween()
		player_anim.modulate = Color(5, 5, 5, 1) 
		flash_tween.tween_property(player_anim, "modulate", Color(1, 1, 1, 1), 0.3)
			
		# 4. Selesaikan Logika (Damage 0)
		finish_enemy_attack(0) 
		
		# Tunggu sebentar biar pose block kelihatan keren menahan serangan
		await get_tree().create_timer(0.3).timeout
		
		# Balik ke Idle
		if player_anim.sprite_frames.has_animation("idle"):
			player_anim.play("idle")
		
		# 5. Musuh Mundur
		await enemy_return_to_pos()
		
	else:
		# --- PARRY GAGAL (TOO LATE) ---
		spawn_floating_text(player_anim, "PARRY FAILED", Color(1.0, 0.0, 0.0, 1.0)) # Teks merah
		
		# JEDA SEBENTAR agar teks "TOO LATE" sempat naik
		await get_tree().create_timer(0.4).timeout
		
		# Musuh Serang
		await enemy_play_attack_anim()
		
		# Kena Damage
		var min_dmg = enemy_data.get("damage_min", 1)
		var max_dmg = enemy_data.get("damage_max", 5)
		var damage = randi_range(min_dmg, max_dmg)
		finish_enemy_attack(damage)
		
		# Musuh mundur
		await enemy_return_to_pos()

# --- Helper Functions untuk Animasi Musuh yang Dipecah ---

func enemy_move_to_player():
	enemy_anim.z_index = 1  
	var tween = get_tree().create_tween()
	var offset_jarak = enemy_data.get("attack_offset", 70.0)
	var attack_pos = Vector2(player_anim.position.x + offset_jarak, player_anim.position.y)
	tween.tween_property(enemy_anim, "position", attack_pos, 0.4).set_trans(Tween.TRANS_SINE)
	await tween.finished

func enemy_play_attack_anim():
	if enemy_anim.sprite_frames.has_animation("attack"):
		enemy_anim.play("attack")
		await enemy_anim.animation_finished
	else:
		# Efek "Bump" sederhana jika tidak ada animasi attack
		var bump_tween = get_tree().create_tween()
		var hit_pos = player_anim.position 
		bump_tween.tween_property(enemy_anim, "position", hit_pos, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bump_tween.tween_property(enemy_anim, "position", enemy_anim.position, 0.2) # Balik ke posisi depan player
		await bump_tween.finished

func enemy_return_to_pos():
	var return_tween = get_tree().create_tween()
	return_tween.tween_property(enemy_anim, "position", original_enemy_pos, 0.4).set_trans(Tween.TRANS_SINE)
	await return_tween.finished
	enemy_anim.z_index = 0
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)

# =========================================
# --- END OF NEW LOGIC ---
# =========================================

func finish_enemy_attack(damage_amount):
	player_hp -= damage_amount
	if player_hp < 0: player_hp = 0
	Global.player_current_hp = player_hp
	
	# Update UI & Text
	if damage_amount > 0:
		spawn_floating_text(player_anim, str(damage_amount), Color(1, 0.5, 0))
		question_label.text = "🛡️ MUSUH MENYERANG!\nKamu terkena %s Damage." % str(damage_amount)
		await play_player_hit_effect()
	else:
		question_label.text = "✨ SERANGAN DITANGKIS!\nKamu tidak terkena damage."
	
	update_ui()
	
	# Cek Mati/Hidup
	if player_hp <= 0:
		game_over("💀 HP HABIS!\nKamu butuh belajar lagi...")
	else:
		await get_tree().create_timer(1.5).timeout # Jeda sedikit sebelum giliran baru
		start_new_turn()

# --- UTILS LAINNYA (Tidak Berubah) ---

func update_mana_ui():
	if ult_progress:
		ult_progress.max_value = max_mana
		ult_progress.value = current_mana
		
		if current_mana >= max_mana:
			ult_button.disabled = false
			var tween = get_tree().create_tween().set_loops()
			tween.tween_property(ult_progress, "modulate", Color(1.5, 1.5, 1.5), 0.5)
			tween.tween_property(ult_progress, "modulate", Color(1, 1, 1), 0.5)
		else:
			ult_button.disabled = true
			ult_progress.modulate = Color(1, 1, 1)

func increase_mana(amount):
	current_mana += amount
	if current_mana > max_mana:
		current_mana = max_mana
	Global.player_current_mana = current_mana
	update_mana_ui()

func spawn_floating_text(target_node, value_text, color):
	if floating_text_scene:
		var text_instance = floating_text_scene.instantiate()
		add_child(text_instance) 
		text_instance.z_index = 100 
		
		var offset_y = -30.0 
		var collision_node = target_node.get_node_or_null("CollisionShape2D")
		if collision_node == null:
			for child in target_node.get_children():
				if child is CollisionShape2D:
					collision_node = child
					break
		
		if collision_node and collision_node.shape:
			var shape = collision_node.shape
			var shape_height = 0.0
			if shape is CircleShape2D: shape_height = shape.radius
			elif shape is RectangleShape2D: shape_height = shape.size.y / 2.0
			elif shape is CapsuleShape2D: shape_height = shape.height / 2.0
			offset_y = -(shape_height * target_node.scale.y) - 30.0
			
		var random_x = randf_range(-20, 20)
		text_instance.global_position = target_node.global_position + Vector2(random_x, offset_y)
		text_instance.setup(str(value_text), color)

func wait_for_frame(anim_sprite, target_frame):
	var safety_timer = 0.0
	while anim_sprite.frame < target_frame:
		await get_tree().process_frame
		safety_timer += get_process_delta_time()
		if not anim_sprite.is_playing() or safety_timer > 2.0: 
			break

func play_enemy_hit_effect():
	# [FIX] Selalu berikan kilatan putih (Flash) di awal, bahkan untuk Slime
	var flash_tween = get_tree().create_tween()
	enemy_anim.modulate = Color(10, 10, 10, 1) # Putih sangat terang (HDR Bloom)
	flash_tween.tween_property(enemy_anim, "modulate", Color(1, 1, 1, 1), 0.15)
	
	if enemy_anim.sprite_frames.has_animation("hit"):
		enemy_anim.frame = 0 
		enemy_anim.play("hit")
		await enemy_anim.animation_finished
		if enemy_hp > 0:
			enemy_anim.play(enemy_idle_anim_name)
	else:
		# Jika tidak ada animasi hit, tunggu tween flash selesai
		await flash_tween.finished

func play_player_hit_effect():
	if player_anim.sprite_frames.has_animation("hit"):
		player_anim.play("hit")
		await player_anim.animation_finished
		if player_anim.sprite_frames.has_animation("idle"):
			player_anim.play("idle")
	else:
		var tween = get_tree().create_tween()
		tween.tween_property(player_anim, "modulate", Color(1, 0, 0, 1), 0.1)
		tween.tween_property(player_anim, "modulate", Color(1, 1, 1, 1), 0.1)
		await tween.finished

func shake_screen(duration, intensity):
	var tween = get_tree().create_tween()
	var base_pos = position 
	if camera: base_pos = camera.position
	
	for i in range(10):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", base_pos + offset, duration/10)
			
	tween.tween_property(self, "position", base_pos, 0.0)

# --- ULTIMATE & ATTACK LOGIC ---

func perform_ultimate():
	if current_mana < max_mana or is_waiting_next_turn or not battle_active:
		return
	
	set_buttons_enabled(false)
	is_waiting_next_turn = true
	
	ult_progress.modulate = Color(1, 1, 1) 
	current_mana = 0
	Global.player_current_mana = 0
	update_mana_ui()
	
	question_label.text = "⚡ ULTIMATE COMBO! ⚡"
	
	if player_anim.sprite_frames.has_animation("emote"):
		player_anim.play("emote")
		await player_anim.animation_finished
	
	await move_player_to_enemy()
	player_anim.modulate = Color(2, 0.5, 0.5) 
	
	var slash_count = 10 
	var initial_speed = 1.5
	
	for i in range(slash_count):
		if player_anim.sprite_frames.has_animation("attack_2"):
			player_anim.frame = 0 
			player_anim.play("attack_2")
			player_anim.speed_scale = initial_speed + (i * 0.3)
			
			# Slash Pertama (Frame 2)
			await wait_for_frame(player_anim, 2)
			shake_screen(0.1, 1.0 + i)
			play_enemy_hit_effect()
			
			var slash_dmg = randi_range(1, 5)
			enemy_hp -= slash_dmg
			spawn_floating_text(enemy_anim, str(slash_dmg), Color(1, 0, 0))
			update_ui() # [FIX] Darah berkurang seketika di tebasan 1
			
			# Slash Kedua (Frame 5)
			await wait_for_frame(player_anim, 5)
			var slash_dmg_2 = randi_range(1, 5)
			enemy_hp -= slash_dmg_2
			spawn_floating_text(enemy_anim, str(slash_dmg_2), Color(1, 0, 0))
			update_ui() # [FIX] Darah berkurang seketika di tebasan 2
			
			if i < slash_count - 1:
				await get_tree().process_frame
			else:
				await player_anim.animation_finished
		else:
			await get_tree().create_timer(0.05).timeout
	
	player_anim.speed_scale = 1.0 
	
	if player_anim.sprite_frames.has_animation("attack_3"):
		player_anim.frame = 0
		player_anim.play("attack_3")
		await wait_for_frame(player_anim, 2)
	else:
		player_anim.play("attack_1")
	
	Engine.time_scale = 0.3 
	shake_screen(0.6, 15.0)
	play_enemy_hit_effect() 
	
	var base_ult_dmg = Global.player_damage_max * 5
	var is_crit_final = randf() < Global.player_crit_chance
	var final_damage = base_ult_dmg
	var final_text = str(final_damage)
	
	if is_crit_final:
		final_damage = int(final_damage * 1.5)
		final_text = str(final_damage) + "!!"
	
	enemy_hp -= final_damage
	if enemy_hp < 0: enemy_hp = 0
	
	spawn_floating_text(enemy_anim, final_text, Color(1, 0, 0)) 
	update_ui() # [FIX] Update untuk serangan final
	
	await get_tree().create_timer(0.15).timeout 
	Engine.time_scale = 1.0
	
	await player_anim.animation_finished
	player_anim.modulate = Color(1, 1, 1)
	
	await return_player_to_start()
	
	question_label.text = "💥 FINAL BLOW!!\nTotal Damage Dahsyat!" 
	
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)
	
	if enemy_hp <= 0:
		win_battle()
		return
	
	await get_tree().create_timer(1.0).timeout
	enemy_turn()

func check_answer(btn_index):
	# [FIX] Tambahkan pengecekan is_performing_action agar tidak double input
	if is_waiting_next_turn or not battle_active or is_performing_action: return
	
	if is_confirming_flee:
		if btn_index == 0: perform_flee()
		elif btn_index == 1: cancel_flee()
		return

	set_buttons_enabled(false)
	is_waiting_next_turn = true
	is_performing_action = true # Kunci status agar turn tidak kacau
	
	if btn_index == current_correct_index:
		increase_mana(25) 
		await move_player_to_enemy()
		
		var damage_min = Global.player_damage_min
		var damage_max = Global.player_damage_max
		var is_critical = randf() < Global.player_crit_chance
		var raw_damage = randi_range(damage_min, damage_max)
		
		# --- LOGIKA POWER-UP ATTACK (Perfect Answer > 6s) ---
		var p_chance = 0.5 # Peluang 50%, sesuaikan dengan Global.player_powerup_chance jika ada
		if "player_powerup_chance" in Global: p_chance = Global.player_powerup_chance
		
		if current_time > 6.0 and randf() < p_chance:
			# 1. Jalankan urutan QTE (Fungsi ini harus ada di script)
			await run_powerup_qte_sequence()
			
			# 2. Tentukan aksi berdasarkan jumlah hits sukses
			if powerup_hits == 2:
				question_label.text = "🔥 FULL POWER COMBO!! 🔥"
				spawn_floating_text(player_anim, "POWER UP!!", Color.RED) # Merah jika 2 hit
				await execute_combo_attack(raw_damage, is_critical, ["attack_2", "attack_1", "attack_3"])
				
			elif powerup_hits == 1:
				question_label.text = "⚡ POWER UP ATTACK! ⚡"
				spawn_floating_text(player_anim, "POWER UP!", Color.YELLOW) # Kuning jika 1 hit
				await execute_combo_attack(raw_damage, is_critical, ["attack_2", "attack_1"])
				
			else:
				question_label.text = "⚔️ POWER UP MISSED!\nSerangan Normal..."
				await execute_combo_attack(raw_damage, is_critical, ["attack_2"])
		
		else:
			# --- LOGIKA SERANGAN NORMAL (Berdasarkan Waktu) ---
			var multiplier = 1.0
			var anim_to_play = "attack_1"
			var info_text = ""
			
			if current_time > 6.0: 
				multiplier = 1.5
				anim_to_play = "attack_2"
				info_text = " (PERFECT!)"
			elif current_time < 3.0: 
				multiplier = 0.8
				anim_to_play = "attack_3"
				info_text = " (WEAK!)"
			
			question_label.text = "⚔️ HIT!%s" % info_text
			await execute_combo_attack(int(raw_damage * multiplier), is_critical, [anim_to_play])
		
		if enemy_hp < 0: enemy_hp = 0
		update_ui()
		await return_player_to_start()
		
	else:
		question_label.text = "❌ JAWABAN SALAH...\nSeranganmu meleset!"
		update_ui()
		await get_tree().create_timer(1.0).timeout
	
	# [FIX] Reset status perform aksi setelah semua animasi selesai
	is_performing_action = false 
	
	if enemy_hp <= 0:
		win_battle()
		return
	
	await get_tree().create_timer(0.5).timeout
	enemy_turn()

# Menjalankan 2 QTE berurutan di atas musuh
func run_powerup_qte_sequence():
	powerup_hits = 0
	Engine.time_scale = 0.2 # Slow motion dramatis
	
	# --- QTE 1: AREA BESAR & LOKASI KANAN-ATAS ---
	# Offset X: +20 s/d +80 (Kanan) | Offset Y: -80 s/d -120 (Atas)
	var pos1 = enemy_anim.global_position + Vector2(randf_range(20, 80), randf_range(-80, -120))
	
	# Panggil dengan ukuran zone 40.0 (Besar/Mudah)
	powerup_qte.start_powerup(pos1, 0.8, 40.0)
	if await powerup_qte.powerup_finished: 
		powerup_hits += 1
	
	await get_tree().create_timer(0.1, true).timeout # Jeda singkat real-time
	
	# --- QTE 2: AREA KECIL & LOKASI KANAN-ATAS ---
	if battle_active:
		# Posisi sedikit digeser agar tidak menumpuk sempurna
		var pos2 = enemy_anim.global_position + Vector2(randf_range(40, 100), randf_range(-60, -100))
		
		# Panggil dengan ukuran zone 15.0 (Kecil/Sulit)
		powerup_qte.start_powerup(pos2, 0.7, 15.0)
		if await powerup_qte.powerup_finished: 
			powerup_hits += 1
	
	Engine.time_scale = 1.0 # Balik ke waktu normal

# Menjalankan list animasi combo satu per satu
func execute_combo_attack(base_dmg, is_crit, anim_list):
	for i in range(anim_list.size()):
		var anim_name = anim_list[i]
		if not player_anim.sprite_frames.has_animation(anim_name): continue
		
		player_anim.frame = 0
		player_anim.play(anim_name)
		
		# --- LOGIKA MULTI-HIT UNTUK ATTACK_2 ---
		if anim_name == "attack_2":
			# Bagi damage menjadi dua bagian agar sinkron dengan 2 slash
			var dmg_per_hit = int(base_dmg / 2)
			if anim_list.size() > 1 and i > 0: dmg_per_hit = int(dmg_per_hit * 0.8)
			
			# Tunggu Slash Pertama (Frame 2)
			await wait_for_frame_safe(player_anim, 2)
			apply_hit_logic(dmg_per_hit, is_crit)
			
			# Tunggu Slash Kedua (Frame 5)
			await wait_for_frame_safe(player_anim, 5)
			apply_hit_logic(dmg_per_hit, is_crit)
		
		else:
			# Serangan normal 1 hit (attack_1 atau attack_3)
			var hit_f = 5 if anim_name == "attack_1" else 2
			await wait_for_frame_safe(player_anim, hit_f)
			
			var final_dmg = base_dmg
			if anim_list.size() > 1 and i > 0: final_dmg = int(base_dmg * 0.8)
			apply_hit_logic(final_dmg, is_crit)
		
		await player_anim.animation_finished

# Ganti fungsi pembantu ini jika kamu menggunakannya dalam check_answer
func apply_hit_logic(dmg, is_crit):
	if is_crit: dmg = int(dmg * 1.5)
	enemy_hp = max(0, enemy_hp - dmg)
	spawn_floating_text(enemy_anim, str(dmg) + ("!!" if is_crit else ""), Color.RED if is_crit else Color.WHITE)
	play_enemy_hit_effect()
	update_ui() # [FIX] Update bar HP per hit untuk serangan normal/power-up
	shake_screen(0.1, 5.0)

# Pengaman agar tidak stuck jika animasi gagal mencapai frame tertentu
func wait_for_frame_safe(sprite, target):
	var t = 0.0; var timeout = 1.5
	while sprite.frame < target and sprite.is_playing():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > timeout: break # Paksa lanjut setelah 1.5 detik

func setup_player_anim():
	if player_anim.sprite_frames == null: return
	if player_anim.sprite_frames.has_animation("idle"): player_anim.play("idle")
	else: player_anim.play("default")

func load_enemy_data():
	var type = Global.active_enemy_type
	if Global.enemy_database.has(type):
		enemy_data = Global.enemy_database[type]
		enemy_hp = enemy_data["hp"]
		
		var file_name = enemy_data.get("question_file", "Bee.json")
		question_bank = Global.load_question_file(file_name)
		question_bank.shuffle()
		
		if enemy_data.has("frames"):
			enemy_anim.sprite_frames = enemy_data["frames"]
			enemy_anim.scale = enemy_data.get("scale", Vector2(1, 1)) 
			enemy_anim.flip_h = enemy_data.get("should_flip", true)
			var target_anim = enemy_data.get("animation_name", "default")
			if enemy_anim.sprite_frames.has_animation(target_anim):
				enemy_idle_anim_name = target_anim
			elif enemy_anim.sprite_frames.has_animation("fly"):
				enemy_idle_anim_name = "fly"
			elif enemy_anim.sprite_frames.has_animation("idle"):
				enemy_idle_anim_name = "idle"
			else:
				enemy_idle_anim_name = "default"
			enemy_anim.play(enemy_idle_anim_name)
	else:
		enemy_info.text = "Unknown Enemy"

func ask_to_flee():
	if is_waiting_next_turn or not battle_active: return
	is_confirming_flee = true
	question_label.text = "⚠️ YAKIN INGIN KABUR?"
	btn1.text = "YA (Kabur)"
	btn2.text = "TIDAK (Lanjut)"
	btn3.visible = false
	btn4.visible = false
	current_btn_index = 0
	highlight_button()

func cancel_flee():
	is_confirming_flee = false
	if current_question_data.size() > 0:
		question_label.text = current_question_data["q"]
		btn1.text = current_question_data["a"][0]
		btn2.text = current_question_data["a"][1]
		btn3.text = current_question_data["a"][2]
		btn4.text = current_question_data["a"][3]
	btn3.visible = true
	btn4.visible = true
	current_btn_index = 0
	highlight_button()

func perform_flee():
	battle_active = false
	question_label.text = "🏃 Kamu melarikan diri!"
	if Global.current_enemy_id != "":
		Global.just_fled_from_id = Global.current_enemy_id
	await get_tree().create_timer(1.0).timeout
	quit_battle()

func change_selection(offset):
	var new_index = current_btn_index + offset
	var max_index = 1 if is_confirming_flee else (buttons.size() - 1)
	if new_index >= 0 and new_index <= max_index:
		current_btn_index = new_index
		highlight_button()

func highlight_button():
	buttons[current_btn_index].grab_focus()

func update_ui():
	player_info.text = "Player HP: " + str(max(0, player_hp))
	if enemy_data.has("name"):
		enemy_info.text = enemy_data["name"] + " HP: " + str(max(0, enemy_hp))
	else:
		enemy_info.text = "Enemy HP: " + str(max(0, enemy_hp))

func start_new_turn():
	if not battle_active: return
	is_confirming_flee = false
	btn3.visible = true
	btn4.visible = true
	is_waiting_next_turn = false
	current_time = max_time
	timer_bar.max_value = max_time
	timer_bar.value = max_time
	timer_label.modulate = Color(1, 1, 1) 
	set_buttons_enabled(true)
	generate_question()
	current_btn_index = 0
	highlight_button()

func generate_question():
	if question_bank.size() == 0: return
	var random_index = randi() % question_bank.size()
	var data = question_bank[random_index]
	current_question_data = data 
	question_label.text = data["q"]
	btn1.text = data["a"][0]
	btn2.text = data["a"][1]
	btn3.text = data["a"][2]
	btn4.text = data["a"][3]
	current_correct_index = data["c"]

func move_player_to_enemy():
	player_anim.z_index = 1 
	enemy_anim.z_index = 0  
	var tween = get_tree().create_tween()
	var target_pos = Vector2(enemy_anim.position.x - 70, enemy_anim.position.y)
	if player_anim.sprite_frames.has_animation("walk"): player_anim.play("walk")
	tween.tween_property(player_anim, "position", target_pos, 0.5).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if player_anim.sprite_frames.has_animation("idle"): player_anim.play("idle")

func return_player_to_start():
	var tween = get_tree().create_tween()
	player_anim.flip_h = true 
	if player_anim.sprite_frames.has_animation("walk"): player_anim.play("walk")
	tween.tween_property(player_anim, "position", original_player_pos, 0.5).set_trans(Tween.TRANS_SINE)
	await tween.finished
	player_anim.flip_h = false
	if player_anim.sprite_frames.has_animation("idle"): player_anim.play("idle")
	player_anim.z_index = 0

func set_buttons_enabled(enabled: bool):
	for btn in buttons: btn.disabled = !enabled
	if enabled: highlight_button()

func win_battle():
	Engine.time_scale = 1.0
	battle_active = false
	var enemy_name = enemy_data.get("name", "Musuh")
	question_label.text = "🏆 MENANG!\n%s berhasil dikalahkan." % enemy_name
	if player_anim.sprite_frames.has_animation("emote"): player_anim.play("emote")
	
	if enemy_anim.sprite_frames.has_animation("die"):
		enemy_anim.play("die")
		await enemy_anim.animation_finished
	else:
		var death_tween = get_tree().create_tween()
		death_tween.tween_property(enemy_anim, "modulate:a", 0.0, 1.0)
		await death_tween.finished
		
	if Global.current_enemy_id != "":
		Global.defeated_enemies.append(Global.current_enemy_id)
		Global.just_defeated_id = Global.current_enemy_id 
	await get_tree().create_timer(1.0).timeout 
	quit_battle()

func game_over(reason):
	Engine.time_scale = 1.0
	battle_active = false
	question_label.text = reason
	
	if player_anim:
		var tween = get_tree().create_tween()
		tween.tween_property(player_anim, "modulate:a", 0.0, 1.5)
		if player_anim.sprite_frames.has_animation("die"):
			player_anim.play("die")
	
	await get_tree().create_timer(2.0).timeout
	Global.change_scene_with_loading("res://Scenes/Main.tscn")

func quit_battle():
	var target_map = "res://Scenes/map2.tscn"
	if Global.last_scene_path != "":
		target_map = Global.last_scene_path
	
	Global.change_scene_with_loading(target_map)
