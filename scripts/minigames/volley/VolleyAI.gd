class_name VolleyAI
extends VolleyPlayer

# Rival : se place sous le point de chute prédit, un peu décalé vers le fond
# pour que la balle reparte vers le joueur, et saute (parfois) quand elle
# arrive. Battable : réflexes, vitesse et précision montent avec les points.

const HOME_X: float = 240.0
# Décalage blob/balle au service : à droite de la balle (elle part vers le
# filet) et assez près pour que la tête la touche (rayons 19 + 12).
const SERVE_OFFSET_MIN: float = 4.0
const SERVE_OFFSET_MAX: float = 18.0

# Géométrie du terrain, posée par VolleyMatch (évite une dépendance croisée).
var court_half: float = 440.0
var net_half_w: float = 4.0
var net_top: float = -110.0

var _speed_factor: float = 0.6
var _reaction: float = 0.34
var _aim_error: float = 16.0
var _jump_chance: float = 0.2
var _blunder_chance: float = 0.28
var _think_timer: float = 0.0
var _target_x: float = HOME_X
var _plan_offset: float = 16.0
var _plan_jump: bool = false
var _serve_wait: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	char_config = CharacterSpriteFactory.random_config(randi())
	super._ready()
	_rng.randomize()
	set_difficulty(0)
	replan()

func set_difficulty(points_played: int) -> void:
	var t: float = clampf(float(points_played) / 8.0, 0.0, 1.0)
	# Battable d'entrée : lent à réagir, souvent mal placé ; il se reprend un
	# peu au fil des points sans jamais tout renvoyer.
	_speed_factor = lerpf(0.6, 0.82, t)
	_reaction = lerpf(0.34, 0.18, t)
	_aim_error = lerpf(16.0, 8.0, t)
	_jump_chance = lerpf(0.2, 0.45, t)
	_blunder_chance = lerpf(0.28, 0.12, t)

# Nouvelle trajectoire (service, touche, balle qui change de camp) : nouveau
# choix de frappe. Décalage > 0 = blob à droite de la balle → renvoi à gauche.
func replan() -> void:
	# Décalages à l'échelle de la tête (rayon 19).
	_plan_offset = _rng.randf_range(6.0, 15.0) + _rng.randf_range(-_aim_error, _aim_error)
	if _rng.randf() < _blunder_chance:
		_plan_offset += _rng.randf_range(-24.0, 24.0)
	_plan_jump = _rng.randf() < _jump_chance
	_serve_wait = 0.0
	_think_timer = 0.0

func think(delta: float, ball: VolleyBall, serving: bool) -> void:
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = _reaction
		_target_x = _choose_target(ball, serving)
	var dx: float = _target_x - position.x
	input_axis = clampf(dx / 10.0, -1.0, 1.0) * _speed_factor
	input_jump = _want_jump(delta, ball, serving)

func _choose_target(ball: VolleyBall, serving: bool) -> float:
	if serving:
		# Au service, pas de bourde de placement : au-delà de ~30 px la tête
		# ne touche plus la balle et il sautait à côté sans fin (match bloqué).
		return clampf(ball.position.x + clampf(_plan_offset, SERVE_OFFSET_MIN, SERVE_OFFSET_MAX), min_x, max_x)
	if ball.frozen:
		return HOME_X
	# Hauteur où la balle touche le haut d'un blob debout.
	var contact_y: float = -(HEAD_Y + RADIUS) - VolleyBall.RADIUS * 0.5
	var px: float = ball.predict_x_at(contact_y, court_half, net_half_w, net_top)
	if px < 0.0:
		return HOME_X
	return clampf(px + _plan_offset, min_x, max_x)

func _want_jump(delta: float, ball: VolleyBall, serving: bool) -> bool:
	if not on_ground:
		# Garder l'appui en montée = saut complet.
		return vel.y < 0.0
	if serving and _serve_wait > 0.5:
		# Retombé sans toucher : on se recale avant de ressauter.
		_serve_wait = 0.0
		_plan_offset *= 0.5
		_think_timer = 0.0
		return false
	if serving:
		if absf(_target_x - position.x) < 6.0:
			_serve_wait += delta
		else:
			_serve_wait = 0.0
		return _serve_wait > 0.5
	if not _plan_jump or ball.frozen or ball.position.x < 0.0 or ball.vel.y <= 0.0:
		return false
	var dx: float = absf(ball.position.x - position.x)
	var above: float = -(HEAD_Y + RADIUS) - ball.position.y
	return dx < 40.0 and above > 40.0 and above < 150.0
