extends Marker2D

@onready var label = $Label

func setup(text_value: String, color: Color):
	label.text = text_value
	label.modulate = color
	
	# --- [BARU] LOGIKA UKURAN TEXT BERDASARKAN DAMAGE ---
	var damage_int = int(text_value)
	var scale_factor = 1.0
	
	# Rumus: 0.8 (kecil) sampai 1.5 (besar) tergantung damage (0 - 100)
	# Clamp memastikan ukuran tidak terlalu kecil atau terlalu raksasa
	scale_factor = clamp(0.8 + (damage_int * 0.01), 0.8, 2.0)
	
	# Set ukuran awal
	scale = Vector2(scale_factor, scale_factor)
	# ----------------------------------------------------
	
	# --- ANIMASI TWEEN ---
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 1. Gerak ke atas (Random sedikit kiri kanan biar natural)
	var random_x = randf_range(-20, 20)
	tween.tween_property(self, "position", position + Vector2(random_x, -80), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. Efek Pop (Membesar sedikit lalu mengecil)
	tween.tween_property(self, "scale", scale * 1.5, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# 3. Fade Out
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.4)
	
	await tween.finished
	queue_free()
