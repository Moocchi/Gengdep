extends CharacterBody2D

# --- EXPORT VARIABLES ---
@export var enemy_id = "soul_harbinger_1"
@export var enemy_type = "soul_harbinger"

# --- BOSS STATS ---
@export var chase_speed = 180.0  # Sedikit lebih cepat dari Nightborn
@export var wander_speed = 25.0
@export var wander_range = 80.0
@export var acceleration = 500.0
@export var friction = 400.0

# --- SYSTEM VARIABLES ---
var current_charge = 0
var max_charge = 3
var player = null
var start_position = Vector2.ZERO
var target_position = Vector2.ZERO
var is_stunned = false

@onready var animated_sprite = $AnimatedSprite2D
@onready var wander_timer = $"Wander Time"

func _ready():
	# 1. Debugging ID
	print("--- Checking Soul Harbinger ID: ", enemy_id, " ---")
	
	# 2. Cek Kematian (Logika Utama)
	if enemy_id in Global.defeated_enemies:
		if Global.just_defeated_id == enemy_id:
			Global.just_defeated_id = "" 
			print("Soul Harbinger ", enemy_id, " kalah. Menjalankan animasi mati.")
			
			if Global.last_enemy_position != Vector2.ZERO:
				global_position = Global.last_enemy_position
			
			is_stunned = true
			set_physics_process(false)
			play_death_sequence()
		else:
			print("Soul Harbinger ", enemy_id, " sudah mati. Menghapus dari map.")
			self.visible = false
			queue_free()
		return 
	
	# 3. Logika Stun jika kabur
	if Global.just_fled_from_id == enemy_id:
		Global.just_fled_from_id = ""
		if Global.last_enemy_position != Vector2.ZERO:
			global_position = Global.last_enemy_position
		apply_stun(5.0)
	
	# 4. Setup Awal
	start_position = global_position 
	target_position = start_position
	current_charge = 0
	
	if wander_timer:
		wander_timer.wait_time = randf_range(1.5, 4.0)
		wander_timer.start()

func _physics_process(delta):
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
	if distance > 10.0:
		desired_velocity = direction * current_speed_target
		# Menggunakan animasi "run" atau "fly" jika tersedia
		if animated_sprite.sprite_frames.has_animation("run"):
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")
		
		# Balik arah (Flip) berdasarkan arah gerak horizontal
		animated_sprite.flip_h = direction.x < 0
	else:
		desired_velocity = Vector2.ZERO
		animated_sprite.play("idle")
		if player == null: _pick_new_wander_target()

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()

# =========================================
# --- LOGIKA KHUSUS BOSS (SOUL REAP) ---
# =========================================

func perform_charge_visual():
	current_charge += 1
	if animated_sprite.sprite_frames.has_animation("charge"):
		animated_sprite.play("charge")
	
	# Visual: Soul Harbinger bersinar Ungu Kegelapan seiring charge
	var tween = create_tween()
	var dark_glow = Color(1.0, 0.5 + (current_charge * 0.2), 1.5 + (current_charge * 1.0))
	tween.tween_property(self, "modulate", dark_glow, 0.5)

func reset_charge_status():
	current_charge = 0
	modulate = Color(1, 1, 1, 1)

# =========================================
# --- STANDAR MUSUH (MENDUKUNG MAP LOGIC) ---
# =========================================

func _pick_new_wander_target():
	var random_pos = Vector2(randf_range(-wander_range, wander_range), randf_range(-wander_range, wander_range))
	target_position = start_position + random_pos

func _on_detection_area_body_entered(body):
	if body.name == "Player": 
		player = body

func _on_detection_area_body_exited(body):
	if body == player: 
		player = null

func _on_wander_time_timeout():
	if player == null: _pick_new_wander_target()

func _on_hitbox_body_entered(body):
	if is_stunned or body.name != "Player": return
	
	# Data Transfer ke Global
	Global.last_player_position = body.global_position
	Global.last_enemy_position = global_position
	Global.last_scene_path = get_tree().current_scene.scene_file_path
	Global.current_enemy_id = enemy_id
	Global.active_enemy_type = enemy_type
	
	# Screenshot Transisi
	visible = false; body.visible = false
	await get_tree().process_frame; await get_tree().process_frame
	var viewport_img = get_viewport().get_texture().get_image()
	Global.battle_background_texture = ImageTexture.create_from_image(viewport_img)
	
	Global.change_scene_with_loading("res://Scenes/BattleScene.tscn")

func play_death_sequence():
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("Detection Area"):
		get_node("Detection Area").monitoring = false
		
	if animated_sprite.sprite_frames.has_animation("die"):
		animated_sprite.play("die")
		if not animated_sprite.sprite_frames.get_animation_loop("die"):
			await animated_sprite.animation_finished
		else:
			await get_tree().create_timer(2.0).timeout
	
	print("Soul Harbinger musnah.")
	queue_free()

func apply_stun(duration):
	is_stunned = true
	modulate = Color(0.4, 0.2, 0.6, 1) # Warna Ungu Gelap saat pusing
	
	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
		
	await get_tree().create_timer(duration).timeout
	
	is_stunned = false
	modulate = Color(1, 1, 1, 1)
	
	# Deteksi ulang player di sekitar
	var detection_area = get_node_or_null("Detection Area")
	if detection_area:
		for body in detection_area.get_overlapping_bodies():
			if body.name == "Player":
				player = body
				break

	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", false)
