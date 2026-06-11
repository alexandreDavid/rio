extends "res://scripts/tests/IntegrationTestBase.gd"

# Groupe : Narratif & voies. Extrait du monolithe IntegrationTest.
# run() rejoue les tests dans l'ordre d'origine (await préservé).

func run() -> void:
	_test_act1_to_act2_transition()
	await _test_act2_directed_flow()
	await _test_prologue_end_to_end()
	await _test_voie_trafico_end_to_end()
	await _test_voie_policia_end_to_end()
	await _test_voie_consortium_end_to_end()
	await _test_voie_prefeito_end_to_end()
	_test_beto_quest_chain()
	_test_pmpatrol_act_dispatch()
	_test_reactive_variant_matching()
	_test_epilogue_paths_present()


# Bascule acte 1 → 2 via les vrais mécanismes : accepter act1_heritage,
# rencontrer le consortium (flag met_consortium), payer 500 R$ → l'acte doit
# basculer à 2 automatiquement. A déjà été cassé par des pivots quêtes morts
# (act1_meet_ramos/tito) — ce test verrouille la classe « blocage après 500 ».
func _test_act1_to_act2_transition() -> void:
	_section("Acte 1 → 2 : basculement automatique après 500 R$")
	_reset_campaign_state()
	_assert(QuestManager.accept("act1_heritage"), "act1_heritage acceptée")
	_assert(CampaignManager.current_act == 1, "départ acte 1")
	# Simule la rencontre Dom Nilton : pose met_consortium via DialogueBridge
	# pour déclencher _link_quest_on_flag (qui clôt meet_consortium).
	DialogueBridge.set_flag("met_consortium")
	_assert(QuestManager.get_objectives_state("act1_heritage").get("meet_consortium", false),
		"meet_consortium clos par le flag")
	# Simule l'acompte au niveau campagne (CampaignManager.pay_debt ne dépend
	# pas du joueur — il maj debt_paid + déclenche _check_act_advance) puis
	# clôt les deux objectifs que DialogueBridge.pay_debt closerait en jeu.
	CampaignManager.pay_debt(CampaignManager.ACT1_THRESHOLD)
	QuestManager.complete_objective("act1_heritage", "earn_seed_money")
	QuestManager.complete_objective("act1_heritage", "first_payment")
	_assert(QuestManager.is_completed("act1_heritage"),
		"act1_heritage complétée après acompte (3 objectifs OK)")
	# Nouveau design : le seul acompte ne bascule PLUS en acte 2 — il faut le
	# retour à la maison + la nuit chez tio Zé (flag act1_closed).
	_assert(CampaignManager.current_act == 1,
		"acte 1 maintenu après le seul acompte (retour maison requis)")
	CampaignManager.set_flag("act1_closed")
	_assert(CampaignManager.current_act == 2,
		"acte 2 enclenché après le retour maison (act1_closed)")
	_reset_campaign_state()


# Acte 2 dirigé : la nuit doit passer dans la maison (HouseNightTrigger →
# Act1NightCutscene → flag `act1_closed`) AVANT que les patrons (Tito, Ramos,
# Padre, Magalhães) ne proposent leur pacte. À la sortie, TitoApprocheTrigger
# pousse Tito vers le joueur.
func _test_act2_directed_flow() -> void:
	_section("Acte 2 dirigé — nuit, pact gating, Tito aborde")
	_reset_campaign_state()
	_complete_quest_all_objectives("prologue_pedrinho")
	_complete_quest_all_objectives("act1_heritage")
	CampaignManager.pay_debt(CampaignManager.ACT1_THRESHOLD)
	_assert(CampaignManager.current_act == 1,
		"acte 1 maintenu tant que la nuit (retour maison) n'est pas passée")
	_assert(not CampaignManager.has_flag("act1_closed"),
		"act1_closed pas encore posé tant que la nuit n'est pas passée")

	# Pacte refusé tant que act1_closed=false (Tito ne propose pas l'offer).
	# On vérifie via la cinématique : on appelle directement les knots et on
	# regarde si le pacte est engagé. Tito.gd contient le gating ; pour le
	# tester sans NPC instancié, on rejoue la logique d'Act1NightCutscene.
	_assert(not CampaignManager.has_flag("voie_trafico"),
		"voie_trafico inactive avant act1_closed")

	# Joue la cinématique de nuit via DialogueBridge directement.
	DialogueBridge.start_dialogue("narrateur", "act1_night_fall")
	DialogueBridge.choose(0)  # next → act1_night_wake
	DialogueBridge.choose(0)  # set_flag act1_closed
	_assert(CampaignManager.has_flag("act1_closed"),
		"act1_closed posé après la cinématique de nuit (set_flag chain)")
	_assert(CampaignManager.current_act == 2,
		"acte 2 atteint après le retour maison + nuit (act1_closed)")

	# Une fois act1_closed posé, le pacte Tito est jouable.
	DialogueBridge.start_dialogue("tito", "tito_pacto_trafico_offer")
	# Choix 1 : "Plus tard" → tito_approached seulement (pas de voie scellée).
	DialogueBridge.choose(1)
	_assert(CampaignManager.has_flag("tito_approached"),
		"choix 'plus tard' pose tito_approached")
	_assert(not CampaignManager.has_flag("voie_trafico"),
		"choix 'plus tard' ne scelle pas la voie")
	_reset_campaign_state()


