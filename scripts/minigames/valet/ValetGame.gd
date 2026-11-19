class_name ValetGame
extends MinigameBase

# Mini-jeu valet du Copa Palace.
# Cycle : voiture arrive à l'entrée → garer dans une place libre → patience client →
# voiture réclamée (clignote) → ramener à l'entrée. Tip selon vitesse de réponse.
# Pression : les voitures arrivent à leur rythme (de plus en plus serré), un
# client qui attend trop à l'entrée klaxonne (tip rogné), et une voiture
# réclamée non rendue à temps = client parti furieux, sans tip.

signal match_ended(qualifies: bool, tips: int)

const ValetArt := preload("res://scripts/minigames/valet/ValetArt.gd")

const DURATION: float = 120.0
const MAX_CUSTOMERS: int = 8
# Qualifié = au moins 4 clients rendus, au plus 1 parti fâché.
const QUALIFY_SERVED: int = 4
const MAX_LOST_TO_QUALIFY: int = 1

const ARENA_W: float = 1920.0
const ARENA_H: float = 1080.0

const PLAYER_RADIUS: float = 28.0
const PLAYER_SPEED: float = 720.0
const PLAYER_DRIVE_SPEED: float = 560.0
const PICKUP_RANGE: float = 130.0
const SLOT_RANGE: float = 140.0

const CAR_W: float = 88.0
const CAR_H: float = 132.0
const SLOT_W: float = 140.0
const SLOT_H: float = 180.0

const DROP_ZONE: Rect2 = Rect2(720.0, 60.0, 480.0, 240.0)
const SLOTS: Array = [
	Vector2(240.0, 780.0),
	Vector2(560.0, 780.0),
	Vector2(960.0, 780.0),
	Vector2(1360.0, 780.0),
	Vector2(1680.0, 780.0),
]

const CAR_COLORS: Array = [
	Color(0.85, 0.22, 0.22, 1),
	Color(0.25, 0.5, 0.9, 1),
	Color(0.95, 0.85, 0.22, 1),
	Color(0.55, 0.85, 0.5, 1),
	Color(0.85, 0.5, 0.85, 1),
]

const TIP_BASE: int = 12
const TIP_MAX: int = 40
# Temps garé avant que le client redemande sa voiture (tiré au hasard).
const PATIENCE_MIN: float = 10.0
const PATIENCE_MAX: float = 18.0
# Au-delà, le client réclamant repart fâché (tip 0, client perdu).
const RESPONSE_WINDOW: float = 22.0
# Une voiture laissée à l'entrée au-delà de ce délai klaxonne (−10 R$ de tip).
const HONK_AFTER: float = 9.0
const HONK_PENALTY: int = 10
# Intervalle d'arrivée : de 11 s en début de service à 5 s à la fin.
const SPAWN_INTERVAL_START: float = 11.0
const SPAWN_INTERVAL_END: float = 5.0
const MAX_WAITING_AT_ENTRANCE: int = 2
const SPAWN_DELAY_INITIAL: float = 0.5

enum CarStatus { ARRIVING, CARRIED, PARKED, REQUESTED, DELIVERED }

# Rendu : places des clients au bord du trottoir, de part et d'autre du tapis
# rouge et des voitures en dépose.
const PORCH_SPOTS: Array[float] = [815.0, 1105.0, 745.0, 1175.0, 675.0, 1245.0]
const PORCH_Y: float = 196.0
const ELEGANT_SHIRTS: Array[Color] = [
	Color(0.96, 0.95, 0.91), Color(0.18, 0.18, 0.24), Color(0.20, 0.26, 0.48),
	Color(0.86, 0.78, 0.60), Color(0.78, 0.36, 0.48), Color(0.62, 0.14, 0.18),
]
const ELEGANT_PANTS: Array[Color] = [
	Color(0.16, 0.16, 0.20), Color(0.92, 0.90, 0.84), Color(0.22, 0.24, 0.36),
]

# Capture hors partie : "play" saute le tutoriel, "busy" met en plus le service
# en route (voitures garées, une réclamée, une qui klaxonne), "carry" y ajoute
# la voiture réclamée en main. Sans effet en jeu.
var preview: String = ""

