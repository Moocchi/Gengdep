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
var enemy_charge_level = 0 # <--- TAMBAHKAN INI
var max_enemy_charge = 3   # <--- TAMBAHKAN INI

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
@onready var player = $BattleArea/PlayerAnim  # Pastikan path ini sesuai dengan Scene Tree kamu
@onready var enemy = $BattleArea/EnemyAnim

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
	align_positions()
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
	
	var is_boss = enemy_data.get("is_boss", false)
	
	# --- 1. LOGIKA BOSS CHARGE (Peluang 30%) ---
	if is_boss and enemy_charge_level < 3 and randf() < 0.3:
		enemy_charge_level += 1 
		await perform_boss_charge_visual() 
		
		# [FIX] Pengecekan Khusus Jika Stack Mencapai Maksimal (3)
		if enemy_charge_level == 3:
			# Mengubah warna teks menjadi merah untuk peringatan bahaya
			question_label.modulate = Color(1, 1, 1) 
			question_label.text = "🛑 WARNING !! FULL STACK REACHED\nDAMAGE MULTIPLY BY 3.5"
		else:
			question_label.modulate = Color(1, 1, 1) # Putih normal
			question_label.text = "⚠️ %s MENGUMPULKAN STACK!\n(STACK %d / 3)" % [enemy_data["name"], enemy_charge_level]
		
		# Beri jeda 1.5 detik agar pemain sempat membaca peringatan bahaya
		await get_tree().create_timer(1.5).timeout
		question_label.modulate = Color(1, 1, 1) # Reset warna ke putih normal
		
		start_new_turn() # Selesai giliran dan kembali ke Player
		return

	# --- 2. LOGIKA MENYERANG (Multiplier Berdasarkan Stack) ---
	var damage_multiplier = 1.0
	if enemy_charge_level == 1: 
		damage_multiplier = 1.5
	elif enemy_charge_level == 2: 
		damage_multiplier = 3.0
	elif enemy_charge_level == 3: 
		damage_multiplier = 3.5 # Damage maksimal saat full stack
	
	await enemy_move_to_player()
	
	var roll = randf()
	if roll < Global.player_parry_chance:
		Engine.time_scale = 0.1 
		var spawn_pos = Vector2(randf_range(300.0, 450.0), 100.0)
		parry_qte_system.start_qte(spawn_pos, 0.6)
		return
	else:
		await enemy_play_attack_anim()
		
		# Base Attack Nightborn 10-15
		var min_dmg = enemy_data.get("damage_min", 10)
		var max_dmg = enemy_data.get("damage_max", 15)
		var final_damage = int(randi_range(min_dmg, max_dmg) * damage_multiplier)
		
		# Sesuai permintaanmu: Reset charge hanya terjadi di apply_hit_logic lewat Critical
		
		finish_enemy_attack(final_damage)
		await enemy_return_to_pos()

