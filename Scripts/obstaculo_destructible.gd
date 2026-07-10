extends StaticBody2D
## obstaculo_destructible.gd
## ══════════════════════════════════════════════════════════════════════════
## Árbol / arbusto que bloquea el camino (StaticBody2D con colisión, igual
## que las paredes) y que sólo puede destruirse golpeándolo con un ítem
## marcado como `es_hacha = true` (ver Item.gd). Cualquier otro golpe
## (espada, puños, etc.) rebota: el obstáculo se sacude pero no pierde vida.
##
## Usa exactamente la misma firma que slime.gd/mushroom.gd — `recibir_golpe`
## — así que jugador.gd no necesita ningún cambio: HitboxArma ya llama a
## este método en cualquier body que lo tenga (ver jugador.gd →
## _on_hitbox_arma_body_entered).
##
## Para crear un obstáculo nuevo: duplica una de las escenas ya armadas
## (ArbolGrande.tscn / ArbustoAlto.tscn / ArbustoChico.tscn), o instancia
## esta escena base y ajusta `Sprite2D.texture` + `CollisionShape2D.shape`
## al tamaño real de tu imagen.
## ══════════════════════════════════════════════════════════════════════════

## Golpes necesarios ≈ vida_maxima / daño_del_arma (con la espada por
## defecto, 20 de daño → 2 golpes para vida_maxima=40).
@export var vida_maxima: int = 40

## Si true (default), sólo un Item con `es_hacha = true` hace daño real.
## Ponlo en false si algún día quieres un obstáculo que cualquier arma
## pueda romper (por ejemplo un cofre de madera).
@export var requiere_hacha: bool = true

## Nombre del sonido (ya definido en SFX.gd) que suena cuando golpeas el
## obstáculo SIN el hacha equipada — feedback de "esto no funciona".
@export var sfx_bloqueado: String = "ui_click"

var _salud: int
var _destruido: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _colision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_salud = vida_maxima


## Llamado por HitboxArma (ver jugador.gd) cada vez que un swing conecta.
func recibir_golpe(cantidad: int) -> void:
	if _destruido:
		return

	if requiere_hacha and not _tiene_hacha_equipada():
		if has_node("/root/SFX"):
			SFX.play(sfx_bloqueado)
		_sacudir()
		return

	_salud -= cantidad
	_flash_golpe()
	if has_node("/root/SFX"):
		SFX.play("hit")
	if has_node("/root/VFX"):
		VFX.golpe(global_position)

	if _salud <= 0:
		_destruir()


func _tiene_hacha_equipada() -> bool:
	if not has_node("/root/Inventory"):
		return false
	var contenido = Inventory.obtener_item_activo()
	return contenido != null and contenido["item"].es_hacha == true


## Parpadeo blanco breve al recibir daño real (mismo lenguaje visual que
## _flash_damage() en jugador.gd, para que se sienta consistente).
func _flash_golpe() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.6, 1.6, 1.6), 0.05)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


## Sacudida lateral cuando golpeas SIN el hacha correcta: dice "no sirvió"
## sin necesidad de texto en pantalla.
func _sacudir() -> void:
	var pos_original := _sprite.position
	var tween := create_tween()
	tween.tween_property(_sprite, "position", pos_original + Vector2(3, 0), 0.04)
	tween.tween_property(_sprite, "position", pos_original - Vector2(3, 0), 0.08)
	tween.tween_property(_sprite, "position", pos_original, 0.04)


func _destruir() -> void:
	_destruido = true
	# Deja de bloquear el camino inmediatamente, aunque la animación de
	# desvanecido todavía esté corriendo.
	_colision.set_deferred("disabled", true)

	if has_node("/root/SFX"):
		SFX.play("enemy_death")
	if has_node("/root/VFX"):
		VFX.muerte(global_position)

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(_sprite, "scale", _sprite.scale * 0.6, 0.4)
	tween.tween_callback(queue_free)