# Prologue JOUABLE de bout en bout : Seu João donne la quête, puis le joueur
# enquête en interagissant les vrais spots de la favela (mère → vovó → Juca →
# citerne). Couvre l'accessibilité/position/gating des spots du prologue.
func _test_prologue_end_to_end() -> void:
	_section("Jouabilité — prologue « Cadê o Pedrinho? » (spots réels favela)")
	_reset_campaign_state()
	# La mère aborde le joueur (cutscene MaeAborde) — chaîne 2 répliques :
	# accept_quest + flag, puis clôt l'objectif ask_mae.
	CampaignManager.set_flag("intro_bump_seen")
	DialogueBridge.start_dialogue("vizinha", "mae_prologue_offer")
	DialogueBridge.choose(0)  # accept_quest + prologue_started + next
	DialogueBridge.choose(0)  # finish_quest ask_mae
	_assert(QuestManager.is_active("prologue_pedrinho")
			or QuestManager.is_completed("prologue_pedrinho"),
		"prologue accepté via la mère (cutscene MaeAborde)")
	_assert(CampaignManager.has_flag("prologue_started"),
		"flag prologue_started posé par la mère")
	_assert(QuestManager.get_objectives_state("prologue_pedrinho").get("ask_mae", false),
		"objectif ask_mae clos par la mère (plus besoin de la recliquer)")
	var fav: Node = (load(_FAVELA) as PackedScene).instantiate()
	add_child(fav)
	await get_tree().process_frame
	await get_tree().process_frame
	var spots: Array = []
	for sn in ["VizinhaSpot", "VovoSpot", "GarotoSpot", "PedrinhoSpot"]:
		var n: Node = _find_by_name_in(fav, sn)
		_assert(n != null, "prologue : spot '%s' présent et accessible (in-game)" % sn)
		if n:
			spots.append(n)
	var cycles: int = 16
	while not QuestManager.is_completed("prologue_pedrinho") and cycles > 0:
		for spot in spots:
			spot._on_interacted(null)
			if DialogueBridge.is_active():
				DialogueBridge.choose(0)
		cycles -= 1
	_assert(QuestManager.is_completed("prologue_pedrinho"),
		"prologue résolu via les spots (mère→vovó→Juca→citerne→retour mère)")
	var ost: Dictionary = QuestManager.get_objectives_state("prologue_pedrinho")
	_assert(bool(ost.get("find_pedrinho", false)),
		"find_pedrinho clos (citerne)")
	_assert(bool(ost.get("bring_home", false)),
		"bring_home clos (Pedrinho rendu à sa mère — discours change)")
	_assert(CampaignManager.has_flag("pedrinho_following"),
		"flag pedrinho_following posé (Pedrinho a suivi)")
	_assert(CampaignManager.has_flag("pedrinho_home"),
		"flag pedrinho_home posé (retrouvailles)")
	_assert(_find_by_name_in(fav, "PedrinhoFollower") != null,
		"PedrinhoFollower présent dans la favela (suiveur)")
	fav.queue_free()
	# Deux frames : laisse les call_deferred des nodes favela libérés se vider
	# avant que le prochain test n'émette des signaux globaux.
	await get_tree().process_frame
	await get_tree().process_frame


