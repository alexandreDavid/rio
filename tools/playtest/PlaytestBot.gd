extends Node

# Bot-joueur « grandeur nature » (headless, --fixed-fps 60).
# Instancie le VRAI jeu (Main.tscn, nouvelle partie) et le joue comme un joueur
# moyen : il ne connaît que ce que le HUD lui montre (bandeau d'objectif +
# boussole = NavigationDirector, prompt d'interaction, téléphone), il MARCHE
# (inputs injectés, vitesse/stamina réelles), lit les dialogues à vitesse
# humaine, cherche quand le guidage ne pointe rien, paie le taxi, accepte des
# missions pour gagner l'argent demandé. Les mini-jeux sont simulés (durée
# nominale + résultat d'un joueur moyen qui progresse).
# Tout est journalisé (JSON) pour mesurer rythme, temps morts, friction.
# Usage : tools/playtest/run_playtest.sh [budget_s] [sortie.json]

const NavScript: GDScript = preload("res://tools/playtest/BotNav.gd")
const COPA_BOUNDS: Rect2 = Rect2(-450, -1500, 3800, 2300)
const READ_CHARS_PER_SEC: float = 18.0      # ~220 mots/min
const READ_BASE_SEC: float = 0.6
const PHONE_SEC: float = 5.0                # ouvrir le téléphone, choisir
const INTERACT_COOLDOWN: float = 120.0      # on ne re-parle pas tout de suite au même
const WALK_TIMEOUT: float = 150.0
const STUCK_SEC: float = 1.2
const DECLINE_RE: String = "(?i)plus tard|réfléch|refus|pas maintenant|laisse tomber|je passe|une autre fois|pas aujourd|^non\\b|rien pour l'instant|je reviendrai"

var budget_sec: float = 5400.0
var stall_limit_sec: float = 900.0
var out_path: String = "user://playtest.json"

var _t: float = 0.0
var _wall0: int = 0
var _log: Array = []
var _state: String = "boot"
var _time_by_state: Dictionary = {}
var _main: Node
var _world: Node2D
var _player: CharacterBody2D
var _inv: Node
var _stamina: Node
var _nav = null
var _nav_key: String = ""
var _dist_walked: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _last_progress_t: float = 0.0
var _finished: bool = false
var _finish_reason: String = ""
var _interacted_at: Dictionary = {}   # instance_id -> t
var _tried_by_text: Dictionary = {}   # texte d'objectif -> {instance_id: true} (essayé sans progrès)
var _tried: Dictionary = {}           # vue courante (alias dans _tried_by_text)
var _failed_targets: Dictionary = {}  # instance_id/label -> t
var _knot_hist: Array = []            # [t, knot]
var _last_line: Dictionary = {}       # speaker, text
var _last_choices: Array = []
var _mg_attempts: Dictionary = {}
var _last_guidance: String = ""
var _interactables_cache: Array = []
var _interactables_cache_t: float = -100.0
var _interiors: Array = []
var _money_prev: int = 0
var _taxi_spent: int = 0
var _counters: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20261007
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		budget_sec = float(args[0])
	if args.size() >= 2:
		out_path = args[1]
	_wall0 = Time.get_ticks_msec()
	await _run()


func _process(delta: float) -> void:
	_t += delta
	_time_by_state[_state] = float(_time_by_state.get(_state, 0.0)) + delta
	if _player != null and is_instance_valid(_player):
		var p: Vector2 = _player.global_position
		if _last_pos != Vector2.ZERO:
			var d: float = p.distance_to(_last_pos)
			if d < 60.0:  # > 60 px en 1 frame = téléport, pas de la marche
				_dist_walked += d
		_last_pos = p


# ---------------------------------------------------------------- journal

var _last_ev_sig: String = ""
var _last_ev_t: float = -1.0
func _ev(kind: String, detail: Dictionary = {}) -> void:
	var sig: String = kind + JSON.stringify(detail)
	if sig == _last_ev_sig and _t - _last_ev_t < 1.0 and kind in ["no_path", "travel_walk", "travel_walk_failed", "wander", "unreachable", "no_prompt"]:
		return
	_last_ev_sig = sig
	_last_ev_t = _t
	var e: Dictionary = {"t": snappedf(_t, 0.1), "k": kind}
	for key in detail:
		e[key] = detail[key]
	if _player != null and is_instance_valid(_player):
		e["pos"] = [int(_player.global_position.x), int(_player.global_position.y)]
	e["dist"] = DistrictManager.current()
	e["money"] = _money()
	e["debt"] = CampaignManager.debt_paid
	e["act"] = CampaignManager.current_act
	_log.append(e)
	_counters[kind] = int(_counters.get(kind, 0)) + 1
	print("[bot %7.1fs] %-14s %s" % [_t, kind, JSON.stringify(detail)])


func _set_state(s: String) -> void:
	if s != _state:
		_state = s


func _progress() -> void:
	_last_progress_t = _t


func _progress_quest() -> void:
	_last_progress_t = _t
	_tried_by_text.clear()
	_tried = {}
	_tried_by_text[_last_guidance] = _tried


func _money() -> int:
	if _inv == null:
		return 0
	return int(_inv.get("money"))


# ---------------------------------------------------------------- boucle

func _run() -> void:
	await get_tree().process_frame
	# Protège les vraies sauvegardes : aucune écriture pendant la session.
	SaveSystem._loading = true
	_connect_signals()
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	# Le jeu résout « World », les mini-jeux et les marqueurs via current_scene :
	# Main doit être la scène courante, comme en jeu réel.
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	for i in 12:
		await get_tree().process_frame
	_player = GameManager.player as CharacterBody2D
	if _player == null:
		push_error("[bot] pas de joueur")
		get_tree().quit(2)
		return
	_world = _main.get_node("World") as Node2D
	_inv = _player.get_node_or_null("Inventory")
	_stamina = _player.get_node_or_null("Stamina")
	_money_prev = _money()
	for n in _world.find_children("*", "Node2D", true, false):
		if n.scene_file_path.contains("/interiors/"):
			_interiors.append(n)
	_ev("start", {"budget": budget_sec, "district": DistrictManager.current(),
			"save_present": SaveSystem.has_save()})
	_last_progress_t = 0.0
	var next_dump: float = 300.0
	while not _finished:
		if _t >= next_dump:
			next_dump += 300.0
			_dump(false)
		if _t >= budget_sec:
			_finish("budget de temps atteint")
			break
		if _t - _last_progress_t > stall_limit_sec:
			_finish("aucun progrès depuis %d s" % int(stall_limit_sec))
			break
		await _tick()
	_dump()
	get_tree().quit(0)