var _time_left: float = DURATION
var _customers_served: int = 0
var _lost: int = 0
var _total_tips: int = 0
var _ended: bool = false
var _total_spawned: int = 0
var _spawn_cooldown: float = SPAWN_DELAY_INITIAL

var _player_pos: Vector2 = Vector2(960.0, 480.0)
var _carried_idx: int = -1

var _cars: Array = []
var _occupied_slots: Dictionary = {}
var _slot_highlights: Array = []  # Array[ColorRect] indexée comme SLOTS

@onready var arena: Node2D = $Arena
@onready var player_node: ColorRect = $Arena/Player
@onready var drop_zone_rect: ColorRect = $Arena/DropZone
@onready var drop_zone_label: Label = $Arena/DropZoneLabel
@onready var status_label: Label = $UI/Status
@onready var timer_label: Label = $UI/Timer
@onready var tip_label: Label = $UI/Tips
@onready var prompt_label: Label = $UI/Prompt
@onready var context_label: Label = $Arena/Player/Context
@onready var tutorial_root: Control = $UI/Tutorial
@onready var tutorial_button: Button = $UI/Tutorial/Panel/Margin/Layout/StartButton
@onready var help_button: Button = $UI/HelpButton
@onready var touch_controls: CanvasLayer = get_node_or_null("TouchControls")

var _tutorial_visible: bool = true
var _valet_sprite: Sprite2D = null
var _walk_t: float = 0.0
var _facing_left: bool = false
var _spots_taken: Dictionary = {}  # index de PORCH_SPOTS → car dict

func _ready() -> void:
	EventBus.minigame_started.emit("valet")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_collect_slot_highlights()
	_dress()
	_set_status("Bem-vindo ao Copa. Le service ouvre.")
	if prompt_label:
		prompt_label.text = "Joystick : bouger · Bouton Action : prendre / garer / restituer"
	_refresh_drop_zone_visual()
	if tutorial_button:
		tutorial_button.pressed.connect(_close_tutorial)
	if help_button:
		help_button.pressed.connect(_open_tutorial)
		# Fond sombre : la pastille translucide se perdait sur le décor peint.
		var help_box: StyleBoxTexture = UITheme.pastille_box(UITheme.CREAM, Color(0.08, 0.09, 0.12, 0.82))
		help_button.add_theme_stylebox_override("normal", help_box)
		help_button.add_theme_stylebox_override("hover", help_box)
	if tutorial_root:
		tutorial_root.add_to_group("gamepad_menu")
		tutorial_root.visible = true
		GamepadBridge.focus_first.call_deferred(tutorial_root)
	if help_button:
		help_button.visible = false
	if touch_controls:
		touch_controls.visible = false
	if preview != "":
		_close_tutorial()
		if preview == "busy" or preview == "carry":
			_stage_preview()
		if preview == "carry":
			_player_pos = SLOTS[2]
			_action_pickup()
			_player_pos = Vector2(1000.0, 500.0)

func _collect_slot_highlights() -> void:
	if arena == null:
		return
	for i in range(SLOTS.size()):
		var node: ColorRect = arena.get_node_or_null("Slot%d" % i) as ColorRect
		_slot_highlights.append(node)

func _process(delta: float) -> void:
	if _ended:
		return
	if _tutorial_visible:
		return
	_time_left -= delta
	_spawn_cooldown = max(0.0, _spawn_cooldown - delta)
	if _time_left <= 0.0 or _customers_served + _lost >= MAX_CUSTOMERS:
		_end_game()
		return
	_update_player(delta)
	_update_cars()
	_maybe_spawn_next()
	_update_visuals()
	_update_labels()

func _close_tutorial() -> void:
	_tutorial_visible = false
	if tutorial_root:
		tutorial_root.visible = false
	if help_button:
		help_button.visible = true
	if touch_controls:
		touch_controls.visible = true

func _open_tutorial() -> void:
	_tutorial_visible = true
	if tutorial_root:
		tutorial_root.visible = true
		GamepadBridge.focus_first.call_deferred(tutorial_root)
	if help_button:
		help_button.visible = false
	if touch_controls:
		touch_controls.visible = false

