extends Control

signal parry_finished(is_success: bool)

@onready var qte_container = $QTEContainer
@onready var success_zone = $QTEContainer/BaseCircle/SuccessZone
@onready var spinner_hand = $QTEContainer/BaseCircle/SpinnerHand
@onready var center_button = $QTEContainer/CenterKeyPrompt
@onready var center_label = $QTEContainer/CenterKeyPrompt/Label

# [PENTING] Pastikan Ripple dipindah ke QTEContainer (bukan di dalam BaseCircle)
# agar tidak ikut hilang saat BaseCircle disembunyikan.
@onready var ripple = $QTEContainer/SuccessRipple
@onready var base_circle = $QTEContainer/BaseCircle

var parry_tween: Tween
var zone_start_angle = 0.0
var zone_end_angle = 0.0
var is_active = false

var style_normal: StyleBoxFlat
var style_pressed: StyleBoxFlat

func _ready():
	visible = false
	if ripple:
		ripple.visible = false
		ripple.pivot_offset = ripple.size / 2 
	
	center_button.focus_mode = Control.FOCUS_NONE 
	center_button.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color.BLACK
	style_normal.border_color = Color.WHITE
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(25)
	
	style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color.WHITE
	style_pressed.border_color = Color.BLACK
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(25)
	
	if center_label and center_label.label_settings:
		center_label.label_settings = center_label.label_settings.duplicate()
	
	_apply_style_normal()

func _input(event):
	if not is_active: return
	if event.is_action_pressed("confirm_button") or event.is_action_pressed("ui_accept"):
		_handle_interaction()

func _handle_interaction():
	if not is_active: return
	is_active = false 
	
	if parry_tween: parry_tween.kill()
	
	var current_angle = spinner_hand.rotation_degrees
	var tolerance = 10.0 
	var result = (current_angle >= (zone_start_angle - tolerance) and current_angle <= (zone_end_angle + tolerance))
	
	_on_button_pressed_visual()
	
	if result:
		trigger_ripple_effect()
	
	_end_qte(result)

func trigger_ripple_effect():
	if not ripple: return
	
	ripple.visible = true
	ripple.scale = Vector2(1, 1)
	ripple.modulate.a = 1.0
	
	var ripple_tween = create_tween().set_parallel(true)
	
	# [FIX] JANGAN gunakan set_speed_scale di sini untuk Parry.
	# Karena BattleScene akan langsung mengembalikan Engine.time_scale ke 1.0.
	# Dengan durasi 0.2, dia akan terlihat sangat pas di mata pemain.
	var duration = 0.2 
	
	ripple_tween.tween_property(ripple, "scale", Vector2(2.5, 2.5), duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	ripple_tween.tween_property(ripple, "modulate:a", 0.0, duration)
	
	ripple_tween.chain().tween_callback(func(): ripple.visible = false)

func _on_button_pressed_visual():
	center_button.add_theme_stylebox_override("normal", style_pressed)
	if center_label and center_label.label_settings:
		center_label.label_settings.font_color = Color.BLACK
		center_label.label_settings.outline_color = Color.WHITE

func _on_button_released_visual():
	_apply_style_normal()
	if center_label and center_label.label_settings:
		center_label.label_settings.font_color = Color.WHITE
		center_label.label_settings.outline_color = Color.BLACK

func _apply_style_normal():
	center_button.add_theme_stylebox_override("normal", style_normal)

func start_qte(mouse_pos: Vector2, _unused_duration: float = 1.0):
	visible = true
	base_circle.visible = true
	center_button.visible = true
	
	is_active = true
	_on_button_released_visual()
	
	qte_container.global_position = mouse_pos + Vector2(0, -20)
	spinner_hand.rotation_degrees = 0
	
	var random_zone_rot = randf_range(60.0, 300.0)
	success_zone.rotation_degrees = random_zone_rot
	
	var zone_width_degrees = (success_zone.value / success_zone.max_value) * 360.0
	zone_start_angle = random_zone_rot
	zone_end_angle = random_zone_rot + zone_width_degrees
	
	if parry_tween: parry_tween.kill()
	parry_tween = create_tween()
	
	var game_duration = 1.0 * Engine.time_scale 
	parry_tween.tween_property(spinner_hand, "rotation_degrees", 360.0, game_duration).set_trans(Tween.TRANS_LINEAR)
	
	parry_tween.finished.connect(func():
		if is_active: _end_qte(false)
	)

func _end_qte(result: bool):
	is_active = false
	# Sembunyikan elemen utama saja agar Ripple tetap terlihat memudar
	base_circle.visible = false
	center_button.visible = false
	
	parry_finished.emit(result)
