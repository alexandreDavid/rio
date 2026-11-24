extends MinigameBase

# Racha do Porto : course de rue en fausse 3D (même projection que la Lagoa),
# de bout en bout — Porto Maravilha → Túnel Marcello Alencar → Aterro (MAM) →
# Enseada de Botafogo (Pão de Açúcar) → Túnel do Pasmado → Rio Sul → Túnel
# Novo → Av. Princesa Isabel, Copacabana. Cinq rivaux, du trafic à doubler
# (táxis, ônibus, kombis), trois charges de nitro. Pódio (top 3) = qualifié.

signal match_ended(qualifies: bool, tips: int)

const Art := preload("res://scripts/minigames/racha_porto/RachaPortoArt.gd")

# Projection
const SEG_LEN: float = 200.0
const ROAD_W: float = 1800.0          # demi-largeur de la chaussée (3 voies)
const CAM_H: float = 1000.0
const FOCAL: float = 806.0
const HORIZON_Y: float = 430.0
const CX: float = 960.0
const PLAYER_Z: float = 1400.0
const DRAW_DIST: int = 140
const NEAR_Z: float = 160.0
const PIX: float = 4.0
const RUMBLE_W: float = 1.08
const WALL_X: float = 1.22            # murs du tunnel, en demi-largeurs
const TUN_H: float = 2500.0

# Conduite
const MAX_SPEED: float = 11000.0
const ACCEL: float = MAX_SPEED / 5.0
const BRAKE: float = MAX_SPEED * 1.0
const COAST: float = MAX_SPEED * 0.22
const STEER: float = 2.3
const CENTRIFUGAL: float = 0.3
const OFFROAD_LIMIT: float = MAX_SPEED * 0.35
const OFFROAD_DECEL: float = MAX_SPEED * 1.1
const X_LIMIT: float = 1.5
const HIT_COOLDOWN: float = 0.8
const KMH_AT_MAX: float = 180.0
const NITRO_CHARGES: int = 3
const NITRO_TIME: float = 1.8
const NITRO_BOOST: float = 1.22
const LANES: Array[float] = [-0.66, 0.0, 0.66]
# Aspiration (vácuo) : collé derrière une voiture, on gagne un peu de pointe.
const DRAFT_RANGE: float = 1900.0
const DRAFT_BOOST: float = 1.05
const CAR_LEN: float = 320.0          # encombrement d'une voiture, en profondeur
const PLAYER_HALF: float = 0.17

# Course
const COUNTDOWN: float = 3.0
const RIVAL_COUNT: int = 5
const TRAFFIC_COUNT: int = 34
const MAX_TIME: float = 200.0
# Inscription 50 R$ (borne) : le pódio rembourse, la vitória paie.
const PAYOUTS: Dictionary = {1: 220, 2: 110, 3: 60}

enum Zone { PORTO, T_ALENCAR, ATERRO, BOTAFOGO, T_PASMADO, RIOSUL, T_NOVO, COPA }
const ZONE_NAMES: Array[String] = ["PORTO MARAVILHA", "TÚNEL MARCELLO ALENCAR", "ATERRO DO FLAMENGO",
	"ENSEADA DE BOTAFOGO", "TÚNEL DO PASMADO", "RIO SUL", "TÚNEL NOVO", "COPACABANA"]
