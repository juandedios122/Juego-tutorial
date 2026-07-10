extends Area2D
## item_pickup.gd  —  Objeto recogible en el mundo.
##
## Cómo armar la escena en el editor (ItemPickup.tscn):
##   Area2D  (este script)
##   ├─ Sprite2D           ← se rellena solo con el ícono del Item asignado
##   └─ CollisionShape2D   ← un CircleShape2D chico (radio ~10-14) alcanza
##
## Uso: arrastra este .tscn al mundo (o instáncialo desde código, p. ej. al
## morir un enemigo) y asígnale un `item` en el Inspector. El sprite tomará
## automáticamente el ícono de ese Item — no hace falta un sprite por ítem.

@export var item     : Item = null
@export var cantidad : int  = 1

## Pequeño efecto de flotación para que se note en el suelo (opcional).
@export var flotar : bool = true

@onready var sprite: Sprite2D = $Sprite2D

var _tiempo: float = 0.0
var _y_base: float = 0.0


func _ready() -> void:
	if item != null and item.icono != null:
		sprite.texture = item.icono
	_y_base = position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not flotar:
		return
	_tiempo += delta
	sprite.position.y = sin(_tiempo * 3.0) * 2.5


func _on_body_entered(body: Node2D) -> void:
	if item == null:
		return
	if not body.has_method("player"):
		return

	var sobrante := Inventory.agregar_item(item, cantidad)
	if sobrante < cantidad:
		# Entró al menos parte del stack: el pickup desaparece.
		if has_node("/root/SFX"):
			SFX.play("pickup")
		queue_free()
	# Si sobrante == cantidad, el inventario estaba lleno y el ítem se
	# queda en el suelo (Inventory ya emitió item_no_cupo para avisar).
