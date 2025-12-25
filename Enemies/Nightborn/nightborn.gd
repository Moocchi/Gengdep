extends CharacterBody2D

@export var enemy_id = "nightborn_1"
@export var enemy_type = "nightborn"
var current_charge = 0
var max_charge = 3

@export var chase_speed = 150.0 
@export var wander_speed = 15.0
@export var wander_range = 60.0
@export var acceleration = 400.0
@export var friction = 300.0

# --- SYSTEM VARIABLES ---
var player = null
var start_position = Vector2.ZERO
var target_position = Vector2.ZERO
var is_stunned = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var wander_timer = $"Wander Time"

func _ready():
	# 1. Debugging ID
	print("--- Checking Nightborn ID: ", enemy_id, " ---")
	print("Defeated List: ", Global.defeated_enemies)

	# 2. Cek Kematian (Logika Utama)
	if enemy_id in Global.defeated_enemies:
		if Global.just_defeated_id == enemy_id:
			# Baru saja dikalahkan di BattleScene
			Global.just_defeated_id = "" 
			print("Enemy ", enemy_id, " baru saja kalah. Menjalankan animasi mati.")
			
			# Gunakan posisi terakhir musuh saat battle dipicu
			if Global.last_enemy_position != Vector2.ZERO:
				global_position = Global.last_enemy_position
			
			# Hentikan semua gerakan dan jalankan animasi mati
			is_stunned = true
			set_physics_process(false)
			play_death_sequence()
		else:
			# Jika sudah mati dari sesi sebelumnya, langsung hapus
			print("Enemy ", enemy_id, " sudah mati sebelumnya. Menghapus dari map.")
			self.visible = false
			queue_free()
		return # Berhenti agar logic di bawah tidak dijalankan
	
	# 3. [FIX] Logika Stun & Posisi jika kabur
	if Global.just_fled_from_id == enemy_id:
		Global.just_fled_from_id = ""
		
		# Pindahkan musuh ke posisi saat battle dimulai agar tidak teleport balik ke spawn awal
		if Global.last_enemy_position != Vector2.ZERO:
			global_position = Global.last_enemy_position
			
		# Terapkan efek stun/pusing selama 5 detik
		apply_stun(5.0)
	
	# 4. Setup Awal
	# start_position penting untuk wander_range agar musuh tidak "lari" balik ke spawn saat jalan-jalan
	start_position = global_position 
	target_position = start_position
	current_charge = 0
	
	if wander_timer:
		wander_timer.wait_time = randf_range(1.0, 3.0)
		wander_timer.start()

func _physics_process(delta):
	# Jika sedang terkena stun, hentikan semua logika gerakan.
	if is_stunned: return

	var current_speed_target = 0.0
	var desired_velocity = Vector2.ZERO
	
	if player:
		target_position = player.global_position
		current_speed_target = chase_speed
	else:
		current_speed_target = wander_speed

	var direction = global_position.direction_to(target_position)
	var distance = global_position.distance_to(target_position)
	
	# Gerakan & Animasi
	if distance > 5.0:
		desired_velocity = direction * current_speed_target
		animated_sprite.play("run") # Nightborn lari
		animated_sprite.flip_h = direction.x < 0
	else:
		desired_velocity = Vector2.ZERO
		animated_sprite.play("idle") # Pose diam
		if player == null: _pick_new_wander_target()

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()

# =========================================
# --- LOGIKA KHUSUS MINI BOSS (CHARGE) ---
# =========================================

func decide_next_action() -> String:
	# Jika charge penuh, paksa Mega Attack.
	if current_charge >= max_charge:
		return "MEGA_ATTACK"
	
	# Peluang 10% serangan normal, 90% charge.
	if randf() < 0.10:
		return "NORMAL_ATTACK"
	
	return "CHARGE"

func perform_charge_visual():
	current_charge += 1
	if animated_sprite.sprite_frames.has_animation("charge"):
		animated_sprite.play("charge")
	
	# Visual: Karakter berubah warna seiring bertambahnya charge.
	var tween = create_tween()
	var glow = Color(1.0 + (current_charge * 0.5), 1.0, 1.0 + (current_charge * 1.5))
	tween.tween_property(self, "modulate", glow, 0.5)

func reset_charge_status():
	current_charge = 0
	modulate = Color(1, 1, 1, 1)

# =========================================
# --- STANDAR MUSUH ---
# =========================================

func _pick_new_wander_target():
	var random_pos = Vector2(randf_range(-wander_range, wander_range), randf_range(-wander_range, wander_range))
	target_position = start_position + random_pos

func _on_detection_area_body_entered(body):
	if body.name == "Player": player = body

func _on_detection_area_body_exited(body):
	if body == player: player = null

func _on_wander_time_timeout():
	if player == null: _pick_new_wander_target()

func _on_hitbox_body_entered(body):
	if is_stunned or body.name != "Player": return
	
	# Simpan data ke Global sebelum pindah ke BattleScene.
	Global.last_player_position = body.global_position
	Global.last_enemy_position = global_position
	Global.last_scene_path = get_tree().current_scene.scene_file_path
	Global.current_enemy_id = enemy_id
	Global.active_enemy_type = enemy_type
	
	# Ambil Screenshot Background untuk transisi.
	visible = false; body.visible = false
	await get_tree().process_frame; await get_tree().process_frame
	var viewport_img = get_viewport().get_texture().get_image()
	Global.battle_background_texture = ImageTexture.create_from_image(viewport_img)
	
	Global.change_scene_with_loading("res://Scenes/BattleScene.tscn")

func play_death_sequence():
	# Matikan tabrakan agar tidak memicu battle lagi saat animasi mati
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	# Matikan area deteksi jika ada
	if has_node("DetectionArea"):
		$DetectionArea.monitoring = false
		
	if animated_sprite.sprite_frames.has_animation("die"):
		animated_sprite.play("die")
		# Jika animasi tidak loop, tunggu sampai selesai
		if not animated_sprite.sprite_frames.get_animation_loop("die"):
			await animated_sprite.animation_finished
		else:
			# Jika looping, beri timer manual agar tidak nyangkut selamanya
			await get_tree().create_timer(1.5).timeout
	
	print("Animasi mati selesai. Menghapus node ", enemy_id)
	queue_free()

func apply_stun(duration):
	is_stunned = true
	modulate = Color(0.5, 0.5, 0.5, 1) 
	
	# Mematikan hitbox agar tidak masuk battle berulang saat pusing
	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
		
	await get_tree().create_timer(duration).timeout
	
	is_stunned = false
	modulate = Color(1, 1, 1, 1)
	
	# [FIX] Re-detect Player agar Nightborn langsung agresif lagi
	var detection_area = get_node_or_null("Detection Area")
	if detection_area:
		for body in detection_area.get_overlapping_bodies():
			if body.name == "Player":
				player = body
				break

	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", false)