func _finish(reason: String) -> void:
	_finished = true
	_finish_reason = reason
	_ev("end", {"reason": reason})


func _connect_signals() -> void:
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_failed.connect(func(q: String) -> void:
		_tried.clear()
		_ev("quest_failed", {"q": q}))
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.reputation_changed.connect(func(ax: String, v: int) -> void: _ev("rep", {"axis": ax, "value": v}))
	EventBus.notification_requested.connect(func(t: String, _c: Color) -> void: _ev("toast", {"text": t}))
	EventBus.chrono_updated.connect(_on_chrono_updated)
	EventBus.chrono_cleared.connect(_on_chrono_cleared)
	EventBus.chase_started.connect(func(c: String) -> void: _ev("chase_started", {"chaser": c}))
	EventBus.chase_ended.connect(_on_chase_ended)
	EventBus.minigame_started.connect(func(id: String) -> void: _ev("minigame_started", {"id": id}))
	EventBus.minigame_ended.connect(_on_minigame_ended)
	EventBus.time_of_day_changed.connect(func(p: int) -> void: _ev("phase", {"phase": p}))
	EventBus.day_elapsed.connect(func(d: int) -> void: _ev("day", {"day": d}))
	EventBus.dialogue_started.connect(func(npc: String) -> void: _ev("dialogue_started", {"npc": npc, "knot": DialogueBridge._active_knot}))
	EventBus.dialogue_ended.connect(func(npc: String) -> void: _ev("dialogue_ended", {"npc": npc}))
	DistrictManager.district_changed.connect(func(d: String) -> void: _ev("district", {"to": d}))
	DialogueBridge.line_shown.connect(_on_line_shown)
	DialogueBridge.choices_presented.connect(_on_choices_presented)
	NavigationDirector.nav_target_changed.connect(_on_guidance)
	DynamicMissionManager.mission_completed.connect(_on_mission_completed)
	DynamicMissionManager.mission_expired.connect(func(c: int) -> void: _ev("mission_expired", {"cat": c}))
	_on_guidance()


func _on_quest_accepted(q: String) -> void:
	_progress_quest()
	_ev("quest_accepted", {"q": q, "name": _qname(q), "main": _qmain(q)})


func _on_quest_updated(q: String, o: String) -> void:
	_progress_quest()
	_ev("objective_done", {"q": q, "o": o})


func _on_quest_completed(q: String) -> void:
	_progress_quest()
	_ev("quest_completed", {"q": q, "name": _qname(q), "main": _qmain(q)})


func _on_money_changed(m: int) -> void:
	var d: int = m - _money_prev
	_money_prev = m
	if d == 0:
		return
	if d > 0:
		_progress()
	_ev("money", {"delta": d})


func _on_debt_paid(a: int, r: int) -> void:
	_progress_quest()
	_ev("debt_paid", {"amount": a, "remaining": r})


func _on_act_changed(a: int) -> void:
	_progress_quest()
	_ev("act_changed", {"act": a})


func _on_chrono_updated(src: String, label: String, s: float) -> void:
	if _counters.has("chrono:" + src):
		return
	_counters["chrono:" + src] = 1
	_ev("chrono_start", {"src": src, "label": label, "sec": int(s)})


func _on_chrono_cleared(src: String) -> void:
	_counters.erase("chrono:" + src)
	_ev("chrono_end", {"src": src})
	if src == "stakeout" or src.begins_with("chase:"):
		_tried.clear()  # on peut retenter auprès du donneur


func _on_chase_ended(c: String, e: bool) -> void:
	if e:
		_progress()
	_ev("chase_ended", {"chaser": c, "escaped": e})


func _on_minigame_ended(id: String, r: Dictionary) -> void:
	_ev("minigame_ended", {"id": id, "ok": bool(r.get("qualifies", r.get("won", false)))})


func _on_line_shown(sp: String, tx: String) -> void:
	_last_line = {"speaker": sp, "text": tx}


func _on_choices_presented(ch: Array) -> void:
	_last_choices = ch.duplicate()


func _on_mission_completed(c: int, m: int, _r: int) -> void:
	_progress()
	_ev("mission_completed", {"cat": c, "money": m})


func _on_guidance() -> void:
	var txt: String = NavigationDirector.current_text()
	if txt != _last_guidance:
		_last_guidance = txt
		if not _tried_by_text.has(txt):
			_tried_by_text[txt] = {}
		_tried = _tried_by_text[txt]
		var live: Dictionary = NavigationDirector.get_live()
		_ev("guidance", {"text": txt, "kind": int(live.kind), "target_dist": String(NavigationDirector._sel.get("dist", ""))})


func _qname(q: String) -> String:
	var qq: Quest = QuestManager.get_quest(q)
	return qq.display_name if qq else q


func _qmain(q: String) -> bool:
	var qq: Quest = QuestManager.get_quest(q)
	return qq != null and qq.quest_type == Quest.QuestType.MAIN


# ---------------------------------------------------------------- un cycle