func _update_player(delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"),
	)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed: float = PLAYER_DRIVE_SPEED if _carried_idx >= 0 else PLAYER_SPEED
	_player_pos += dir * speed * delta
	_player_pos.x = clamp(_player_pos.x, PLAYER_RADIUS, ARENA_W - PLAYER_RADIUS)
	_player_pos.y = clamp(_player_pos.y, PLAYER_RADIUS, ARENA_H - PLAYER_RADIUS)
	if player_node:
		player_node.position = _player_pos - Vector2(PLAYER_RADIUS, PLAYER_RADIUS)
	_animate_valet(dir, delta)
	if _carried_idx >= 0:
		var car: ColorRect = _cars[_carried_idx].node as ColorRect
		car.position = _player_pos - Vector2(CAR_W * 0.5, CAR_H * 0.5)
	if Input.is_action_just_pressed("interact"):
		_handle_interact()

# --- Logique d'interaction ---
# L'interact essaie l'action contextuelle la plus évidente :
#   sans rien : ramasser la voiture la plus proche dans la portée.
#   avec une voiture REQUESTED dans la drop zone : restituer.
#   avec n'importe quelle voiture portée près d'un slot libre : garer.
# Toute autre situation déclenche un feedback texte.

func _handle_interact() -> void:
	if _carried_idx < 0:
		_action_pickup()
	else:
		_action_drop()

func _action_pickup() -> void:
	var best_idx: int = -1
	var best_dist: float = PICKUP_RANGE
	for i in range(_cars.size()):
		var c: Dictionary = _cars[i]
		if c.status == CarStatus.DELIVERED or c.status == CarStatus.CARRIED:
			continue
		var car_node: ColorRect = c.node
		var center: Vector2 = car_node.position + Vector2(CAR_W * 0.5, CAR_H * 0.5)
		var d: float = _player_pos.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_idx = i
	if best_idx < 0:
		_set_status("Approche-toi d'une voiture pour la prendre.")
		return
	var c: Dictionary = _cars[best_idx]
	var prev: int = c.status
	# IMPORTANT : on garde le flag requested_pending intact à travers la prise en main.
	# Le statut courant passe à CARRIED (utilisé pour le compte des voitures à l'entrée),
	# mais c'est requested_pending qui décide si la voiture est livrable.
	c.status = CarStatus.CARRIED
	_carried_idx = best_idx
	(c.node as ColorRect).z_index = 2
	if prev == CarStatus.ARRIVING:
		_release_client(c)  # il a confié ses clés, il entre à l'hôtel
	if prev == CarStatus.PARKED or prev == CarStatus.REQUESTED:
		if c.slot_idx >= 0:
			_occupied_slots.erase(c.slot_idx)
		c.slot_idx = -1
	if c.requested_pending:
		_set_status("Vite ! Le client t'attend à l'entrée.")
	elif prev == CarStatus.ARRIVING:
		_set_status("Gare-la dans une place libre (places lignées).")
	else:
		_set_status("Voiture en main.")

func _action_drop() -> void:
	if _carried_idx < 0:
		return
	var c: Dictionary = _cars[_carried_idx]
	# Restitution : la voiture est livrable si requested_pending (le statut courant
	# est CARRIED après pickup, mais ce flag survit).
	if DROP_ZONE.has_point(_player_pos):
		if c.requested_pending:
			_deliver(c)
			return
		_set_status("Aucun client n'attend cette voiture pour l'instant.")
		return
	# Garer dans le slot libre le plus proche.
	var best_slot: int = -1
	var best_dist: float = SLOT_RANGE
	for i in range(SLOTS.size()):
		if _occupied_slots.has(i):
			continue
		var d: float = _player_pos.distance_to(SLOTS[i])
		if d < best_dist:
			best_dist = d
			best_slot = i
	if best_slot < 0:
		_set_status("Approche-toi d'une place libre pour garer.")
		return
	# Une voiture déjà demandée ne se re-gare pas — elle doit être restituée.
	if c.requested_pending:
		_set_status("Le client attend cette voiture à l'entrée !")
		return
	(c.node as ColorRect).position = SLOTS[best_slot] - Vector2(CAR_W * 0.5, CAR_H * 0.5)
	c.status = CarStatus.PARKED
	c.slot_idx = best_slot
	c.parked_at = DURATION - _time_left
	(c.node as ColorRect).z_index = 0
	_occupied_slots[best_slot] = _carried_idx
	_carried_idx = -1
	_set_status("Place %d occupée. Continue le service." % (best_slot + 1))

