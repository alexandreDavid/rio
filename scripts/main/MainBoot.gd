extends Node

# Entry-point boot script. Vérifie les autoloads et enregistre les quêtes connues.

# Preload des cinématiques (class_name) pour s'assurer que Godot les résout au
# parse-time même quand le projet n'a pas encore généré tous les .uid de classe.
const _Act3IntroCutsceneRef = preload("res://scripts/cutscenes/Act3IntroCutscene.gd")

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
	"res://resources/quests/beto_lost.tres",
]

# Quêtes auto-acceptées dès qu'elles deviennent disponibles (passage d'acte).
# Pivot narratif → on veut qu'elles apparaissent dans le journal sans dialogue préalable.
const AUTO_ACCEPT_ON_AVAILABLE: Array[String] = [
	"act2_intro",
]

const NG_PLUS_META_PATH: String = "user://ng_plus.json"

func _ready() -> void:
	print("[Rio] boot\n" + _autoload_report())
	_register_quests()
	_load_ng_plus_meta()
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.corn_cart_state_changed.connect(_on_corn_cart_state_changed)
	EventBus.customer_served.connect(_on_customer_served)
	DistrictManager.district_changed.connect(_on_district_changed)
	# Auto-load en différé : laisse tous les enfants (Player, NPCs, HUD…) finir leur _ready
	# avant d'écraser leur état avec la sauvegarde.
	if SaveSystem.has_save():
		call_deferred("_attempt_load")
	else:
		# Nouvelle partie : le joueur démarre dans la maison de tio Zé,
		# physiquement présente DANS la favela. Pose le district courant en
		# conséquence — sans ça, walk_to("copacabana") via ExitToCopa serait
		# court-circuité car _current resterait à "copacabana" par défaut.
		DistrictManager.set_current("favela_morro")
		call_deferred("_check_auto_accept")
		call_deferred("_play_intro_cutscene")

func _on_act_changed(new_act: int) -> void:
	_check_auto_accept()
	if new_act == 2:
		# Au passage d'acte 2 : on demande au joueur de revenir à la favela
		# voir tio Zé / sa mère / vovó. La cinématique reveal du Concierge se
		# déclenche en parallèle pour le moment fort sur le calçadão.
		CampaignManager.set_flag("should_visit_home")
		Act2RevealCutscene.run()
	elif new_act == 3:
		# Pivot acte 3 : Dom Nilton vient officialiser le choix de voie. Si le
		# joueur est ailleurs qu'à Copa, _on_district_changed la rejouera quand
		# il y reviendra.
		_Act3IntroCutsceneRef.run()

# Premier client servi : marque first_sale_done (utilisé par l'ObjectiveBanner +
# par les dialogues réactifs de la maison). Vérifie aussi si on peut déclencher
# le 1er shakedown (le joueur a probablement maintenant l'argent du pot-de-vin).
func _on_customer_served(_npc_id: String) -> void:
	if not CampaignManager.has_flag("first_sale_done"):
		CampaignManager.set_flag("first_sale_done")
	_try_first_shakedown()

# Note: la cascade des paliers narratifs (5k, 10k, 15k, 20k) ainsi que le flag
# first_payment_done vivent désormais dans CampaignManager.pay_debt() — ils sont
# état de campagne, pas state machine de boot. MainBoot ne s'abonne plus à
# debt_paid (kept simple : la responsabilité a migré là où elle appartient).

func _on_corn_cart_state_changed(_carrying: bool) -> void:
	# La logique de déclenchement vit dans _try_first_shakedown — appelée aussi
	# par district_changed et customer_served, le 1er à remplir les conditions gagne.
	_try_first_shakedown()

# Mapping district → objectif de la quête tour guidé. Quand le joueur arrive
# dans un district avec la quête active, on coche l'objectif et on lui glisse
# un pourboire de 100 R$ comme promis par le touriste.
const TOUR_OBJECTIVES: Dictionary = {
	"corcovado":  "see_corcovado",
	"pao_acucar": "see_paoacucar",
	"lagoa":      "see_lagoa",
	# Maracanã n'est pas dans le tour officiel — c'est plus une activité supporter.
}

# Conditions du premier shakedown PMPatrol :
# - Pas encore joué
# - Joueur sur le calçadão (sinon le PM marche 150 s depuis la plage)
# - Charrette en main (cohérent avec le scénario : il taxe le vendeur)
# - Au moins l'argent du pot-de-vin (sinon le choix "Payer" ne fait rien et c'est frustrant)
const FIRST_SHAKEDOWN_BRIBE_AMOUNT: int = 20

func _try_first_shakedown() -> void:
	if CampaignManager.has_flag("first_shakedown_played"):
		return
	if DistrictManager.current() != "copacabana":
		return
	var cart: Node = get_tree().get_first_node_in_group("corn_cart")
	if cart == null or not cart.has_method("is_carrying") or not cart.call("is_carrying"):
		return
	if GameManager.player == null:
		return
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null or inv.money < FIRST_SHAKEDOWN_BRIBE_AMOUNT:
		return
	FirstShakedownCutscene.run()

func _on_district_changed(district_id: String) -> void:
	# Premier shakedown : ré-évalue à chaque changement de district (cas où le
	# joueur arrive sur le calçadão avec la charrette + de l'argent en poche).
	_try_first_shakedown()
	# Pivot acte 3 différé : si le joueur n'était pas à Copa au moment de la
	# bascule, on rejoue dès qu'il y arrive.
	if district_id == "copacabana" and CampaignManager.current_act >= 3 \
			and not CampaignManager.has_flag("act3_intro_played"):
		_Act3IntroCutsceneRef.run()
	# Visite famille : entrer dans la favela suffit à consommer le hint
	# "should_visit_home" — peu importe à quelle variante mãe/vovó le joueur
	# parle (letter / sick / revisit / after_payment), être chez lui = visite
	# accomplie. Évite que le bandeau reste figé sur "Monte voir tio Zé" quand
	# une variante de palier post-5k prend le dessus sur "after_payment" et
	# ne pose pas elle-même home_visit_done.
	if district_id == "favela_morro" \
			and CampaignManager.has_flag("should_visit_home") \
			and not CampaignManager.has_flag("home_visit_done"):
		CampaignManager.set_flag("home_visit_done")
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
		var tour_inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
		if tour_inv:
			tour_inv.add_money(100)
	QuestManager.complete_objective("tourist_vip_tour", obj_id)

func _check_auto_accept() -> void:
	for quest_id in AUTO_ACCEPT_ON_AVAILABLE:
		if QuestManager.is_available(quest_id):
			QuestManager.accept(quest_id)

# Charge le fichier méta NG+ (écrit par Epilogue.gd au "Nouvelle partie+"). Sert
# à ce que IntroSeuJoao et autres dialogues sachent qu'on n'est pas la 1re run.
func _load_ng_plus_meta() -> void:
	if not FileAccess.file_exists(NG_PLUS_META_PATH):
		return
	var f: FileAccess = FileAccess.open(NG_PLUS_META_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return
	CampaignManager.ng_plus_count = int(data.get("ng_plus_count", 0))
	var paths: Variant = data.get("completed_paths", [])
	if paths is Array:
		CampaignManager.completed_paths = (paths as Array).duplicate()
	# Flag dérivé pour les ReactiveDialogueSpot et le DialogueBridge — peut être
	# testé comme n'importe quel autre flag campagne.
	if CampaignManager.ng_plus_count > 0:
		CampaignManager.set_flag("is_ng_plus")

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