func perform_boss_charge_visual():
	# 1. Mainkan animasi charge sampai selesai
	if enemy_anim.sprite_frames.has_animation("charge"):
		enemy_anim.play("charge")
		await enemy_anim.animation_finished 
	
	# 2. Efek Kedip Putih Kilat (White Flash)
	var flash_tween = create_tween()
	var flash_color = Color(5.0, 5.0, 5.0, 1.0) # Putih HDR
	var normal_color = Color(1.0, 1.0, 1.0, 1.0)
	
	# Berubah jadi putih (0.1s) lalu kembali normal (0.1s)
	flash_tween.tween_property(enemy_anim, "modulate", flash_color, 0.2).set_trans(Tween.TRANS_LINEAR)
	flash_tween.tween_property(enemy_anim, "modulate", normal_color, 0.2).set_trans(Tween.TRANS_LINEAR)
	
	await flash_tween.finished
	
	# 3. Kembali ke animasi Idle
	enemy_anim.play(enemy_idle_anim_name)

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
	
	var move_anim = "run" if enemy_anim.sprite_frames.has_animation("run") else "walk"
	if enemy_anim.sprite_frames.has_animation(move_anim):
		enemy_anim.play(move_anim)
	
	var tween = get_tree().create_tween()
	var offset_jarak = enemy_data.get("attack_offset", 70.0)
	var attack_pos = Vector2(player_anim.position.x + offset_jarak, enemy_anim.position.y)
	tween.tween_property(enemy_anim, "position", attack_pos, 0.4).set_trans(Tween.TRANS_SINE)
	await tween.finished
	
	enemy_anim.play(enemy_idle_anim_name)

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
	# 1. Tentukan animasi gerak (run/walk/fly)
	# Bee biasanya menggunakan 'fly' sebagai animasi gerak/idlenya
	var move_anim = "run"
	if enemy_anim.sprite_frames.has_animation("run"):
		move_anim = "run"
	elif enemy_anim.sprite_frames.has_animation("fly"):
		move_anim = "fly"
	else:
		move_anim = "walk"
	
	if enemy_anim.sprite_frames.has_animation(move_anim):
		enemy_anim.play(move_anim)
		
		# 2. LOGIKA FLIP SAAT MUNDUR:
		# Jika should_flip = true (aslinya hadap kanan), maka saat mundur flip_h harus FALSE (hadap kanan)
		# Jika should_flip = false (aslinya hadap kiri), maka saat mundur flip_h harus TRUE (hadap kanan)
		enemy_anim.flip_h = !enemy_data.get("should_flip", true)

	# 3. Gerakan Mundur ke Posisi Awal
	var return_tween = get_tree().create_tween()
	return_tween.tween_property(enemy_anim, "position", original_enemy_pos, 0.4).set_trans(Tween.TRANS_SINE)
	
	# Tunggu sampai musuh benar-benar sampai di rumahnya
	await return_tween.finished
	
	# 4. RESET SETELAH SAMPAI
	enemy_anim.z_index = 0
	
	# Kembalikan arah hadap agar kembali melihat ke arah Player (Kiri)
	# Gunakan nilai asli dari database (true untuk Bee/Nightborn)
	enemy_anim.flip_h = enemy_data.get("should_flip", true)
	
	# Kembali ke animasi idle (default/fly/idle)
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)

# =========================================
# --- END OF NEW LOGIC ---
# =========================================

func finish_enemy_attack(damage_amount):
	player_hp -= damage_amount
	if player_hp < 0: player_hp = 0
	Global.player_current_hp = player_hp
	
	# --- UPDATE UI & TEXT ---
	if damage_amount > 0:
		# Tentukan warna teks: Merah jika damage > 15 (Damage Gede), Orange jika biasa
		var dmg_color = Color(1, 0.5, 0) # Orange default
		if damage_amount >= 15:
			dmg_color = Color(1, 0, 0) # Merah (Damage Boss/Charge)
			shake_screen(0.2, 8.0) # Guncangan layar lebih kuat untuk damage besar
			
		spawn_floating_text(player_anim, str(damage_amount), dmg_color)
		question_label.text = "🛡️ %s MENYERANG!\nKamu terkena %s Damage." % [enemy_data.get("name", "Musuh"), str(damage_amount)]
		await play_player_hit_effect()
	else:
		question_label.text = "✨ SERANGAN DITANGKIS!\nKamu tidak terkena damage."
	
	update_ui()
	
	# Cek Mati/Hidup
	if player_hp <= 0:
		game_over("💀 HP HABIS!\nKamu butuh belajar lagi...")
	else:
		await get_tree().create_timer(1.5).timeout 
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