func _deliver(c: Dictionary) -> void:
	var elapsed: float = DURATION - _time_left
	var waited: float = elapsed - float(c.requested_at)
	var ratio: float = clamp(1.0 - waited / RESPONSE_WINDOW, 0.0, 1.0)
	var tip: int = int(round(TIP_BASE + (TIP_MAX - TIP_BASE) * ratio))
	if c.get("honked", false):
		tip = maxi(tip - HONK_PENALTY, 0)
	_total_tips += tip
	sfx("coin")
	if ratio >= 0.6:
		sfx("mg_perfect")
		pulse(0.35, 0.06)
	_customers_served += 1
	c.status = CarStatus.DELIVERED
	(c.node as ColorRect).queue_free()
	_release_client(c)
	_carried_idx = -1
	_set_status("+R$ %d tip ! (%d/%d clients)" % [tip, _customers_served, MAX_CUSTOMERS])

# Client réclamant laissé trop longtemps : il part (à pied, furieux), la
# voiture reste au garage de l'hôtel — plus rien à gagner sur ce client.
func _lose_customer(c: Dictionary) -> void:
	_lost += 1
	var idx: int = _cars.find(c)
	if idx == _carried_idx:
		_carried_idx = -1
	if int(c.slot_idx) >= 0:
		_occupied_slots.erase(int(c.slot_idx))
	c.status = CarStatus.DELIVERED
	c.requested_pending = false
	(c.node as ColorRect).queue_free()
	_release_client(c)
	sfx("mg_miss")
	pulse(0.6, 0.2)
	_set_status("😤 « Esquece ! » Un client est parti sans sa voiture (%d perdu%s)." % [_lost, "s" if _lost > 1 else ""])

# --- Cycle clients ---

func _update_cars() -> void:
	var elapsed: float = DURATION - _time_left
	for c in _cars:
		if c.status == CarStatus.PARKED:
			if elapsed - float(c.parked_at) >= float(c.patience):
				c.status = CarStatus.REQUESTED
				c.requested_pending = true
				c.requested_at = elapsed
				_seat_client(c, true)
				sfx("prompt_chime")
				_set_status("Un client redemande sa voiture — elle clignote !")
		elif c.status == CarStatus.ARRIVING and not c.honked:
			if elapsed - float(c.arrived_at) >= HONK_AFTER:
				c.honked = true
				sfx("mg_miss", 1.3)
				pulse(0.3, 0.1)
				_set_status("📯 Fom-fom ! Une voiture s'impatiente à l'entrée.")
	for c in _cars.duplicate():
		if c.requested_pending and c.status != CarStatus.DELIVERED \
				and elapsed - float(c.requested_at) >= RESPONSE_WINDOW:
			_lose_customer(c)

func _maybe_spawn_next() -> void:
	if _spawn_cooldown > 0.0:
		return
	if _total_spawned >= MAX_CUSTOMERS:
		return
	var waiting: int = 0
	for c in _cars:
		if c.status == CarStatus.ARRIVING:
			waiting += 1
	if waiting >= MAX_WAITING_AT_ENTRANCE:
		return
	if _occupied_slots.size() >= SLOTS.size():
		return  # Les places sont pleines : on attend que le joueur restitue.
	_spawn_arriving_car()

