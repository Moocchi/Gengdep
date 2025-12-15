extends CharacterBody2D

class_name Player

@export var movement_speed: float = 500
@export var roll_speed: float = 60

var character_direction: Vector2 = Vector2.ZERO
var is_attacking: bool = false
var is_rolling: bool = false
var is_emoting: bool = false


func _physics_process(delta):
	var sprite = %sprite
	var sprite_attack = %sprite_attack

	# --- Input arah (tidak bisa digerakkan saat attack/roll/emote) ---
	if not is_attacking and not is_rolling and not is_emoting:
		character_direction.x = Input.get_axis("move_left", "move_right")
		character_direction.y = Input.get_axis("move_up", "move_down")
		character_direction = character_direction.normalized()

	# --- Flip arah ---
	if character_direction.x > 0:
		sprite.flip_h = false
		sprite_attack.flip_h = false
	elif character_direction.x < 0:
		sprite.flip_h = true
		sprite_attack.flip_h = true

	# --- ATTACK 1 ---
	if Input.is_action_just_pressed("attack_1") and not is_attacking and not is_rolling and not is_emoting:
		_do_attack(sprite, sprite_attack, "attack_1")
		return

	# --- ATTACK 2 ---
	if Input.is_action_just_pressed("attack_2") and not is_attacking and not is_rolling and not is_emoting:
		_do_attack(sprite, sprite_attack, "attack_2", true)
		return

	# --- ATTACK 3 ---
	if Input.is_action_just_pressed("attack_3") and not is_attacking and not is_rolling and not is_emoting:
		_do_attack(sprite, sprite_attack, "attack_3", true)
		return

	# --- EMOTE ---
	if Input.is_action_just_pressed("emote") and not is_attacking and not is_rolling and not is_emoting:
		_do_emote(sprite)
		return

	# --- ROLL ---
	if Input.is_action_just_pressed("roll") and not is_rolling and not is_attacking and not is_emoting:
		_do_roll(sprite)
		return

	# --- Gerak & animasi normal ---
	if not is_attacking and not is_rolling and not is_emoting:
		if character_direction != Vector2.ZERO:
			velocity = character_direction * movement_speed
			if sprite.animation != "walk":
				sprite.play("walk")
		else:
			velocity = velocity.move_toward(Vector2.ZERO, movement_speed)
			if sprite.animation != "idle":
				sprite.play("idle")

	move_and_slide()


# --- ATTACK (mendukung animasi recover) ---
func _do_attack(sprite, sprite_attack, anim_name: String, has_recover: bool = false):
	is_attacking = true
	velocity = Vector2.ZERO

	sprite.visible = false
	sprite_attack.visible = true
	sprite_attack.play(anim_name)

	await sprite_attack.animation_finished

	if has_recover and (sprite_attack.animation == "attack_2" or sprite_attack.animation == "attack_3"):
		var recover_name = anim_name + "_recover"
		if sprite_attack.sprite_frames.has_animation(recover_name):
			sprite_attack.play(recover_name)
			await sprite_attack.animation_finished

	is_attacking = false
	sprite_attack.visible = false
	sprite.visible = true
	sprite.play("idle")


# --- ROLL ---
func _do_roll(sprite):
	is_rolling = true

	var roll_dir = Vector2.ZERO
	if character_direction != Vector2.ZERO:
		roll_dir = character_direction
	else:
		roll_dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT

	sprite.play("roll")

	while sprite.is_playing() and sprite.animation == "roll":
		# --- SAFETY CHECK (PERBAIKAN) ---
		# Cek apakah Player masih menempel di Tree? Jika tidak (sedang pindah scene), hentikan fungsi.
		if not is_inside_tree() or get_tree() == null:
			is_rolling = false
			return

		var progress = sprite.frame / float(sprite.sprite_frames.get_frame_count("roll"))
		
		# Gunakan clamp agar progress tidak error jika animasi glitch
		# (Opsional, tapi bagus untuk safety)
		progress = clamp(progress, 0.0, 1.0) 
		
		var eased_speed = roll_speed * (1.0 - pow(progress, 2))
		velocity = roll_dir * eased_speed
		move_and_slide()
		
		# --- PERBAIKAN UTAMA ERROR ---
		# Ambil referensi tree ke variabel dulu
		var tree = get_tree()
		
		# Jika tree masih ada, baru kita await frame selanjutnya
		if tree:
			await tree.process_frame
		else:
			# Jika tree null (scene ganti), stop loop
			return

	is_rolling = false
	velocity = Vector2.ZERO
	
	# Safety check lagi sebelum play idle, takutnya node sudah dihapus saat loop selesai
	if is_inside_tree():
		sprite.play("idle")