func _test_voie_trafico_end_to_end() -> void:
	# Trafico A2 (pickup_palace) est désormais bouclée par un Pickable au Palace
	# (PalaceSacoche, scenes/props/) — pas via le contact spot. Le test la coche
	# manuellement (arrival hook) en l'absence du Pickable physique.
	# A6 (réception cargo) est sur l'îlot offshore de Zona Sul — même instance.
	# A3 (drive_botafogo) est cochée par MainBoot._on_district_changed.
	await _run_voie_e2e({
		"name": "Tráfico", "pact_npc": "tito", "pact_knot": "tito_pacto_trafico_offer",
		"voie_flag": "voie_trafico", "q1": "trafico_a1_livraison", "q9": "trafico_a9_corrida",
		"crown_knot": "tito_trafico_corrida", "endgame": CampaignManager.Endgame.TRAFICO,
		"arrival": [
			["trafico_a2_pickup", "pickup_palace"],
			["trafico_a3_chauffeur", "drive_botafogo"],
		],
		"stations": [
			[_COPA, "TraficoContactSpot"], [_COPA, "TraficoTioZeSpot"],
			[_ZONASUL, "TraficoZonaSulSpot"], [_FAVELA, "TraficoIntimSpot"],
			[_ZONASUL, "TraficoCagarrasSpot"], [_NITEROI, "TraficoNiteroiSpot"],
		],
	})


func _test_voie_policia_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Polícia", "pact_npc": "ramos", "pact_knot": "ramos_pacto_policia_offer",
		"voie_flag": "voie_policia", "q1": "policia_b1_intel", "q9": "policia_b9_madrugada",
		"crown_knot": "ramos_policia_madrugada", "endgame": CampaignManager.Endgame.POLICIA,
		"stations": [
			[_COPA, "PoliciaContactSpot"], [_COPA, "PoliciaTioZeSpot"],
			[_FAVELA, "PoliciaFilatureSpot"], [_BOTAFOGO, "PoliciaEscorteSpot"],
			[_ZONASUL, "PoliciaDescenteSpot"], [_CORCOVADO, "PoliciaReperageSpot"],
			[_NITEROI, "PoliciaSaisieSpot"], [_MARACANA, "PoliciaSegurancaSpot"],
		],
	})


func _test_voie_consortium_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Consortium", "pact_npc": "magalhaes", "pact_knot": "magalhaes_pacto_consortium_offer",
		"voie_flag": "voie_consortium", "q1": "consortium_c1_recouvrement", "q9": "consortium_c9_pacto",
		"crown_knot": "magalhaes_consortium_pacto", "endgame": CampaignManager.Endgame.CONSORTIUM,
		"stations": [
			[_COPA, "ConsortiumContactSpot"], [_COPA, "ConsortiumTioZeSpot"],
			[_BARRA, "ConsortiumBarraSpot"], [_ZONASUL, "ConsortiumZonaSulSpot"],
			[_SANTOS, "ConsortiumAeroportoSpot"], [_NITEROI, "ConsortiumNiteroiSpot"],
		],
	})


func _test_voie_prefeito_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Prefeito", "pact_npc": "padre", "pact_knot": "padre_pacto_prefeito_offer",
		"voie_flag": "voie_prefeito", "q1": "prefeito_d1_peticao", "q9": "prefeito_d9_eleicao",
		"crown_knot": "padre_prefeito_eleicao", "endgame": CampaignManager.Endgame.PREFEITO,
		"stations": [
			[_COPA, "PrefeitoContactSpot"], [_COPA, "PrefeitoTioZeSpot"],
			[_BOTAFOGO, "PrefeitoAterroSpot"], [_FAVELA, "PrefeitoFavelaSpot"],
			[_ZONASUL, "PrefeitoZonaSulSpot"], [_MARACANA, "PrefeitoMaracanaSpot"],
			[_NITEROI, "PrefeitoNiteroiSpot"],
		],
	})


# --- Tests pour pivots narratifs récents ---

func _test_beto_quest_chain() -> void:
	_section("Side quest favela : O Beto sumiu")
	QuestManager._state.clear()
	QuestManager._objectives.clear()
	# Re-register au cas où.
	for path in QUEST_RESOURCES:
		if ResourceLoader.exists(path):
			var q: Resource = load(path)
			if q is Quest:
				QuestManager.register_quest(q)
	_assert(QuestManager.is_available("beto_lost"), "beto_lost disponible")
	_assert(QuestManager.accept("beto_lost"), "accept beto_lost")
	QuestManager.complete_objective("beto_lost", "find_beto")
	_assert(QuestManager.is_active("beto_lost"), "encore actif après find_beto")
	QuestManager.complete_objective("beto_lost", "tell_vizinha")
	_assert(QuestManager.is_completed("beto_lost"), "beto_lost complétée après tell_vizinha")