func _spawn_arriving_car() -> void:
	var car: ColorRect = ColorRect.new()
	car.size = Vector2(CAR_W, CAR_H)
	car.color = CAR_COLORS[_total_spawned % CAR_COLORS.size()]
	var art_color: Color = ValetArt.LUX_COLORS[_total_spawned % ValetArt.LUX_COLORS.size()]
	_dress_car(car, art_color, ValetArt.LUX_KINDS[_total_spawned % ValetArt.LUX_KINDS.size()])
	# Léger offset horizontal selon le numéro pour que les voitures suivantes
	# ne se superposent pas aux précédentes en attente.
	var ox: float = -60.0 + 60.0 * (_total_spawned % 3)
	car.position = Vector2(
		DROP_ZONE.position.x + DROP_ZONE.size.x * 0.5 - CAR_W * 0.5 + ox,
		DROP_ZONE.position.y + DROP_ZONE.size.y - CAR_H - 30.0,
	)
	if arena:
		arena.add_child(car)
	_cars.append({
		"node": car,
		"color": car.color,
		"status": CarStatus.ARRIVING,
		"slot_idx": -1,
		"parked_at": 0.0,
		"requested_at": 0.0,
		"requested_pending": false,
		"arrived_at": DURATION - _time_left,
		"patience": randf_range(PATIENCE_MIN, PATIENCE_MAX),
		"honked": false,
		"art_color": art_color,
		"client": null,
		"spot": -1,
	})
	_seat_client(_cars[_cars.size() - 1], false)
	_total_spawned += 1
	# Le rythme se resserre au fil du service.
	var progress: float = clampf(1.0 - _time_left / DURATION, 0.0, 1.0)
	_spawn_cooldown = lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, progress)
	sfx("prompt_chime", 0.8)
	_set_status("Nouvelle voiture à l'entrée !")

# --- Affordances visuelles ---

func _update_visuals() -> void:
	# Place : libres en vert vif quand le joueur porte une voiture, sinon estompées.
	var carrying: bool = _carried_idx >= 0
	for i in range(_slot_highlights.size()):
		var rect: ColorRect = _slot_highlights[i]
		if rect == null:
			continue
		var t0: float = Time.get_ticks_msec() / 1000.0
		if _occupied_slots.has(i) or not carrying:
			rect.color = Color(0, 0, 0, 0)
		else:
			rect.color = Color(0.45, 0.95, 0.45, 0.22 + 0.10 * sin(t0 * 5.0))
	# Voitures réclamées : pulsation, warnings orange et bulle « ! » (y compris portées).
	var t: float = Time.get_ticks_msec() / 1000.0
	var blink: bool = fmod(t, 0.5) < 0.25
	for c in _cars:
		if c.status == CarStatus.DELIVERED:
			continue
		var node: ColorRect = c.node
		var hz: Node2D = node.get_node_or_null("Hazard") as Node2D
		var badge: Node2D = node.get_node_or_null("Badge") as Node2D
		var honk: Node2D = node.get_node_or_null("Honk") as Node2D
		if c.requested_pending:
			var glow: float = 1.1 + 0.3 * sin(t * 6.0)
			node.modulate = Color(glow, glow * 0.9, glow * 0.85, 1.0)
		else:
			node.modulate = Color(1, 1, 1, 1)
		if hz:
			hz.visible = c.requested_pending and blink
		if badge:
			# En main, l'étiquette de contexte prend le relais au-dessus du capot.
			badge.visible = c.requested_pending and c.status != CarStatus.CARRIED
			badge.position.y = -30.0 - (6.0 if fmod(t, 0.6) < 0.3 else 0.0)
		if honk:
			honk.visible = c.status == CarStatus.ARRIVING and c.honked and fmod(t, 0.8) < 0.45
	_update_clients(t)
	_refresh_drop_zone_visual()
	_refresh_context_label()

func _refresh_drop_zone_visual() -> void:
	if drop_zone_rect == null or drop_zone_label == null:
		return
	var carrying_requested: bool = false
	if _carried_idx >= 0:
		carrying_requested = _cars[_carried_idx].requested_pending
	if carrying_requested:
		var t: float = Time.get_ticks_msec() / 1000.0
		drop_zone_rect.color = Color(0.45, 0.95, 0.45, 0.26 + 0.10 * sin(t * 5.0))
		drop_zone_label.text = "RESTITUER ICI"
		drop_zone_label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.58))
	else:
		drop_zone_rect.color = Color(0, 0, 0, 0)
		drop_zone_label.text = "ENTRÉE · VALET"
		drop_zone_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))

