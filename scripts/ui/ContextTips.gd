class_name ContextTips
extends CanvasLayer

# Astuces contextuelles : remplacent le guide d'accueil de 6 pages qui mettait
# le jeu en pause au 1er lancement. Chaque astuce tient en une ligne, apparaît
# au moment où le geste sert (première interaction, premier objectif, premier
# pas sur le sable…), désigne le bouton concerné d'un anneau doré et s'en va
# seule — dès que le geste est fait ou au bout de quelques secondes. Jamais de
# pause, jamais rien à fermer. Vue une fois = vue pour de bon (Settings).

const TIPS: Dictionary = {
	"bouger": {
		"touch": "Glisse le pouce ici pour marcher",
		"pad": "Stick gauche pour marcher",
		"keys": "Flèches ou ZQSD pour marcher",
		"target": "MobileLayer/MobileControls/Joystick",
		"ttl": 12.0,
	},
	"parler": {
		"touch": "Touche ✋ : parler, prendre, acheter",
		"pad": "Ⓐ : parler, prendre, acheter",
		"keys": "[E] : parler, prendre, acheter",
		"target": "MobileLayer/MobileControls/InteractButton",
		"ttl": 10.0,
	},
	"objectif": {
		"all": "Ton prochain pas est écrit ici.\nLa flèche dorée t'y emmène.",
		"target": "UI/ObjectiveBanner",
		"ttl": 7.0,
	},
	"telephone": {
		"touch": "📱 Ton téléphone : taxi, Diário, réglages",
		"pad": "Ⓨ : ton téléphone (taxi, Diário, réglages)",
		"keys": "[P] : ton téléphone (taxi, Diário, réglages)",
		"target": "UI/HUD/MenuButton",
		"ttl": 8.0,
	},
	"courir": {
		"touch": "Touche 🏃 pour courir — ça te coupe le souffle",
		"pad": "Tiens Ⓑ pour courir — ça te coupe le souffle",
		"keys": "Tiens [Shift] pour courir — ça te coupe le souffle",
		"target": "MobileLayer/MobileControls/RunButton",
		"ttl": 8.0,
	},
	"carrocinha": {
		"all": "🌽 Ton stock de milho.\nVa vers les gens, ils t'achètent un épi.",
		"target": "UI/HUD/Top/StockLabel",
		"ttl": 8.0,
	},
	"acompte": {
		"all": "Ce que le consortium attend de toi.\nChaque real versé te rapproche du prochain acte.",
		"target": "UI/HUD/Top/DebtLabel",
		"ttl": 8.0,
	},
	"altinha": {
		"touch": "⚽ Du sable, du monde : une roda d'altinha ?",
		"pad": "Ⓧ : une roda d'altinha sur le sable",
		"keys": "[Espace] : une roda d'altinha sur le sable",
		"target": "MobileLayer/MobileControls/AltinhaButton",
		"ttl": 9.0,
	},
}

# Temps de marche cumulé avant de souffler l'astuce « courir ».
const WALK_BEFORE_RUN_TIP: float = 15.0
# Une astuce interrompue après ce délai compte comme lue.
const MIN_READ_TIME: float = 3.0
const MOVE_DONE_DIST: float = 140.0
const POLL_INTERVAL: float = 0.25

var _queue: Array[String] = []
var _current: String = ""
var _shown_for: float = 0.0
var _show_pos: Vector2 = Vector2.ZERO
var _target: Control = null
var _in_dialogue: bool = false
var _in_minigame: bool = false
var _walk_time: float = 0.0
var _poll: float = 0.0
var _last_money: int = -1
var _pulse: float = 0.0

var _overlay: Control
var _bubble: Label
var _tween: Tween


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Test : `godot --path . -- --astuces` rejoue toutes les astuces.
	if "--astuces" in OS.get_cmdline_user_args():
		Settings.reset_tips()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_pointer)
	add_child(_overlay)
	_bubble = Label.new()
	_bubble.theme_type_variation = &"Pastille"
	_bubble.add_theme_font_size_override("font_size", 28)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_overlay.add_child(_bubble)
	EventBus.interaction_available.connect(func(_n: Node) -> void: request("parler"))
	EventBus.interaction_lost.connect(_on_interaction_lost)
	EventBus.quest_accepted.connect(func(_q: String) -> void: request("objectif"))
	EventBus.quest_completed.connect(func(_q: String) -> void: request("telephone"))
	EventBus.chase_started.connect(func(_c: String) -> void: request("courir"))
	EventBus.chrono_updated.connect(func(_s: String, _l: String, _t: float) -> void: request("courir"))
	EventBus.corn_cart_state_changed.connect(_on_cart_state)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(func(_n: String) -> void: _in_dialogue = false)
	EventBus.minigame_started.connect(_on_minigame_started)
	EventBus.minigame_ended.connect(func(_m: String, _r: Dictionary) -> void: _in_minigame = false)


# Met une astuce en file si elle n'a jamais été vue.
func request(id: String) -> void:
	if not TIPS.has(id) or Settings.has_seen_tip(id):
		return
	if id == _current or _queue.has(id):
		return
	_queue.append(id)


func current() -> String:
	return _current


static func input_mode() -> String:
	if GamepadBridge.active:
		return "pad"
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return "touch"
	return "keys"


static func text_for(id: String, mode: String) -> String:
	var tip: Dictionary = TIPS.get(id, {})
	return String(tip.get("all", tip.get(mode, "")))


func _process(delta: float) -> void:
	_pulse += delta
	if _current != "":
		_update_current(delta)
	_poll += delta
	if _poll >= POLL_INTERVAL:
		_poll = 0.0
		_poll_world()
	if _current == "" and not _queue.is_empty() and not _busy():
		_show(_queue.pop_front())