func _tick() -> void:
	# 1. Carte d'acte (le jeu est en pause tant qu'elle est affichée).
	var card: Node = get_tree().get_first_node_in_group("act_card")
	if card != null and bool(card.get("_showing")):
		_set_state("lecture")
		await _wait(4.0)
		_ev("act_card", {"act": CampaignManager.current_act})
		card.call("_dismiss")
		await _frame()
		return
	# 2. UI modales ouvertes par une interaction (taxi, missions) : on referme.
	var closed_any: bool = false
	for ui_name in ["TaxiUI", "MissionBoardUI", "JournalUI", "Phone", "QuestLog"]:
		var ui: Node = _main.get_node_or_null(ui_name)
		if ui != null and ("visible" in ui) and bool(ui.get("visible")) and ui.has_method("close"):
			await _wait(4.0)  # on lit l'écran
			ui.call("close")
			_ev("ui_closed", {"ui": ui_name})
			closed_any = true
			if ui_name == "MissionBoardUI":
				await _accept_best_mission("tableau")
	if closed_any:
		await _frame()
		return
	if get_tree().paused:
		_ev("paused_unknown", {})
		get_tree().paused = false
		await _frame()
		return
	# 2b. En selle (vélo de location) : on descend, les interactions sont ignorées sinon.
	if _player.has_method("is_mounted") and bool(_player.call("is_mounted")):
		var veh: Node = _player.get("_mounted_vehicle")
		if veh != null and veh.has_method("dismount"):
			veh.call("dismount")
			_ev("dismount", {"vehicle": veh.name})
			await _frame()
			return
	# 3. Dialogue.
	if DialogueBridge.is_active():
		await _handle_dialogue()
		return
	# 4. Cutscene sans dialogue : on regarde.
	if CutsceneRunner.is_running():
		_set_state("cutscene")
		await _frame()
		return
	# 5. Mini-jeu actif.
	var mg: Node = _find_active_minigame()
	if mg != null:
		await _simulate_minigame(mg)
		return
	# 6. Poursuite / planque.
	var chaser: Node2D = _find_node_of_class("CobradorChase")
	if chaser != null:
		await _flee(chaser)
		await _frame()
		return
	var stake: Node2D = _find_node_of_class("StakeoutZone")
	if stake != null:
		await _stakeout(stake)
		await _frame()
		return
	# 7. Navigation selon le guidage.
	await _navigate()
	await _frame()


func _frame() -> void:
	await get_tree().physics_frame


func _wait(sec: float) -> void:
	var t0: float = _t
	while _t - t0 < sec and not _finished:
		await _frame()


# ---------------------------------------------------------------- dialogues

func _handle_dialogue() -> void:
	_set_state("dialogue")
	var knot: String = DialogueBridge._active_knot
	var text: String = String(_last_line.get("text", ""))
	var speaker: String = String(_last_line.get("speaker", ""))
	var choices: Array = _last_choices.duplicate()
	var read: float = READ_BASE_SEC + float(text.length()) / READ_CHARS_PER_SEC + 0.4 * choices.size()
	await _wait(read)
	if not DialogueBridge.is_active():
		return
	if DialogueBridge._active_knot != knot:
		return  # le knot a changé pendant la lecture (cutscene) : on relit
	_knot_hist.append([_t, knot])
	var repeats: int = 0
	for h in _knot_hist:
		if h[1] == knot and _t - h[0] < 90.0:
			repeats += 1
	var idx: int = _pick_choice(choices, repeats)
	_ev("dialogue", {"knot": knot, "speaker": speaker, "chars": text.length(), "read": snappedf(read, 0.1),
			"choices": choices.size(), "choice": idx,
			"choice_text": String(choices[idx]) if idx < choices.size() else "", "repeat": repeats})
	DialogueBridge.choose(idx)
	await _frame()
	await _frame()


func _pick_choice(choices: Array, repeats: int) -> int:
	if choices.is_empty():
		return 0
	if repeats >= 3:
		return choices.size() - 1  # ça boucle : on prend la sortie
	var money: int = _money()
	var re: RegEx = RegEx.new()
	re.compile(DECLINE_RE)
	var best: int = -1
	var best_cost: int = -1
	var first_affordable: int = -1
	for i in choices.size():
		var c: String = String(choices[i])
		var cost: int = _parse_cost(c)
		if cost > money:
			continue
		if first_affordable == -1:
			first_affordable = i
		if re.search(c) != null:
			continue
		if cost > best_cost:
			best = i
			best_cost = cost
	if best == -1:
		best = first_affordable if first_affordable != -1 else 0
	return best


func _parse_cost(c: String) -> int:
	var re: RegEx = RegEx.new()
	re.compile("R\\$\\s*(\\d[\\d\\s]*)|(\\d[\\d\\s]*)\\s*R\\$|(?i)(payer|poser|donner|verser|avancer|mettre)\\s+(\\d+)")
	var m: RegExMatch = re.search(c)
	if m == null:
		return 0
	for g in [1, 2, 4]:
		var s: String = m.get_string(g).replace(" ", "")
		if s != "" and s.is_valid_int():
			return int(s)
	return 0


# ---------------------------------------------------------------- mini-jeux

func _find_active_minigame() -> Node:
	for parent in [self, _main]:
		for n in parent.get_children():
			if n == _world or n == _main:
				continue
			if n.has_signal("match_ended"):
				return n
	return null


func _simulate_minigame(mg: Node) -> void:
	_set_state("minijeu")
	var id: String = String(mg.get("minigame_id")) if ("minigame_id" in mg) else mg.name
	var tries: int = int(_mg_attempts.get(id, 0))
	var p_ok: float = minf(0.85, 0.4 + 0.15 * tries)
	var ok: bool = _rng.randf() < p_ok
	var dur: float = 75.0
	if "DURATION" in mg:
		dur = float(mg.get("DURATION"))
	_ev("minigame_sim", {"id": id, "try": tries + 1, "ok": ok, "dur": dur})
	_mg_attempts[id] = tries + 1
	await _wait(dur)
	if not is_instance_valid(mg):
		return
	var args: Array = []
	for sig in mg.get_signal_list():
		if sig.name != "match_ended":
			continue
		for a in sig.args:
			var nm: String = String(a.name).to_lower()
			match int(a.type):
				TYPE_BOOL:
					args.append(ok if not nm.contains("rival") else ok)
				TYPE_INT:
					if nm.contains("opponent"):
						args.append(9 if ok else 15)
					elif nm.contains("integrity"):
						args.append(80 if ok else 30)
					else:
						args.append(30 if ok else 8)
				TYPE_FLOAT:
					args.append(40.0 if ok else 12.0)
				_:
					args.append(null)
	# Le jeu réel émet lui-même minigame_ended ; on le fait à sa place.
	if "minigame_id" in mg:
		EventBus.minigame_ended.emit(id, {"qualifies": ok, "won": ok})
	mg.callv("emit_signal", ["match_ended"] + args)
	await _frame()
	await _frame()
	if is_instance_valid(mg) and mg.is_inside_tree():
		mg.queue_free()
		if _world:
			_world.visible = true
			_world.process_mode = Node.PROCESS_MODE_INHERIT
		var ui: Node = _main.get_node_or_null("UI")
		if ui:
			(ui as CanvasItem).visible = true
	if ok:
		_progress()


# ---------------------------------------------------------------- poursuite / planque