# Par zone : tronçons [entrée, tenue, sortie, courbure, dénivelé en segments].
const TRACK: Array = [
	[Zone.PORTO, [[0, 130, 0, 0.0, 0.0], [30, 60, 30, 2.0, 0.0], [20, 50, 20, -2.5, 0.0], [0, 90, 0, 0.0, -4.0]]],
	[Zone.T_ALENCAR, [[0, 80, 0, 0.0, -6.0], [50, 140, 50, 3.0, 0.0], [0, 60, 0, 0.0, 0.0], [40, 90, 40, -2.2, 0.0], [0, 90, 0, 0.0, 10.0]]],
	[Zone.ATERRO, [[0, 120, 0, 0.0, 0.0], [40, 100, 40, -1.6, 0.0], [0, 90, 0, 0.0, 3.0], [40, 110, 40, 2.4, -3.0], [0, 110, 0, 0.0, 0.0], [30, 70, 30, -3.0, 0.0]]],
	[Zone.BOTAFOGO, [[0, 80, 0, 0.0, 0.0], [50, 150, 50, 3.4, 0.0], [0, 70, 0, 0.0, 0.0], [40, 80, 40, 2.0, 2.0]]],
	[Zone.T_PASMADO, [[0, 70, 0, 0.0, 4.0], [30, 80, 30, -2.6, 0.0], [0, 60, 0, 0.0, -4.0]]],
	[Zone.RIOSUL, [[0, 50, 0, 0.0, 0.0], [30, 60, 30, 3.4, 0.0], [30, 40, 30, -2.6, 0.0], [0, 150, 0, 0.0, 2.0]]],
	[Zone.T_NOVO, [[0, 100, 0, 0.0, 3.0], [0, 110, 0, 0.0, 0.0], [0, 90, 0, 0.0, -5.0]]],
	[Zone.COPA, [[0, 190, 0, 0.0, 0.0], [0, 260, 0, 0.0, 0.0]]],
]
const FINISH_BEFORE_END: int = 170    # la ligne d'arrivée, puis une zone de freinage

class Car:
	var z: float = 0.0
	var offset: float = 0.0
	var target: float = 0.0
	var speed: float = 0.0
	var base: float = 0.0
	var kind: int = 0        # Art.CarKind
	var color: Color = Color.WHITE
	var rival: bool = false
	var done: bool = false
	var half: float = 0.2

## Aperçu et réglage : l'IA conduit la voiture du joueur.
@export var autoplay: bool = false
## Réglage : plafond de vitesse du conducteur automatique (1 = parfait).
@export var bot_skill: float = 1.0
## Captures : démarre la caméra à ce segment (0 = départ normal).
@export var preview_seg: int = 0

var curve: PackedFloat32Array = PackedFloat32Array()
var hy: PackedFloat32Array = PackedFloat32Array()
var zone: PackedInt32Array = PackedInt32Array()
var props: Dictionary = {}            # segment → Array[[kind, offset, variant]]
var gantries: Dictionary = {}         # segment → texte (portique)
var finish_seg: int = 0
var cars: Array = []
var t: float = 0.0
var dist: float = 0.0
var px: float = 0.0
var speed: float = 0.0
var lean: float = 0.0
var braking: bool = false
var nitro_t: float = 0.0
var nitro_left: int = NITRO_CHARGES
var drafting: bool = false
var far_off: float = 0.0
var zone_far0: float = 0.0   # défilement de l'horizon à l'entrée de la zone
var view: Rect2 = Rect2(0, 0, 1920, 1080)
var shake: Vector2 = Vector2.ZERO

var _n: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _art: RefCounted = null
var _font: Font = null
var _countdown: float = COUNTDOWN
var _last_beat: int = 4
var _elapsed: float = 0.0
var _ended: bool = false
var _hit_cd: float = 0.0
var _scrape_cd: float = 0.0
var _was_off: bool = false
var _me: Car = Car.new()          # le joueur, vu comme un obstacle par les autres
var _solids: Array = []           # cars + _me
var _tail_cd: float = 0.0
var _last_rank: int = 0
var _zone_now: int = -1
var _banner_t: float = 0.0
var _status_t: float = 0.0
var _fingers: Dictionary = {}
var _touch_gas: bool = false
var _touch_brake: bool = false
var _touch_nitro: bool = false
var _nitro_was: bool = false
var _player_color: Color = Color(0.86, 0.10, 0.12)

# Projection de l'image courante (lue par le rendu des sprites).
var pj_seg: PackedInt32Array = PackedInt32Array()
var pj_x1: PackedFloat32Array = PackedFloat32Array()
var pj_y1: PackedFloat32Array = PackedFloat32Array()
var pj_s1: PackedFloat32Array = PackedFloat32Array()
var pj_x2: PackedFloat32Array = PackedFloat32Array()
var pj_y2: PackedFloat32Array = PackedFloat32Array()
var pj_s2: PackedFloat32Array = PackedFloat32Array()
var pj_clip: PackedFloat32Array = PackedFloat32Array()

