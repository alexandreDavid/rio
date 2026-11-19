class_name PeladaGame
extends MinigameBase

# Pelada de society sur synthétique : 3 joueurs de champ + 1 goleiro par
# équipe, ni touche ni hors-jeu (le ballon rebondit sur l'alambrado). Le
# joueur dirige un joueur de son time ; les autres et les Coletes sont à l'IA.
# Joystick = courir ; PASSE / CHUTE (tenir pour charger) en attaque ;
# TROCAR / CARRINHO en défense. 2:30 ou premier à 3 ; égalité = gol de ouro.

signal match_ended(qualifies: bool, tips: int)

const PeladaPlayer := preload("res://scripts/minigames/pelada/PeladaPlayer.gd")
const PeladaArt := preload("res://scripts/minigames/pelada/PeladaArt.gd")

const FIELD_W: float = 2200.0
const FIELD_H: float = 820.0
const CENTER: Vector2 = Vector2(1100, 410)
const GOAL_HALF: float = 115.0
const GOAL_DEPTH: float = 90.0
const BAR_Z: float = 105.0
const BOX_DEPTH: float = 300.0
const BOX_HALF: float = 200.0

const MATCH_TIME: float = 150.0
const GOLDEN_TIME: float = 45.0
const WIN_GOALS: int = 3

const GRAVITY: float = 1700.0
const ROLL_DECEL: float = 420.0
const DRIBBLE_REACH: float = 30.0
const PICKUP_MAX_SPEED: float = 1150.0
const STEAL_RANGE: float = 44.0
const CHARGE_TIME: float = 0.7

const SPEED_AI: float = 285.0
const SPEED_HUMAN: float = 330.0
const CARRY_FACTOR: float = 0.9

const TEAMS: Dictionary = {
	"flamengo": {"name": "FLAMENGO", "a": Color(0.86, 0.10, 0.12), "b": Color(0.11, 0.09, 0.10)},
	"vasco": {"name": "VASCO", "a": Color(0.96, 0.96, 0.94), "b": Color(0.11, 0.09, 0.10)},
	"fluminense": {"name": "FLUMINENSE", "a": Color(0.55, 0.08, 0.17), "b": Color(0.96, 0.96, 0.94)},
	"botafogo": {"name": "BOTAFOGO", "a": Color(0.11, 0.09, 0.10), "b": Color(0.96, 0.96, 0.94)},
}
const COLETE: Color = Color(0.86, 0.96, 0.22)
const COLETE_SHORTS: Color = Color(0.16, 0.22, 0.42)

enum State { KICKOFF, PLAY, GOAL, ENDED }

## Aperçu (outils de capture) : l'IA joue aussi le joueur du time.
@export var autoplay: bool = false
## Décor derrière le grillage : "aterro" (baie, Pão de Açúcar) ou "morro" (favela).
@export var setting: String = "aterro"

var players: Array = []          # PeladaPlayer
var ball_pos: Vector2 = CENTER
var ball_z: float = 0.0
var ball_vel: Vector2 = Vector2.ZERO
var ball_vz: float = 0.0
var owner_p: Node2D = null
var last_touch_team: int = -1
var controlled: Node2D = null

var _state: int = State.KICKOFF
var _state_t: float = 0.0
var _clock: float = MATCH_TIME
var _golden: bool = false
var _score: Array[int] = [0, 0]
var _kickoff_team: int = 0
var _gk_tested: Array[bool] = [false, false]
var _charging: bool = false
var _charge: float = 0.0
var _ai_think: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _team_id: String = "flamengo"
var _art: Node2D = null
var _cam: Camera2D = null

# Commandes : doigts suivis à la main (joystick + bouton en même temps).
var _fingers: Dictionary = {}
var _btn_a_held: bool = false
var _btn_b_held: bool = false
var _key_a_held: bool = false
var _key_b_held: bool = false
var _a_was: bool = false
var _b_was: bool = false

@onready var score_label: Label = $UI/Score
@onready var clock_label: Label = $UI/Clock
@onready var banner: Label = $UI/Banner
@onready var help_label: Label = $UI/Help
@onready var btn_a: Button = $UI/BtnA
@onready var btn_b: Button = $UI/BtnB


func _ready() -> void:
	EventBus.minigame_started.emit("pelada")
	_rng.randomize()
	_team_id = _read_team()
	_cam = get_node_or_null("Camera2D") as Camera2D
	if _cam:
		_cam.make_current()
		_cam.zoom = Vector2(1.25, 1.25)
		_cam.position = CENTER
	_art = PeladaArt.new()
	add_child(_art)
	_art.call("build", self)
	_spawn_teams()
	for b: Button in [btn_a, btn_b]:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.focus_mode = Control.FOCUS_NONE
			var box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.78))
			b.add_theme_stylebox_override("normal", box)
			b.add_theme_stylebox_override("hover", box)
			b.add_theme_stylebox_override("pressed", UITheme.pastille_box(UITheme.CREAM, Color(0.30, 0.55, 0.25, 0.9)))
			SafeArea.apply(b)
	_start_kickoff(0)
	_update_hud()


