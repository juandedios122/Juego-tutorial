extends Node2D
## puente_zona.gd
## ══════════════════════════════════════════════════════════════════════════
## Puente que conecta el pueblo con una futura región del juego. Por ahora
## el paso está cerrado con una verja: el jugador puede caminar sobre el
## puente y ver el cartel, pero no puede cruzar hasta que esa región se
## implemente en una futura actualización.
##
## Para "abrir" el puente el día de mañana: borra/desactiva el nodo
## "VerjaCierre" (o su CollisionShape2D) y cambia change_scene_to_file() al
## mapa de la nueva región.
## ══════════════════════════════════════════════════════════════════════════

@export var nombre_zona   : String = "Zona desconocida"
@export var radio_deteccion : float = 50.0

@onready var _zona          : Area2D           = $ZonaDeteccion
@onready var _forma_zona    : CollisionShape2D = $ZonaDeteccion/CollisionShape2D
@onready var _cartel        : Label             = $Cartel

var _jugador_cerca: bool = false


func _ready() -> void:
	if _forma_zona.shape is CircleShape2D:
		_forma_zona.shape.radius = radio_deteccion

	_cartel.text = "🔒 %s\n(Próximamente)" % nombre_zona
	_cartel.modulate.a = 0.0

	_zona.body_entered.connect(_on_zona_body_entered)
	_zona.body_exited.connect(_on_zona_body_exited)


func _on_zona_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		_jugador_cerca = true
		_mostrar_cartel(true)


func _on_zona_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		_jugador_cerca = false
		_mostrar_cartel(false)


func _mostrar_cartel(visible_ahora: bool) -> void:
	var tw := _cartel.create_tween()
	tw.tween_property(_cartel, "modulate:a", 1.0 if visible_ahora else 0.0, 0.25)
