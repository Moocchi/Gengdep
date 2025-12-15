extends Control

# --- CONFIG ---
var max_time = 10.0
var current_time = 0.0
var battle_active = true
var is_waiting_next_turn = false
var is_confirming_flee = false 

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

# --- REFERENSI NODE ---
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

# ANIMASI
@onready var player_anim = $BattleArea/PlayerAnim
@onready var enemy_anim = $BattleArea/EnemyAnim

# TOMBOL
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
		ult_button.disabled = true 
	
	if exit_button:
		exit_button.pressed.connect(ask_to_flee)
		exit_button.focus_mode = Control.FOCUS_NONE
	
	player_hp = Global.player_current_hp
	current_mana = Global.player_current_mana
	
	load_enemy_data()
	setup_player_anim()
	update_mana_ui()
	
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
	if battle_active and not is_waiting_next_turn:
		handle_gamepad_input()

	if is_confirming_flee:
		return

	if battle_active and not is_waiting_next_turn:
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

func handle_gamepad_input():
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

# --- FUNGSI FLOATING TEXT (AUTO HEIGHT DARI COLLISION) ---
func spawn_floating_text(target_node, value, color):
	if floating_text_scene:
		var text_instance = floating_text_scene.instantiate()
		add_child(text_instance) 
		
		# Default offset
		var offset_y = -30.0 
		
		# Coba cari node CollisionShape2D di dalam target
		# Kita asumsi strukturnya: Musuh -> CollisionShape2D
		var collision_node = target_node.get_node_or_null("CollisionShape2D")
		
		# Jika tidak ketemu langsung, coba cari di children (karena nama bisa beda)
		if collision_node == null:
			for child in target_node.get_children():
				if child is CollisionShape2D:
					collision_node = child
					break
		
		if collision_node and collision_node.shape:
			var shape = collision_node.shape
			var shape_height = 0.0
			
			# Deteksi tipe shape untuk ambil tinggi yang benar
			if shape is CircleShape2D:
				shape_height = shape.radius
			elif shape is RectangleShape2D:
				shape_height = shape.size.y / 2.0
			elif shape is CapsuleShape2D:
				shape_height = shape.height / 2.0
			
			# Tambahkan scaling musuh (penting jika musuh di-scale up/down)
			var total_height = shape_height * target_node.scale.y
			
			# Set offset di atas kepala (+sedikit jarak extra)
			offset_y = -total_height - 20.0
			
		# Posisi Random X
		var random_x = randf_range(-20, 20)
		
		# Terapkan posisi
		text_instance.global_position = target_node.global_position + Vector2(random_x, offset_y)
		
		text_instance.setup(str(value), color)

# --- [BARU] FUNGSI HELPER UNTUK TUNGGU FRAME ANIMASI ---
# Fungsi ini menahan kode sampai animasi mencapai frame tertentu
func wait_for_frame(anim_sprite, target_frame):
	while anim_sprite.frame < target_frame:
		await get_tree().process_frame
		# Safety check: Jika animasi berhenti atau ganti, break loop
		if not anim_sprite.is_playing(): 
			break

# --- FUNGSI EFEK VISUAL ---
func play_enemy_hit_effect():
	if enemy_anim.sprite_frames.has_animation("hit"):
		enemy_anim.frame = 0 
		enemy_anim.play("hit")
		await enemy_anim.animation_finished
		if enemy_hp > 0:
			enemy_anim.play(enemy_idle_anim_name)
	else:
		var tween = get_tree().create_tween()
		tween.tween_property(enemy_anim, "modulate", Color(10, 10, 10, 1), 0.1)
		tween.tween_property(enemy_anim, "modulate", Color(1, 1, 1, 1), 0.1)
		await tween.finished

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
	var original_pos = position
	for i in range(10):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(self, "position", original_pos + offset, duration/10)
	tween.tween_property(self, "position", original_pos, 0.0)

