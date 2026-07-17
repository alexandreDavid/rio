class_name AltinhaBall
extends Node2D

# Balle d'altinha : trajectoire parabolique simulée (hauteur = v0*t - 0.5*g*t²),
# pas de RigidBody — un seul vecteur `kick_velocity` fixe à la fois l'arc et sa
# durée (v0 haut = arc haut et lent = passe "mole" ; v0 bas = tir tendu et
# rapide). Le nœud lui-même reste toujours à (0,0) : from/to/ground/world sont
# exprimés dans l'espace local du parent (AltinhaGame), pas via les transforms.

const GRAVITY: float = 340.0
const RADIUS: float = 7.0

var show_marker: bool = true
var marker_color: Color = Color(1.0, 1.0, 1.0, 0.55)

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _total: float = 1.0
var _v0: float = 220.0
var _height: float = 0.0
var _grounded: bool = true

# Lance un nouveau vol depuis `from` vers `to`. `kick_velocity` détermine à la
# fois la hauteur de l'arc et sa durée (physiquement lié : un tir plus haut
# reste plus longtemps en l'air).
func launch(from: Vector2, to: Vector2, kick_velocity: float) -> void:
	_from = from
	_to = to
	_v0 = maxf(kick_velocity, 40.0)
	_total = 2.0 * _v0 / GRAVITY
	_elapsed = 0.0
	_height = 0.0
	_grounded = false
	queue_redraw()

# Avance la simulation d'un pas. Renvoie true si la balle vient de toucher
# sa cible CE frame (fin de vol naturelle, sans intervention du joueur).
func advance(delta: float) -> bool:
	if _grounded:
		return false
	_elapsed += delta
	_height = _v0 * _elapsed - 0.5 * GRAVITY * _elapsed * _elapsed
	queue_redraw()
	if _height <= 0.0 and _elapsed > 0.03:
		_height = 0.0
		_grounded = true
		return true
	return false

# Position au sol (projection), interpolée du départ vers la cible.
func ground_pos() -> Vector2:
	var t: float = clampf(_elapsed / _total, 0.0, 1.0) if _total > 0.0 else 1.0
	return _from.lerp(_to, t)

# Position visible de la balle (sol moins la hauteur simulée).
func world_pos() -> Vector2:
	return ground_pos() - Vector2(0.0, _height)

func height() -> float:
	return _height

func is_grounded() -> bool:
	return _grounded

func target() -> Vector2:
	return _to

func _draw() -> void:
	if _grounded:
		return
	# Cercle de chute : annoncé dès le lancer, fixe à la cible — c'est là qu'il
	# faut se placer avant que la balle n'y arrive.
	if show_marker:
		draw_arc(_to, 16.0, 0.0, TAU, 24, marker_color, 2.0)
	var ground: Vector2 = ground_pos()
	var shadow_scale: float = clampf(1.0 - _height / 200.0, 0.3, 1.0)
	_draw_ellipse(ground, Vector2(8.0, 3.4) * shadow_scale, Color(0.0, 0.0, 0.0, 0.32 * shadow_scale))
	var p: Vector2 = world_pos()
	draw_circle(p, RADIUS, Color(0.96, 0.95, 0.9, 1.0))
	draw_arc(p, RADIUS, 0.0, TAU, 18, Color(0.15, 0.15, 0.15, 1.0), 1.3)
	draw_circle(p + Vector2(1.4, -1.0), 1.8, Color(0.2, 0.2, 0.2, 1.0))

# Godot n'a pas de draw_ellipse : approximation par polygone (cf. AltinhaSession).
func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
