extends Node

# Wrapper sur le runtime narratif (inkgd si installé, placeholder sinon).
# Autoload name: DialogueBridge.
# Les quêtes et l'UI ne connaissent que les signaux line_shown / choices_presented
# / dialogue_finished — le moteur sous-jacent est interchangeable.

signal line_shown(speaker: String, text: String)
signal choices_presented(choices: Array)
signal dialogue_finished()

# Dialogues placeholder — actifs tant qu'inkgd n'est pas installé. Une fois le
# plugin en place et milho.ink compilé, ces entrées sont contournées.
#
# Format d'une entrée :
#   "knot_name": {
#       "speaker": String,
#       "text": String,
#       "choices": [String, ...],
#       "on_choose": { "0": {action}, "1": {action}, ... }  # optionnel
#   }
# Actions possibles (même champ = exclusif) :
#   {"accept_quest": "quest_id"}   → QuestManager.accept(id)
#   {"sell_at": int, "rep": {}}    → cart.sell(price, rep)
#   {"give_away": true, "rep": {}} → cart.give_away(rep)
#   {"return_cart": true}          → cart.drop_off(inventory)
#   {"rep": {axis_int: delta}}     → ReputationSystem.modify(...)
const PLACEHOLDER_DIALOGUES: Dictionary = {}

var _active_npc_id: String = ""
var _active_knot: String = ""
var _loader: InkStoryLoader = null

# Dialogues injectés à la volée (Viewpoint, StreetVendor, StreetEvent…), plus
# les knots `spot_<npc_id>_<variant>` construits par ReactiveDialogueSpot pour
# toutes les missions de voie (A/B/C/D) : eux n'apparaissent JAMAIS dans
# PLACEHOLDER_DIALOGUES — toute analyse statique qui les y cherche se trompe.
# Godot 4 interdit l'index-assignment sur un const Dictionary, donc les knots
# dynamiques passent par ce dico runtime à part.
var _runtime_dialogues: Dictionary = {}

# Roda scénarisée en cours (verbe `start_altinha`). Les essais sont comptés
# dans les flags de campagne (`<flag>_essais`) : sauvegardés et remis à zéro
# avec la partie.
var _altinha_challenge: Dictionary = {}

# Enregistre un knot éphémère utilisable par start_dialogue. La donnée a la
# même forme qu'une entrée de PLACEHOLDER_DIALOGUES.
func register_runtime_dialogue(knot_id: String, data: Dictionary) -> void:
	_runtime_dialogues[knot_id] = data

func _has_placeholder(knot_id: String) -> bool:
	return PLACEHOLDER_DIALOGUES.has(knot_id) or _runtime_dialogues.has(knot_id)

# Vue agrégée de tous les knots disponibles (PLACEHOLDER_DIALOGUES const +
# registres runtime alimentés par les spots et les splits par acte). Utilisé
# par les tests d'intégration qui doivent voir l'intégralité du graphe.
func all_dialogues() -> Dictionary:
	var merged: Dictionary = PLACEHOLDER_DIALOGUES.duplicate()
	for k in _runtime_dialogues:
		merged[k] = _runtime_dialogues[k]
	return merged

func _get_placeholder(knot_id: String) -> Dictionary:
	if _runtime_dialogues.has(knot_id):
		return _runtime_dialogues[knot_id]
	return PLACEHOLDER_DIALOGUES.get(knot_id, {})

func _ready() -> void:
	_loader = InkStoryLoader.new()
	_loader.name = "InkStoryLoader"
	add_child(_loader)
	_loader.line_produced.connect(_on_ink_line)
	_loader.choices_produced.connect(_on_ink_choices)
	_loader.story_ended.connect(_on_ink_ended)
	_loader.ready_to_play.connect(_on_ink_ready)
	# Merge des knots externes (split par acte/voie pour alléger ce fichier).
	# Du point de vue de start_dialogue/choose, indistinguable d'un knot
	# PLACEHOLDER_DIALOGUES — _has_placeholder check les deux.
	_merge_external_dialogues()
	EventBus.minigame_ended.connect(_on_minigame_ended_for_challenge)