func _find_node_of_class(cls: String) -> Node2D:
	for parent in [_world, _main, get_tree().current_scene]:
		if parent == null:
			continue
		for n in parent.get_children():
			if n.get_script() != null and String(n.get_script().get_global_name()) == cls:
				return n as Node2D
	return null


func _flee(chaser: Node2D) -> void:
	_set_state("fuite")
	var away: Vector2 = (_player.global_position - chaser.global_position).normalized()
	if away.length() < 0.1:
		away = Vector2.RIGHT
	var target: Vector2 = _player.global_position + away * 320.0
	await _walk_to(target, 24.0, 1.5, true)


func _stakeout(zone: Node2D) -> void:
	_set_state("planque")
	var to_me: Vector2 = (_player.global_position - zone.global_position).normalized()
	if to_me.length() < 0.1:
		to_me = Vector2.DOWN
	var target: Vector2 = zone.global_position + to_me * 150.0
	var d: float = _player.global_position.distance_to(zone.global_position)
	if d > 90.0 and d < 220.0:
		await _wait(0.5)  # bonne distance : on reste planqué
		return
	var ok: bool = await _walk_to(target, 20.0, 1.0, false)
	if not ok:
		await _wait(0.5)


# ---------------------------------------------------------------- navigation

func _navigate() -> void:
	# Mission dynamique acceptée → son chrono prime (comme un joueur sous pression).
	for cat in 3:
		if DynamicMissionManager.is_accepted(cat):
			var marker: Node = DynamicMissionManager._markers.get(cat)
			if marker != null and is_instance_valid(marker):
				if _t - float(_failed_targets.get(marker.get_instance_id(), -1000.0)) < 45.0:
					continue
				var mdist: String = _district_at((marker as Node2D).global_position)
				if mdist != DistrictManager.current():
					await _travel(mdist)
					return
				await _goto_node(marker as Node2D, "mission", "marqueur mission")
				return
	var live: Dictionary = NavigationDirector.get_live()
	var text: String = String(live.text)
	var kind: int = int(live.kind)
	var dist: String = String(NavigationDirector._sel.get("dist", ""))
	# Dans un intérieur et la cible n'y est pas (pas de point ici) : on sort,
	# après avoir salué les présents une fois (recherche courte).
	if _in_interior() and (kind != NavigationDirector.Kind.POINT or not _region_bounds().has_point(live.world_pos)):
		# On parle d'abord à ceux qu'on n'a pas encore essayés pour cet objectif
		# (un joueur dans la maison le soir va voir sa mère), puis on sort.
		var fresh: Node2D = _untried_in_region()
		if fresh != null and _interior_chat_count < 6:
			_interior_chat_count += 1
			await _goto_node(fresh, "recherche", text)
			return
		var door: Node2D = _exit_door_in_region()
		if door != null:
			_interior_chat_count = 0
			await _goto_node(door, "sortie", text)
			return
	if text == "":
		await _earn_or_explore("libre")
		return
	if kind == NavigationDirector.Kind.TRAVEL and dist != "" and dist != DistrictManager.current():
		await _travel(dist)
		return
	var money_goal: int = _money_goal(text)
	if kind == NavigationDirector.Kind.POINT:
		var pos: Vector2 = live.world_pos
		var node: Node2D = _interactable_near(pos, 56.0)
		if node != null and not _tried.has(node.get_instance_id()) \
				and _t - float(_interacted_at.get(node.get_instance_id(), -1000.0)) >= INTERACT_COOLDOWN:
			await _goto_node(node, "guidé", text)
			return
		if money_goal > 0 and _money() < money_goal:
			# L'objectif est de l'argent : clients du milho s'il y en a, sinon on
			# se débrouille (missions, rush…).
			await _earn_or_explore("objectif %d R$" % money_goal)
			return
		if _player.global_position.distance_to(pos) > 48.0 and _t - float(_failed_targets.get(text, -1000.0)) > 30.0:
			_set_state("marche")
			var ok: bool = await _walk_to(pos, 40.0)
			if not ok:
				_failed_targets[text] = _t
				await _search_around(_player.global_position, 900.0, text)
			return
		# Ancrage atteint (calçadão, Atlântica…) sans interactif : on cherche autour.
		await _search_around(pos, 650.0, text)
		return
	# Texte sans position : besoin d'argent ? sinon on cherche.
	var low: String = text.to_lower()
	if money_goal > 0 or low.contains("réunis") or low.contains("il manque") or low.contains("gagner r$") or low.contains("continue de gagner"):
		await _earn_or_explore("argent")
		return
	await _search_around(_player.global_position, 900.0, text)


var _travel_hist: Array = []
var _ignore_travel_until: float = -1.0

