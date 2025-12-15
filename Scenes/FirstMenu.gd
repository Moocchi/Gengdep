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

# --- [BARU] REFERENSI OVERLAY PUTIH ---
# Pastikan kamu sudah membuat node ColorRect bernama "FadeOverlay" di scene
@onready var fade_overlay = $FadeOverlay

# --- PATH ---
var starting_level_path = "res://Scenes/Main.tscn" 
var save_file_path = "user://savegame.save"

func _ready():
	# 1. [BARU] Jalankan Efek Flash Putih -> Redup
	play_fade_in()
	
	# 2. Hubungkan Signal
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	if btn_close_credits: btn_close_credits.pressed.connect(_on_close_credits_pressed)
	if btn_confirm_yes: btn_confirm_yes.pressed.connect(_on_confirm_yes_pressed)
	if btn_confirm_no: btn_confirm_no.pressed.connect(_on_confirm_no_pressed)
	
	# Sembunyikan panel di awal
	credits_panel.visible = false
	confirm_panel.visible = false
	
	# Fokus ke tombol setelah efek fade selesai (opsional, biar mulus)
	await get_tree().create_timer(0.5).timeout
	btn_new_game.grab_focus()

# --- [BARU] FUNGSI ANIMASI FADE IN ---
func play_fade_in():
	# Pastikan di awal dia putih solid (alpha 1.0)
	fade_overlay.modulate.a = 1.0
	fade_overlay.visible = true
	
	# Buat tween untuk mengubah alpha dari 1.0 ke 0.0
	var tween = create_tween()
	# Durasi 0.8 detik, pakai transisi SINE biar halus
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# Setelah selesai, sembunyikan node-nya (opsional, tapi praktik bagus)
	await tween.finished
	fade_overlay.visible = false

# --- LOGIKA NEW GAME ---
func _on_new_game_pressed():
	if FileAccess.file_exists(save_file_path):
		confirm_panel.visible = true
		btn_confirm_no.grab_focus()
	else:
		start_fresh_game()

# --- LOGIKA KONFIRMASI ---
func _on_confirm_yes_pressed():
	start_fresh_game()

func _on_confirm_no_pressed():
	confirm_panel.visible = false
	btn_new_game.grab_focus()

# --- FUNGSI MULAI ---
func start_fresh_game():
	print("Membuat Save Baru...")
	reset_global_data()
	get_tree().change_scene_to_file(starting_level_path)

# --- FUNGSI LAINNYA ---
func _on_load_pressed():
	if FileAccess.file_exists(save_file_path):
		print("Loading Game...")
		# Logika load data JSON nanti di sini
		get_tree().change_scene_to_file(starting_level_path)
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
