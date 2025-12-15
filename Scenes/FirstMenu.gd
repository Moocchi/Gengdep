extends Control

# --- REFERENSI TOMBOL MENU ---
@onready var btn_new_game = $MenuContainer/BtnNewGame
@onready var btn_load = $MenuContainer/BtnLoad
@onready var btn_credits = $MenuContainer/BtnCredits
@onready var btn_exit = $MenuContainer/BtnExit

# --- REFERENSI PANEL ---
@onready var credits_panel = $CreditsPanel
@onready var btn_close_credits = $CreditsPanel/BtnCloseCredits
@onready var confirm_panel = $ConfirmationPanel
@onready var btn_confirm_yes = $ConfirmationPanel/HBoxContainer/BtnYes
@onready var btn_confirm_no = $ConfirmationPanel/HBoxContainer/BtnNo

# --- OVERLAY ---
@onready var fade_overlay = $FadeOverlay

# --- PATH ---
var starting_level_path = "res://Scenes/Main.tscn" 
var save_file_path = "user://savegame.save"

func _ready():
	# 1. Jalankan animasi Fade In
	play_fade_in()
	
	# 2. Hubungkan Signal Tombol
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	if btn_close_credits: btn_close_credits.pressed.connect(_on_close_credits_pressed)
	if btn_confirm_yes: btn_confirm_yes.pressed.connect(_on_confirm_yes_pressed)
	if btn_confirm_no: btn_confirm_no.pressed.connect(_on_confirm_no_pressed)
	
	# 3. Setup Awal Panel
	credits_panel.visible = false
	confirm_panel.visible = false
	
	# 4. Fokus Otomatis ke New Game (Wajib buat Stik)
	# Kita pakai call_deferred biar aman, menunggu frame siap
	btn_new_game.call_deferred("grab_focus")

# --- [FIXED] AUTO FOCUS GUARD ---
# Ini menjaga agar fokus tidak hilang kalau user klik sembarang tempat pakai mouse
func _process(_delta):
	var focus_owner = get_viewport().gui_get_focus_owner()
	
	# Kalau tidak ada tombol yang difokus (hilang fokus), paksa balik ke New Game
	if focus_owner == null:
		if confirm_panel.visible:
			btn_confirm_no.grab_focus()
		elif credits_panel.visible:
			btn_close_credits.grab_focus()
		else:
			btn_new_game.grab_focus()

# --- [FIXED] INPUT STIK MANUAL (ANTI ERROR) ---
func _input(event):
	if not is_inside_tree():
		return

	if event.is_action_pressed("confirm_button") or event.is_action_pressed("ui_accept"):
		var vp := get_viewport()
		if vp == null:
			return

		var focused = vp.gui_get_focus_owner()
		if focused is BaseButton:
			focused.pressed.emit()
			vp.call_deferred("set_input_as_handled")


# --- FUNGSI LAINNYA ---

func play_fade_in():
	if fade_overlay:
		fade_overlay.modulate.a = 1.0
		fade_overlay.visible = true
		var tween = create_tween()
		tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		await tween.finished
		fade_overlay.visible = false

func _on_new_game_pressed():
	if FileAccess.file_exists(save_file_path):
		confirm_panel.visible = true
		btn_confirm_no.grab_focus() # Pindah fokus stik
	else:
		start_fresh_game()

func _on_confirm_yes_pressed():
	start_fresh_game()

func _on_confirm_no_pressed():
	confirm_panel.visible = false
	btn_new_game.grab_focus() # Balikin fokus stik

func start_fresh_game():
	print("Membuat Save Baru...")
	reset_global_data()
	# Pindah scene pakai Loading Screen
	Global.change_scene_with_loading(starting_level_path)

func _on_load_pressed():
	if FileAccess.file_exists(save_file_path):
		print("Loading Game...")
		Global.change_scene_with_loading(starting_level_path)
	else:
		print("Save file tidak ditemukan!")

func _on_credits_pressed():
	credits_panel.visible = true
	btn_close_credits.grab_focus()

func _on_close_credits_pressed():
	credits_panel.visible = false
	btn_credits.grab_focus()

func _on_exit_pressed():
	get_tree().quit()

func reset_global_data():
	Global.player_current_hp = 100
	Global.player_current_mana = 0
	Global.defeated_enemies = []
	Global.current_enemy_id = ""
	Global.just_defeated_id = ""
	Global.just_fled_from_id = ""
	Global.last_player_position = Vector2.ZERO