func _refresh_context_label() -> void:
	if context_label == null:
		return
	var msg: String = ""
	if _carried_idx < 0:
		var nearest: float = PICKUP_RANGE
		var found: int = -1
		for i in range(_cars.size()):
			var c: Dictionary = _cars[i]
			if c.status == CarStatus.DELIVERED or c.status == CarStatus.CARRIED:
				continue
			var center: Vector2 = (c.node as ColorRect).position + Vector2(CAR_W * 0.5, CAR_H * 0.5)
			var d: float = _player_pos.distance_to(center)
			if d < nearest:
				nearest = d
				found = i
		if found >= 0:
			if _cars[found].requested_pending:
				msg = InputHints.act() + " Récupérer pour le client"
			else:
				msg = InputHints.act() + " Prendre la voiture"
	else:
		var c: Dictionary = _cars[_carried_idx]
		if DROP_ZONE.has_point(_player_pos) and c.requested_pending:
			msg = InputHints.act() + " RESTITUER"
		elif c.requested_pending:
			msg = "→ Va à l'entrée pour restituer"
		else:
			var near_free_slot: bool = false
			for i in range(SLOTS.size()):
				if _occupied_slots.has(i):
					continue
				if _player_pos.distance_to(SLOTS[i]) < SLOT_RANGE:
					near_free_slot = true
					break
			msg = InputHints.act() + " Garer ici" if near_free_slot else "→ Trouve une place libre"
	context_label.text = msg

# --- UI / fin ---

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if tip_label:
		tip_label.text = "R$ %d · %d/%d" % [_total_tips, _customers_served, MAX_CUSTOMERS]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = final_qualifies(_customers_served >= QUALIFY_SERVED and _lost <= MAX_LOST_TO_QUALIFY)
	_set_status("Service terminé · %d clients · %d partis fâchés · R$ %d en tips" % [_customers_served, _lost, _total_tips])
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("valet", {"tips": _total_tips, "served": _customers_served, "qualifies": qualifies})
	match_ended.emit(qualifies, _total_tips)

# --- Habillage (rendu seul : la logique reste sur les ColorRect) ---

func _dress() -> void:
	if arena == null:
		return
	var floor_rect: ColorRect = arena.get_node_or_null("Floor") as ColorRect
	if floor_rect:
		floor_rect.color = ValetArt.ASPHALT
	var court: Sprite2D = ValetArt.backdrop()
	arena.add_child(court)
	arena.move_child(court, 1 if floor_rect else 0)
	for i in range(_slot_highlights.size()):
		var rect: ColorRect = _slot_highlights[i]
		if rect:
			rect.color = Color(0, 0, 0, 0)
	if player_node:
		player_node.color = Color(0, 0, 0, 0)
		player_node.z_index = 4
		_valet_sprite = char_sprite(96.0, {
			"skin": CharacterSpriteFactory.PALETTE_SKIN[2],
			"hair_color": CharacterSpriteFactory.PALETTE_HAIR_COLOR[0],
			"hair_style": "short",
			"shirt_color": Color(0.80, 0.13, 0.15),   # gilet rouge du voiturier
			"shirt_pattern": "pocket",
			"pants_color": Color(0.14, 0.14, 0.18),
			"hat_style": "none",
			"hat_color": Color(0.14, 0.14, 0.18),
		})
		_valet_sprite.position = Vector2(PLAYER_RADIUS, PLAYER_RADIUS + 36.0)
		player_node.add_child(_valet_sprite)
		player_node.move_child(_valet_sprite, 0)
	_dress_tutorial()

func _dress_car(car: ColorRect, art_color: Color, kind: int) -> void:
	car.color = Color(0, 0, 0, 0)
	var art: Sprite2D = Sprite2D.new()
	art.name = "Art"
	art.texture = ValetArt.car(art_color, kind)
	art.centered = false
	art.scale = Vector2(ValetArt.N, ValetArt.N)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	car.add_child(art)
	var hz: Sprite2D = Sprite2D.new()
	hz.name = "Hazard"
	hz.texture = ValetArt.hazard()
	hz.centered = false
	hz.scale = art.scale
	hz.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hz.visible = false
	car.add_child(hz)
	var badge: Sprite2D = Sprite2D.new()
	badge.name = "Badge"
	badge.texture = ValetArt.alert_badge()
	badge.scale = art.scale
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.position = Vector2(CAR_W * 0.5, -30.0)
	badge.z_index = 6
	badge.visible = false
	car.add_child(badge)
	var honk: Node2D = Node2D.new()
	honk.name = "Honk"
	honk.visible = false
	honk.z_index = 6
	for side in [-1, 1]:
		var w: Sprite2D = Sprite2D.new()
		w.texture = ValetArt.honk_waves()
		w.scale = art.scale
		w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		w.flip_h = side < 0
		w.position = Vector2(CAR_W * 0.5 + side * (CAR_W * 0.5 + 12.0), 12.0)
		honk.add_child(w)
	car.add_child(honk)