func _travel(dist: String) -> void:
	_set_state("voyage")
	# Ping-pong de guidage (A dit « va en B », B dit « va en A ») : un joueur
	# décroche et fait autre chose. On le détecte et on explore sur place.
	if _t < _ignore_travel_until:
		await _search_around(_player.global_position, 1400.0, "pingpong")
		return
	_travel_hist.append([_t, dist])
	var recent: Dictionary = {}
	for h in _travel_hist:
		if _t - h[0] < 40.0:
			recent[h[1]] = int(recent.get(h[1], 0)) + 1
	if recent.size() >= 2:
		var alternating: int = 0
		for k in recent:
			if recent[k] >= 2:
				alternating += 1
		if alternating >= 2:
			_ignore_travel_until = _t + 150.0
			_travel_hist.clear()
			_ev("guidance_pingpong", {"between": recent.keys(), "text": NavigationDirector.current_text()})
			await _search_around(_player.global_position, 1400.0, "pingpong")
			return
	# 1. Une sortie piétonne connue dans la région ?
	var exits: Array = _exits_in_region()
	var best: Node2D = null
	var best_d: float = INF
	var locked: Node2D = null
	for e in exits:
		if String(e.get("target_district")) != dist:
			continue
		if _t - float(_failed_targets.get(e.get_instance_id(), -1000.0)) < 120.0 and not (e.has_method("_is_locked") and bool(e.call("_is_locked"))):
			continue
		if e.has_method("_is_locked") and bool(e.call("_is_locked")):
			locked = e
			continue
		var d: float = _player.global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null and locked != null:
		# La sortie existe mais est verrouillée par la trame : le joueur va voir
		# le panneau (et se fait rattraper), puis cherche quoi faire sur place.
		if not _failed_targets.has(locked.get_instance_id()):
			_failed_targets[locked.get_instance_id()] = _t
			_ev("exit_locked", {"to": dist, "exit": locked.name, "msg": String(locked.get("block_message")).left(60)})
			await _walk_to(locked.global_position, 30.0, 60.0)
			return
		await _search_around(_player.global_position, 1400.0, "verrou:" + dist)
		return
	if best != null:
		_ev("travel_walk", {"to": dist, "exit": best.name})
		var from: String = DistrictManager.current()
		var ok: bool = await _walk_to(best.global_position, 10.0)
		if DistrictManager.current() != from:
			return
		if not ok:
			_ev("travel_walk_failed", {"to": dist, "exit": best.name})
			_failed_targets[best.get_instance_id()] = _t
		return
	# 2. Taxi par le téléphone (dispo partout) si on a la course.
	var fare: int = DistrictManager.get_fare(dist)
	if _money() >= fare and DistrictManager.available_destinations().has(dist):
		await _wait(PHONE_SEC)
		var before: int = _money()
		if DistrictManager.travel_to(dist):
			_taxi_spent += before - _money()
			_ev("taxi", {"to": dist, "fare": fare})
			await _frame()
			await _frame()
		return
	if not DistrictManager.available_destinations().has(dist):
		_ev("travel_impossible", {"to": dist})
		_failed_targets[dist] = _t
		await _search_around(_player.global_position, 900.0, "sans taxi:" + dist)
		return
	# 3. Pas de quoi payer : on va gagner la course.
	_ev("taxi_broke", {"to": dist, "fare": fare})
	await _earn_or_explore("taxi")


func _goto_node(node: Node2D, mode: String, label: String) -> void:
	_set_state("marche")
	if OS.has_environment("BOT_DEBUG"):
		print("[bot dbg] goto %s (%s) from %s" % [node.name, label, _player.global_position])
	var stand: Vector2 = _stand_pos_for(node)
	var ok: bool = await _walk_to(stand, 10.0, WALK_TIMEOUT, false, node)
	await _frame()
	if not is_instance_valid(node):
		return
	var inter: Node = _interactable_of(node)
	var cur: Node = _player.get("_current_interactable")
	if ok and inter != null and cur != inter:
		# Arrivé à la station mais le prompt n'est pas là : on vient au contact.
		var t0: float = _t
		while not _finished and _t - t0 < 4.0 and _player.get("_current_interactable") != inter \
				and is_instance_valid(node):
			var d: Vector2 = node.global_position - _player.global_position
			if d.length() < 2.0:
				break
			_press(d.normalized(), false)
			await _frame()
		_release_inputs()
		await _frame()
		cur = _player.get("_current_interactable")
	if cur != null and inter != null and cur == inter:
		await _interact(node, mode, label)
		return
	if ok and cur != null:
		# Autre interactif sous la main : on prend celui-là (c'est ce que verrait le
		# joueur) — sauf s'il a déjà été essayé pour cet objectif.
		var other: Node2D = _owner_of_interactable(cur)
		if other != null and not _tried.has(other.get_instance_id()) \
				and _t - float(_interacted_at.get(other.get_instance_id(), -1000.0)) >= INTERACT_COOLDOWN:
			await _interact(other, mode, label)
			return
	if ok:
		_ev("no_prompt", {"node": node.name, "mode": mode, "label": label})
		_tried[node.get_instance_id()] = true
	else:
		_ev("unreachable", {"node": node.name, "mode": mode, "label": label})
	_failed_targets[node.get_instance_id()] = _t


func _interact(node: Node2D, mode: String, label: String) -> void:
	var inter: Node = _interactable_of(node)
	if inter == null:
		return
	_interacted_at[node.get_instance_id()] = _t
	_tried[node.get_instance_id()] = true
	_ev("interact", {"node": node.name, "mode": mode, "label": label,
			"prompt": String(inter.get("prompt")) if "prompt" in inter else ""})
	inter.call("interact", _player)
	await _frame()
	await _frame()


func _search_around(center: Vector2, radius: float, label: String) -> void:
	_set_state("recherche")
	if OS.has_environment("BOT_DEBUG"):
		print("[bot dbg] search around %s r=%d (%s)" % [center, radius, label])
	var cands: Array = _interactables_in_region()
	var best: Node2D = null
	var best_score: float = INF
	for n in cands:
		var d: float = n.global_position.distance_to(center)
		if d > radius:
			continue
		if n.get_script() != null and String(n.get_script().get_global_name()) == "Rideable":
			continue
		var score: float = _player.global_position.distance_to(n.global_position) + 1.5 * d
		if _t - float(_interacted_at.get(n.get_instance_id(), -1000.0)) < INTERACT_COOLDOWN:
			continue
		if _tried.has(n.get_instance_id()):
			continue
		if _t - float(_failed_targets.get(n.get_instance_id(), -1000.0)) < 240.0:
			continue
		# Un « ! » visible attire l'œil.
		var qi: Node = n.get_node_or_null("QuestIndicator")
		if qi != null and (qi as CanvasItem).visible:
			score *= 0.3
		if score < best_score:
			best_score = score
			best = n
	if best == null:
		# Rien de neuf à portée : errance vers un point de la région.
		_set_state("errance")
		_ensure_nav()
		var b: Rect2 = _region_bounds()
		var target: Vector2 = center + Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius * 0.5, radius * 0.5))
		target = target.clamp(b.position + Vector2(16, 16), b.end - Vector2(16, 16))
		var c: Vector2i = _nav.nearest_free(target, 20)
		if c.x != 2147483647:
			target = NavScript.center_of(c)
		_ev("wander", {"label": label, "to": [int(target.x), int(target.y)]})
		await _walk_to(target, 24.0, 40.0)
		await _frame()
		return
	await _goto_node(best, "recherche", label)