var _ui: CanvasLayer = null
var _pos_label: Label = null
var _speed_label: Label = null
var _status: Label = null
var _banner: Label = null
var _banner_sub: Label = null
var _gas_btn: Button = null
var _brake_btn: Button = null
var _nitro_btn: Button = null

const HELP: String = "Tiens ACELERA · glisse le pouce sur NITRO · FREIO avant les virages"


func _ready() -> void:
	EventBus.minigame_started.emit("racha_porto")
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.make_current()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 2016
	_font = PixelFont.ui_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	for team: String in ["flamengo", "vasco", "fluminense", "botafogo"]:
		if CampaignManager.has_flag("time_" + team):
			_player_color = {"flamengo": Color(0.86, 0.10, 0.12), "vasco": Color(0.93, 0.93, 0.9),
				"fluminense": Color(0.55, 0.08, 0.17), "botafogo": Color(0.16, 0.16, 0.18)}[team]
	_art = Art.new()
	_build_track()
	_art.call("decorate", self, _rng)
	_spawn_cars()
	# Les Packed*Array se copient : on les dimensionne un par un.
	pj_x1.resize(DRAW_DIST)
	pj_y1.resize(DRAW_DIST)
	pj_s1.resize(DRAW_DIST)
	pj_x2.resize(DRAW_DIST)
	pj_y2.resize(DRAW_DIST)
	pj_s2.resize(DRAW_DIST)
	pj_clip.resize(DRAW_DIST)
	pj_seg.resize(DRAW_DIST)
	_build_ui()
	if preview_seg > 0:
		dist = float(preview_seg) * SEG_LEN
		_countdown = 0.0
		speed = MAX_SPEED * 0.8
	else:
		_show_banner("3", "Do Porto até Copacabana · pódio = top 3", COUNTDOWN)
	_update_view()


# --- Piste ---

func _add_road(z: int, enter: int, hold: int, leave: int, c: float, hill: float) -> void:
	var start_y: float = 0.0 if hy.is_empty() else hy[hy.size() - 1]
	var end_y: float = start_y + hill * SEG_LEN
	var total: float = float(enter + hold + leave)
	var k: int = 0
	for i in enter:
		curve.append(c * pow(float(i) / float(enter), 2.0))
		k += 1
		hy.append(_ease(start_y, end_y, float(k) / total))
		zone.append(z)
	for i in hold:
		curve.append(c)
		k += 1
		hy.append(_ease(start_y, end_y, float(k) / total))
		zone.append(z)
	for i in leave:
		curve.append(_ease(c, 0.0, float(i) / float(leave)))
		k += 1
		hy.append(_ease(start_y, end_y, float(k) / total))
		zone.append(z)


func _ease(a: float, b: float, p: float) -> float:
	return a + (b - a) * (0.5 - cos(p * PI) * 0.5)


func _build_track() -> void:
	for sec: Array in TRACK:
		for r: Array in sec[1]:
			_add_road(int(sec[0]), int(r[0]), int(r[1]), int(r[2]), float(r[3]), float(r[4]))
	_n = curve.size()
	finish_seg = _n - FINISH_BEFORE_END


func is_tunnel(z: int) -> bool:
	return z == Zone.T_ALENCAR or z == Zone.T_PASMADO or z == Zone.T_NOVO


func seg_count() -> int:
	return _n


func seg_at(z: float) -> int:
	return clampi(int(z / SEG_LEN), 0, _n - 1)


func seg_y1(i: int) -> float:
	return hy[maxi(i - 1, 0)]


# --- Voitures ---