# Tous les knots vivent désormais dans ces scripts (split par acte/domaine).
# PLACEHOLDER_DIALOGUES reste vide mais conservé : _has_placeholder /
# all_dialogues / _get_placeholder le fusionnent avec _runtime_dialogues.
const _EXTERNAL_DIALOGUES: Array[Script] = [
	preload("res://scripts/dialogues/Act1Dialogues.gd"),
	preload("res://scripts/dialogues/Act2Dialogues.gd"),
	preload("res://scripts/dialogues/Act3Dialogues.gd"),
	preload("res://scripts/dialogues/Act4Dialogues.gd"),
	preload("res://scripts/dialogues/SidePlageDialogues.gd"),
	preload("res://scripts/dialogues/SideServicesDialogues.gd"),
	preload("res://scripts/dialogues/SideBaiaDialogues.gd"),
]

func _merge_external_dialogues() -> void:
	for src in _EXTERNAL_DIALOGUES:
		for knot_id in src.KNOTS:
			register_runtime_dialogue(knot_id, src.KNOTS[knot_id])

func start_dialogue(npc_id: String, ink_knot: String) -> void:
	if _active_npc_id != "":
		print("[DialogueBridge] ignore start (déjà actif: %s)" % _active_npc_id)
		return
	_active_npc_id = npc_id
	_active_knot = ink_knot
	NarrativeJournal.mark_read(ink_knot)
	EventBus.dialogue_started.emit(npc_id)
	print("[DialogueBridge] start_dialogue npc=%s knot=%s loader_ready=%s placeholder=%s" % [npc_id, ink_knot, _loader.is_ready() if _loader else false, _has_placeholder(ink_knot)])
	if _loader and _loader.is_ready() and _loader.start_from_knot(ink_knot):
		return
	if _has_placeholder(ink_knot):
		var d: Dictionary = _get_placeholder(ink_knot)
		line_shown.emit(d.speaker, _sub_placeholders(d.text))
		choices_presented.emit(d.choices)

# Time de coração du joueur (flag posé à l'intro). "" si pas encore choisi.
const TIME_FLAGS: Dictionary = {
	"time_flamengo": "Flamengo",
	"time_vasco": "Vasco",
	"time_fluminense": "Fluminense",
	"time_botafogo": "Botafogo",
}

func time_coracao() -> String:
	for flag in TIME_FLAGS:
		if has_flag(flag):
			return TIME_FLAGS[flag]
	return ""

# Substitue les placeholders culturels dans les textes de knots.
# {time} → time de coração (fallback neutre si non choisi, ex. vieille save).
func _sub_placeholders(text: String) -> String:
	if text.find("{time}") == -1:
		return text
	var t: String = time_coracao()
	return text.replace("{time}", t if t != "" else "Flamengo")

func choose(choice_index: int) -> void:
	print("[DialogueBridge] choose(%d) called" % choice_index)
	if _loader and _loader.is_ready():
		_loader.choose(choice_index)
		return
	# Placeholder : chaîne les knots si l'action a "next", sinon applique et
	# termine. _get_placeholder couvre AUSSI les dialogues runtime (spots
	# ReactiveDialogueSpot) — sinon leurs actions finish_quest/accept_quest
	# ne s'appliquent jamais en jeu (prologue + voies en dépendent).
	var dlg: Dictionary = _get_placeholder(_active_knot)
	var on_choose: Dictionary = dlg.get("on_choose", {})
	var action = on_choose.get(str(choice_index), null)
	# Jeitinho : la 3e voie carioca — résoudre par la relation plutôt que par
	# l'argent ou la force. Gate par NPCAffinity : si on connaît assez le
	# contact, l'action "ok" s'applique ; sinon refus doux, sans pénalité.
	if action != null and action.has("jeitinho"):
		action = _resolve_jeitinho(action.jeitinho)
	if action != null and action.has("next"):
		# Effets latéraux applicables avant de chaîner sur le knot suivant.
		# Si l'acceptation échoue (prereq manquant), on saute aussi les autres side effects
		# pour ne pas laisser un état partiel — et on bascule vers un knot de refus.
		if action.has("accept_quest") and not _try_accept_any(action.accept_quest):
			_show_locked_message(action.accept_quest)
			return
		if action.has("set_flag"):
			set_flag(String(action.set_flag))
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		_active_knot = action.next
		NarrativeJournal.mark_read(_active_knot)
		if _has_placeholder(_active_knot):
			var d: Dictionary = _get_placeholder(_active_knot)
			line_shown.emit(d.speaker, _sub_placeholders(d.text))
			choices_presented.emit(d.choices)
		return
	if action != null:
		_apply_placeholder_action(action)
	end_dialogue()