func _test_pmpatrol_act_dispatch() -> void:
	_section("PMPatrol — knots récurrents par acte + scaling bribe")
	# Vérifie que les knots existent et que les montants/structure correspondent
	# au design (acte 1: 50, acte 2: 80, acte 3+: 150).
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	var expectations: Array = [
		{"knot": "cop_shakedown_recurring", "amount": 50},
		{"knot": "cop_shakedown_recurring_act2", "amount": 80},
		{"knot": "cop_shakedown_recurring_act3", "amount": 150},
	]
	for e in expectations:
		var knot: String = String(e.knot)
		_assert(dialogues.has(knot), "knot '%s' présent" % knot)
		if not dialogues.has(knot):
			continue
		var d: Dictionary = dialogues[knot]
		var on_choose: Dictionary = d.get("on_choose", {})
		var pay_action: Dictionary = on_choose.get("0", {})
		var bribe: int = int(pay_action.get("pay_bribe", -1))
		_assert(bribe == int(e.amount), "%s : pay_bribe = %d (attendu %d)" % [knot, bribe, int(e.amount)])
	# La cinématique 1er shakedown utilise le knot canonique cop_shakedown.
	_assert(dialogues.has("cop_shakedown"), "cop_shakedown (1er) présent")


func _test_reactive_variant_matching() -> void:
	_section("ReactiveDialogueSpot : sélection de variante")
	# Test unitaire de la logique de matching (sans instancier le Node, on appelle
	# directement le helper). On crée un ReactiveDialogueSpot temporaire.
	var spot_script: GDScript = load("res://scripts/world/ReactiveDialogueSpot.gd")
	_assert(spot_script != null, "ReactiveDialogueSpot.gd charge")
	if spot_script == null:
		return
	var spot: Node = spot_script.new()
	var test_variants: Array[Dictionary] = [
		{"id": "A", "flag": "test_flag_a"},
		{"id": "B", "flag": "test_flag_b", "not_flag": "test_seen_b"},
		{"id": "default"},
	]
	spot.variants = test_variants
	# Reset flags test.
	CampaignManager.flags.erase("test_flag_a")
	CampaignManager.flags.erase("test_flag_b")
	CampaignManager.flags.erase("test_seen_b")

	# Aucun flag : default match.
	var v: Dictionary = spot._pick_variant()
	_assert(v.get("id", "") == "default", "aucun flag → default")
	# A actif : A match.
	CampaignManager.set_flag("test_flag_a")
	v = spot._pick_variant()
	_assert(v.get("id", "") == "A", "flag A posé → variante A")
	# A + B actifs : A reste (priorité ordre).
	CampaignManager.set_flag("test_flag_b")
	v = spot._pick_variant()
	_assert(v.get("id", "") == "A", "A et B actifs → A (1ère match)")
	# Retire A : B prend le relais.
	CampaignManager.flags.erase("test_flag_a")
	v = spot._pick_variant()
	_assert(v.get("id", "") == "B", "A retiré → B")
	# Pose le seen de B : B est masqué, on retombe sur default.
	CampaignManager.set_flag("test_seen_b")
	v = spot._pick_variant()
	_assert(v.get("id", "") == "default", "B seen → fallback default")
	# Cleanup.
	for f in ["test_flag_a", "test_flag_b", "test_seen_b"]:
		CampaignManager.flags.erase(f)
	spot.free()


func _test_epilogue_paths_present() -> void:
	_section("EpilogueScreen — 3 voies définies")
	var script: GDScript = load("res://scripts/ui/Epilogue.gd")
	_assert(script != null, "Epilogue.gd charge")
	if script == null:
		return
	# EPILOGUES est une constante du script — accessible via get_script_constant_map.
	var consts: Dictionary = script.get_script_constant_map()
	_assert(consts.has("EPILOGUES"), "constante EPILOGUES présente")
	if not consts.has("EPILOGUES"):
		return
	var epilogues: Dictionary = consts["EPILOGUES"]
	for path in [CampaignManager.Endgame.PREFEITO, CampaignManager.Endgame.POLICIA, CampaignManager.Endgame.TRAFICO]:
		_assert(epilogues.has(path), "épilogue défini pour la voie %d" % path)
		if not epilogues.has(path):
			continue
		var data: Dictionary = epilogues[path]
		_assert(String(data.get("title", "")) != "", "voie %d : title non vide" % path)
		_assert(String(data.get("body", "")).length() > 200, "voie %d : body substantiel (>200 chars)" % path)