# Déclencheurs qui ne sont pas des événements : premier pas après l'ouverture,
# longue marche, pieds dans le sable.
func _poll_world() -> void:
	if _busy():
		return
	if CampaignManager.has_flag("narrative_intro_seen"):
		request("bouger")
	if not Settings.has_seen_tip("altinha") and BeachZone.altinha_here():
		request("altinha")
	var p: Node = GameManager.player
	if p is CharacterBody2D and (p as CharacterBody2D).velocity.length() > 10.0:
		_walk_time += POLL_INTERVAL
		if _walk_time >= WALK_BEFORE_RUN_TIP:
			request("courir")


func _busy() -> bool:
	if get_tree().paused or _in_dialogue or _in_minigame:
		return true
	if CutsceneRunner.is_running():
		return true
	var p: Node = GameManager.player
	return p == null or not is_instance_valid(p) or not p.is_physics_processing()


func _show(id: String) -> void:
	_current = id
	_shown_for = 0.0
	var p: Node = GameManager.player
	_show_pos = (p as Node2D).global_position if p is Node2D else Vector2.ZERO
	_bubble.text = text_for(id, input_mode())
	_bubble.reset_size()
	_bubble.visible = true
	_bubble.pivot_offset = _bubble.size * 0.5
	_bubble.scale = Vector2(0.6, 0.6)
	_bubble.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	_place()


# `seen` : l'astuce a fait son office (geste fait, lue assez longtemps) et ne
# reviendra plus ; sinon elle retourne en tête de file.
func _hide(seen: bool) -> void:
	if _current == "":
		return
	if seen:
		Settings.mark_tip_seen(_current)
	else:
		_queue.push_front(_current)
	_current = ""
	_target = null
	_bubble.visible = false
	_overlay.queue_redraw()


func _update_current(delta: float) -> void:
	if _busy():
		# Ouvrir le téléphone pendant son astuce, c'est l'avoir comprise.
		var learned: bool = _current == "telephone" and get_tree().paused
		_hide(learned or _shown_for >= MIN_READ_TIME)
		return
	_shown_for += delta
	var tip: Dictionary = TIPS[_current]
	if _shown_for >= float(tip.get("ttl", 8.0)):
		_hide(true)
		return
	match _current:
		"bouger":
			var p: Node = GameManager.player
			if p is Node2D and (p as Node2D).global_position.distance_to(_show_pos) >= MOVE_DONE_DIST:
				_hide(true)
				return
		"altinha":
			if not BeachZone.altinha_here():
				_hide(_shown_for >= MIN_READ_TIME)
				return
	_place()


# La bulle se pose du côté du bouton qui regarde le centre de l'écran, assez
# loin pour ne pas masquer le pouce ; sans bouton visible, au tiers bas.
func _place() -> void:
	var view: Vector2 = _overlay.get_viewport_rect().size
	_target = _find_target(String(TIPS[_current].get("target", "")))
	var half: Vector2 = _bubble.size * 0.5
	var center: Vector2 = Vector2(view.x * 0.5, view.y * 0.68)
	if _target:
		var r: Rect2 = _target.get_global_rect()
		var c: Vector2 = r.get_center()
		var dir: Vector2 = (view * 0.5 - c).normalized()
		var reach: float = r.size.length() * 0.5 + 40.0
		center = c + dir * (reach + absf(dir.x) * half.x + absf(dir.y) * half.y)
	var margin: float = 24.0
	center.x = clampf(center.x, half.x + margin, view.x - half.x - margin)
	center.y = clampf(center.y, half.y + margin, view.y - half.y - margin)
	_bubble.position = center - half
	_overlay.queue_redraw()


func _find_target(path: String) -> Control:
	if path == "":
		return null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var n: Node = scene.get_node_or_null(path)
	if n is Control and (n as Control).is_visible_in_tree():
		return n
	return null


# Anneau doré qui respire autour du bouton + trait jusqu'à la bulle.
func _draw_pointer() -> void:
	if _current == "" or _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return
	var r: Rect2 = _target.get_global_rect()
	var c: Vector2 = r.get_center()
	var radius: float = r.size.length() * 0.5 * 0.8 + 10.0 + sin(_pulse * 5.0) * 5.0
	var gold: Color = UITheme.GOLD
	var ink: Color = Color(0.1, 0.06, 0.16, 0.8)
	_overlay.draw_arc(c, radius, 0.0, TAU, 48, ink, 9.0)
	_overlay.draw_arc(c, radius, 0.0, TAU, 48, gold, 5.0)
	var b: Rect2 = _bubble.get_rect()
	var from: Vector2 = c + (b.get_center() - c).normalized() * (radius + 6.0)
	var to: Vector2 = _closest_point(b, c)
	if from.distance_to(to) > 12.0 and not b.has_point(from):
		_overlay.draw_line(from, to, ink, 8.0)
		_overlay.draw_line(from, to, gold, 4.0)


func _closest_point(rect: Rect2, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))


func _on_interaction_lost(_n: Node) -> void:
	# On s'est éloigné avant d'agir : l'astuce reviendra à la prochaine occasion.
	if _current == "parler":
		_hide(false)
		_queue.erase("parler")


# Une cinématique ouvre aussi un dialogue : seule l'astuce affichée compte
# comme apprise, pas celle encore en file.
func _on_dialogue_started(_n: String) -> void:
	_in_dialogue = true
	if _current == "parler":
		_hide(true)


func _on_cart_state(carrying: bool) -> void:
	if carrying:
		request("carrocinha")


func _on_minigame_started(_m: String) -> void:
	_in_minigame = true
	if _current == "altinha":
		_hide(true)


func _on_money_changed(amount: int) -> void:
	if _last_money >= 0 and amount > _last_money:
		request("acompte")
	_last_money = amount
