class_name ValetGame
extends Node2D

# Mini-jeu valet du Copa Palace.
# Cycle : voiture arrive à l'entrée → garer dans une place libre → patience client →
# voiture réclamée (clignote) → ramener à l'entrée. Tip selon vitesse de réponse.
# Tolérant : vitesse haute, portées larges, surlignage des cibles, labels contextuels.

signal match_ended(qualifies: bool, tips: int)

const DURATION: float = 120.0
const MAX_CUSTOMERS: int = 4

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
const PATIENCE: float = 16.0
const RESPONSE_WINDOW: float = 22.0
const SPAWN_DELAY_AFTER_RETURN: float = 1.0
const SPAWN_DELAY_INITIAL: float = 0.5

enum CarStatus { ARRIVING, CARRIED, PARKED, REQUESTED, DELIVERED }

var _time_left: float = DURATION
var _customers_served: int = 0
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

var _tutorial_visible: bool = true

func _ready() -> void:
	EventBus.minigame_started.emit("valet")
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
	_collect_slot_highlights()
	_set_status("Bem-vindo ao Copa. Le service ouvre.")
	if prompt_label:
		prompt_label.text = "[E] Prendre · Garer · Restituer    [WASD/Flèches] Bouger"
	_refresh_drop_zone_visual()
	if tutorial_button:
		tutorial_button.pressed.connect(_close_tutorial)
	if help_button:
		help_button.pressed.connect(_open_tutorial)
	if tutorial_root:
		tutorial_root.visible = true
	if help_button:
		help_button.visible = false

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
	if _time_left <= 0.0 or _customers_served >= MAX_CUSTOMERS:
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

func _open_tutorial() -> void:
	_tutorial_visible = true
	if tutorial_root:
		tutorial_root.visible = true
	if help_button:
		help_button.visible = false

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
	_occupied_slots[best_slot] = _carried_idx
	_carried_idx = -1
	_set_status("Place %d occupée. Continue le service." % (best_slot + 1))

func _deliver(c: Dictionary) -> void:
	var elapsed: float = DURATION - _time_left
	var waited: float = elapsed - float(c.requested_at)
	var ratio: float = clamp(1.0 - waited / RESPONSE_WINDOW, 0.0, 1.0)
	var tip: int = int(round(TIP_BASE + (TIP_MAX - TIP_BASE) * ratio))
	_total_tips += tip
	_customers_served += 1
	c.status = CarStatus.DELIVERED
	(c.node as ColorRect).queue_free()
	_carried_idx = -1
	_spawn_cooldown = SPAWN_DELAY_AFTER_RETURN
	_set_status("+R$ %d tip ! (%d/%d clients)" % [tip, _customers_served, MAX_CUSTOMERS])

# --- Cycle clients ---

func _update_cars() -> void:
	var elapsed: float = DURATION - _time_left
	for c in _cars:
		if c.status == CarStatus.PARKED:
			if elapsed - float(c.parked_at) >= PATIENCE:
				c.status = CarStatus.REQUESTED
				c.requested_pending = true
				c.requested_at = elapsed

func _maybe_spawn_next() -> void:
	if _spawn_cooldown > 0.0:
		return
	if _total_spawned >= MAX_CUSTOMERS:
		return
	for c in _cars:
		if c.status == CarStatus.ARRIVING:
			return
	if _occupied_slots.size() >= SLOTS.size():
		return  # Les places sont pleines : on attend que le joueur restitue.
	_spawn_arriving_car()

func _spawn_arriving_car() -> void:
	var car: ColorRect = ColorRect.new()
	car.size = Vector2(CAR_W, CAR_H)
	car.color = CAR_COLORS[_total_spawned % CAR_COLORS.size()]
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
	})
	_total_spawned += 1
	_set_status("Nouvelle voiture à l'entrée !")

# --- Affordances visuelles ---

func _update_visuals() -> void:
	# Place : libres en vert vif quand le joueur porte une voiture, sinon estompées.
	var carrying: bool = _carried_idx >= 0
	for i in range(_slot_highlights.size()):
		var rect: ColorRect = _slot_highlights[i]
		if rect == null:
			continue
		if _occupied_slots.has(i):
			rect.color = Color(0.4, 0.4, 0.45, 0.35)
		elif carrying:
			rect.color = Color(0.55, 0.95, 0.55, 0.55)
		else:
			rect.color = Color(0.55, 0.55, 0.6, 0.4)
	# Voitures réclamées : pulsation rouge claire (incluant celles portées par le joueur).
	var t: float = Time.get_ticks_msec() / 1000.0
	for c in _cars:
		if c.status == CarStatus.DELIVERED:
			continue
		if c.requested_pending:
			var pulse: float = 1.1 + 0.4 * sin(t * 6.0)
			(c.node as ColorRect).modulate = Color(pulse, pulse * 0.85, pulse * 0.85, 1.0)
		else:
			(c.node as ColorRect).modulate = Color(1, 1, 1, 1)
	_refresh_drop_zone_visual()
	_refresh_context_label()

func _refresh_drop_zone_visual() -> void:
	if drop_zone_rect == null or drop_zone_label == null:
		return
	var carrying_requested: bool = false
	if _carried_idx >= 0:
		carrying_requested = _cars[_carried_idx].requested_pending
	if carrying_requested:
		drop_zone_rect.color = Color(0.55, 0.95, 0.55, 0.55)
		drop_zone_label.text = "RESTITUER ICI"
	else:
		drop_zone_rect.color = Color(0.85, 0.78, 0.45, 0.5)
		drop_zone_label.text = "ENTRÉE — clients arrivent ici"

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
				msg = "[E] Récupérer pour le client"
			else:
				msg = "[E] Prendre la voiture"
	else:
		var c: Dictionary = _cars[_carried_idx]
		if DROP_ZONE.has_point(_player_pos) and c.requested_pending:
			msg = "[E] RESTITUER"
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
			msg = "[E] Garer ici" if near_free_slot else "→ Trouve une place libre"
	context_label.text = msg

# --- UI / fin ---

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func _update_labels() -> void:
	if timer_label:
		timer_label.text = "%.1fs" % max(_time_left, 0.0)
	if tip_label:
		tip_label.text = "💰 R$ %d (%d/%d)" % [_total_tips, _customers_served, MAX_CUSTOMERS]

func _end_game() -> void:
	if _ended:
		return
	_ended = true
	var qualifies: bool = _customers_served > 0
	_set_status("Service terminé · %d clients · R$ %d en tips" % [_customers_served, _total_tips])
	await get_tree().create_timer(2.4).timeout
	EventBus.minigame_ended.emit("valet", {"tips": _total_tips, "served": _customers_served, "qualifies": qualifies})
	match_ended.emit(qualifies, _total_tips)