# Menambahkan parameter extra_offset_y dengan nilai default 0.0
# Fungsi untuk memunculkan teks melayang
# [FIX] Tambahkan parameter extra_offset_x dengan default 0.0
func spawn_floating_text(target_node, value_text, color, extra_offset_y: float = 0.0, extra_offset_x: float = 0.0, custom_z_index: int = 100, is_fast: bool = false):
	if floating_text_scene:
		var text_instance = floating_text_scene.instantiate()
		add_child(text_instance)
		text_instance.z_index = custom_z_index
		
		var offset_y = -30.0 + extra_offset_y # [FIX] Tambahkan extra_offset_y sejak awal sebagai fallback
		
		if is_fast:
			offset_y = extra_offset_y 
		else:
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
				
				# [FIX] Pastikan extra_offset_y ditambahkan di sini juga
				offset_y = -(shape_height * target_node.scale.y) - 30.0 + extra_offset_y
		
		var final_x = 0.0
		if is_fast:
			final_x = extra_offset_x
		else:
			final_x = randf_range(-20, 20) + extra_offset_x
			
		text_instance.global_position = target_node.global_position + Vector2(final_x, offset_y)
		text_instance.setup(str(value_text), color)
		
		if is_fast:
			var t = create_tween()
			t.tween_property(text_instance, "global_position:y", text_instance.global_position.y - 80, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(text_instance, "modulate:a", 0, 0.5)
			t.tween_callback(text_instance.queue_free)

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
	# 1. Validasi Awal & Konsumsi Resource
	if current_mana < max_mana or is_waiting_next_turn or not battle_active:
		return
	
	set_buttons_enabled(false)
	is_waiting_next_turn = true
	
	# Reset Mana
	ult_progress.modulate = Color(1, 1, 1) 
	current_mana = 0
	Global.player_current_mana = 0
	update_mana_ui()
	
	# 2. Intro Animasi
	question_label.text = "⚡ ULTIMATE COMBO! ⚡"
	
	if player_anim.sprite_frames.has_animation("emote"):
		player_anim.play("emote")
		await player_anim.animation_finished
	
	await move_player_to_enemy()
	player_anim.modulate = Color(2, 0.5, 0.5) # Efek Aura Merah
	
	# 3. Multi-Hit Combo (10 Tebasan Cepat)
	var slash_count = 10 
	var initial_speed = 1.5
	
	for i in range(slash_count):
		if player_anim.sprite_frames.has_animation("attack_2"):
			player_anim.frame = 0 
			player_anim.play("attack_2")
			# Semakin lama semakin cepat
			player_anim.speed_scale = initial_speed + (i * 0.3)
			
			# Tebasan Pertama (Frame 2)
			await wait_for_frame(player_anim, 2)
			shake_screen(0.1, 1.0 + i)
			play_enemy_hit_effect()
			
			var slash_dmg = randi_range(1, 5)
			enemy_hp -= slash_dmg
			spawn_floating_text(enemy_anim, str(slash_dmg), Color(1, 0, 0))
			update_ui() 
			
			# Tebasan Kedua (Frame 5)
			await wait_for_frame(player_anim, 5)
			var slash_dmg_2 = randi_range(1, 5)
			enemy_hp -= slash_dmg_2
			spawn_floating_text(enemy_anim, str(slash_dmg_2), Color(1, 0, 0))
			update_ui() 
			
			if i < slash_count - 1:
				await get_tree().process_frame
			else:
				await player_anim.animation_finished
		else:
			await get_tree().create_timer(0.05).timeout
	
	# 4. Final Blow (Serangan Penutup)
	player_anim.speed_scale = 1.0 
	
	if player_anim.sprite_frames.has_animation("attack_3"):
		player_anim.frame = 0
		player_anim.play("attack_3")
		await wait_for_frame(player_anim, 2)
	else:
		player_anim.play("attack_1")
	
	# Efek Slow Motion Dramatis
	Engine.time_scale = 0.3 
	shake_screen(0.6, 15.0)
	
	# Kalkulasi Damage Akhir
	var base_ult_dmg = Global.player_damage_max * 5
	var is_crit_final = randf() < Global.player_crit_chance
	
	# [FIX] Gunakan apply_hit_logic agar memicu WEAKENED! jika crit
	apply_hit_logic(base_ult_dmg, is_crit_final)
	
	# Jeda sedikit dalam slow-mo sebelum kembali normal
	await get_tree().create_timer(0.15).timeout 
	Engine.time_scale = 1.0
	
	# 5. Cleanup & Selesai Turn
	await player_anim.animation_finished
	player_anim.modulate = Color(1, 1, 1)
	
	await return_player_to_start()
	
	question_label.text = "💥 FINAL BLOW!!\nTotal Damage Dahsyat!" 
	
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)
		await get_tree().create_timer(1.0).timeout
		enemy_turn()
	else:
		win_battle()

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
		var p_chance = 0.5 
		if "player_powerup_chance" in Global: p_chance = Global.player_powerup_chance
		
		if current_time > 6.0 and randf() < p_chance:
			# 1. Jalankan urutan QTE
			await run_powerup_qte_sequence()
			
			# [FIX] Tentukan offset Y secara dinamis hanya untuk Boss
			var powerup_offset_y = 0.0
			if enemy_data.get("is_boss", false):
				# Jika musuh berbadan besar (Nightborn), tarik teks ke atas lebih jauh (-160)
				powerup_offset_y = -40.0 
			else:
				# Jika musuh kecil (Bee/Slime), gunakan offset standar (0)
				powerup_offset_y = 0.0

			# 2. Tentukan aksi berdasarkan jumlah hits sukses
			if powerup_hits == 2:
				question_label.text = "🔥 FULL POWER COMBO!! 🔥"
				# Gunakan powerup_offset_y yang sudah kita hitung di atas
				spawn_floating_text(player_anim, "POWER UP!!", Color.RED, powerup_offset_y)
				await execute_combo_attack(raw_damage, is_critical, ["attack_2", "attack_1", "attack_3"])
				
			elif powerup_hits == 1:
				question_label.text = "⚡ POWER UP ATTACK! ⚡"
				# Gunakan powerup_offset_y yang sama
				spawn_floating_text(player_anim, "POWER UP!", Color.YELLOW, powerup_offset_y)
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
	
	var p_min_x = 800.0
	var p_max_x = 1050.0
	var p_y = 100.0 # Karena min_y dan max_y sama-sama 100
	
	# --- QTE 1: AREA BESAR & LOKASI KANAN-ATAS ---
	# Offset X: +20 s/d +80 (Kanan) | Offset Y: -80 s/d -120 (Atas)
	var pos1 = Vector2(randf_range(p_min_x, p_max_x), p_y)
	
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
# Ganti fungsi pembantu ini jika kamu menggunakannya dalam check_answer
func apply_hit_logic(dmg, is_crit):
	if is_crit: 
		dmg = int(dmg * 1.5)
		
		# --- LOGIKA BREAK CHARGE (SEMUA JENIS ATTACK) ---
		if enemy_charge_level > 0:
			enemy_charge_level = 0 
			
			# [FIX] Panggil dengan offset X -20.0 agar geser ke kiri
			# Urutan: target, teks, warna, off_y, OFF_X, z_index, is_fast
			spawn_floating_text(enemy_anim, "WEAKENED!", Color.CYAN, 0.0, -60.0, 200, true)
			
			# Info di Battle Log
			question_label.text = "💥 CRITICAL HIT! STACK %s RESET!!" % [enemy_data.get("name", "Musuh")]
			
			# Efek visual kilatan biru
			var break_tween = get_tree().create_tween()
			enemy_anim.modulate = Color(0, 5, 5, 1) 
			break_tween.tween_property(enemy_anim, "modulate", Color(1, 1, 1, 1), 0.3)
			
	enemy_hp = max(0, enemy_hp - dmg)
	
	# Munculkan Angka Damage Normal (Offset X default 0)
	spawn_floating_text(enemy_anim, str(dmg) + ("!!" if is_crit else ""), Color.RED if is_crit else Color.WHITE)
	
	play_enemy_hit_effect()
	update_ui() 
	shake_screen(0.1, 5.0 if not is_crit else 10.0)

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
	var p_offset = enemy_data.get("player_attack_offset", 70.0)
	var tween = get_tree().create_tween()
	var target_pos = Vector2(enemy_anim.position.x - p_offset, player_anim.position.y)
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
	
func align_positions():
	# 1. Pastikan data musuh sudah di-load agar bisa mengambil y_offset
	if enemy_data == null or not enemy_data.has("y_offset"):
		# Jika tidak ada offset, samakan saja Y-nya (seperti default)
		enemy.global_position.y = player.global_position.y
		return
		
	# 2. Ambil posisi Y Player sebagai patokan lantai
	var ground_level_y = player.global_position.y
	
	# 3. Ambil nilai modifier dari dictionary (misal -55.0 untuk Nightborn)
	var modifier = enemy_data.get("y_offset", 0.0)
	
	# 4. Terapkan posisi dengan tambahan offset
	enemy.global_position.y = ground_level_y + modifier

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