# Résout une action jeitinho : {"npc": id, "tier": min, "ok": {action},
# "ko_speaker"?, "ko_text"?}. Renvoie l'action à appliquer (ok ou refus).
# Le refus est un knot runtime sans aucun effet : tenter le jeitinho ne coûte
# jamais rien — c'est la relation qui manque, pas la compétence.
func _resolve_jeitinho(j: Dictionary) -> Dictionary:
	var npc: String = String(j.get("npc", ""))
	var min_tier: int = int(j.get("tier", NPCAffinity.Tier.ACQUAINTANCE))
	if npc != "" and NPCAffinity.tier(npc) >= min_tier:
		return j.get("ok", {})
	var knot_id: String = "jeitinho_ko_%s_%s" % [_active_knot, npc]
	register_runtime_dialogue(knot_id, {
		"speaker": String(j.get("ko_speaker", "Sobrinho")),
		"text": String(j.get("ko_text",
			"Tu lâches le nom… et ça tombe à plat. Vous vous connaissez à peine. Le jeitinho, ça se construit — un café, un service, une conversation. Reviens quand ce sera une vraie relation.")),
		"choices": ["C'est noté"],
	})
	return {"next": knot_id}

func end_dialogue() -> void:
	print("[DialogueBridge] end_dialogue (was active: %s)" % _active_npc_id)
	if _active_npc_id != "":
		EventBus.dialogue_ended.emit(_active_npc_id)
	_active_npc_id = ""
	_active_knot = ""
	dialogue_finished.emit()

# Renvoie true si un dialogue est actuellement en cours (utilisé par les cutscenes
# pour différer leur déclenchement après la fin du dialogue actif).
func is_active() -> bool:
	return _active_npc_id != ""