# --- EMOTE (main animasi lalu reverse) ---
func _do_emote(sprite):
	is_emoting = true
	velocity = Vector2.ZERO

	var anim_name = "emote"
	if not sprite.sprite_frames.has_animation(anim_name):
		print("⚠ Emote animation not found!")
		is_emoting = false
		return

	sprite.play(anim_name)
	await sprite.animation_finished

	# reverse frame secara manual
	for frame in range(sprite.sprite_frames.get_frame_count(anim_name) - 1, -1, -1):
		sprite.frame = frame
		await get_tree().create_timer(0.05).timeout  # kecepatan mundur

	is_emoting = false
	sprite.play("idle")


func _ready():
	NavigationManager.on_trigger_player_spawn.connect(_on_spawn)
	%sprite_attack.visible = false
	
	# --- FIX BLINK KAMERA (VERSI FINAL) ---
	if Global.last_player_position != Vector2.ZERO:
		var cam = $Camera2D
		
		# 1. Matikan Smoothing Total (Hard Disable)
		# Kita simpan dulu settingan aslinya (nyala/mati)
		var original_smoothing = cam.position_smoothing_enabled
		cam.position_smoothing_enabled = false
		
		# 2. Pindahkan Player
		global_position = Global.last_player_position
		
		# 3. Paksa Kamera update detik ini juga (sebelum layar digambar)
		cam.force_update_scroll()
		
		# 4. Trik Rahasia: Tunggu 2 Frame Render
		# Frame 1: Logic jalan
		# Frame 2: Layar digambar di posisi baru (tanpa smoothing)
		await get_tree().process_frame
		await get_tree().process_frame
		
		# 5. Kembalikan settingan smoothing seperti semula
		cam.position_smoothing_enabled = original_smoothing
		
		# 6. Reset Data Global
		Global.last_player_position = Vector2.ZERO
	NavigationManager.on_trigger_player_spawn.connect(_on_spawn)
	%sprite_attack.visible = false
	
	# Cek apakah ada data posisi dari Global? (Pulang dari Battle)
	if Global.last_player_position != Vector2.ZERO:
		global_position = Global.last_player_position
		
		# --- [FIX BLINK KAMERA] ---
		# Ambil referensi kamera (Sesuaikan nama node kamera kamu, biasanya "Camera2D")
		var camera = $Camera2D 
		
		if camera:
			# Matikan smoothing sesaat agar kamera langsung "teleport" ke posisi player
			camera.reset_smoothing()
			# Paksa update posisi layar saat ini juga
			camera.force_update_scroll()
		# --------------------------

		# Reset data Global dengan jeda (kode lama kamu)
		get_tree().create_timer(0.1).timeout.connect(func(): Global.last_player_position = Vector2.ZERO)

func _on_spawn(pos : Vector2, dir : String):
	# --- SAFETY CHECK (PRIORITAS BATTLE) ---
	# Jika variable Global masih ada isinya, berarti kita baru saja set posisi dari Battle.
	# Maka, ABAIKAN perintah spawn dari NavigationManager ini.
	if Global.last_player_position != Vector2.ZERO:
		return 

	# Kalau tidak ada data battle, baru jalankan spawn normal (pindah map/pintu)
	global_position = pos
	
	# Reset animasi & logika spawn lainnya...
	%sprite.play("idle")
	%sprite_attack.visible = false
	%sprite.visible = true
	
	var direction_fixed = dir.to_lower().strip_edges()
	if direction_fixed == "left":
		%sprite.flip_h = true
		%sprite_attack.flip_h = true
	elif direction_fixed == "right":
		%sprite.flip_h = false
		%sprite_attack.flip_h = false