func _earn_or_explore(why: String) -> void:
	# Acte 1 : la carrocinha si on ne l'a pas (le guidage le dit normalement).
	var cart: Node = get_tree().get_first_node_in_group("corn_cart")
	var carrying: bool = cart != null and cart.has_method("is_carrying") and bool(cart.call("is_carrying"))
	if carrying:
		# Clients à servir à portée ?
		for n in _interactables_in_region():
			if n.get_script() != null and String(n.get_script().get_global_name()) == "CustomerNPC" \
					and not bool(n.get("has_purchased")) \
					and _t - float(_interacted_at.get(n.get_instance_id(), -1000.0)) >= INTERACT_COOLDOWN:
				await _goto_node(n, "milho", "client")
				return
	# Mission dynamique (téléphone) : la plus proche, locale d'abord.
	var any_accepted: bool = false
	for cat in 3:
		if DynamicMissionManager.is_accepted(cat):
			any_accepted = true
	if not any_accepted:
		_set_state("telephone")
		await _wait(PHONE_SEC)
		if await _accept_best_mission(why):
			return
	# Rush milho (acte 2+) si la carrocinha est dans la région.
	if cart != null and cart is Node2D and not carrying and CampaignManager.current_act >= 2 \
			and _region_bounds().has_point((cart as Node2D).global_position) \
			and _t - float(_interacted_at.get(cart.get_instance_id(), -1000.0)) >= 30.0:
		await _goto_node(cart as Node2D, "rush", "carrocinha")
		return
	await _search_around(_player.global_position, 900.0, "explore:" + why)


var _interior_chat_count: int = 0

func _in_interior() -> bool:
	var p: Vector2 = _player.global_position
	for n in _interiors:
		if is_instance_valid(n):
			var bb: Rect2 = _rects_bbox(n)
			if bb.size.x > 0.0 and bb.grow(120.0).has_point(p):
				return true
	return false