# --- [REVISI] ULTIMATE COMBO DENGAN SYNC FRAME & 10 DAMAGE NUMBERS ---
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
	
	await move_player_to_enemy()
	player_anim.modulate = Color(2, 0.5, 0.5) 
	
	var slash_count = 5
	var initial_speed = 1.0
	
	# FASE SLASH 5X (Attack 2 - Hit di Frame 2 & 5)
	for i in range(slash_count):
		if player_anim.sprite_frames.has_animation("attack_2"):
			player_anim.frame = 0 
			player_anim.play("attack_2")
			player_anim.speed_scale = initial_speed + (i * 0.4)
			
			# Hitungan Damage per slash (dibagi 2 hit)
			var total_slash_damage = randi_range(10, 15)
			var dmg_1 = int(total_slash_damage / 2)
			var dmg_2 = total_slash_damage - dmg_1
			
			# --- HIT PERTAMA (Frame 2) ---
			await wait_for_frame(player_anim, 2)
			shake_screen(0.1, 1.0 + i)
			play_enemy_hit_effect()
			enemy_hp -= dmg_1
			spawn_floating_text(enemy_anim, dmg_1, Color(1, 1, 0)) # Kuning
			
			# --- HIT KEDUA (Frame 5) ---
			await wait_for_frame(player_anim, 5)
			shake_screen(0.1, 2.0 + i)
			play_enemy_hit_effect()
			enemy_hp -= dmg_2
			spawn_floating_text(enemy_anim, dmg_2, Color(1, 1, 0)) # Kuning
			
			update_ui()
			
			# Tunggu sisa animasi (khusus slash terakhir play full, yg lain cut)
			if i < slash_count - 1:
				await get_tree().process_frame # Jeda dikit
			else:
				await player_anim.animation_finished
		else:
			await get_tree().create_timer(0.2).timeout
	
	# FASE LAST BLOW (Attack 3 - Hit di Frame 2)
	player_anim.speed_scale = 1.0 
	
	if player_anim.sprite_frames.has_animation("attack_3"):
		player_anim.frame = 0
		player_anim.play("attack_3")
		
		# --- FINAL HIT (Frame 2) ---
		await wait_for_frame(player_anim, 2)
	else:
		player_anim.play("attack_1")
	
	shake_screen(0.6, 8.0)
	play_enemy_hit_effect() 
	
	var final_damage = randi_range(50, 70)
	enemy_hp -= final_damage
	if enemy_hp < 0: enemy_hp = 0
	
	spawn_floating_text(enemy_anim, final_damage, Color(1, 0, 0)) # Merah Besar
	question_label.text = "💥 FINAL BLOW!!\nTotal Damage Dahsyat!" 
	update_ui()
	
	await player_anim.animation_finished
	player_anim.modulate = Color(1, 1, 1)
	
	await return_player_to_start()
	
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)
	
	if enemy_hp <= 0:
		win_battle()
		return
	
	await get_tree().create_timer(1.0).timeout
	enemy_turn()

# --- [REVISI] STANDARD ATTACK DENGAN FRAME SYNC ---
func check_answer(btn_index):
	if is_waiting_next_turn or not battle_active: return
	
	if is_confirming_flee:
		if btn_index == 0: perform_flee()
		elif btn_index == 1: cancel_flee()
		return

	set_buttons_enabled(false)
	is_waiting_next_turn = true
	
	if btn_index == current_correct_index:
		increase_mana(25) 
		await move_player_to_enemy()
		
		var base_damage = randi_range(1, 10)
		var bonus_damage = 0 # Bisa ditambah logika bonus waktu
		var total_damage = base_damage + bonus_damage
		
		# PILIH ANIMASI & SYNC DAMAGE
		if current_time > 6.0 and player_anim.sprite_frames.has_animation("attack_2"):
			# --- ATTACK 2 (Double Hit) ---
			player_anim.frame = 0
			player_anim.play("attack_2")
			
			var dmg_1 = int(total_damage / 2)
			var dmg_2 = total_damage - dmg_1
			
			# Hit 1 (Frame 2)
			await wait_for_frame(player_anim, 2)
			enemy_hp -= dmg_1
			spawn_floating_text(enemy_anim, dmg_1, Color(1, 1, 1))
			play_enemy_hit_effect()
			
			# Hit 2 (Frame 5)
			await wait_for_frame(player_anim, 5)
			enemy_hp -= dmg_2
			spawn_floating_text(enemy_anim, dmg_2, Color(1, 1, 1))
			play_enemy_hit_effect()
			
			await player_anim.animation_finished
			
			# Play recover animation if exists
			if player_anim.sprite_frames.has_animation("attack_2_recover"):
				player_anim.play("attack_2_recover")
				await player_anim.animation_finished

		elif current_time > 3.0 and player_anim.sprite_frames.has_animation("attack_1"):
			# --- ATTACK 1 (Hit Frame 5) ---
			player_anim.frame = 0
			player_anim.play("attack_1")
			
			await wait_for_frame(player_anim, 5)
			
			enemy_hp -= total_damage
			spawn_floating_text(enemy_anim, total_damage, Color(1, 1, 1))
			play_enemy_hit_effect()
			
			await player_anim.animation_finished

		else:
			# --- ATTACK 3 (Hit Frame 2) - Fallback ---
			if player_anim.sprite_frames.has_animation("attack_3"):
				player_anim.frame = 0
				player_anim.play("attack_3")
				
				await wait_for_frame(player_anim, 2)
				
				enemy_hp -= total_damage
				# Warna Merah kalau Damage Besar (misal attack 3 dianggap kuat)
				var color = Color(1, 0, 0) if total_damage > 10 else Color(1, 1, 1)
				spawn_floating_text(enemy_anim, total_damage, color)
				play_enemy_hit_effect()
				
				await player_anim.animation_finished
			else:
				# Fallback total jika tidak ada animasi
				await get_tree().create_timer(0.5).timeout
				enemy_hp -= total_damage
				spawn_floating_text(enemy_anim, total_damage, Color(1, 1, 1))
		
		if enemy_hp < 0: enemy_hp = 0
		
		var log_header = "⚔️ SERANGAN BERHASIL!"
		var log_body = "Musuh terkena %s Damage." % str(total_damage)
		
		question_label.text = "%s\n%s" % [log_header, log_body]
		update_ui()
		await return_player_to_start()
		
	else:
		question_label.text = "❌ JAWABAN SALAH...\nSeranganmu meleset!"
		update_ui()
		await get_tree().create_timer(1.0).timeout
	
	if enemy_hp <= 0:
		win_battle()
		return
	
	await get_tree().create_timer(0.8).timeout
	enemy_turn()

