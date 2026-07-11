@tool
extends StaticBody2D
## casa.gd
## ══════════════════════════════════════════════════════════════════════════
## Construye una casa del pueblo de forma procedural, tile a tile, usando
## Assets/sprites/tilesets/walls/walls.png como pared y wooden_door.png como
## puerta. Así una sola escena (Casa.tscn) sirve para todas las casas del
## pueblo: solo cambia ancho/alto/variante/color en el Inspector y se ve
## una casa distinta al instante (también funciona en el editor gracias a
## @tool, no hace falta correr el juego para verla).
##
## NOTA para Juan: elegí los tiles de "pared plana" y "remate superior" de
## walls.png a ojo (COL_VARIANTE / FILA_*) sin poder previsualizar el editor
## de Godot desde acá. Si algún tile no combina bien, ajusta esas constantes
## abriendo walls.png en el inspector de TileSet — es cuestión de segundos.
## ══════════════════════════════════════════════════════════════════════════

const TILE_SIZE := 16
const TEX_WALLS  : Texture2D = preload("res://Assets/sprites/tilesets/walls/walls.png")
const TEX_PUERTA : Texture2D = preload("res://Assets/sprites/tilesets/walls/wooden_door.png")
const TEX_LUZ    : Texture2D = preload("res://Assets/sprites/objects/light_soft.png")

## Columna base del tile de pared "plano" para cada variante de color.
## 0 = piedra gris · 1 = madera tostada (mitad derecha de la hoja walls.png)
const COL_VARIANTE := [2, 6]
const FILA_TRIM    := 0   ## fila usada como remate superior (linea de techo)
const FILA_RELLENO := 2   ## fila usada como relleno de pared

@export var ancho_tiles: int = 4:
	set(v):
		ancho_tiles = maxi(2, v)
		_reconstruir()

@export var alto_tiles: int = 3:
	set(v):
		alto_tiles = maxi(2, v)
		_reconstruir()

@export var variante: int = 0:
	set(v):
		variante = clampi(v, 0, 1)
		_reconstruir()

@export var con_luz: bool = true:
	set(v):
		con_luz = v
		_reconstruir()

@export var tinte: Color = Color.WHITE:
	set(v):
		tinte = v
		_reconstruir()


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	if not is_inside_tree():
		return

	for hijo in get_children():
		hijo.queue_free()

	var col: int = COL_VARIANTE[variante]

	# ── Paredes: remate superior (techo) + relleno hasta el suelo ───────────
	for x in range(ancho_tiles):
		_crear_tile(Vector2i(col, FILA_TRIM), Vector2(x * TILE_SIZE, 0))
		for y in range(1, alto_tiles):
			_crear_tile(Vector2i(col, FILA_RELLENO), Vector2(x * TILE_SIZE, y * TILE_SIZE))

	# ── Puerta, centrada en la base de la fachada ────────────────────────────
	var puerta := Sprite2D.new()
	puerta.name = "Puerta"
	puerta.texture = TEX_PUERTA
	puerta.centered = false
	puerta.position = Vector2(
		(ancho_tiles * TILE_SIZE) / 2.0 - 16,
		(alto_tiles - 1) * TILE_SIZE
	)
	add_child(puerta)

	# ── Colisión: ocupa toda la huella de la casa ────────────────────────────
	var colision := CollisionShape2D.new()
	colision.name = "CollisionShape2D"
	var forma := RectangleShape2D.new()
	forma.size = Vector2(ancho_tiles * TILE_SIZE, alto_tiles * TILE_SIZE)
	colision.shape = forma
	colision.position = forma.size / 2.0
	add_child(colision)

	# ── Luz cálida junto a la puerta ──────────────────────────────────────────
	if con_luz:
		var luz := PointLight2D.new()
		luz.name = "LuzPuerta"
		luz.texture = TEX_LUZ
		luz.color = Color(1.0, 0.82, 0.55)
		luz.energy = 0.85
		luz.texture_scale = 1.4
		luz.position = Vector2(ancho_tiles * TILE_SIZE / 2.0, alto_tiles * TILE_SIZE - 4)
		add_child(luz)


func _crear_tile(celda: Vector2i, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = TEX_WALLS
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(celda.x * TILE_SIZE, celda.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	s.position = pos
	s.modulate = tinte
	add_child(s)