func _elegant_config(seed_value: int) -> Dictionary:
	var cfg: Dictionary = CharacterSpriteFactory.random_config(seed_value)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	cfg["shirt_color"] = ELEGANT_SHIRTS[rng.randi() % ELEGANT_SHIRTS.size()]
	cfg["pants_color"] = ELEGANT_PANTS[rng.randi() % ELEGANT_PANTS.size()]
	cfg["shirt_pattern"] = "solid" if rng.randf() < 0.7 else "pocket"
	cfg["hat_style"] = "fedora" if rng.randf() < 0.3 else "none"
	cfg["hat_color"] = Color(0.92, 0.85, 0.55) if rng.randf() < 0.5 else Color(0.18, 0.18, 0.22)
	return cfg

# Le client attend sur le porche : à l'arrivée (il confie ses clés) ou quand
# il redemande sa voiture (ticket à la couleur de la voiture).
func _seat_client(c: Dictionary, wants_car: bool) -> void:
	if arena == null:
		return
	var spot: int = -1
	for i in range(PORCH_SPOTS.size()):
		if not _spots_taken.has(i):
			spot = i
			break
	if spot < 0:
		return
	_spots_taken[spot] = c
	c.spot = spot
	var client: Node2D = c.client as Node2D
	if client == null or not is_instance_valid(client):
		client = Node2D.new()
		client.z_index = 3
		var body: Sprite2D = char_sprite(96.0, _elegant_config(7919 * (_cars.find(c) + 3)))
		body.name = "Body"
		client.add_child(body)
		var ticket: Sprite2D = Sprite2D.new()
		ticket.name = "Ticket"
		ticket.centered = false
		ticket.scale = Vector2(ValetArt.N, ValetArt.N)
		ticket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ticket.position = Vector2(-21.0, -96.0 - 48.0)
		client.add_child(ticket)
		var fill: ColorRect = ColorRect.new()
		fill.name = "Fill"
		fill.position = ticket.position + Vector2(9.0, 33.0)
		fill.size = Vector2(24.0, 6.0)
		client.add_child(fill)
		arena.add_child(client)
		c.client = client
	(client.get_node("Ticket") as Sprite2D).texture = ValetArt.client_ticket(c.art_color, wants_car)
	client.position = Vector2(PORCH_SPOTS[spot], PORCH_Y)
	client.visible = true

func _release_client(c: Dictionary) -> void:
	if int(c.get("spot", -1)) >= 0:
		_spots_taken.erase(int(c.spot))
	c.spot = -1
	var client: Node2D = c.get("client") as Node2D
	if client and is_instance_valid(client):
		client.visible = false

func _update_clients(t: float) -> void:
	var elapsed: float = DURATION - _time_left
	for c in _cars:
		var client: Node2D = c.get("client") as Node2D
		if client == null or not is_instance_valid(client) or not client.visible:
			continue
		var ratio: float = 1.0
		if c.requested_pending:
			ratio = 1.0 - (elapsed - float(c.requested_at)) / RESPONSE_WINDOW
		elif c.status == CarStatus.ARRIVING:
			ratio = 1.0 - (elapsed - float(c.arrived_at)) / HONK_AFTER
		ratio = clampf(ratio, 0.0, 1.0)
		var fill: ColorRect = client.get_node("Fill") as ColorRect
		fill.size.x = snappedf(24.0 * ratio, 3.0)
		var col: Color = Color(0.36, 0.86, 0.36)
		if ratio < 0.35:
			col = Color(0.95, 0.24, 0.20) if fmod(t, 0.4) < 0.2 else Color(0.70, 0.12, 0.12)
		elif ratio < 0.65:
			col = Color(0.98, 0.78, 0.20)
		fill.color = col
		# Impatient : il tape du pied.
		var body: Sprite2D = client.get_node("Body") as Sprite2D
		var frame: int = 0
		if ratio < 0.35 and fmod(t, 0.3) < 0.15:
			frame = 1
		body.region_rect = Rect2(frame * CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.DIR_DOWN * CharacterSpriteFactory.CELL_H,
			CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)