func _exit_door_in_region() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for n in _interactables_in_region():
		if n is BuildingDoor and bool(n.get("is_exit")):
			if _t - float(_failed_targets.get(n.get_instance_id(), -1000.0)) < 60.0:
				continue
			var d: float = n.global_position.distance_to(_player.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func _untried_in_region() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for n in _interactables_in_region():
		if n is BuildingDoor or _tried.has(n.get_instance_id()):
			continue
		if _t - float(_interacted_at.get(n.get_instance_id(), -1000.0)) < INTERACT_COOLDOWN:
			continue
		var d: float = n.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _unvisited_in_region() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for n in _interactables_in_region():
		if n is BuildingDoor:
			continue
		if _interacted_at.has(n.get_instance_id()):
			continue
		var d: float = n.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


# Objectif d'argent lisible dans le bandeau : « (R$ 0 / 500) », « il manque 300 »,
# « Réunis 1 200 R$ », « déposer 500 R$ ». 0 si aucun.
func _money_goal(text: String) -> int:
	var re: RegEx = RegEx.new()
	re.compile("R\\$\\s*\\d[\\d\\s]*\\s*/\\s*(\\d[\\d\\s]*)|manque\\s+(\\d[\\d\\s]*)|Réunis\\s+(\\d[\\d\\s]*)|déposer\\s+(\\d[\\d\\s]*)")
	var m: RegExMatch = re.search(text)
	if m == null:
		return 0
	for g in [1, 2, 3, 4]:
		var v: String = m.get_string(g).replace(" ", "").replace("\u00a0", "")
		if v != "" and v.is_valid_int():
			return int(v)
	return 0


func _accept_best_mission(why: String) -> bool:
	for cat in 3:
		if DynamicMissionManager.is_accepted(cat):
			return false
	var best_cat: int = -1
	var best_cost: float = INF
	for cat in 3:
		var m: Dictionary = DynamicMissionManager.get_mission(cat)
		if m.is_empty() or bool(m.get("accepted", false)):
			continue
		var target_dist: String = String(m.get("district", "copacabana"))
		var cost: float = 0.0
		if target_dist != DistrictManager.current():
			cost = 1000.0 + float(DistrictManager.get_fare(target_dist)) * 10.0
			if not bool(DistrictManager.DISTRICTS.get(target_dist, {}).get("taxi_available", true)) and not _has_walk_exit(target_dist):
				continue
			if _money() < DistrictManager.get_fare(target_dist) and not _has_walk_exit(target_dist):
				continue
		if cost < best_cost:
			best_cost = cost
			best_cat = cat
	if best_cat == -1:
		return false
	if DynamicMissionManager.accept(best_cat):
		var m: Dictionary = DynamicMissionManager.get_mission(best_cat)
		_ev("mission_accepted", {"cat": best_cat, "title": String(m.get("title", "")),
				"money": int(m.get("money", 0)), "budget": int(m.get("time_total", 0)), "why": why})
		return true
	return false


func _has_walk_exit(dist: String) -> bool:
	for e in _exits_in_region():
		if String(e.get("target_district")) == dist and not (e.has_method("_is_locked") and bool(e.call("_is_locked"))):
			return true
	return false


# ---------------------------------------------------------------- marche

# Marche jusqu'à `target` (chemin A*, inputs injectés). Retourne true si arrivé.
# S'interrompt (false) si un dialogue/cutscene/téléport survient, ou si on
# touche `stop_node` (interactif cible détecté par le joueur).
func _walk_to(target: Vector2, stop_dist: float = 12.0, timeout: float = WALK_TIMEOUT,
		sprint: bool = false, stop_node: Node2D = null) -> bool:
	_ensure_nav()
	_unblock_expired(40.0)
	if _nav.nearest_free(_player.global_position).x == 2147483647:
		# Le joueur n'est pas sur la grille courante (téléport, intérieur) : on la refait.
		_nav = null
		_ensure_nav()
	var path: PackedVector2Array = _nav.path(_player.global_position, target)
	if path.is_empty() and not _temp_blocks.is_empty():
		_unblock_expired(0.0)
		path = _nav.path(_player.global_position, target)
	if path.is_empty():
		_ev("no_path", {"to": [int(target.x), int(target.y)]})
		_release_inputs()
		return false
	if OS.has_environment("BOT_DEBUG"):
		print("[bot dbg] path %d pts to %s" % [path.size(), target])
	var dbg_n: int = 0
	var idx: int = 0
	var t0: float = _t
	var stuck_t: float = _t
	var stuck_pos: Vector2 = _player.global_position
	var replans: int = 0
	var start_dist: String = DistrictManager.current()
	var stop_inter: Node = _interactable_of(stop_node) if stop_node != null else null
	var prev_p: Vector2 = _player.global_position
	while not _finished:
		if DialogueBridge.is_active() or CutsceneRunner.is_running() or get_tree().paused \
				or _find_active_minigame() != null or DistrictManager.current() != start_dist \
				or _player.global_position.distance_to(prev_p) > 80.0:
			_release_inputs()
			return false
		prev_p = _player.global_position
		if stop_inter != null and _player.get("_current_interactable") == stop_inter:
			_release_inputs()
			return true
		var p: Vector2 = _player.global_position
		if p.distance_to(target) <= stop_dist:
			_release_inputs()
			return true
		if _t - t0 > timeout:
			_release_inputs()
			_ev("walk_timeout", {"to": [int(target.x), int(target.y)]})
			return false
		while idx < path.size() - 1 and p.distance_to(path[idx]) < 7.0:
			idx += 1
		var wp: Vector2 = path[idx]
		var dir: Vector2 = (wp - p)
		if dir.length() > 0.01:
			dir = dir.normalized()
		var remaining: float = p.distance_to(target)
		var run: bool = sprint or (remaining > 100.0 and _stamina_ratio() > 0.35)
		if _stamina_ratio() < 0.08:
			run = false
		_press(dir, run)
		dbg_n += 1
		if OS.has_environment("BOT_DEBUG") and dbg_n % 60 == 1:
			print("[bot dbg] walk t=%.1f p=%s wp=%s idx=%d/%d pf=%d" % [_t, p, wp, idx, path.size(), Engine.get_physics_frames()])
		# Détection de blocage.
		if p.distance_to(stuck_pos) > 3.0:
			stuck_pos = p
			stuck_t = _t
		elif _t - stuck_t > STUCK_SEC:
			replans += 1
			for ox in [-8.0, 0.0, 8.0]:
				for oy in [-8.0, 0.0, 8.0]:
					_block_temp(wp + Vector2(ox, oy))
			# Pas de côté (un PNJ dans le passage, un prop sans mur…)
			var side: Vector2 = Vector2(-dir.y, dir.x) * (1.0 if replans % 2 == 0 else -1.0)
			for i in 12:
				_press(side, false)
				await _frame()
			path = _nav.path(_player.global_position, target)
			idx = 0
			stuck_t = _t
			stuck_pos = _player.global_position
			if replans > 8 or path.is_empty():
				_release_inputs()
				_ev("stuck", {"at": [int(p.x), int(p.y)], "to": [int(target.x), int(target.y)]})
				return false
		await _frame()
	_release_inputs()
	return false


var _temp_blocks: Array = []  # [cell Vector2i, t]

func _block_temp(p: Vector2) -> void:
	var c: Vector2i = NavScript.cell_of(p)
	if _nav.is_free(c):
		_nav.block_cell(p)
		_temp_blocks.append([c, _t])

func _unblock_expired(age: float) -> void:
	var keep: Array = []
	for b in _temp_blocks:
		if _t - float(b[1]) >= age:
			_nav.call("unblock_cell", b[0])
		else:
			keep.append(b)
	_temp_blocks = keep


func _press(dir: Vector2, run: bool) -> void:
	_release_inputs()
	if dir.x > 0.05:
		Input.action_press("move_right", dir.x)
	elif dir.x < -0.05:
		Input.action_press("move_left", -dir.x)
	if dir.y > 0.05:
		Input.action_press("move_back", dir.y)
	elif dir.y < -0.05:
		Input.action_press("move_forward", -dir.y)
	if run:
		Input.action_press("run")


func _release_inputs() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back", "run"]:
		Input.action_release(a)


func _stamina_ratio() -> float:
	if _stamina != null and _stamina.has_method("ratio"):
		return float(_stamina.call("ratio"))
	return 1.0


# ---------------------------------------------------------------- perception

func _region_bounds() -> Rect2:
	var p: Vector2 = _player.global_position
	for n in _interiors:
		if not is_instance_valid(n):
			continue
		var bb: Rect2 = _rects_bbox(n)
		if bb.size.x > 0.0 and bb.grow(120.0).has_point(p):
			return _quantize(bb.grow(60.0))
	var cur: String = DistrictManager.current()
	# Copa et la Zona Sul forment un littoral continu : une seule grille.
	if cur == "copacabana" or cur == "zona_sul":
		var zs: Node = _world.get_node_or_null("ZonaSulDistrict")
		var merged: Rect2 = COPA_BOUNDS
		if zs != null:
			var zb: Rect2 = _ground_bbox(zs)
			if zb.size.x > 0.0:
				merged = merged.merge(zb.grow(150.0))
		if merged.has_point(p):
			return merged
	var nn: String = String(DistrictManager.DISTRICTS.get(cur, {}).get("node_name", ""))
	if nn != "":
		var dn: Node = _world.get_node_or_null(nn)
		if dn != null:
			var bb2: Rect2 = _ground_bbox(dn)
			if bb2.size.x > 0.0 and bb2.grow(300.0).has_point(p):
				return _quantize(bb2.grow(150.0))
	if COPA_BOUNDS.has_point(p):
		return COPA_BOUNDS
	return Rect2(p - Vector2(1200, 900), Vector2(2400, 1800))


# Quartier contenant un point monde (bbox des districts, sinon Copa).
func _district_at(p: Vector2) -> String:
	# La bande de Copa (x ≥ -300) prime : la Zona Sul la chevauche à l'Arpoador.
	if p.x >= -300.0 and COPA_BOUNDS.has_point(p):
		return "copacabana"
	for id in DistrictManager.DISTRICTS:
		var nn: String = String(DistrictManager.DISTRICTS[id].get("node_name", ""))
		if nn == "":
			continue
		var dn: Node = _world.get_node_or_null(nn)
		if dn == null:
			continue
		var bb: Rect2 = _ground_bbox(dn)
		if bb.size.x > 0.0 and bb.grow(200.0).has_point(p):
			return id
	return "copacabana"


# Bornes arrondies à 512 px : un décor animé (nuage, bondinho) qui déplace la
# bbox d'un district ne doit pas faire reconstruire la grille à chaque image.
func _quantize(r: Rect2) -> Rect2:
	var q: float = 512.0
	var x0: float = floor(r.position.x / q) * q
	var y0: float = floor(r.position.y / q) * q
	var x1: float = ceil(r.end.x / q) * q
	var y1: float = ceil(r.end.y / q) * q
	return Rect2(x0, y0, x1 - x0, y1 - y0)


func _region_key(b: Rect2) -> String:
	# Clé = géométrie réelle de la grille (un intérieur généré par code ou la
	# boîte de secours autour du joueur ne doivent pas réutiliser la grille de Copa).
	return "%d_%d_%d_%d" % [int(b.position.x), int(b.position.y), int(b.size.x), int(b.size.y)]


func _ensure_nav() -> void:
	var b: Rect2 = _region_bounds()
	var key: String = _region_key(b)
	if _nav != null and _nav_key == key:
		return
	var t0: int = Time.get_ticks_msec()
	_nav = NavScript.new()
	_nav.call("build", _player.get_world_2d().direct_space_state, b)
	_nav_key = key
	_temp_blocks.clear()
	_ev("nav_built", {"region": key, "cells": int(_nav.get("cell_count")), "solid": int(_nav.get("solid_count")),
			"ms": Time.get_ticks_msec() - t0})


func _rects_bbox(node: Node) -> Rect2:
	var bbox: Rect2 = Rect2()
	var first: bool = true
	for cr in node.find_children("*", "ColorRect", true, false):
		if cr.is_in_group("district_backdrop") or not (cr as ColorRect).visible:
			continue
		var r: Rect2 = (cr as ColorRect).get_global_rect()
		bbox = r if first else bbox.merge(r)
		first = false
	return bbox if not first else Rect2()


func _ground_bbox(owner: Node) -> Rect2:
	var bbox: Rect2 = Rect2()
	var first: bool = true
	for cr in owner.get_children():
		if not (cr is ColorRect) or cr.is_in_group("district_backdrop") or not (cr as ColorRect).visible:
			continue
		var r: Rect2 = (cr as ColorRect).get_global_rect()
		bbox = r if first else bbox.merge(r)
		first = false
	return bbox if not first else Rect2()


# Tous les nœuds « interactifs » (porteurs d'un Interactable activé) de la région.
func _interactables_in_region() -> Array:
	if _t - _interactables_cache_t > 2.0:
		_interactables_cache.clear()
		for a in _world.find_children("*", "Area2D", true, false):
			if a is Interactable and bool(a.get("enabled")) and (a as Node2D).is_visible_in_tree():
				var owner: Node2D = _owner_of_interactable(a)
				if owner != null and owner != _player:
					_interactables_cache.append(owner)
		_interactables_cache_t = _t
	var b: Rect2 = _region_bounds()
	var out: Array = []
	for n in _interactables_cache:
		if is_instance_valid(n) and b.has_point(n.global_position):
			out.append(n)
	return out


func _exits_in_region() -> Array:
	var b: Rect2 = _region_bounds()
	var out: Array = []
	for a in _world.find_children("*", "Area2D", true, false):
		if a is DistrictExit and b.has_point((a as Node2D).global_position):
			out.append(a)
	return out


func _owner_of_interactable(a: Node) -> Node2D:
	var p: Node = a.get_parent()
	if p is Node2D:
		return p as Node2D
	return a as Node2D


func _interactable_of(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node is Interactable:
		return node
	if "interactable" in node and node.get("interactable") != null:
		return node.get("interactable")
	return node.get_node_or_null("Interactable")


func _interactable_near(pos: Vector2, r: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = r
	for n in _interactables_in_region():
		var d: float = n.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = n
	return best


# Où se tenir pour déclencher l'interactif d'un nœud : une cellule libre qui
# recouvre sa zone d'interaction, au plus près du joueur.
func _stand_pos_for(node: Node2D) -> Vector2:
	_ensure_nav()
	var inter: Node = _interactable_of(node)
	var rect: Rect2 = Rect2(node.global_position - Vector2(12, 12), Vector2(24, 24))
	if inter != null:
		var cs: CollisionShape2D = null
		for c in inter.get_children():
			if c is CollisionShape2D:
				cs = c
				break
		if cs != null and cs.shape is RectangleShape2D:
			var sz: Vector2 = (cs.shape as RectangleShape2D).size
			rect = Rect2(cs.global_position - sz * 0.5, sz)
		elif cs != null and cs.shape is CircleShape2D:
			var rr: float = (cs.shape as CircleShape2D).radius
			rect = Rect2(cs.global_position - Vector2(rr, rr), Vector2(rr * 2, rr * 2))
	# 1er passage : centre du corps dans la zone (chevauchement garanti) ;
	# 2e passage : zone élargie de la demi-boîte du joueur (chevauchement partiel).
	var best: Vector2 = node.global_position
	var best_d: float = INF
	for pass_rect in [rect.grow(-3.0), rect.grow_individual(6, 9, 6, 9)]:
		var inner: Rect2 = pass_rect
		if inner.size.x < 4.0 or inner.size.y < 4.0:
			continue
		var c0: Vector2i = NavScript.cell_of(inner.position)
		var c1: Vector2i = NavScript.cell_of(inner.end)
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var c: Vector2i = Vector2i(cx, cy)
				if not _nav.is_free(c):
					continue
				var cp: Vector2 = NavScript.center_of(c)
				if not inner.has_point(cp):
					continue
				var d: float = cp.distance_to(_player.global_position)
				if d < best_d:
					best_d = d
					best = cp
		if best_d < INF:
			break
	return best


# ---------------------------------------------------------------- sortie

func _dump(final: bool = true) -> void:
	var wall: int = Time.get_ticks_msec() - _wall0
	var summary: Dictionary = {
		"game_time_s": snappedf(_t, 0.1),
		"wall_ms": wall,
		"reason": _finish_reason if _finished else "en cours",
		"act": CampaignManager.current_act,
		"debt_paid": CampaignManager.debt_paid,
		"money": _money(),
		"day": TimeOfDay.day_count,
		"dist_walked_px": int(_dist_walked),
		"taxi_spent": _taxi_spent,
		"time_by_state": _time_by_state,
		"counters": _counters,
		"flags": CampaignManager.flags.keys(),
		"active_quests": QuestManager.get_active_ids(),
	}
	var completed: Array = []
	for q in QuestManager._quests.keys():
		if QuestManager.is_completed(q):
			completed.append(q)
	summary["completed_quests"] = completed
	var data: Dictionary = {"summary": summary, "timeline": _log}
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "", false))
		f.close()
	if not final:
		return
	print("\n=============== PLAYTEST ===============")
	print(JSON.stringify(summary, "  "))
	print("écrit : %s" % out_path)
