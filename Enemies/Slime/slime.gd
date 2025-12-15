extends CharacterBody2D

# --- IDENTITAS ---
@export var enemy_id = "slime_1"
@export var enemy_type = "slime"

# --- CONFIG GERAKAN ---
@export var chase_speed = 40.0
@export var wander_speed = 20.0
@export var wander_range = 50.0
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
	# 1. Cek Kematian
	if enemy_id in Global.defeated_enemies:
		if Global.just_defeated_id == enemy_id:
			Global.just_defeated_id = ""
			if Global.last_enemy_position != Vector2.ZERO:
				global_position = Global.last_enemy_position
			play_death_sequence()
		else:
			queue_free()
		return
	
	# 2. Cek Kabur
	if Global.just_fled_from_id == enemy_id:
		Global.just_fled_from_id = ""
		if Global.last_enemy_position != Vector2.ZERO:
			global_position = Global.last_enemy_position
		apply_stun(2.0)
	
	start_position = global_position
	target_position = start_position
	
	if wander_timer:
		wander_timer.wait_time = randf_range(1.0, 3.0)
		wander_timer.start()
		if not wander_timer.timeout.is_connected(_on_wander_time_timeout):
			wander_timer.timeout.connect(_on_wander_time_timeout)

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
	
	if distance > 5.0:
		desired_velocity = direction * current_speed_target
		if direction.x < 0:
			animated_sprite.flip_h = true if enemy_type == "bee" else false
		elif direction.x > 0:
			animated_sprite.flip_h = false if enemy_type == "bee" else true
	else:
		desired_velocity = Vector2.ZERO
		if player == null: _pick_new_wander_target()

	if desired_velocity != Vector2.ZERO:
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	move_and_slide()

func apply_stun(duration):
	is_stunned = true
	modulate = Color(0.5, 0.5, 0.5, 1) 
	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(duration).timeout
	is_stunned = false
	modulate = Color(1, 1, 1, 1)
	player = null
	if has_node("Hitbox/CollisionShape2D"):
		$Hitbox/CollisionShape2D.set_deferred("disabled", false)

func play_death_sequence():
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Hitbox/CollisionShape2D"): 
		$Hitbox/CollisionShape2D.set_deferred("disabled", true)
	if has_node("Detection Area/CollisionShape2D"): 
		$"Detection Area/CollisionShape2D".set_deferred("disabled", true)
	
	if animated_sprite.sprite_frames.has_animation("die"):
		animated_sprite.play("die")
		await animated_sprite.animation_finished
		queue_free()
	else:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 1.5)
		await tween.finished
		queue_free()

func _pick_new_wander_target():
	var random_x = randf_range(-wander_range, wander_range)
	var random_y = randf_range(-wander_range, wander_range)
	target_position = start_position + Vector2(random_x, random_y)

func _on_detection_area_body_entered(body):
	if body.name == "Player": player = body

func _on_detection_area_body_exited(body):
	if body == player: player = null

func _on_wander_time_timeout():
	if player == null: _pick_new_wander_target()

func _on_hitbox_body_entered(body):
	if is_stunned: return

	if body.name == "Player":
		print("Battle Start! Melawan: " + enemy_id)
		
		# Simpan Data
		Global.last_player_position = body.global_position
		Global.last_enemy_position = global_position
		if get_tree().current_scene:
			Global.last_scene_path = get_tree().current_scene.scene_file_path
		Global.current_enemy_id = enemy_id
		Global.active_enemy_type = enemy_type
		
		# Efek Screenshot
		visible = false 
		body.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		var viewport_img = get_viewport().get_texture().get_image()
		var screenshot = ImageTexture.create_from_image(viewport_img)
		Global.battle_background_texture = screenshot
		
		# [UPDATE] Pindah Scene pakai Loading
		Global.change_scene_with_loading("res://Scenes/BattleScene.tscn")
