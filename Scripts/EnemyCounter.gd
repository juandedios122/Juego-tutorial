extends Label

func _ready():
	# Configurar el Label para que sea visible
	add_theme_font_size_override("font_size", 24)
	
	# Crear estilo de fondo
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.8)
	bg.set_corner_radius_all(5)
	bg.set_content_margin_all(8)
	
	var label_style = Theme.new()
	label_style.set_stylebox("normal", "Label", bg)
	theme = label_style
	
	# Posicionar en la esquina superior izquierda
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 10
	offset_top = 10
	
	# ✅ FIX: Conectar a la señal de Global en lugar de revisar en _process
	# Antes: _process llamaba update_counter() 60 veces por segundo aunque nada hubiera cambiado
	# Ahora: solo se actualiza cuando un enemigo aparece o muere
	Global.enemy_count_changed.connect(_on_enemy_count_changed)
	
	# Mostrar los valores actuales al arrancar
	update_counter()

# ✅ FIX: _process eliminado — ya no se necesita

func _on_enemy_count_changed(_alive: int, _killed: int) -> void:
	# Esta función se llama automáticamente desde Global
	# cuando spawna o muere un enemigo
	update_counter()

func update_counter():
	text = "Vivos: %d   Muertos: %d" % [Global.enemies_alive, Global.enemies_killed]