func _read_team() -> String:
	for t: String in TEAMS.keys():
		if CampaignManager.has_flag("time_" + t):
			return t
	return "flamengo"


# --- Équipes ---

func _spawn_teams() -> void:
	var team: Dictionary = TEAMS[_team_id]
	var me: Dictionary = CharacterSpriteFactory.config_from_indices(CharacterSpriteFactory.default_indices())
	var shadow: Texture2D = _art.call("shadow_texture")
	for t in 2:
		for r in 4:
			var p: Node2D = PeladaPlayer.new()
			p.team = t
			p.role = r
			var cfg: Dictionary = me.duplicate() if (t == 0 and r == PeladaPlayer.Role.ALA_E) \
					else CharacterSpriteFactory.random_config(1000 + t * 10 + r)
			cfg["hat_style"] = "none"
			cfg["shirt_pattern"] = "solid"
			if r == PeladaPlayer.Role.GK:
				cfg["shirt_color"] = Color(0.35, 0.62, 0.95) if t == 0 else Color(0.58, 0.40, 0.78)
				cfg["pants_color"] = Color(0.13, 0.12, 0.16)
			elif t == 0:
				cfg["shirt_color"] = team["a"]
				cfg["pants_color"] = team["b"]
			else:
				cfg["shirt_color"] = COLETE
				cfg["pants_color"] = COLETE_SHORTS
			p.setup(cfg, shadow)
			p.home = _home(t, r)
			p.position = p.home
			p.speed = SPEED_AI
			p.facing = Vector2(_dir(t), 0)
			_art.call("add_actor", p)
			players.append(p)
			if t == 0 and r == PeladaPlayer.Role.ALA_E:
				controlled = p


func _dir(team: int) -> float:
	return 1.0 if team == 0 else -1.0


func _own_goal_x(team: int) -> float:
	return 0.0 if team == 0 else FIELD_W


func _opp_goal(team: int) -> Vector2:
	return Vector2(FIELD_W if team == 0 else 0.0, CENTER.y)


func _home(team: int, role: int) -> Vector2:
	var fx: float = [0.035, 0.22, 0.40, 0.40][role]
	var fy: float = [0.5, 0.5, 0.26, 0.74][role]
	var x: float = fx * FIELD_W
	if team == 1:
		x = FIELD_W - x
		fy = 1.0 - fy
	return Vector2(x, fy * FIELD_H)


func _gk(team: int) -> Node2D:
	for p in players:
		if p.team == team and p.role == PeladaPlayer.Role.GK:
			return p
	return null


# --- Boucle ---

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_state_t += delta
	_read_buttons()
	for p in players:
		p.tick_timers(delta)
	match _state:
		State.KICKOFF:
			if _state_t > 1.1:
				_state = State.PLAY
				_state_t = 0.0
				sfx("whistle")
				_show_banner("", 0.0)
		State.PLAY:
			_clock -= delta
			if _clock <= 0.0:
				_on_time_up()
			_play_step(delta)
		State.GOAL:
			_ball_physics(delta)
			if _state_t > 2.4:
				if _score[0] >= WIN_GOALS or _score[1] >= WIN_GOALS or _golden:
					_end_game()
				else:
					_start_kickoff(_kickoff_team)
		State.ENDED:
			pass
	for p in players:
		if _state != State.PLAY:
			p.vel = p.vel.move_toward(Vector2.ZERO, 900.0 * delta)
			p.position += p.vel * delta
		p.animate(delta)
	_art.call("sync", self, delta)
	_update_camera(delta)
	_update_hud()


func _play_step(delta: float) -> void:
	_human_control(delta)
	_ai_think -= delta
	var think: bool = _ai_think <= 0.0
	if think:
		_ai_think = 0.12
	for p in players:
		if p == controlled and not autoplay:
			continue
		if p.role == PeladaPlayer.Role.GK:
			_ai_keeper(p, delta)
		elif p == owner_p:
			if think:
				_ai_carrier(p)
		else:
			_ai_off_ball(p)
	_move_players(delta)
	_ball_step(delta)
	_steals()


