extends Node2D

func _ready():
	# DEBUG: Cek apakah tag berhasil dikirim dari Map 2
	print("--- DEBUG START ---")
	print("Tag yang diterima: ", NavigationManager.spawn_door_tag)
	
	var wp = get_tree().current_scene.find_child("WorldPointer", true, false)
	if wp:
		wp.target = null 

	if NavigationManager.spawn_door_tag != null:
		_on_level_spawn(NavigationManager.spawn_door_tag)
	else:
		print("MASALAH: Tag kosong! Player muncul di posisi default (Rumah).")

func _on_level_spawn(destination_tag: String):
	# Kita coba cari node pintu
	var door_path = "Doors/door_" + destination_tag
	print("Mencari pintu dengan nama: ", door_path)
	
	if has_node(door_path):
		print("SUKSES: Pintu ditemukan! Memindahkan player...")
		var door = get_node(door_path)
		# Pindahkan player
		NavigationManager.trigger_player_spawn(door.spawn.global_position, door.spawn_direction)
	else:
		# Jika pintu tidak ketemu, script ini akan kasih tau nama file yg benar
		print("ERROR FATAL: Pintu TIDAK DITEMUKAN!")
		print("Script mencari: '", door_path, "'")
		print("Tapi daftar nama pintu yang ada di folder 'Doors' adalah:")
		
		# Cek isi folder Doors
		if has_node("Doors"):
			for child in get_node("Doors").get_children():
				print("- ", child.name)
		else:
			print("Folder 'Doors' tidak ditemukan! Cek nama Node induknya.")
	print("--- DEBUG END ---")