func _spawn_cars() -> void:
	var palette: Array[Color] = [Color(0.15, 0.45, 0.85), Color(0.95, 0.75, 0.15), Color(0.25, 0.7, 0.4),
		Color(0.9, 0.45, 0.15), Color(0.6, 0.3, 0.75)]
	var bases: Array[float] = [1.02, 0.995, 0.97, 0.945, 0.92]
	for k in RIVAL_COUNT:
		var r: Car = Car.new()
		r.rival = true
		r.kind = Art.CarKind.RACER
		r.color = palette[k]
		r.base = MAX_SPEED * bases[k]
		r.offset = LANES[(k + 1) % 3]
		r.target = r.offset
		r.z = PLAYER_Z + 700.0 + 650.0 * float(RIVAL_COUNT - k)
		r.half = 0.2
		cars.append(r)
	var track_len: float = float(finish_seg) * SEG_LEN
	for k in TRAFFIC_COUNT:
		var c: Car = Car.new()
		var roll: float = _rng.randf()
		c.kind = Art.CarKind.TAXI if roll < 0.4 else (Art.CarKind.SEDAN if roll < 0.7 else (Art.CarKind.KOMBI if roll < 0.85 else Art.CarKind.BUS))
		c.color = [Color(0.85, 0.85, 0.86), Color(0.3, 0.32, 0.38), Color(0.6, 0.12, 0.12), Color(0.2, 0.35, 0.6)][_rng.randi() % 4]
		c.half = 0.26 if c.kind == Art.CarKind.BUS else 0.2
		c.base = MAX_SPEED * _rng.randf_range(0.26, 0.38)
		c.speed = c.base
		c.offset = LANES[_rng.randi() % 3]
		c.target = c.offset
		c.z = 30000.0 + (track_len - 40000.0) * (float(k) + _rng.randf() * 0.6) / float(TRAFFIC_COUNT)
		cars.append(c)


func _update_cars(delta: float) -> void:
	var pz: float = dist + PLAYER_Z
	_me.z = pz
	_me.offset = px
	_me.speed = speed
	_me.half = PLAYER_HALF
	if _solids.is_empty():
		_solids = cars.duplicate()
		_solids.append(_me)
	_tail_cd = maxf(_tail_cd - delta, 0.0)
	for o in cars:
		var c: Car = o
		if c.done:
			c.speed = move_toward(c.speed, 0.0, MAX_SPEED * 0.5 * delta)
			c.z += c.speed * delta
			continue
		var s: float = c.base
		if c.rival:
			var i: int = seg_at(c.z)
			s *= 1.0 - minf(absf(curve[i]) * 0.012, 0.06)
			# Élastique léger : la course reste serrée sans être truquée.
			var gap: float = c.z - pz
			if gap > 8000.0:
				s *= 0.96
			elif gap < -3000.0:
				# Derrière le joueur, ils recollent sans le dépasser d'office.
				s = maxf(s, minf(s * 1.03, MAX_SPEED * 0.99))
			# Un véhicule devant dans sa voie (le joueur compris) : il déboîte,
			# sinon il lève le pied.
			# Vue longue : à pleine vitesse, 6000 unités ne font que 0,8 s.
			var block: Car = _blocker(c, 6000.0)
			if block != null:
				var best: float = c.target
				var best_free: float = -1.0
				for lane: float in LANES:
					var free: float = _free_ahead(c, lane)
					if free > best_free + 200.0:
						best_free = free
						best = lane
				c.target = best
				if block.z - c.z < 700.0 and absf(block.offset - c.offset) < 0.3:
					s = minf(s, block.speed)
			c.speed = move_toward(c.speed, s, ACCEL * 1.1 * delta)
			if c.z >= float(finish_seg) * SEG_LEN:
				c.done = true
		# Changement de voie : jamais dans une voiture qui roule à côté.
		var prev: float = c.offset
		c.offset = move_toward(c.offset, c.target, (1.6 if c.rival else 0.9) * delta)
		if c.offset != prev and _overlaps_side(c):
			c.offset = prev
		c.z += c.speed * delta
		_keep_behind(c)


