class_name Item
extends Resource
## Item.gd  —  Recurso (Resource) que define un ítem de inventario.
##
## Para crear un ítem nuevo: click derecho en el FileSystem → New Resource →
## "Item" → guárdalo como .tres (ej. "res://Items/pocion_vida.tres") y rellena
## los campos en el Inspector, incluyendo el campo `icono` con tu imagen.
##
## Todos los ítems del juego deben vivir en una carpeta, por ejemplo
## "res://Items/", para que sea fácil encontrarlos y asignarlos en
## ItemPickup.tscn, en recompensas de enemigos, en el spawner, etc.

## Identificador único y estable del ítem (usado para guardar partidas,
## comparar ítems y buscarlos por código). Ej: "pocion_vida", "espada_hierro".
## IMPORTANTE: una vez que uses un id en una partida guardada, no lo cambies.
@export var id: String = ""

@export var nombre: String = "Ítem sin nombre"

@export_multiline var descripcion: String = ""

## Acá es donde asignas tu imagen — se usa tanto en el slot del inventario
## como (si usas ItemPickup.tscn) en el sprite del objeto tirado en el mundo.
@export var icono: Texture2D = null

enum Tipo { CONSUMIBLE, ARMA, MATERIAL, LLAVE, MISC }
@export var tipo: Tipo = Tipo.MISC

## Cuántas unidades del mismo ítem pueden apilarse en un solo slot.
## Pon 1 para ítems únicos (armas, llaves) y más para consumibles/materiales.
@export_range(1, 999) var stack_max: int = 1

## Solo se usa si `tipo == ARMA`: al equipar este ítem en la hotbar, su
## ícono reemplaza el sprite del arma en la mano del jugador (ver
## jugador.gd → _actualizar_arma_equipada()). Este multiplicador ajusta el
## tamaño de ESE ícono en la mano sin tocar código — súbelo o bájalo si tu
## imagen se ve muy grande o muy chica comparada con la espada por defecto.
@export var escala_en_mano: Vector2 = Vector2.ONE

## Corrección de orientación SOLO para armas cuyo dibujo no apunta en la
## misma dirección base que la espada original del juego (por eso se veía
## "al revés" o giraba raro al atacar). No cambia la coreografía del golpe,
## solo corrige cómo se ve TU imagen dentro de ese golpe:
##   - espejo_en_mano: activa esto si tu arma queda mostrando el lado
##     equivocado (como una imagen en espejo de como debería verse).
##   - rotacion_en_mano: grados que se SUMAN a cada rotación del swing, por
##     si tu arma está dibujada apuntando hacia otro lado "de base" (ej. si
##     tu espada apunta hacia arriba en la imagen en vez de en diagonal).
##   - offset_en_mano: ajuste fino de posición si no queda centrada en la
##     mano.
@export var espejo_en_mano: bool = false
@export var rotacion_en_mano: float = 0.0
@export var offset_en_mano: Vector2 = Vector2.ZERO

## Marca esta arma como "hacha" para efectos de gameplay: los obstáculos
## destructibles (ver obstaculo_destructible.gd) sólo reciben daño real de
## un ítem con este flag activo — cualquier otra arma rebota sin efecto.
## Solo tiene sentido si `tipo == ARMA`.
@export var es_hacha: bool = false

## Si es true, aparece el botón "Usar" en el panel de acciones y se
## descuenta 1 unidad al usarlo, aplicando `efecto` sobre el jugador.
@export var consumible: bool = false

enum Efecto { NINGUNO, CURAR_VIDA, DAR_XP, DAR_PUNTOS, DAR_CORAZONES_TEMP }
@export var efecto: Efecto = Efecto.NINGUNO
@export var efecto_valor: int = 0

## Valor de referencia por si en el futuro agregas compra/venta.
@export var valor: int = 0

## Aplica el efecto de este ítem sobre un jugador. Devuelve true si el
## efecto se aplicó correctamente (y por lo tanto el ítem debe consumirse).
func aplicar_efecto(jugador: Node) -> bool:
	match efecto:
		Efecto.CURAR_VIDA:
			if not jugador.has_method("receive_damage"):
				return false
			if not ("health" in jugador) or not ("max_health" in jugador):
				return false
			jugador.health = min(jugador.health + efecto_valor, jugador.max_health)
			if jugador.has_method("update_hearts"):
				jugador.update_hearts()
			return true
		Efecto.DAR_XP:
			Global.ganar_xp(efecto_valor)
			return true
		Efecto.DAR_PUNTOS:
			Global.sumar_puntos(efecto_valor)
			return true
		Efecto.DAR_CORAZONES_TEMP:
			# Corazones naranjas: vida EXTRA temporal, separada de la vida
			# normal. Ver jugador.gd → agregar_corazones_temporales().
			if not jugador.has_method("agregar_corazones_temporales"):
				return false
			jugador.agregar_corazones_temporales(efecto_valor)
			return true
		_:
			return false
