@tool
extends RichTextEffect
class_name RichTextStiffWave

# Nama tag BBCode: [stiff]
var bbcode = "stiff"

func _process_custom_fx(char_fx):
	# --- PARAMETER ---
	# height: Tinggi loncatan (pixel)
	var height = char_fx.env.get("height", 15.0) 
	
	# speed: Seberapa cepat pindah ke huruf berikutnya
	var speed = char_fx.env.get("speed", 8.0)    
	
	# limit: Total panjang karakter + jeda istirahat sebelum loop lagi.
	# "NOW LOADING..." itu ada 14 karakter. 
	# Jadi kalau limit di-set 20, berarti ada jeda 6 ketukan kosong sebelum ulang.
	var limit = char_fx.env.get("limit", 20.0)

	# --- LOGIKA SATU PER SATU (CURSOR) ---
	
	# Hitung posisi "kursor" saat ini berdasarkan waktu
	# floor() membulatkan ke bawah supaya gerakannya patah (kotak), bukan halus.
	var current_cursor_pos = int(floor(char_fx.elapsed_time * speed))
	
	# Gunakan modulo (%) agar looping setelah mencapai batas (limit)
	var active_index = current_cursor_pos % int(limit)
	
	# Cek apakah huruf ini adalah huruf yang sedang ditunjuk kursor?
	if char_fx.relative_index == active_index:
		# Ya! Huruf ini naik.
		char_fx.offset.y = -height
	else:
		# Tidak. Huruf ini diam di bawah.
		char_fx.offset.y = 0
		
	return true