# Personne ne traverse personne : qui rattrape un véhicule dans sa file reste
# derrière, à sa vitesse (le joueur est un véhicule comme les autres).
func _keep_behind(c: Car) -> void:
	for o in _solids:
		var d: Car = o
		if d == c:
			continue
		var dz: float = d.z - c.z
		if dz <= 0.0 or dz >= CAR_LEN or c.speed <= d.speed:
			continue
		if absf(d.offset - c.offset) >= c.half + d.half - 0.04:
			continue
		c.z = d.z - CAR_LEN
		c.speed = d.speed
		if d == _me and c.rival and _tail_cd <= 0.0:
			_tail_cd = 2.5
			sfx("mg_hit", 0.7)
			pulse(0.3, 0.06)
			_flash("Rival na sua cola ! Ferme la porte.")


func _overlaps_side(c: Car) -> bool:
	for o in _solids:
		var d: Car = o
		if d == c:
			continue
		# Marge : la voiture collée juste derrière (à CAR_LEN pile) peut déboîter.
		if absf(d.z - c.z) < CAR_LEN * 0.9 and absf(d.offset - c.offset) < c.half + d.half - 0.04:
			return true
	return false


func _blocker(c: Car, range_z: float) -> Car:
	var best: Car = null
	for o in _solids:
		var d: Car = o
		if d == c:
			continue
		var dz: float = d.z - c.z
		# Plus lent que l'allure visée (et non que la vitesse du moment : collé
		# derrière lui on roule à sa vitesse, il reste pourtant à doubler).
		if dz > 0.0 and dz < range_z and absf(d.offset - c.offset) < 0.32 and d.speed < maxf(c.speed, c.base):
			if best == null or d.z < best.z:
				best = d
	return best


func _free_ahead(c: Car, lane: float) -> float:
	var free: float = 6000.0
	for o in _solids:
		var d: Car = o
		if d == c:
			continue
		var dz: float = d.z - c.z
		if dz > -CAR_LEN and dz < free and absf(d.offset - lane) < 0.32:
			free = dz
	return free


func position_rank() -> int:
	var pz: float = dist + PLAYER_Z
	var rank: int = 1
	for o in cars:
		var c: Car = o
		if c.rival and c.z > pz:
			rank += 1
	return rank


# --- Boucle ---

func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_update_view()
	t += delta
	_tick_banner(delta)
	if _ended:
		speed = move_toward(speed, 0.0, MAX_SPEED * 0.7 * delta)
		dist = minf(dist + speed * delta, float(_n - 12) * SEG_LEN - PLAYER_Z)
		_update_cars(delta)
		queue_redraw()
		return
	if _countdown > 0.0:
		_tick_countdown(delta)
		queue_redraw()
		return
	_elapsed += delta
	_update_player(delta)
	_update_cars(delta)
	_check_hits()
	_tick_zone()
	far_off += curve[seg_at(dist + PLAYER_Z)] * (speed / MAX_SPEED) * 26.0 * delta
	if dist + PLAYER_Z >= float(finish_seg) * SEG_LEN:
		_end_game()
	elif _elapsed > MAX_TIME:
		_end_game()
	_update_hud()
	queue_redraw()


func _update_view() -> void:
	var vp: Viewport = get_viewport()
	var vis: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vis
	view = Rect2(a, b - a)


func _tick_countdown(delta: float) -> void:
	_countdown -= delta
	var beat: int = ceili(_countdown)
	if beat != _last_beat:
		_last_beat = beat
		if beat > 0:
			sfx("checkpoint", 0.7)
			_show_banner(str(beat), _banner_sub.text if _banner_sub else "", 1.2)
		else:
			sfx("whistle", 1.3)
			_show_banner("VAI !", "", 0.8)
			for o in cars:
				var c: Car = o
				if c.rival:
					c.speed = 0.0


func _tick_zone() -> void:
	var z: int = zone[seg_at(dist + PLAYER_Z)]
	if z == _zone_now:
		return
	var from_tunnel: bool = _zone_now >= 0 and is_tunnel(_zone_now)
	_zone_now = z
	zone_far0 = far_off
	if _elapsed > 1.0:
		var sub: String = ""
		# Une charge rendue à chaque sortie de tunnel : le nitro se gère sur
		# toute la course, pas seulement au départ.
		if from_tunnel and nitro_left < NITRO_CHARGES:
			nitro_left += 1
			sub = "+1 NITRO"
		_show_banner(ZONE_NAMES[z], sub, 1.8)
		sfx("checkpoint")