func _animate_valet(dir: Vector2, delta: float) -> void:
	if _valet_sprite == null:
		return
	# Au volant : le voiturier est dans la voiture.
	_valet_sprite.visible = _carried_idx < 0
	var row: int = CharacterSpriteFactory.DIR_DOWN
	var col: int = 0
	if dir.length() > 0.1:
		_walk_t += delta
		col = 1 + int(_walk_t / 0.14) % 2
		if absf(dir.x) > absf(dir.y):
			row = CharacterSpriteFactory.DIR_RIGHT
			_facing_left = dir.x < 0.0
		elif dir.y < 0.0:
			row = CharacterSpriteFactory.DIR_UP
	else:
		_walk_t = 0.0
		var prev_row: int = int(_valet_sprite.region_rect.position.y / CharacterSpriteFactory.CELL_H)
		row = prev_row
	_valet_sprite.flip_h = row == CharacterSpriteFactory.DIR_RIGHT and _facing_left
	_valet_sprite.region_rect = Rect2(col * CharacterSpriteFactory.CELL_W, row * CharacterSpriteFactory.CELL_H,
		CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)

# Panneau tutoriel : vignette « voiturier · voiture · cliente » sous le titre.
func _dress_tutorial() -> void:
	var layout: VBoxContainer = get_node_or_null("UI/Tutorial/Panel/Margin/Layout") as VBoxContainer
	if layout == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Illustration"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var valet_cfg: Dictionary = {
		"skin": CharacterSpriteFactory.PALETTE_SKIN[2],
		"hair_color": CharacterSpriteFactory.PALETTE_HAIR_COLOR[0],
		"hair_style": "short", "shirt_color": Color(0.80, 0.13, 0.15),
		"shirt_pattern": "pocket", "pants_color": Color(0.14, 0.14, 0.18),
		"hat_style": "none", "hat_color": Color(0.14, 0.14, 0.18),
	}
	var cell: Rect2 = Rect2(0, 0, CharacterSpriteFactory.CELL_W, CharacterSpriteFactory.CELL_H)
	var valet: AtlasTexture = AtlasTexture.new()
	valet.atlas = CharacterSpriteFactory.build_sheet(valet_cfg)
	valet.region = cell
	var guest: AtlasTexture = AtlasTexture.new()
	guest.atlas = CharacterSpriteFactory.build_sheet(_elegant_config(7919 * 4))
	guest.region = cell
	var pics: Array = [
		[valet, Vector2(64, 96)],
		[ValetArt.car(ValetArt.LUX_COLORS[0], 2), Vector2(64, 96)],
		[ValetArt.car(ValetArt.LUX_COLORS[3], 1), Vector2(64, 96)],
		[guest, Vector2(64, 96)],
	]
	for p in pics:
		var tr: TextureRect = TextureRect.new()
		tr.texture = p[0]
		tr.custom_minimum_size = p[1]
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	layout.add_child(row)
	layout.move_child(row, 1)

# Mise en scène pour les captures (preview == "busy").
func _stage_preview() -> void:
	for k in [0, 2, 3]:
		_spawn_arriving_car()
		var c: Dictionary = _cars[_cars.size() - 1]
		_player_pos = (c.node as ColorRect).position + Vector2(CAR_W * 0.5, CAR_H * 0.5)
		_action_pickup()
		_player_pos = SLOTS[k]
		_action_drop()
	_cars[1].parked_at = -100.0
	_update_cars()
	_spawn_arriving_car()
	_cars[_cars.size() - 1].arrived_at = -100.0
	_update_cars()
	_player_pos = Vector2(1180.0, 520.0)
	_spawn_cooldown = 60.0