func _apply_placeholder_action(action: Dictionary) -> void:
	# Flag-jour (beats quotidiens : le jantar) — valeur = jour courant.
	if action.has("set_flag_day"):
		CampaignManager.set_flag(String(action.set_flag_day), TimeOfDay.day_count)
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory

	# --- Add-ons composables (ne retournent PAS) : cumulables avec n'importe
	# quel bloc englobant ci-dessous. Utilisés par les verbes de voie.
	# `debt_credit` : le patron solde une part de la dette directement chez le
	# consortium — SANS toucher le cash du joueur (≠ pay_debt qui le ponctionne).
	# C'est le canal des versements scénarisés qui rythment les seuils d'acte.
	if action.has("debt_credit"):
		CampaignManager.pay_debt(int(action.debt_credit))
	# `start_chase` : lâche une poursuite de rue sur le joueur (voie Tráfico…).
	# Config = dict CobradorChase (chaser_id, textes, vitesses) ; le poursuivant
	# attend poliment la fin du dialogue (gel tant que DialogueBridge est actif).
	if action.has("start_chase"):
		CobradorChase.spawn(action.start_chase if action.start_chase is Dictionary else {})
	# `start_stakeout` : lance une filature (voie Polícia) — {quest, objective,
	# duration?, seed?}. Le succès coche l'objectif via QuestManager.
	if action.has("start_stakeout"):
		StakeoutZone.spawn(action.start_stakeout if action.start_stakeout is Dictionary else {})
	# `start_altinha` : une roda avec le PNJ — {flag, touch_goal, setting,
	# max_tries, win_text, retry_text, relent_text}. Réussir (ou insister
	# max_tries fois : on ne bloque jamais un joueur neuf) pose `flag`, que la
	# variante suivante du spot attend. La récompense est la relation, pas l'argent.
	if action.has("start_altinha"):
		start_altinha_challenge(action.start_altinha if action.start_altinha is Dictionary else {})

	# Cas composé accept_quest + finish_quest : la quête à accepter dépend
	# souvent de la quête à clôre (prereq), donc on délègue à la branche
	# finish_quest qui ordonne complete → accept correctement (voies A/B/C/D).
	if action.has("accept_quest") and not action.has("finish_quest"):
		if not _try_accept_any(action.accept_quest):
			_show_locked_message(action.accept_quest)
			return
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		if action.has("set_flag"):
			set_flag(String(action.set_flag))
		return
	if action.has("sell_at"):
		if cart and cart.is_carrying() and cart.sell(action.sell_at, action.get("rep", {})):
			EventBus.customer_served.emit(_active_npc_id)
		return
	if action.has("give_away"):
		if cart and cart.is_carrying() and cart.give_away(action.get("rep", {})):
			EventBus.customer_served.emit(_active_npc_id)
		return
	if action.has("return_cart"):
		if cart and cart.is_carrying():
			cart.drop_off(inv)
		return
	# IMPORTANT : ordre des checks composés. set_endgame > finish_quest > pay_bribe.
	# Les actions narratives combinent souvent plusieurs effets dans une même
	# action (ex. padre_act3_close = set_endgame + finish_quest + rep,
	# tito_favor_ask = finish_quest + pay_bribe + rep). Les blocs « les plus
	# englobants » doivent être traités d'abord pour gérer leurs sous-effets.
	if action.has("set_endgame"):
		# Finale acte 3 : la voie est scellée, dette purgée, écran de fin déclenché.
		# Englobe finish_quest (paie le payout, complète l'objectif) + rep.
		var path: int = _endgame_path_for_string(String(action.set_endgame))
		if action.has("finish_quest"):
			var info: Dictionary = action.finish_quest
			var dlg_payout: int = int(info.get("payout", 0))
			if inv and dlg_payout > 0:
				inv.add_money(dlg_payout)
			# Si le dialogue a versé > 0, c'est lui qui paie → coupe l'auto-pay
			# QuestManager pour éviter le double paiement. Sinon le payout est
			# 0 par convention et c'est `money_reward` de la .tres qui paie.
			QuestManager.complete_objective(info.quest, info.objective, dlg_payout <= 0)
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		CampaignManager.complete_endgame(path)
		return
	if action.has("finish_quest"):
		# finish_quest avant pay_bribe : les bribe-pour-finir-une-quête
		# (ex. tito_favor_ask) doivent dépenser l'argent ET compléter la quête.
		var info: Dictionary = action.finish_quest
		if action.has("pay_bribe"):
			if inv == null or not inv.spend_money(int(action.pay_bribe)):
				push_warning("[DialogueBridge] pay_bribe %d failed — quest not completed" % int(action.pay_bribe))
				return
		var dlg_payout: int = int(info.get("payout", 0))
		if inv and dlg_payout > 0:
			inv.add_money(dlg_payout)
		# Si le dialogue a versé > 0, c'est lui qui paie → coupe l'auto-pay
		# QuestManager pour éviter le double paiement. Sinon (payout = 0 par
		# convention), on laisse `money_reward` de la .tres faire le paiement.
		QuestManager.complete_objective(info.quest, info.objective, dlg_payout <= 0)
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		# pay_debt en bonus de finish_quest (consortium_*_done patterns).
		if action.has("pay_debt"):
			pay_debt(int(action.pay_debt))
		# set_flag en bonus (utilisé pour les pivots narratifs post-quête).
		if action.has("set_flag"):
			set_flag(String(action.set_flag))
		# accept_quest en bonus : chaîne close+next dans le même dialogue (évite
		# au joueur de devoir réinteragir avec le même NPC pour la suite —
		# motif des voies A/B/C/D, ex. trafico a1→a2 sur le même contact).
		if action.has("accept_quest"):
			_try_accept_any(action.accept_quest)
		return
	if action.has("pay_bribe"):
		# Bribe pure (sans finish_quest) : ex. flic qui demande de l'argent.
		if inv and inv.spend_money(action.pay_bribe):
			for axis_key in action.get("rep", {}):
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("pay_debt"):
		pay_debt(int(action.pay_debt))
		return
	# Raid : prend un % de l'argent du joueur. Utilisé par CreditorVisitManager
	# quand un cobrador débarque et force le paiement. Float 0..1.
	if action.has("raid_pct"):
		var pct: float = clamp(float(action.raid_pct), 0.0, 1.0)
		if inv:
			var taken: int = int(round(float(inv.money) * pct))
			inv.spend_money(taken)
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("earn"):
		# Gain direct, hors quête (jobs répétables : shifts au bar, promenade du chien…).
		if inv:
			inv.add_money(int(action.earn))
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("set_flag"):
		set_flag(String(action.set_flag))
		return
	if action.has("rep"):
		for axis_key in action.rep:
			ReputationSystem.modify(int(axis_key), action.rep[axis_key])