# ... (Sisa fungsi ke bawah sama seperti sebelumnya) ...
# ... (perform_enemy_attack_animation, enemy_turn, dll) ...

func perform_enemy_attack_animation():
	enemy_anim.z_index = 1  
	player_anim.z_index = 0 
	var tween = get_tree().create_tween()
	var offset_jarak = enemy_data.get("attack_offset", 70.0)
	var attack_pos = Vector2(player_anim.position.x + offset_jarak, player_anim.position.y)
	
	tween.tween_property(enemy_anim, "position", attack_pos, 0.5).set_trans(Tween.TRANS_SINE)
	await tween.finished
	
	if enemy_anim.sprite_frames.has_animation("attack"):
		enemy_anim.play("attack")
		await enemy_anim.animation_finished
	else:
		var bump_tween = get_tree().create_tween()
		var hit_pos = player_anim.position 
		bump_tween.tween_property(enemy_anim, "position", hit_pos, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bump_tween.tween_property(enemy_anim, "position", attack_pos, 0.2)
		await bump_tween.finished
	
	var return_tween = get_tree().create_tween()
	return_tween.tween_property(enemy_anim, "position", original_enemy_pos, 0.5).set_trans(Tween.TRANS_SINE)
	await return_tween.finished
	
	if enemy_hp > 0:
		enemy_anim.play(enemy_idle_anim_name)
	
	enemy_anim.z_index = 0

func enemy_turn():
	if not battle_active: return
	
	await perform_enemy_attack_animation()
	
	var min_dmg = enemy_data.get("damage_min", 1)
	var max_dmg = enemy_data.get("damage_max", 5)
	var damage = randi_range(min_dmg, max_dmg)
	
	player_hp -= damage
	if player_hp < 0: player_hp = 0
	Global.player_current_hp = player_hp
	
	spawn_floating_text(player_anim, damage, Color(1, 0.5, 0))
	
	question_label.text = "🛡️ MUSUH MENYERANG BALIK!\nKamu terkena %s Damage." % str(damage)
	update_ui()
	
	await play_player_hit_effect()
	
	if player_hp <= 0:
		game_over("💀 HP HABIS!\nKamu butuh belajar lagi...")
	else:
		await get_tree().create_timer(2.0).timeout
		start_new_turn()

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
	battle_active = false
	question_label.text = reason

func quit_battle():
	if Global.last_scene_path != "": get_tree().change_scene_to_file(Global.last_scene_path)
	else: get_tree().change_scene_to_file("res://Scenes/map2.tscn")
