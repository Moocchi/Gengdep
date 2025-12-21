extends Control

# Signal untuk lapor jumlah hit ke BattleScene
signal powerup_finished(is_success: bool)

@onready var qte_container = $QTEContainer
@onready var success_zone = $QTEContainer/BaseCircle/SuccessZone
@onready var spinner_hand = $QTEContainer/BaseCircle/SpinnerHand
@onready var center_button = $QTEContainer/CenterKeyPrompt
@onready var center_label = $QTEContainer/CenterKeyPrompt/Label

# [FIX] Pastikan SuccessRipple sudah dipindah keluar dari BaseCircle (sejajar BaseCircle)
@onready var ripple = $QTEContainer/SuccessRipple 
@onready var base_circle = $QTEContainer/BaseCircle

var parry_tween: Tween
var zone_start_angle = 0.0
var zone_end_angle = 0.0
var is_active = false

func _ready():
	visible = false
	if ripple:
		ripple.visible = false
		ripple.pivot_offset = ripple.size / 2 # Melebar dari tengah

func _input(event):
	if not is_active: return
	if event.is_action_pressed("confirm_button") or event.is_action_pressed("ui_accept"):
		_handle_interaction()

func start_powerup(spawn_pos: Vector2, duration: float = 0.8, zone_size: float = 25.0):
	visible = true
	# Reset visibilitas elemen utama untuk QTE berikutnya
	base_circle.visible = true
	center_button.visible = true
	
	is_active = true
	qte_container.global_position = spawn_pos
	spinner_hand.rotation_degrees = 0
	
	# Set ukuran success zone dinamis
	success_zone.value = zone_size
	
	# Acak posisi Success Zone
	var random_zone_rot = randf_range(0.0, 300.0)
	success_zone.rotation_degrees = random_zone_rot
	
	zone_start_angle = random_zone_rot
	zone_end_angle = random_zone_rot + (success_zone.value / success_zone.max_value * 360.0)
	
	if parry_tween: parry_tween.kill()
	parry_tween = create_tween()
	
	# Putaran jarum tetap mengikuti time_scale agar slow-mo terasa
	var game_dur = duration * Engine.time_scale
	parry_tween.tween_property(spinner_hand, "rotation_degrees", 360.0, game_dur).set_trans(Tween.TRANS_LINEAR)
	
	parry_tween.finished.connect(func():
		if is_active: _end_qte(false)
	)

func _handle_interaction():
	if not is_active: return
	is_active = false
	
	if parry_tween: parry_tween.kill()
	
	var current_angle = spinner_hand.rotation_degrees
	var tolerance = 15.0 
	var success = (current_angle >= (zone_start_angle - tolerance) and current_angle <= (zone_end_angle + tolerance))
	
	if success:
		trigger_ripple_effect()
	
	_end_qte(success)

func trigger_ripple_effect():
	if not ripple: return
	
	ripple.visible = true
	ripple.scale = Vector2(1, 1)
	ripple.modulate.a = 1.0
	
	var ripple_tween = create_tween().set_parallel(true)
	
	# [PENTING] Abaikan Engine.time_scale agar selalu 0.2 detik real-time
	ripple_tween.set_ignore_time_scale(true) 
	
	var fixed_duration = 0.2 
	
	ripple_tween.tween_property(ripple, "scale", Vector2(2.5, 2.5), fixed_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	ripple_tween.tween_property(ripple, "modulate:a", 0.0, fixed_duration)
	
	ripple_tween.chain().tween_callback(func(): ripple.visible = false)

func _end_qte(success):
	# Sembunyikan hanya lingkaran utama dan tombol agar Ripple tetap bisa memudar
	base_circle.visible = false
	center_button.visible = false
	
	powerup_finished.emit(success)