# Tente d'accepter une quête. Si refus (prereq, acte, réputation), log un warning
# clair et retourne false pour que l'appelant puisse jouer un knot de remplacement.
func _try_accept(quest_id: String) -> bool:
	if QuestManager.accept(quest_id):
		return true
	var missing: Array[String] = QuestManager.missing_prerequisites(quest_id)
	if missing.is_empty():
		push_warning("[DialogueBridge] accept '%s' refusé (acte/réputation insuffisants)" % quest_id)
	else:
		push_warning("[DialogueBridge] accept '%s' refusé — prereqs manquants : %s" % [quest_id, ", ".join(missing)])
	return false

# `accept_quest` peut être un String simple ou un Array de quest_ids — on tente
# chaque ID dans l'ordre, le 1er qui réussit suffit. Utile pour les pactes acte
# 3 qui veulent accepter A1 si pas fait, ou A2 si A1 déjà bouclée en acte 2.
func _try_accept_any(payload: Variant) -> bool:
	if payload is String:
		return _try_accept(payload)
	if payload is Array:
		for qid in payload:
			if _try_accept(String(qid)):
				return true
	return false

# Affiche un message générique de refus puis termine le dialogue. Évite que le joueur
# reste coincé sur un knot dont l'action principale a échoué silencieusement.
func _show_locked_message(quest_id: String) -> void:
	var pretty: Array[String] = []
	for pid in QuestManager.missing_prerequisites(quest_id):
		var pq: Quest = QuestManager.get_quest(pid)
		pretty.append(pq.display_name if pq != null and pq.display_name != "" else pid)
	# Réputation insuffisante : on dit quel axe construire et où on en est.
	for r in QuestManager.missing_reputation(quest_id):
		pretty.append("%s %d/%d" % [ReputationSystem.axis_label(r.axis), r.current, r.threshold])
	var hint: String = ""
	if not pretty.is_empty():
		hint = " — d'abord : %s" % ", ".join(pretty)
	line_shown.emit("", "Pas encore le bon moment%s." % hint)
	choices_presented.emit(["D'accord"])
	# Vide le knot actif pour que le prochain `choose()` retombe sur end_dialogue.
	_active_knot = ""

func _on_ink_line(speaker: String, text: String) -> void:
	line_shown.emit(speaker, text)

func _on_ink_choices(choices: Array) -> void:
	choices_presented.emit(choices)

func _on_ink_ended() -> void:
	end_dialogue()

func _on_ink_ready() -> void:
	_loader.bind_external("accept_quest", Callable(self, "accept_quest"))
	_loader.bind_external("complete_objective", Callable(self, "complete_objective"))
	_loader.bind_external("modify_reputation", Callable(self, "modify_reputation"))
	_loader.bind_external("get_reputation", Callable(self, "get_reputation"))
	_loader.bind_external("add_money", Callable(self, "add_money"))
	_loader.bind_external("sell_corn", Callable(self, "sell_corn"))
	_loader.bind_external("give_corn", Callable(self, "give_corn"))
	_loader.bind_external("return_cart", Callable(self, "return_cart"))
	_loader.bind_external("pay_debt", Callable(self, "pay_debt"))
	_loader.bind_external("current_act", Callable(self, "current_act"))
	_loader.bind_external("set_flag", Callable(self, "set_flag"))
	_loader.bind_external("has_flag", Callable(self, "has_flag"))

# --- External-function hooks callable from Ink ---

func accept_quest(quest_id: String) -> void:
	QuestManager.accept(quest_id)

func complete_objective(quest_id: String, objective_id: String) -> void:
	QuestManager.complete_objective(quest_id, objective_id)

func modify_reputation(axis: int, delta: int) -> void:
	ReputationSystem.modify(axis, delta)