# --- Commandes du joueur ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_fingers[st.index] = st.position
		else:
			_fingers.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _fingers.has(sd.index):
			_fingers[sd.index] = sd.position
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_fingers[-1] = mb.position
			else:
				_fingers.erase(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _fingers.has(-1):
			_fingers[-1] = (event as InputEventMouseMotion).position
	elif event.is_action("interact") and not event.is_echo():
		_key_a_held = event.is_pressed()
	elif event.is_action("jump") and not event.is_echo():
		_key_b_held = event.is_pressed()
	_btn_a_held = _held(btn_a)
	_btn_b_held = _held(btn_b)


func _held(btn: Button) -> bool:
	if btn == null or not btn.is_visible_in_tree():
		return false
	var rect: Rect2 = btn.get_global_rect()
	var on: bool = false
	for f in _fingers.values():
		if rect.has_point(f as Vector2):
			on = true
	btn.button_pressed = on
	return on


func _read_buttons() -> void:
	var a: bool = _btn_a_held or _key_a_held
	var b: bool = _btn_b_held or _key_b_held
	if _state == State.PLAY and not autoplay:
		if a and not _a_was:
			_on_a()
		if b and not _b_was:
			_on_b_down()
		if not b and _b_was:
			_on_b_up()
	_a_was = a
	_b_was = b


func _stick() -> Vector2:
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return v.limit_length(1.0)


func _human_control(delta: float) -> void:
	if autoplay or controlled == null:
		return
	var p: Node2D = controlled
	if _charging:
		_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
		if owner_p != p:
			_charging = false
	if not p.is_free():
		return
	var s: Vector2 = _stick()
	var sp: float = SPEED_HUMAN * (CARRY_FACTOR if owner_p == p else 1.0)
	p.vel = s * sp
	if s.length() > 0.2:
		p.facing = s.normalized()


# A : PASSE (avec la bola) · PEDE (le goleiro la tient) · TROCAR (défense).
func _on_a() -> void:
	if controlled == null:
		return
	if owner_p == controlled:
		var mate: Node2D = _pick_pass_target(controlled, _stick())
		if mate:
			_pass(controlled, mate)
			controlled = mate
	elif owner_p != null and owner_p.team == 0:
		# Le goleiro relance vers celui qui la demande.
		_pass(owner_p, controlled)
	else:
		_switch_player()


func _on_b_down() -> void:
	if controlled == null or not controlled.is_free():
		return
	if owner_p == controlled:
		_charging = true
		_charge = 0.0
	elif owner_p == null or owner_p.team == 1:
		_start_slide(controlled)


func _on_b_up() -> void:
	if not _charging:
		return
	_charging = false
	if owner_p != controlled:
		return
	var s: Vector2 = _stick()
	var power: float = 0.4 + 0.6 * _charge
	_shoot(controlled, s.y * GOAL_HALF * 0.85, power, 0.03)


func _switch_player() -> void:
	var best: Node2D = null
	var bd: float = INF
	for p in players:
		if p.team != 0 or p.role == PeladaPlayer.Role.GK or p == controlled:
			continue
		var d: float = p.position.distance_to(ball_pos)
		if d < bd:
			bd = d
			best = p
	if best:
		controlled = best
		sfx("ui_click")


func _auto_switch_to_ball() -> void:
	# Le time perd la bola : on reprend le joueur le plus proche.
	var best: Node2D = null
	var bd: float = INF
	for p in players:
		if p.team != 0 or p.role == PeladaPlayer.Role.GK:
			continue
		var d: float = p.position.distance_to(ball_pos)
		if d < bd:
			bd = d
			best = p
	if best:
		controlled = best


# --- Gestes ---

func _pick_pass_target(from: Node2D, stick: Vector2) -> Node2D:
	var dir: Vector2 = stick.normalized() if stick.length() > 0.3 else from.facing
	var best: Node2D = null
	var best_s: float = -INF
	for p in players:
		if p == from or p.team != from.team or p.role == PeladaPlayer.Role.GK:
			continue
		var to: Vector2 = p.position - from.position
		var s: float = dir.dot(to.normalized()) * 2.0 - to.length() / 1400.0 + _openness(p) / 400.0
		if s > best_s:
			best_s = s
			best = p
	return best


# Distance au défenseur le plus proche (plus c'est grand, plus il est libre).
func _openness(p: Node2D) -> float:
	var m: float = 9999.0
	for q in players:
		if q.team != p.team:
			m = minf(m, q.position.distance_to(p.position))
	return minf(m, 400.0)


func _release_ball(from: Node2D) -> void:
	owner_p = null
	from.pickup_cd = 0.3
	from.hold_t = 0.0
	last_touch_team = from.team
	_gk_tested = [false, false]


func _pass(from: Node2D, to: Node2D) -> void:
	var target: Vector2 = to.position + to.vel * 0.3
	var d: Vector2 = target - ball_pos
	var spd: float = clampf(d.length() * 1.5 + 300.0, 550.0, 1050.0)
	_release_ball(from)
	ball_vel = d.normalized() * spd
	ball_vz = 0.0
	ball_z = 0.0
	# Passe longue au-dessus des jambes adverses.
	if d.length() > 650.0:
		ball_vz = 380.0
	for p in players:
		p.pass_target = false
	to.pass_target = true
	sfx("mg_hit", 1.1)


func _shoot(from: Node2D, aim_y: float, power: float, noise: float) -> void:
	var goal: Vector2 = _opp_goal(from.team)
	var target: Vector2 = Vector2(goal.x, goal.y + aim_y)
	var dir: Vector2 = (target - ball_pos).normalized().rotated(_rng.randf_range(-noise, noise))
	_release_ball(from)
	ball_vel = dir * (950.0 + 900.0 * power)
	ball_vz = 90.0 + 260.0 * power
	ball_z = 4.0
	if power > 0.9:
		_show_banner("BOMBA !", 0.7)
		pulse(0.6, 0.08)
	sfx("dj_kick", 0.9 + power * 0.2)
	sfx("mg_hit", 0.8)


func _start_slide(p: Node2D) -> void:
	if p.tackle_cd > 0.0:
		return
	p.slide = 0.36
	p.slide_hit = false
	p.tackle_cd = 0.9
	var dir: Vector2 = p.facing
	if owner_p and owner_p.team != p.team:
		dir = (owner_p.position - p.position).normalized().lerp(dir, 0.4).normalized()
	p.facing = dir
	p.vel = dir * 640.0
	sfx("mg_drop", 0.8)


# --- IA ---

func _ai_carrier(p: Node2D) -> void:
	var goal: Vector2 = _opp_goal(p.team)
	var to_goal: Vector2 = goal - p.position
	var dist: float = to_goal.length()
	var press: Node2D = _nearest_opponent(p)
	var press_d: float = press.position.distance_to(p.position) if press else 9999.0
	# Chute : près du but, ou couloir dégagé à distance raisonnable.
	if dist < 380.0 or (dist < 700.0 and press_d > 150.0 and _rng.randf() < 0.35):
		var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var gk: Node2D = _gk(1 - p.team)
		if gk:
			side = -1.0 if gk.position.y > CENTER.y else 1.0
		_shoot(p, side * _rng.randf_range(40.0, 105.0), _rng.randf_range(0.5, 0.92), 0.07)
		return
	# Passe quand on est pressé et qu'un coéquipier est libre.
	if press_d < 120.0 and _rng.randf() < 0.55:
		var mate: Node2D = null
		var best: float = 160.0
		for q in players:
			if q.team == p.team and q != p and q.role != PeladaPlayer.Role.GK:
				var o: float = _openness(q)
				if o > best:
					best = o
					mate = q
		if mate:
			_pass(p, mate)
			if p.team == 0 and not autoplay:
				controlled = mate
			return
	# Dribble : vers le but, en s'écartant du défenseur.
	var dir: Vector2 = to_goal.normalized()
	if press and press_d < 220.0:
		var away: Vector2 = (p.position - press.position).normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		if perp.dot(away) < 0.0:
			perp = -perp
		dir = (dir + perp * (1.3 - press_d / 220.0)).normalized()
	p.vel = dir * p.speed * CARRY_FACTOR


func _nearest_opponent(p: Node2D) -> Node2D:
	var best: Node2D = null
	var bd: float = INF
	for q in players:
		if q.team != p.team and q.role != PeladaPlayer.Role.GK:
			var d: float = q.position.distance_to(p.position)
			if d < bd:
				bd = d
				best = q
	return best


func _ai_off_ball(p: Node2D) -> void:
	if not p.is_free():
		return
	var target: Vector2 = p.home
	var dir: float = _dir(p.team)
	var predicted: Vector2 = ball_pos + ball_vel * 0.25
	if owner_p == null:
		# Bola solta : le plus proche de chaque time y va.
		if p.pass_target or _is_chaser(p):
			target = predicted
		else:
			target = Vector2(lerpf(p.home.x, ball_pos.x, 0.5), lerpf(p.home.y, ball_pos.y, 0.25))
	elif owner_p.team == p.team:
		# Soutien : les alas devant le porteur, le fixo derrière.
		if p.role == PeladaPlayer.Role.FIXO:
			target = Vector2(owner_p.position.x - dir * 320.0, lerpf(CENTER.y, owner_p.position.y, 0.4))
		else:
			var lane: float = FIELD_H * (0.24 if p.role == PeladaPlayer.Role.ALA_E else 0.76)
			if p.team == 1:
				lane = FIELD_H - lane
			target = Vector2(owner_p.position.x + dir * 260.0, lane)
		target.x = clampf(target.x, 160.0, FIELD_W - 160.0)
	else:
		# Défense : un presse, les autres marquent entre leur homme et le but.
		if _is_chaser(p):
			var goal_dir: Vector2 = (Vector2(_own_goal_x(p.team), CENTER.y) - owner_p.position).normalized()
			target = owner_p.position + goal_dir * 22.0
			# Les Coletes tentent parfois le carrinho.
			if p.team == 1 and p.position.distance_to(owner_p.position) < 120.0 \
					and p.tackle_cd <= 0.0 and _rng.randf() < 0.012:
				_start_slide(p)
				return
		else:
			var mark: Node2D = _mark_for(p)
			if mark:
				var own: Vector2 = Vector2(_own_goal_x(p.team), CENTER.y)
				target = mark.position + (own - mark.position).normalized() * 80.0
	var to: Vector2 = target - p.position
	if to.length() < 12.0:
		p.vel = p.vel.move_toward(Vector2.ZERO, 40.0)
	else:
		p.vel = to.normalized() * p.speed * clampf(to.length() / 60.0, 0.35, 1.0)


func _is_chaser(p: Node2D) -> bool:
	# Côté joueur, ses coéquipiers ne pressent pas à sa place (sauf aperçu).
	if p.team == 0 and not autoplay and owner_p != null:
		return false
	var target: Vector2 = owner_p.position if owner_p else ball_pos
	var best: Node2D = null
	var bd: float = INF
	for q in players:
		if q.team != p.team or q.role == PeladaPlayer.Role.GK:
			continue
		var d: float = q.position.distance_to(target)
		if d < bd:
			bd = d
			best = q
	if p.team == 0 and not autoplay and best == controlled:
		return false
	return best == p


func _mark_for(p: Node2D) -> Node2D:
	# Chaque défenseur prend l'attaquant (hors porteur) le plus proche de son poste.
	var best: Node2D = null
	var bd: float = INF
	for q in players:
		if q.team == p.team or q == owner_p or q.role == PeladaPlayer.Role.GK:
			continue
		var d: float = q.position.distance_to(p.home) * 0.5 + q.position.distance_to(p.position)
		if d < bd:
			bd = d
			best = q
	return best


func _ai_keeper(p: Node2D, delta: float) -> void:
	var gx: float = _own_goal_x(p.team)
	var dir: float = _dir(p.team)
	if owner_p == p:
		p.vel = Vector2.ZERO
		p.hold_t += delta
		var wait: float = 0.9 if p.team == 1 or autoplay else 1.6
		if p.hold_t > wait:
			var mate: Node2D = null
			var best: float = -1.0
			for q in players:
				if q.team == p.team and q != p:
					var o: float = _openness(q)
					if o > best:
						best = o
						mate = q
			if mate:
				_pass(p, mate)
				if p.team == 0 and not autoplay:
					controlled = mate
		return
	if not p.is_free():
		p.vel = Vector2.ZERO
		return
	# Se place sur la bissectrice ballon-but, sort un peu quand le ballon approche.
	var ball_d: float = absf(ball_pos.x - gx)
	var out: float = clampf(140.0 - ball_d * 0.12, 26.0, 110.0)
	var ty: float = clampf(lerpf(CENTER.y, ball_pos.y, 0.6), CENTER.y - GOAL_HALF + 16.0, CENTER.y + GOAL_HALF - 16.0)
	var target: Vector2 = Vector2(gx + dir * out, ty)
	# Bola solta dans sa surface : il sort la chercher.
	if owner_p == null and ball_d < BOX_DEPTH - 40.0 and absf(ball_pos.y - CENTER.y) < BOX_HALF \
			and ball_vel.length() < 500.0:
		target = ball_pos
	var to: Vector2 = target - p.position
	p.vel = to.normalized() * 300.0 * clampf(to.length() / 40.0, 0.0, 1.0)


# --- Déplacements ---

func _move_players(delta: float) -> void:
	for p in players:
		if p.slide > 0.0:
			p.slide -= delta
			p.vel = p.vel.move_toward(Vector2.ZERO, 900.0 * delta)
			if owner_p and owner_p.team != p.team and not p.slide_hit \
					and owner_p.role != PeladaPlayer.Role.GK \
					and p.position.distance_to(owner_p.position) < 58.0:
				# Carrinho dans le ballon : il part dans l'axe du tacle.
				p.slide_hit = true
				var victim: Node2D = owner_p
				_release_ball(victim)
				victim.stun = 0.6
				last_touch_team = p.team
				ball_vel = p.facing * 380.0
				ball_vz = 120.0
				p.pickup_cd = 0.0
				sfx("mg_drop", 1.2)
				pulse(0.5, 0.06)
			if p.slide <= 0.0 and not p.slide_hit:
				p.stun = 0.45
		elif not p.is_free():
			p.vel = Vector2.ZERO
		p.position += p.vel * delta
		if p.role == PeladaPlayer.Role.GK:
			var gx: float = _own_goal_x(p.team)
			p.position.x = clampf(p.position.x, minf(gx, gx + _dir(p.team) * BOX_DEPTH), maxf(gx, gx + _dir(p.team) * BOX_DEPTH))
			p.position.y = clampf(p.position.y, CENTER.y - BOX_HALF, CENTER.y + BOX_HALF)
		p.position.x = clampf(p.position.x, 18.0, FIELD_W - 18.0)
		p.position.y = clampf(p.position.y, 20.0, FIELD_H - 8.0)
	# Les corps ne se traversent pas.
	for i in players.size():
		for j in range(i + 1, players.size()):
			var a: Node2D = players[i]
			var b: Node2D = players[j]
			var d: Vector2 = b.position - a.position
			var l: float = d.length()
			if l < 34.0 and l > 0.01:
				var push: Vector2 = d / l * (34.0 - l) * 0.5
				a.position -= push
				b.position += push


# --- Ballon ---

func _ball_step(delta: float) -> void:
	if owner_p:
		var o: Node2D = owner_p
		if o.role == PeladaPlayer.Role.GK:
			ball_pos = o.position + Vector2(_dir(o.team) * 10.0, -4.0)
			ball_z = 46.0
		else:
			# Conduite : le ballon roule devant le pied, un peu plus loin en course.
			var reach: float = 22.0 + o.vel.length() * 0.025
			ball_pos = o.position + o.facing * reach + Vector2(0, 4)
			ball_z = 0.0
		ball_vel = o.vel
		ball_vz = 0.0
		return
	_ball_physics(delta)
	_keeper_saves()
	if _state != State.PLAY:
		return
	_check_goal()
	_pickups()


func _ball_physics(delta: float) -> void:
	if owner_p:
		return
	if ball_z > 0.0 or ball_vz > 0.0:
		ball_vz -= GRAVITY * delta
		ball_z += ball_vz * delta
		if ball_z <= 0.0:
			ball_z = 0.0
			if ball_vz < -140.0:
				ball_vz = -ball_vz * 0.45
				ball_vel *= 0.88
			else:
				ball_vz = 0.0
	else:
		var sp: float = ball_vel.length()
		if sp > 0.0:
			ball_vel = ball_vel.normalized() * maxf(sp - ROLL_DECEL * delta, 0.0)
	var prev: Vector2 = ball_pos
	ball_pos += ball_vel * delta
	# Filet : une fois dedans, le ballon y reste.
	if _state == State.GOAL:
		var in_left: bool = ball_pos.x < 0.0
		ball_pos.x = clampf(ball_pos.x, -GOAL_DEPTH + 8.0, FIELD_W + GOAL_DEPTH - 8.0)
		if (in_left and ball_pos.x <= -GOAL_DEPTH + 8.0) or (not in_left and ball_pos.x >= FIELD_W + GOAL_DEPTH - 8.0):
			ball_vel *= 0.2
		ball_pos.y = clampf(ball_pos.y, CENTER.y - GOAL_HALF + 8.0, CENTER.y + GOAL_HALF - 8.0)
		return
	var in_mouth: bool = absf(ball_pos.y - CENTER.y) < GOAL_HALF - 8.0 and ball_z < BAR_Z
	# Alambrado : rebond sur les bords (pas de touche ni de corner).
	if (ball_pos.x < 8.0 and not in_mouth) or (ball_pos.x > FIELD_W - 8.0 and not in_mouth):
		if prev.x >= 8.0 and prev.x <= FIELD_W - 8.0:
			ball_pos.x = clampf(ball_pos.x, 8.0, FIELD_W - 8.0)
			ball_vel.x = -ball_vel.x * 0.6
			_wall_thud()
		elif absf(ball_pos.y - CENTER.y) >= GOAL_HALF - 8.0:
			# Rentré par le côté du but : on le ressort.
			ball_pos.x = clampf(ball_pos.x, 8.0, FIELD_W - 8.0)
			ball_vel.x = -ball_vel.x * 0.6
	if ball_pos.y < 10.0 or ball_pos.y > FIELD_H - 6.0:
		ball_pos.y = clampf(ball_pos.y, 10.0, FIELD_H - 6.0)
		ball_vel.y = -ball_vel.y * 0.6
		_wall_thud()


func _wall_thud() -> void:
	if ball_vel.length() > 300.0:
		sfx("mg_drop", 0.7)
		_art.call("shake_fence", ball_pos)


func _keeper_saves() -> void:
	for t in 2:
		if _gk_tested[t]:
			continue
		var gk: Node2D = _gk(t)
		if gk == null or not gk.is_free() and gk.dive <= 0.0:
			continue
		var toward: bool = ball_vel.x * _dir(t) < -50.0
		if not toward:
			continue
		var line_x: float = gk.position.x
		var crossed: bool = (ball_pos.x - line_x) * _dir(t) <= 6.0
		if not crossed:
			continue
		_gk_tested[t] = true
		if ball_z > BAR_Z + 30.0:
			continue
		var dy: float = absf(ball_pos.y - gk.position.y)
		var spd: float = ball_vel.length()
		if dy < 44.0 and spd < 1450.0:
			# Encaixou : il bloque.
			_take_ball(gk)
			gk.hold_t = 0.0
			sfx("mg_good")
			_show_banner("DEFESA !", 0.8)
		elif dy < 104.0:
			gk.dive = 0.5
			gk.dive_dir = signf(ball_pos.y - gk.position.y)
			var chance: float = clampf(0.82 - (spd - 900.0) / 1500.0 - (dy - 44.0) / 160.0, 0.12, 0.85)
			if _rng.randf() < chance:
				# Parada : rebond vers le terrain.
				ball_vel = Vector2(-ball_vel.x * 0.32, _rng.randf_range(-320.0, 320.0))
				ball_vz = 220.0
				last_touch_team = t
				sfx("mg_good")
				_show_banner("QUE DEFESA !", 0.9)


func _check_goal() -> void:
	if absf(ball_pos.y - CENTER.y) >= GOAL_HALF - 6.0 or ball_z >= BAR_Z:
		return
	if ball_pos.x < -6.0:
		_goal(1)
	elif ball_pos.x > FIELD_W + 6.0:
		_goal(0)


func _pickups() -> void:
	if ball_z > 46.0:
		return
	var spd: float = ball_vel.length()
	var best: Node2D = null
	var bd: float = DRIBBLE_REACH
	for p in players:
		if p.pickup_cd > 0.0 or not p.is_free() and p.slide <= 0.0:
			continue
		var d: float = p.position.distance_to(ball_pos)
		if d >= bd:
			continue
		# Une frappe trop forte passe ou est contrée.
		if spd > PICKUP_MAX_SPEED and p.role != PeladaPlayer.Role.GK:
			if p.team != last_touch_team and _rng.randf() < 0.5:
				ball_vel = ball_vel.rotated(_rng.randf_range(-2.4, 2.4)) * 0.35
				ball_vz = 160.0
				last_touch_team = p.team
				sfx("mg_hit", 0.7)
			p.pickup_cd = 0.25
			continue
		bd = d
		best = p
	if best:
		_take_ball(best)


func _take_ball(p: Node2D) -> void:
	var had: Node2D = owner_p
	owner_p = p
	last_touch_team = p.team
	ball_z = 0.0
	ball_vz = 0.0
	for q in players:
		q.pass_target = false
	if p.slide > 0.0:
		p.slide = 0.0
		p.slide_hit = true
		p.vel = Vector2.ZERO
	if p.team == 0 and not autoplay and p.role != PeladaPlayer.Role.GK:
		controlled = p
	if had == null or had.team != p.team:
		sfx("mg_hit", 1.25)


func _steals() -> void:
	if owner_p == null or owner_p.role == PeladaPlayer.Role.GK:
		return
	for p in players:
		if p.team == owner_p.team or p.role == PeladaPlayer.Role.GK or not p.is_free() or p.tackle_cd > 0.0:
			continue
		if p.position.distance_to(owner_p.position) > STEAL_RANGE:
			continue
		p.tackle_cd = 0.75
		var human_carrier: bool = owner_p == controlled and not autoplay
		var chance: float = 0.2 if human_carrier else 0.32
		if p == controlled and not autoplay:
			chance = 0.3
		if _rng.randf() < chance:
			var victim: Node2D = owner_p
			victim.stun = 0.4
			victim.pickup_cd = 0.6
			_take_ball(p)
			if victim.team == 0 and not autoplay:
				_auto_switch_to_ball()
			return


# --- Déroulé du match ---

func _start_kickoff(team: int) -> void:
	_state = State.KICKOFF
	_state_t = 0.0
	_charging = false
	owner_p = null
	ball_pos = CENTER
	ball_vel = Vector2.ZERO
	ball_z = 0.0
	ball_vz = 0.0
	for p in players:
		p.position = p.home
		p.vel = Vector2.ZERO
		p.stun = 0.0
		p.slide = 0.0
		p.dive = 0.0
		p.facing = Vector2(_dir(p.team), 0)
		p.pass_target = false
	# Le time qui engage pose son ala gauche au rond central.
	for p in players:
		if p.team == team and p.role == PeladaPlayer.Role.ALA_E:
			p.position = CENTER - Vector2(_dir(team) * 26.0, 0)
			_take_ball(p)
	if team == 1 and not autoplay:
		for p in players:
			if p.team == 0 and p.role == PeladaPlayer.Role.ALA_E:
				controlled = p
	_show_banner("GOL DE OURO !" if _golden else "BOLA ROLANDO", 1.1)


func _goal(team: int) -> void:
	_score[team] += 1
	_state = State.GOAL
	_state_t = 0.0
	_kickoff_team = 1 - team
	_charging = false
	sfx("torcida_cheer")
	sfx("mg_perfect" if team == 0 else "mg_miss")
	pulse(0.7, 0.12)
	_show_banner("GOOOOL !" if team == 0 else "Gol dos Coletes…", 2.2)
	_art.call("goal_net", ball_pos.x < CENTER.x)
	for p in players:
		if p.team == team:
			p.cheer = 2.0


func _on_time_up() -> void:
	_clock = 0.0
	if _score[0] == _score[1] and not _golden:
		_golden = true
		_clock = GOLDEN_TIME
		sfx("whistle")
		_show_banner("EMPATE — GOL DE OURO !", 1.6)
		return
	_end_game()


func _end_game() -> void:
	if _state == State.ENDED:
		return
	_state = State.ENDED
	_charging = false
	sfx("whistle")
	var won: bool = _score[0] > _score[1]
	var qualifies: bool = final_qualifies(won)
	var msg: String = "VITÓRIA ! %d × %d" % [_score[0], _score[1]]
	if forfeited:
		msg = "Saiu da pelada"
	elif _score[0] == _score[1]:
		msg = "Empate %d × %d" % [_score[0], _score[1]]
	elif not won:
		msg = "Derrota %d × %d — revanche ?" % [_score[0], _score[1]]
	_show_banner(msg, 99.0)
	if qualifies:
		sfx("minigame_win")
	await get_tree().create_timer(bilan_delay(2.8)).timeout
	EventBus.minigame_ended.emit("pelada", {"score": _score[0], "against": _score[1], "qualifies": qualifies})
	match_ended.emit(qualifies, 0)


# --- Caméra et HUD ---

func _update_camera(delta: float) -> void:
	if _cam == null:
		return
	# Caméra rapprochée (joueurs lisibles au téléphone) qui suit le ballon.
	var vis: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = vis * 0.5 / maxf(_cam.zoom.x, 0.01)
	var tx: float = clampf(ball_pos.x, -110.0 + half.x, FIELD_W + 110.0 - half.x)
	if -110.0 + half.x > FIELD_W + 110.0 - half.x:
		tx = CENTER.x
	var ty: float = clampf(ball_pos.y - 40.0, -230.0 + half.y, FIELD_H + 90.0 - half.y)
	var k: float = clampf(delta * 4.0, 0.0, 1.0)
	_cam.position = _cam.position.lerp(Vector2(tx, ty), k)


var _banner_t: float = 0.0

func _show_banner(text: String, dur: float) -> void:
	if banner == null:
		return
	banner.text = text
	banner.visible = text != ""
	_banner_t = dur


func _update_hud() -> void:
	if score_label:
		score_label.text = "%s  %d × %d  COLETES" % [TEAMS[_team_id]["name"], _score[0], _score[1]]
	if clock_label:
		var c: int = int(ceilf(maxf(_clock, 0.0)))
		clock_label.text = ("OURO " if _golden else "") + "%d:%02d" % [c / 60, c % 60]
	if banner and _banner_t < 90.0:
		_banner_t -= get_process_delta_time()
		if _banner_t <= 0.0:
			banner.visible = false
	var attack: bool = owner_p != null and owner_p.team == 0
	if btn_a:
		btn_a.text = "PASSE" if owner_p == controlled and controlled != null else ("PEDE" if attack else "TROCAR")
	if btn_b:
		btn_b.text = "CHUTE" if owner_p == controlled and controlled != null else ("CHUTE" if attack else "CARRINHO")
	if help_label:
		help_label.visible = _clock > MATCH_TIME - 9.0 and _score[0] + _score[1] == 0 and not _golden


func charge_value() -> float:
	return _charge if _charging else 0.0