# --- Conduite ---

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
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_fingers[-1] = mb.position
		else:
			_fingers.erase(-1)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if not _fingers.has(-1):
			return
		_fingers[-1] = (event as InputEventMouseMotion).position
	else:
		return
	_touch_gas = _held(_gas_btn)
	_touch_brake = _held(_brake_btn)
	_touch_nitro = _held(_nitro_btn)


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


func _update_player(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_scrape_cd = maxf(_scrape_cd - delta, 0.0)
	var pseg: int = seg_at(dist + PLAYER_Z)
	var steer: float = clampf(Input.get_axis("move_left", "move_right"), -1.0, 1.0)
	var brake: bool = _touch_brake or Input.is_action_pressed("move_back")
	var nitro: bool = _touch_nitro or Input.is_action_pressed("jump")
	# NITRO est collé à ACELERA et vaut aussi accélérateur : le pouce glisse
	# de l'un à l'autre sans jamais lever le pied.
	var gas: bool = _touch_gas or _touch_nitro or Input.is_action_pressed("move_forward") or Input.is_action_pressed("interact")
	if autoplay:
		var bot: Array = _bot(pseg)
		steer = bot[0]
		gas = true
		brake = bot[1]
		nitro = bot[2]
	if nitro and not _nitro_was and nitro_left > 0 and nitro_t <= 0.0:
		nitro_left -= 1
		nitro_t = NITRO_TIME
		sfx("mg_perfect", 0.8)
		pulse(0.6, 0.15)
		_flash("NITRO !")
	_nitro_was = nitro
	nitro_t = maxf(nitro_t - delta, 0.0)
	braking = brake
	var sp: float = speed / MAX_SPEED
	var dx: float = delta * STEER * minf(sp, 1.0)
	px += steer * dx
	px -= dx * sp * curve[pseg] * CENTRIFUGAL
	var tunnel: bool = is_tunnel(zone[pseg])
	var top: float = MAX_SPEED * (NITRO_BOOST if nitro_t > 0.0 else 1.0)
	var draft: bool = _in_draft()
	if draft:
		top *= DRAFT_BOOST
		if not drafting:
			_flash("Vácuo ! Sors de l'aspiration pour doubler.")
	drafting = draft
	if autoplay:
		top *= bot_skill
	var force: float = -COAST
	if brake:
		force = -BRAKE
	elif gas or nitro_t > 0.0:
		force = ACCEL * (2.2 if nitro_t > 0.0 else (1.6 if draft else 1.0))
	var s: float = speed + force * delta
	if speed > top:
		s = move_toward(speed, top, MAX_SPEED * 0.4 * delta)
	if tunnel:
		# Les murs : on frotte, ça freine, mais on ne sort pas.
		if absf(px) > 1.0:
			px = clampf(px, -1.0, 1.0)
			s = minf(s, speed - MAX_SPEED * 0.9 * delta)
			if _scrape_cd <= 0.0 and speed > MAX_SPEED * 0.3:
				_scrape_cd = 0.5
				sfx("mg_drop", 1.3)
				pulse(0.4, 0.08)
				_flash("O muro ! Garde ta voie.")
		_was_off = false
	else:
		px = clampf(px, -X_LIMIT, X_LIMIT)
		var off: bool = absf(px) > 1.05
		if off and s > OFFROAD_LIMIT:
			s = minf(s, maxf(OFFROAD_LIMIT, speed - OFFROAD_DECEL * delta))
		if off and not _was_off and speed > OFFROAD_LIMIT * 0.6:
			sfx("mg_miss", 0.85)
			pulse(0.35, 0.12)
			_flash("Fora da pista !")
		_was_off = off
	speed = clampf(s, 0.0, MAX_SPEED * NITRO_BOOST)
	shake = Vector2(randf_range(-3.0, 3.0), randf_range(-4.0, 0.0)) if (_was_off or nitro_t > 0.0) and speed > 500.0 else Vector2.ZERO
	lean = lerpf(lean, steer * 0.07 + curve[pseg] * sp * 0.01, clampf(delta * 8.0, 0.0, 1.0))
	dist += speed * delta


func _in_draft() -> bool:
	var pz: float = dist + PLAYER_Z
	for o in cars:
		var c: Car = o
		var dz: float = c.z - pz
		if dz > CAR_LEN and dz < DRAFT_RANGE and absf(c.offset - px) < 0.24 and c.speed > MAX_SPEED * 0.6:
			return true
	return false


# Conducteur automatique (aperçu, réglage) : voie la plus libre, frein en courbe.
func _bot(pseg: int) -> Array:
	var me: Car = _me
	var best: float = 0.0
	var best_free: float = -1.0
	for lane: float in LANES:
		var free: float = _free_ahead(me, lane) - absf(lane - px) * 600.0
		if free > best_free:
			best_free = free
			best = lane
	var ahead: float = curve[mini(pseg + 14, _n - 1)]
	var steer: float = clampf((best - px) * 4.0 + curve[pseg] * 0.28, -1.0, 1.0)
	var brake: bool = absf(ahead) > 3.0 and speed > MAX_SPEED * 0.9
	var nitro: bool = absf(ahead) < 0.4 and absf(curve[pseg]) < 0.4 and best_free > 4500.0 and speed > MAX_SPEED * 0.8
	return [steer, brake, nitro]


func _check_hits() -> void:
	var pz: float = dist + PLAYER_Z
	for o in cars:
		var c: Car = o
		var dz: float = c.z - pz
		var reach: float = PLAYER_HALF + c.half
		var dx: float = px - c.offset
		if absf(dx) >= reach:
			continue
		if dz > 90.0 and dz < CAR_LEN and speed > c.speed:
			# Choc arrière : on perd la moitié de l'élan, pas toute la course.
			speed = maxf(c.speed * 0.9, speed * 0.55)
			dist += dz - CAR_LEN
			if _hit_cd <= 0.0:
				_hit_cd = HIT_COOLDOWN
				sfx("mg_drop")
				pulse(0.7, 0.18)
				_flash("Opa ! Double par l'autre voie." if not c.rival else "Toque no rival !")
		elif dz > -CAR_LEN * 0.85 and dz <= 90.0:
			# Porte contre porte : on est repoussé hors de sa carrosserie.
			var side: float = 1.0 if dx >= 0.0 else -1.0
			px = c.offset + side * reach
			speed *= 0.985
			if _scrape_cd <= 0.0:
				_scrape_cd = 0.5
				sfx("mg_hit", 0.6)
				pulse(0.35, 0.08)
				_flash("Porta com porta !")


# --- Interface ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	_pos_label = _label(66, Color(1, 0.86, 0.35))
	_pos_label.position = Vector2(36, 20)
	_ui.add_child(_pos_label)
	SafeArea.apply(_pos_label)
	_speed_label = _label(44, Color(1, 0.97, 0.88))
	_speed_label.anchor_left = 1.0
	_speed_label.anchor_right = 1.0
	_speed_label.offset_left = -640.0
	_speed_label.offset_right = -330.0
	_speed_label.offset_top = 28.0
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui.add_child(_speed_label)
	SafeArea.apply(_speed_label)
	_banner = _label(88, Color(1, 0.86, 0.35))
	_center(_banner, -330.0, -220.0)
	_banner_sub = _label(36, Color(1, 0.97, 0.88))
	_center(_banner_sub, -200.0, -150.0)
	_status = _label(30, Color(1, 0.95, 0.7))
	_status.anchor_left = 0.5
	_status.anchor_right = 0.5
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = -700.0
	_status.offset_right = 420.0
	_status.offset_top = -84.0
	_status.offset_bottom = -30.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = HELP
	_ui.add_child(_status)
	# Sous le pouce droit : ACELERA dans le coin, NITRO juste à sa gauche
	# (même hauteur, un glissement suffit), FREIO au-dessus.
	_gas_btn = _button("ACELERA", Vector2(-352, -272), Vector2(-32, -32), 50)
	_nitro_btn = _button("NITRO", Vector2(-640, -272), Vector2(-364, -32), 44)
	_brake_btn = _button("FREIO", Vector2(-352, -452), Vector2(-32, -284), 44)


func _label(size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	return l


func _center(l: Label, top: float, bottom: float) -> void:
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = -900.0
	l.offset_right = 900.0
	l.offset_top = top
	l.offset_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.add_child(l)


func _button(text: String, tl: Vector2, br: Vector2, size: int) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = &"TouchButton"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.toggle_mode = true
	b.add_theme_font_size_override("font_size", size)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = tl.x
	b.offset_top = tl.y
	b.offset_right = br.x
	b.offset_bottom = br.y
	var box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.72))
	b.add_theme_stylebox_override("normal", box)
	b.add_theme_stylebox_override("hover", box)
	b.add_theme_stylebox_override("pressed", UITheme.pastille_box(UITheme.CREAM, Color(0.3, 0.55, 0.25, 0.9)))
	_ui.add_child(b)
	SafeArea.apply(b)
	return b


