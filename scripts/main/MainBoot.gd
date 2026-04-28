extends Node

# Entry-point boot script. Vérifie les autoloads et enregistre les quêtes connues.

const AUTOLOADS: Array[String] = [
	"EventBus",
	"GameManager",
	"ReputationSystem",
	"TimeOfDay",
	"QuestManager",
	"DialogueBridge",
	"SaveSystem",
	"AudioManager",
	"SelfCheck",
	"BuildingManager",
	"CampaignManager",
	"NPCScheduler",
	"NarrativeJournal",
	"RandomEventManager",
]

const QUEST_RESOURCES: Array[String] = [
	"res://resources/quests/act1_heritage.tres",
	"res://resources/quests/act1_meet_ramos.tres",
	"res://resources/quests/act1_meet_tito.tres",
	"res://resources/quests/milho_01.tres",
	"res://resources/quests/deliver_package_01.tres",
	"res://resources/quests/find_bracelet_01.tres",
	"res://resources/quests/ze_invitation.tres",
	"res://resources/quests/livraison_cocos.tres",
	"res://resources/quests/police_report.tres",
	"res://resources/quests/pedros_son.tres",
	"res://resources/quests/flowers_for_beatriz.tres",
	"res://resources/quests/bike_delivery.tres",
	"res://resources/quests/church_statue.tres",
	"res://resources/quests/pharmacy_tito.tres",
	"res://resources/quests/escort_contessa.tres",
	"res://resources/quests/lost_dog.tres",
	"res://resources/quests/bar_waiter.tres",
	"res://resources/quests/act2_intro.tres",
	"res://resources/quests/act2_miguel_favela.tres",
	"res://resources/quests/act2_ramos_operacao.tres",
	"res://resources/quests/act2_padre_orfanato.tres",
	"res://resources/quests/act2_pecheur_secret.tres",
	"res://resources/quests/act2_contessa_gala.tres",
	"res://resources/quests/padaria_delivery.tres",
	"res://resources/quests/valet_palace.tres",
	"res://resources/quests/padaria_baking.tres",
	"res://resources/quests/act3_policia_madrugada.tres",
	"res://resources/quests/act3_trafico_corrida.tres",
	"res://resources/quests/act3_prefeito_eleicao.tres",
	"res://resources/quests/act4_prefeito_audiencia.tres",
	"res://resources/quests/act4_policia_purga.tres",
	"res://resources/quests/act4_trafico_tributo.tres",
	"res://resources/quests/padre_corcovado_relic.tres",
	"res://resources/quests/ronaldo_dj_paoacucar.tres",
	"res://resources/quests/carlos_lagoa_volta.tres",
	"res://resources/quests/contessa_date.tres",
	"res://resources/quests/tourist_vip_tour.tres",
	"res://resources/quests/ronaldo_maracana_torcida.tres",
	"res://resources/quests/consortium_airport_pickup.tres",
	"res://resources/quests/ronaldo_aterro_basket.tres",
	"res://resources/quests/pedro_cagarras_sup.tres",
	"res://resources/quests/act4_carnaval_desfile.tres",
]

# Quêtes auto-acceptées dès qu'elles deviennent disponibles (passage d'acte).
# Pivot narratif → on veut qu'elles apparaissent dans le journal sans dialogue préalable.
const AUTO_ACCEPT_ON_AVAILABLE: Array[String] = [
	"act2_intro",
]

func _ready() -> void:
	print("[Rio] boot\n" + _autoload_report())
	_register_quests()
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.corn_cart_state_changed.connect(_on_corn_cart_state_changed)
	DistrictManager.district_changed.connect(_on_district_changed)
	# Auto-load en différé : laisse tous les enfants (Player, NPCs, HUD…) finir leur _ready
	# avant d'écraser leur état avec la sauvegarde.
	if SaveSystem.has_save():
		call_deferred("_attempt_load")
	else:
		# Nouvelle partie : pivots + cinématique d'intro Seu João.
		call_deferred("_check_auto_accept")
		call_deferred("_play_intro_cutscene")

func _on_act_changed(new_act: int) -> void:
	_check_auto_accept()
	if new_act == 2:
		# La cinématique de révélation tio Zé se déclenche avec un petit délai
		# pour laisser passer la fin du dialogue de paiement consortium qui a
		# probablement déclenché ce passage d'acte.
		Act2RevealCutscene.run()

func _on_corn_cart_state_changed(carrying: bool) -> void:
	# Première prise en main de la charrette → PMPatrol vient racketter.
	if not carrying:
		return
	if CampaignManager.has_flag("first_shakedown_played"):
		return
	FirstShakedownCutscene.run()

# Mapping district → objectif de la quête tour guidé. Quand le joueur arrive
# dans un district avec la quête active, on coche l'objectif et on lui glisse
# un pourboire de 100 R$ comme promis par le touriste.
const TOUR_OBJECTIVES: Dictionary = {
	"corcovado":  "see_corcovado",
	"pao_acucar": "see_paoacucar",
	"lagoa":      "see_lagoa",
	# Maracanã n'est pas dans le tour officiel — c'est plus une activité supporter.
}

func _on_district_changed(district_id: String) -> void:
	if not QuestManager.is_active("tourist_vip_tour"):
		return
	if not TOUR_OBJECTIVES.has(district_id):
		return
	var obj_id: String = TOUR_OBJECTIVES[district_id]
	var objs: Dictionary = QuestManager.get_objectives_state("tourist_vip_tour")
	if objs.get(obj_id, false):
		return  # déjà visité avec le touriste
	# Pourboire d'étape (100 R$).
	if GameManager.player:
		var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
		if inv:
			inv.add_money(100)
	QuestManager.complete_objective("tourist_vip_tour", obj_id)

func _check_auto_accept() -> void:
	for quest_id in AUTO_ACCEPT_ON_AVAILABLE:
		if QuestManager.is_available(quest_id):
			QuestManager.accept(quest_id)

func _play_intro_cutscene() -> void:
	# Laisse 2 frames pour que Player et NPCs finissent leur _ready,
	# puis joue la cinématique d'introduction.
	await get_tree().process_frame
	await get_tree().process_frame
	IntroSeuJoao.run()

func _attempt_load() -> void:
	if not SaveSystem.load_game():
		push_warning("[MainBoot] Save présente mais impossible à charger")

func _register_quests() -> void:
	for path in QUEST_RESOURCES:
		if not ResourceLoader.exists(path):
			push_warning("[MainBoot] quête introuvable: %s" % path)
			continue
		var quest: Resource = load(path)
		if quest is Quest:
			QuestManager.register_quest(quest)
		else:
			push_error("[MainBoot] %s n'est pas une Quest" % path)

func _autoload_report() -> String:
	var lines: Array[String] = []
	for n in AUTOLOADS:
		var ok: bool = get_node_or_null("/root/" + n) != null
		lines.append("  %s: %s" % [n, "OK" if ok else "MANQUANT"])
	return "\n".join(lines)