func get_reputation(axis: int) -> int:
	return ReputationSystem.get_value(axis)

func pay_debt(amount: int) -> int:
	var inv: Inventory = _player_inventory()
	if inv == null:
		return 0
	var requested: int = min(amount, inv.money, CampaignManager.debt_remaining())
	if requested <= 0:
		return 0
	if not inv.spend_money(requested):
		return 0
	var applied: int = CampaignManager.pay_debt(requested)
	# Intégration quête acte 1 : dès qu'un premier acompte de 2000 est versé, la quête
	# peut se clôturer (earn_seed_money + first_payment deviennent OK).
	if applied > 0 and QuestManager.is_active("act1_heritage") and CampaignManager.debt_paid >= CampaignManager.ACT1_THRESHOLD:
		QuestManager.complete_objective("act1_heritage", "earn_seed_money")
		QuestManager.complete_objective("act1_heritage", "first_payment")
	return applied

func _link_quest_on_flag(key: String) -> void:
	match key:
		"met_consortium":
			if QuestManager.is_active("act1_heritage"):
				QuestManager.complete_objective("act1_heritage", "meet_consortium")

func current_act() -> int:
	return CampaignManager.current_act

func set_flag(key: String) -> void:
	CampaignManager.set_flag(key, true)
	NPCScheduler.on_flag_set(key)
	_link_quest_on_flag(key)

func has_flag(key: String) -> bool:
	return CampaignManager.has_flag(key)

func add_money(amount: int) -> void:
	var inv: Inventory = _player_inventory()
	if inv:
		inv.add_money(amount)

func sell_corn(price: int) -> void:
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	if cart and cart.is_carrying() and cart.sell(price):
		EventBus.customer_served.emit(_active_npc_id)

func give_corn() -> void:
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	if cart and cart.is_carrying() and cart.give_away():
		EventBus.customer_served.emit(_active_npc_id)

func return_cart() -> void:
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	if cart and cart.is_carrying():
		cart.drop_off(_player_inventory())

func _player_inventory() -> Inventory:
	if GameManager.player == null:
		return null
	return GameManager.player.get_node_or_null("Inventory") as Inventory

func _endgame_path_for_string(s: String) -> int:
	match s.to_upper():
		"PREFEITO": return CampaignManager.Endgame.PREFEITO
		"POLICIA":  return CampaignManager.Endgame.POLICIA
		"TRAFICO":  return CampaignManager.Endgame.TRAFICO
		"CONSORTIUM": return CampaignManager.Endgame.CONSORTIUM
		_:          return CampaignManager.Endgame.NONE


# --- Roda scénarisée (verbe start_altinha) ---

func start_altinha_challenge(config: Dictionary) -> void:
	_altinha_challenge = config
	EventBus.altinha_challenge_requested.emit(config)

func altinha_challenge_pending() -> bool:
	return not _altinha_challenge.is_empty()

func _on_minigame_ended_for_challenge(minigame_id: String, result: Dictionary) -> void:
	if minigame_id != "altinha" or _altinha_challenge.is_empty():
		return
	var cfg: Dictionary = _altinha_challenge
	_altinha_challenge = {}
	var flag: String = String(cfg.get("flag", ""))
	var tries: int = int(CampaignManager.get_flag(flag + "_essais") if CampaignManager.get_flag(flag + "_essais") != null else 0) + 1
	CampaignManager.set_flag(flag + "_essais", tries)
	var goal: int = int(cfg.get("touch_goal", 0))
	var won: bool = bool(result.get("goal_reached", false)) \
		or (goal > 0 and int(result.get("touches", 0)) >= goal) \
		or (goal == 0 and bool(result.get("qualifies", false)))
	var text: String
	var color: Color = Color(0.55, 0.9, 0.55, 1)
	if won:
		text = String(cfg.get("win_text", "Roda réussie !"))
	elif tries >= int(cfg.get("max_tries", 2)):
		text = String(cfg.get("relent_text", cfg.get("win_text", "")))
		won = true
	else:
		text = String(cfg.get("retry_text", "Encore une — reparle-lui."))
		color = Color(0.95, 0.8, 0.45, 1)
	if won and flag != "":
		CampaignManager.set_flag(flag)
	if text != "":
		EventBus.notification_requested.emit(text, color)