func _update_hud() -> void:
	var rank: int = position_rank()
	if _last_rank > 0 and rank != _last_rank and not _ended and _elapsed > 2.0:
		if rank < _last_rank:
			sfx("mg_good")
			_flash("Passou ! %dº" % rank)
		else:
			sfx("mg_miss", 1.4)
			_flash("Perdeu a posição… %dº" % rank)
	_last_rank = rank
	if _pos_label:
		_pos_label.text = "%dº / %d" % [rank, RIVAL_COUNT + 1]
	if _speed_label:
		_speed_label.text = "%d km/h" % int(round(speed / MAX_SPEED * KMH_AT_MAX))
	if _nitro_btn:
		_nitro_btn.text = "NITRO ×%d" % nitro_left
		_nitro_btn.modulate.a = 1.0 if nitro_left > 0 else 0.45


func _show_banner(text: String, sub: String, dur: float) -> void:
	_banner_t = dur
	if _banner:
		_banner.text = text
		_banner.visible = true
	if _banner_sub:
		_banner_sub.text = sub
		_banner_sub.visible = sub != ""


func _tick_banner(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0 and not _ended:
			_banner.visible = false
			_banner_sub.visible = false
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0 and _status and not _ended:
			_status.text = HELP if _elapsed < 12.0 else ""


func _flash(msg: String) -> void:
	_status_t = 1.6
	if _status:
		_status.text = msg


# --- Fin ---

func quit_game() -> void:
	_end_game()


func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var finished: bool = dist + PLAYER_Z >= float(finish_seg) * SEG_LEN
	var pos: int = position_rank() if finished else RIVAL_COUNT + 1
	var qualifies: bool = final_qualifies(finished and pos <= 3)
	var tip: int = 0 if forfeited or not finished else int(PAYOUTS.get(pos, 0))
	for b: Button in [_gas_btn, _brake_btn, _nitro_btn]:
		if b:
			b.visible = false
	if not forfeited:
		if not finished:
			_show_banner("FIM DE PROVA", "Trop lent : les autres sont à la praia.", 99.0)
			sfx("minigame_lose")
		else:
			_show_banner("CHEGADA !  %dº" % pos, ("Pódio ! R$ %d" % tip) if pos <= 3 else "Fora do pódio…", 99.0)
			sfx("minigame_win" if qualifies else "minigame_lose")
			if qualifies:
				sfx("torcida_cheer")
	if _status:
		_status.text = ""
	await get_tree().create_timer(bilan_delay(2.8)).timeout
	EventBus.minigame_ended.emit("racha_porto", {"tip": tip, "position": pos, "time": _elapsed, "qualifies": qualifies})
	match_ended.emit(qualifies, tip)


# --- Rendu ---

func _draw() -> void:
	_art.call("draw", self)


func player_color() -> Color:
	return _player_color


func font() -> Font:
	return _font
