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
	_test_epilogue_memory()
	_test_pos_carnaval()
	_test_contessa_fundo()
	_test_story_clarity()


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
	# A3 (drive_botafogo) se joue au garage de l'enseada (TraficoChauffeurSpot).
	await _run_voie_e2e({
		"name": "Tráfico", "pact_npc": "tito", "pact_knot": "tito_pacto_trafico_offer",
		"voie_flag": "voie_trafico", "q1": "trafico_a1_livraison", "q9": "trafico_a9_corrida",
		"crown_knot": "tito_trafico_corrida", "endgame": CampaignManager.Endgame.TRAFICO,
		# despistar_pm / fugir_praia / semer_flagrante : objectifs FUITE joués par
		# CobradorChase en temps réel — impossibles à dérouler dans la boucle
		# synchrone, cochés par hook (le spot déclenche bien start_chase au passage).
		"arrival": [
			["trafico_a2_pickup", "pickup_palace"],
			["trafico_a2_pickup", "despistar_pm"],
			["trafico_a4_ipanema", "fugir_praia"],
			["trafico_a5_intim", "fugir_morro"],
			["trafico_a6_cagarras", "receive_cargo"],
			["trafico_a7_tioze", "semer_sombra"],
			["trafico_a8_baia", "semer_flagrante"],
		],
		"stations": [
			[_COPA, "TraficoContactSpot"],
			[_FAVELA, "TraficoZildaSpot"], [_COPA, "TraficoFirminoSpot"],
			[_COPA, "TraficoTioZeSpot"],
			[_BOTAFOGO, "TraficoChauffeurSpot"],
			[_ZONASUL, "TraficoZonaSulSpot"], [_FAVELA, "TraficoIntimSpot"],
			[_ZONASUL, "TraficoCagarrasSpot"],
			[_NITEROI, "TraficoBaiaRelaisSpot"], [_NITEROI, "TraficoCriqueSpot"],
			[_NITEROI, "TraficoNiteroiSpot"],
		],
		# Reinado acte 5 : pedágio + blitz (Copa) puis carga du camarote (Sapucaí).
		"reign": {
			"q_last": "reinado_a_carga",
			"arrival": [["reinado_a_pedagio", "fugir_blitz"]],
			"stations": [
				[_COPA, "ReinadoTraficoSpot"],
				[_SAMBO, "ReinadoCargaSpot"],
			],
		},
	})


func _test_voie_policia_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Polícia", "pact_npc": "ramos", "pact_knot": "ramos_pacto_policia_offer",
		"voie_flag": "voie_policia", "q1": "policia_b1_intel", "q9": "policia_b9_madrugada",
		"crown_knot": "ramos_policia_madrugada", "endgame": CampaignManager.Endgame.POLICIA,
		"crown_spot": [_FAVELA, "OperacaoMadrugadaSpot"],
		# Filatures (StakeoutZone temps réel, lancées par les spots) — cochées
		# par hook, la boucle synchrone ne peut pas suivre le suspect.
		"arrival": [
			["policia_b2_filature", "map_network"],
			["policia_b4_descente", "filer_dealer"],
			["policia_b5_reperage", "scout_corcovado"],
			["policia_b6_tioze", "reperer_sombra"],
			["policia_b8_seguranca", "reperer_batedores"],
		],
		"stations": [
			[_COPA, "PoliciaContactSpot"],
			[_COPA, "PoliciaGarcomSpot"], [_COPA, "PoliciaOsmarSpot"],
			[_COPA, "PoliciaTioZeSpot"],
			[_FAVELA, "PoliciaFilatureSpot"],
			[_BOTAFOGO, "PoliciaEscorteSpot"], [_BOTAFOGO, "PoliciaPlanqueSpot"],
			[_ZONASUL, "PoliciaDescenteSpot"], [_CORCOVADO, "PoliciaReperageSpot"],
			[_NITEROI, "PoliciaSaisieSpot"],
			[_MARACANA, "PoliciaBriefingSpot"], [_MARACANA, "PoliciaSegurancaSpot"],
		],
		# Reinado acte 5 : ronde du bloco (Copa) puis Sapucaí limpa (planques).
		"reign": {
			"q_last": "reinado_b_camarote",
			"arrival": [
				["reinado_b_ronda", "vigiar_bloco"],
				["reinado_b_camarote", "varrer_sapucai"],
			],
			"stations": [
				[_COPA, "ReinadoPoliciaSpot"],
				[_SAMBO, "ReinadoCamaroteSpot"],
			],
		},
	})


func _test_voie_consortium_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Consortium", "pact_npc": "magalhaes", "pact_knot": "magalhaes_pacto_consortium_offer",
		"voie_flag": "voie_consortium", "q1": "consortium_c1_recouvrement", "q9": "consortium_c9_pacto",
		"crown_knot": "magalhaes_consortium_pacto", "endgame": CampaignManager.Endgame.CONSORTIUM,
		# Négociations à caution (c3/c8) : la bonne approche n'est pas le choix 0
		# (il faut lire le tell) — cochées par hook, l'enchaînement passe par la
		# variante de clôture des spots.
		"arrival": [
			["consortium_c3_partenariat", "force_signature"],
			["consortium_c5_mac", "launder_mac"],
			["consortium_c6_tioze", "porter_lembranca"],
			["consortium_c7_condos", "align_condos"],
			["consortium_c8_menace", "break_holdout"],
		],
		"stations": [
			[_COPA, "ConsortiumContactSpot"],
			[_COPA, "ConsortiumGovernantaSpot"], [_COPA, "ConsortiumPorteiroSpot"],
			[_COPA, "ConsortiumTioZeSpot"],
			[_BARRA, "ConsortiumBarraSpot"], [_ZONASUL, "ConsortiumZonaSulSpot"],
			[_SANTOS, "ConsortiumAeroportoSpot"], [_NITEROI, "ConsortiumNiteroiSpot"],
		],
		# Reinado acte 5 : charte Riserva (barraqueiro) puis camarote de l'école —
		# négociations à tell (bon choix ≠ 0) cochées par hook.
		"reign": {
			"q_last": "reinado_c_camarote",
			"arrival": [
				["reinado_c_vitrine", "dobrar_barraqueiro"],
				["reinado_c_camarote", "convencer_presidente"],
			],
			"stations": [
				[_COPA, "ReinadoConsortiumSpot"], [_COPA, "BarraqueiroRiservaSpot"],
				[_SAMBO, "ReinadoPresidenteSpot"],
			],
		},
	})


func _test_voie_prefeito_end_to_end() -> void:
	await _run_voie_e2e({
		"name": "Prefeito", "pact_npc": "padre", "pact_knot": "padre_pacto_prefeito_offer",
		"voie_flag": "voie_prefeito", "q1": "prefeito_d1_peticao", "q9": "prefeito_d9_eleicao",
		"crown_knot": "padre_prefeito_eleicao", "endgame": CampaignManager.Endgame.PREFEITO,
		# Mutirão d5 : Válter exige 100 R$ (pas d'inventaire en headless) et le
		# bon choix de Rogério n'est pas le 0 — cochés par hook. Marta, elle,
		# se convainc réellement via son spot (choix 0).
		"arrival": [
			["prefeito_d3_mediation", "ouvir_capanga"],
			["prefeito_d5_rally", "convencer_valter"],
			["prefeito_d5_rally", "convencer_rogerio"],
			["prefeito_d6_mac", "inaugurate_expo"],
			["prefeito_d7_tioze", "porter_lembranca"],
		],
		"stations": [
			[_COPA, "PrefeitoContactSpot"],
			[_COPA, "PrefeitoBeataSpot"], [_COPA, "PrefeitoSacristaoSpot"],
			[_COPA, "PrefeitoTioZeSpot"],
			[_COPA, "PadreCampagneSpot"], [_COPA, "ComicioTribunaSpot"],
			[_BOTAFOGO, "PrefeitoAterroSpot"],
			[_FAVELA, "FamiliaConflitoSpot"], [_FAVELA, "CapangaTitoSpot"],
			[_FAVELA, "PrefeitoFavelaSpot"],
			[_ZONASUL, "PrefeitoZonaSulSpot"], [_ZONASUL, "ProcissaoChegadaSpot"],
			[_MARACANA, "PrefeitoMaracanaSpot"],
			[_MARACANA, "MutiraoMartaSpot"], [_MARACANA, "MutiraoValterSpot"],
			[_MARACANA, "MutiraoRogerioSpot"],
			[_NITEROI, "PrefeitoNiteroiSpot"],
		],
		# Reinado acte 5 : Bloco do Bairro (Filó choix 0, Careca à levier — hook)
		# puis l'ordre des alas à la Sapucaí (hook).
		"reign": {
			"q_last": "reinado_d_alas",
			"arrival": [
				["reinado_d_bloco", "convencer_puxador"],
				["reinado_d_alas", "alinhar_alas"],
			],
			"stations": [
				[_COPA, "ReinadoPrefeitoSpot"],
				[_COPA, "ReinadoCostureiraSpot"], [_COPA, "ReinadoPuxadorSpot"],
				[_SAMBO, "ReinadoAlasSpot"],
			],
		},
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


# L'épilogue se souvient des carrefours : chaque issue (flag posé par le spot)
# produit son paragraphe, un seul par carrefour, inséré dans le corps ; le
# pêcheur (acte 2) a aussi son écho, silence compris.
func _test_epilogue_memory() -> void:
	_section("Épilogue — mémoire des carrefours")
	var script: GDScript = load("res://scripts/ui/Epilogue.gd")
	var consts: Dictionary = script.get_script_constant_map()
	var crossroads: Dictionary = consts["CROSSROADS"]
	var epilogues: Dictionary = consts["EPILOGUES"]
	var pecheur: Dictionary = consts["PECHEUR_SECRET"]
	for path in [CampaignManager.Endgame.TRAFICO, CampaignManager.Endgame.POLICIA, CampaignManager.Endgame.CONSORTIUM, CampaignManager.Endgame.PREFEITO]:
		_assert(crossroads.has(path) and crossroads[path].size() == 2, "voie %d : 2 carrefours mémorisés" % path)
		_assert(script.memory_paragraphs(path, {}, false).is_empty(), "voie %d : aucun flag → aucun paragraphe" % path)
		for crossroad in crossroads.get(path, []):
			_assert(crossroad.size() >= 2, "voie %d : carrefour à ≥ 2 issues" % path)
			for flag in crossroad:
				var memories: PackedStringArray = script.memory_paragraphs(path, {flag: true}, false)
				_assert(memories.size() == 1 and memories[0] == crossroad[flag], "voie %d : %s → son paragraphe" % [path, flag])
		# Deux issues du MÊME carrefour posées (save bricolée) → un seul paragraphe.
		var first: Dictionary = crossroads[path][0]
		var both: Dictionary = {}
		for flag in first:
			both[flag] = true
		_assert(script.memory_paragraphs(path, both, false).size() == 1, "voie %d : un paragraphe max par carrefour" % path)
	# Les flags d'une autre voie n'entrent pas dans l'épilogue.
	_assert(script.memory_paragraphs(CampaignManager.Endgame.PREFEITO, {"voisin_exilado": true}, false).is_empty(), "flag Tráfico ignoré par l'épilogue Prefeito")
	# Pêcheur : Ramos / Miguel / silence, et rien tant que la quête n'est pas close.
	_assert(script.memory_paragraphs(CampaignManager.Endgame.POLICIA, {"pecheur_to_ramos": true}, true) == PackedStringArray([pecheur["pecheur_to_ramos"]]), "pêcheur → Ramos")
	_assert(script.memory_paragraphs(CampaignManager.Endgame.TRAFICO, {"pecheur_to_miguel": true}, true) == PackedStringArray([pecheur["pecheur_to_miguel"]]), "pêcheur → Miguel")
	_assert(script.memory_paragraphs(CampaignManager.Endgame.CONSORTIUM, {}, true) == PackedStringArray([pecheur[""]]), "pêcheur → silence")
	_assert(script.memory_paragraphs(CampaignManager.Endgame.CONSORTIUM, {}, false).is_empty(), "pêcheur pas tranché → pas d'écho")
	# Composition réelle : insertion après « le lendemain », Zé reste en dernier.
	_reset_campaign_state()
	CampaignManager.set_flag("nenem_protegido")
	CampaignManager.set_flag("discurso_criancas")
	var ep: Node = script.new()
	var body: String = ep.compose_body(CampaignManager.Endgame.PREFEITO)
	var parts: PackedStringArray = body.split("\n\n")
	var base: PackedStringArray = String(epilogues[CampaignManager.Endgame.PREFEITO].body).split("\n\n")
	_assert(parts.size() == base.size() + 2, "Prefeito : 2 paragraphes de mémoire ajoutés")
	_assert(parts.size() > 3 and parts[2] == crossroads[CampaignManager.Endgame.PREFEITO][0]["nenem_protegido"], "mémoire insérée après « le lendemain »")
	_assert(parts.size() > 3 and parts[3] == crossroads[CampaignManager.Endgame.PREFEITO][1]["discurso_criancas"], "carrefours dans l'ordre de la chaîne")
	_assert(parts[parts.size() - 1] == base[base.size() - 1], "le paragraphe de Zé reste le dernier")
	# Le sort de Zé s'applique toujours au dernier paragraphe, mémoire ou pas.
	CampaignManager.set_flag("tio_ze_revealed")
	parts = ep.compose_body(CampaignManager.Endgame.PREFEITO).split("\n\n")
	_assert(parts[parts.size() - 1].find("nouveau concierge") != -1, "Zé repris par la Baía → dernier paragraphe réécrit")
	ep.free()
	# Polícia : Zé secouru reste au Palace — l'épilogue ne le fait plus « partir ».
	_reset_campaign_state()
	CampaignManager.set_flag("tio_ze_revealed")
	CampaignManager.set_flag("ze_rescued")
	ep = script.new()
	var policia: String = ep.compose_body(CampaignManager.Endgame.POLICIA)
	_assert(policia.find("est parti") == -1 and policia.find("réception du Palace") != -1, "Polícia + Zé secouru : Zé toujours au Palace")
	ep.free()
	_assert(script.codex_label(1) == "1 entrée de codex débloquée", "codex : singulier à 1")
	_assert(script.codex_label(3) == "3 entrées de codex débloquées", "codex : pluriel à 3")
	_reset_campaign_state()


# Depois do Carnaval : le desfile bascule le monde (Cendres le lendemain, puis
# le rythme de la semaine — feijoada du samedi), le guidage ne renvoie plus au
# Sambódromo, l'épilogue ne revient pas à chaque chargement.
func _test_pos_carnaval() -> void:
	_section("Depois do Carnaval — Cendres, feijoada, guidage")
	var saved_day: int = TimeOfDay.day_count
	var saved_phase: int = TimeOfDay.current_phase
	_reset_campaign_state()
	CampaignManager.current_act = 5
	CampaignManager.set_flag("act1_started")
	TimeOfDay.day_count = 29
	TimeOfDay.current_phase = TimeOfDay.Phase.EVENING
	_complete_quest_all_objectives("act4_carnaval_desfile")
	_assert(QuestManager.is_completed("act4_carnaval_desfile"), "desfile complété (fixture)")
	_assert(CampaignManager.has_flag("pos_carnaval"), "desfile → pos_carnaval")
	_assert(CampaignManager.has_flag("cinzas_pending"), "desfile → Cendres en attente")
	_assert(CarnavalCalendar.hud_label() == CarnavalCalendar.weekday_name(), "HUD : plus de compte à rebours après le desfile")
	# Fermeture de l'épilogue → ellipse jusqu'au mercredi matin.
	EventBus.epilogue_closed.emit()
	_assert(CarnavalCalendar.weekday() == CarnavalCalendar.QUARTA, "réveil un mercredi")
	_assert(TimeOfDay.day_count > 29 and TimeOfDay.day_count <= 36, "ellipse d'au plus une semaine")
	_assert(TimeOfDay.current_phase == TimeOfDay.Phase.MORNING, "réveil le matin")
	_assert(CarnavalCalendar.is_cinzas() and not CampaignManager.has_flag("cinzas_pending"), "Quarta-feira de Cinzas active")
	_assert(CarnavalCalendar.hud_label() == "Quarta-feira de Cinzas", "HUD : Quarta-feira de Cinzas")
	NavigationDirector._recompute()  # le recalcul de changement de jour est différé
	var g: String = NavigationDirector.current_text()
	_assert(g.find("Cinzas") != -1 and g.find("Sambódromo") == -1, "guidage des Cendres (plus le Sambódromo) : %s" % g)
	var cinzas_day: int = TimeOfDay.day_count
	EventBus.epilogue_closed.emit()
	_assert(TimeOfDay.day_count == cinzas_day, "2e fermeture : pas de nouvelle ellipse")
	# Le lendemain, la vie reprend.
	TimeOfDay.skip_to_morning(1)
	_assert(not CarnavalCalendar.is_cinzas(), "les Cendres ne durent qu'un jour")
	_assert(CarnavalCalendar.hud_label() == CarnavalCalendar.weekday_name(), "HUD : jour de semaine simple")
	NavigationDirector._recompute()
	g = NavigationDirector.current_text()
	_assert(g != "" and g.find("Sambódromo") == -1, "guidage post-Carnaval sans Sambódromo : %s" % g)
	# Seu João : la fierté une fois, puis le rythme de la semaine.
	var seu: Node = load("res://scripts/npcs/SeuJoao.gd").new()
	_assert(seu._pos_carnaval_knot() == "seu_joao_carnaval_done", "Seu João : fierté du desfile (1re fois)")
	_assert(seu._pos_carnaval_knot() == "seu_joao_pos_carnaval", "Seu João : invitation du samedi en semaine")
	TimeOfDay.skip_to_morning((CarnavalCalendar.SABADO - CarnavalCalendar.weekday() + 7) % 7)
	_assert(CarnavalCalendar.is_sabado(), "fixture : samedi")
	NavigationDirector._recompute()
	g = NavigationDirector.current_text()
	_assert(g.find("feijoada") != -1, "guidage du samedi → feijoada : %s" % g)
	_assert(seu._pos_carnaval_knot() == "seu_joao_feijoada_chama", "samedi hors de la maison → « monte au morro »")
	var house: Node = Node.new()
	house.name = "HouseInterior"
	house.add_child(seu)
	_assert(seu._pos_carnaval_knot() == "seu_joao_feijoada", "samedi à la maison → feijoada (chaise vide)")
	_assert(seu._pos_carnaval_knot() == "seu_joao_feijoada_after", "une feijoada par samedi")
	NavigationDirector._recompute()
	_assert(NavigationDirector.current_text().find("feijoada à la maison") == -1, "feijoada servie → le guidage n'y renvoie plus")
	CampaignManager.set_flag("ze_rescued")
	TimeOfDay.skip_to_morning(7)
	_assert(seu._pos_carnaval_knot() == "seu_joao_feijoada_ze", "Zé secouru → Zé à table")
	house.free()
	var dialogues: Dictionary = DialogueBridge.all_dialogues()
	for k in ["seu_joao_carnaval_done", "seu_joao_pos_carnaval", "seu_joao_feijoada", "seu_joao_feijoada_ze", "seu_joao_feijoada_after", "seu_joao_feijoada_chama"]:
		_assert(dialogues.has(k), "knot %s présent" % k)
	_assert(String(dialogues.get("seu_joao_carnaval_done", {}).get("text", "")).find("serait fier") == -1, "Seu João ne parle plus de Zé comme d'un mort")
	# Saves d'avant : desfile fait sans bascule → migrée au chargement, sans Cendres.
	CampaignManager.flags.erase("pos_carnaval")
	CampaignManager.flags.erase("cinzas_pending")
	CarnavalCalendar._on_save_loaded()
	_assert(CarnavalCalendar.is_pos_carnaval() and not CampaignManager.has_flag("cinzas_pending"), "migration de save : pos_carnaval sans Cendres")
	TimeOfDay.day_count = saved_day
	TimeOfDay.current_phase = saved_phase
	_reset_campaign_state()


# O fundo do gala : l'arc de la Contessa après le gala. Routage par étape,
# carrefour à 3 issues (flags exclusifs), mémoire (feijoada, épilogue,
# couronnement Prefeito).
func _test_contessa_fundo() -> void:
	_section("Contessa — O fundo do gala")
	var q: Quest = QuestManager.get_quest("contessa_fundo")
	_assert(q != null, "quête contessa_fundo enregistrée")
	if q == null:
		return
	_assert(q.required_act == 3 and q.prerequisite_quest_ids.has("act2_contessa_gala"), "gating : acte 3 + gala")
	_assert(q.objectives.size() == 3, "3 objectifs (filature, écoute, décision)")
	var contessa: Node = load("res://scripts/npcs/Contessa.gd").new()
	var outcomes: Array = [
		{"flag": "contessa_publica", "after": "contessa_fundo_after_publica"},
		{"flag": "contessa_discreta", "after": "contessa_fundo_after_discreta"},
		{"flag": "contessa_vendida", "after": "contessa_fundo_after_vendida"},
	]
	for i in outcomes.size():
		_reset_campaign_state()
		CampaignManager.current_act = 2
		ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 15)  # requis du gala
		_complete_quest_all_objectives("act2_contessa_gala")
		_assert(QuestManager.is_completed("act2_contessa_gala"), "[%d] fixture : gala complété" % i)
		_assert(contessa._pick_knot() != "contessa_fundo_offer", "[%d] acte 2 : pas encore d'offre" % i)
		CampaignManager.current_act = 3
		_assert(contessa._pick_knot() == "contessa_fundo_offer", "[%d] acte 3 après le gala → offre" % i)
		DialogueBridge.start_dialogue("contessa", "contessa_fundo_offer")
		DialogueBridge.choose(0)
		_assert(QuestManager.is_active("contessa_fundo"), "[%d] offre acceptée" % i)
		_assert(contessa._pick_knot() == "contessa_fundo_remind_filer", "[%d] étape 1 : filature" % i)
		QuestManager.complete_objective("contessa_fundo", "filer_ferretti")
		_assert(contessa._pick_knot() == "contessa_fundo_remind_colombo", "[%d] étape 2 : le Colombo" % i)
		QuestManager.complete_objective("contessa_fundo", "ecouter_colombo")
		_assert(contessa._pick_knot() == "contessa_fundo_reveal", "[%d] étape 3 : la révélation" % i)
		DialogueBridge.start_dialogue("contessa", "contessa_fundo_reveal")
		DialogueBridge.choose(i)
		_assert(QuestManager.is_completed("contessa_fundo"), "[%d] carrefour → quête close" % i)
		var set_count: int = 0
		for o in outcomes:
			if CampaignManager.has_flag(String(o.flag)):
				set_count += 1
		_assert(set_count == 1 and CampaignManager.has_flag(String(outcomes[i].flag)), "[%d] une seule issue posée : %s" % [i, outcomes[i].flag])
		_assert(contessa._pick_knot() == String(outcomes[i].after), "[%d] après l'arc → %s" % [i, outcomes[i].after])
	# Issue publique : le bairro l'adopte — la feijoada du samedi après le Carnaval.
	_reset_campaign_state()
	CampaignManager.current_act = 3
	ReputationSystem.set_value(ReputationSystem.Axis.CHARISMA, 15)
	_complete_quest_all_objectives("act2_contessa_gala")
	_complete_quest_all_objectives("contessa_fundo")
	_assert(QuestManager.is_completed("contessa_fundo"), "fixture : arc complété")
	CampaignManager.set_flag("contessa_publica")
	CampaignManager.set_flag("pos_carnaval")
	var saved_day: int = TimeOfDay.day_count
	TimeOfDay.day_count = 1
	while not CarnavalCalendar.is_sabado():
		TimeOfDay.day_count += 1
	_assert(contessa._pick_knot() == "contessa_feijoada", "publica + samedi post-Carnaval → feijoada au morro")
	TimeOfDay.day_count = saved_day
	contessa.free()
	# Épilogue : son sort pour toutes les voies ; au couronnement Prefeito, à ta
	# gauche seulement si alliée.
	var ep_script: GDScript = load("res://scripts/ui/Epilogue.gd")
	var fate: Dictionary = ep_script.get_script_constant_map()["CONTESSA_FATE"]
	for flag in fate:
		var mem: PackedStringArray = ep_script.memory_paragraphs(CampaignManager.Endgame.TRAFICO, {flag: true}, false)
		_assert(mem.size() == 1 and mem[0] == fate[flag], "épilogue : %s → son paragraphe" % flag)
	_reset_campaign_state()
	var ep: Node = ep_script.new()
	var body: String = ep.compose_body(CampaignManager.Endgame.PREFEITO)
	_assert(body.find("Dona Cléo à ta gauche") != -1 and body.find("la Contessa à ta gauche") == -1, "Prefeito sans alliance : Dona Cléo au couronnement")
	CampaignManager.set_flag("contessa_vendida")
	_assert(ep.compose_body(CampaignManager.Endgame.PREFEITO).find("Dona Cléo à ta gauche") != -1, "Prefeito + reçu vendu : pas de Contessa au couronnement")
	CampaignManager.flags.clear()
	CampaignManager.set_flag("contessa_discreta")
	_assert(ep.compose_body(CampaignManager.Endgame.PREFEITO).find("la Contessa à ta gauche") != -1, "Prefeito + alliée : la Contessa à ta gauche")
	ep.free()
	_reset_campaign_state()


# Clarté du scénario (retour 2026-09-16 « le scénario est confus ») :
#  - Seu João n'est jamais appelé « tio Zé » dans les surfaces joueur ;
#  - une seule source pour les titres d'acte (HUD, Diário, Saúde, carte) ;
#  - chaque bascule d'acte a une carte non vide ;
#  - « Onde estou » (story_so_far) reflète l'état : Zé, Nilton, dette, patrons
#    goûtés, voie scellée, règne.
func _test_story_clarity() -> void:
	_section("Clarté du scénario — identités, titres d'acte, « Onde estou »")
	_reset_campaign_state()
	# 1. Titres et cartes d'acte : source unique, complète.
	for n in range(1, 6):
		_assert(CampaignManager.ACT_TITLES.has(n), "ACT_TITLES a l'acte %d" % n)
		_assert(CampaignManager.act_title(n).begins_with("Acte %d" % n), "act_title(%d) commence par « Acte %d »" % [n, n])
	for n in range(2, 6):
		_assert(CampaignManager.act_card_body(n).length() > 120, "carte d'acte %d substantielle" % n)
		_assert(not ("tio Zé" in CampaignManager.act_card_body(n)), "carte d'acte %d : pas de « tio Zé »" % n)
	_assert(CampaignManager.act_card_body(1) == "", "pas de carte pour l'acte 1 (l'intro narrative s'en charge)")
	_assert("Magalhães" in CampaignManager.act_card_body(2) and "Ramos" in CampaignManager.act_card_body(2),
		"carte acte 2 : nomme les 4 patrons")
	_assert("2 000" in CampaignManager.act_card_body(2), "carte acte 2 : dit le seuil 2 000 R$")
	_assert("6 000" in CampaignManager.act_card_body(3), "carte acte 3 : dit le seuil 6 000 R$")
	# Le Diário lit les mêmes titres.
	var cats: Array = NarrativeJournal.categories()
	_assert(cats.size() > 0 and cats[0].id == NarrativeJournal.RESUMO_ID, "Diário : « Onde estou » en première catégorie")
	for cat in cats:
		if cat.has("act"):
			_assert(cat.label == CampaignManager.act_title(int(cat.act)), "Diário : libellé acte %d = ACT_TITLES" % int(cat.act))
	# Les titres de journal ne confondent plus Seu João et Zé (les knots où
	# Seu João PARLE ne sont pas titrés « tio Zé … » ; « L'héritage de tio Zé »
	# reste juste : c'est bien l'héritage de l'oncle).
	for knot in ["seu_joao_evening_ramos", "seu_joao_ng_plus_intro", "seu_joao_advice"]:
		var title: String = String(NarrativeJournal.JOURNAL_ENTRIES.get(knot, {}).get("title", ""))
		_assert(title != "" and not ("tio Zé" in title) and not ("tio Seu" in title),
			"titre Diário '%s' nomme Seu João, pas « tio Zé » (%s)" % [knot, title])
	# 2. Guidage acte 1 : Seu João nommé, jamais « tio Zé ».
	CampaignManager.set_flag("intro_bump_seen")
	NavigationDirector._recompute()
	var g: String = NavigationDirector.current_text()
	_assert("Seu João" in g, "guidage pré-héritage nomme Seu João (obtenu : %s)" % g)
	_assert(not ("tio Zé" in g), "guidage pré-héritage sans « tio Zé »")
	var all_nav: String = FileAccess.get_file_as_string("res://scripts/core/NavigationDirector.gd")
	_assert(all_nav.count("Parle à tio Zé") == 0 and all_nav.count("voir tio Zé") == 0,
		"NavigationDirector : aucune instruction « parle/voir tio Zé »")
	# Le tutoriel et l'app Saúde disent 4 voies.
	var tuto: Dictionary = (load("res://scripts/ui/Tutorial.gd") as GDScript).get_script_constant_map()
	var page0: String = String(tuto["PAGES"][0].get("text", ""))
	_assert("Quatre voies" in page0 and "Magalhães" in page0, "Tutorial : 4 voies dont Consórcio")
	_assert(not ("Trois voies" in page0), "Tutorial : plus de « trois voies »")
	# 3. « Onde estou » — acte 1.
	var so: Array[String] = NarrativeJournal.story_so_far()
	var joined: String = "\n".join(so)
	_assert(so.size() >= 4, "acte 1 : ≥ 4 phrases (%d)" % so.size())
	_assert("Zé" in joined and "disparu" in joined, "acte 1 : Zé disparu")
	_assert("Seu João" in joined and "compadre" in joined, "acte 1 : Seu João situé (compadre)")
	_assert("Nilton" in joined, "acte 1 : Dom Nilton nommé")
	_assert("Pedrinho" in joined, "acte 1 : le prologue Pedrinho d'abord")
	_assert("0 R$ payés" in joined and "500" in joined, "acte 1 : dette 0 payé, palier 500")
	# 4. « Onde estou » — acte 2, un patron goûté.
	_reset_campaign_state()
	CampaignManager.current_act = 2
	CampaignManager.debt_paid = 700
	QuestManager.accept("policia_b1_intel")
	_complete_quest_all_objectives("policia_b1_intel")
	so = NarrativeJournal.story_so_far()
	joined = "\n".join(so)
	_assert("Déjà goûtés : Capitão Ramos" in joined, "acte 2 : Ramos goûté listé")
	_assert("Encore à voir" in joined and "Tito" in joined and "Magalhães" in joined, "acte 2 : patrons restants listés")
	_assert("il manque 1300" in joined, "acte 2 : manque calculé vers 2 000 (obtenu : %s)" % joined)
	_assert("le vrai choix vient à l'acte 3" in joined, "acte 2 : dit que rien n'est scellé")
	# 5. « Onde estou » — acte 3 sans voie, puis voie scellée.
	CampaignManager.current_act = 3
	CampaignManager.debt_paid = 2000
	joined = "\n".join(NarrativeJournal.story_so_far())
	_assert("scelle le pacte" in joined, "acte 3 sans voie : invite à sceller")
	CampaignManager.flags["voie_policia"] = true
	joined = "\n".join(NarrativeJournal.story_so_far())
	_assert("Ta voie : Polícia, avec Capitão Ramos" in joined, "acte 3 : voie Polícia nommée")
	_assert("1 mission sur 9 jouée" in joined, "acte 3 : progression de voie (obtenu : %s)" % joined)
	# 6. Zé révélé / secouru, puis règne.
	CampaignManager.flags["tio_ze_revealed"] = true
	joined = "\n".join(NarrativeJournal.story_so_far())
	_assert("concierge" in joined and "n'est pas mort" in joined, "Zé révélé : dit concierge")
	CampaignManager.flags["ze_rescued"] = true
	joined = "\n".join(NarrativeJournal.story_so_far())
	_assert("arraché" in joined, "Zé secouru : dit le rescue")
	CampaignManager.current_act = 5
	CampaignManager.chosen_endgame = CampaignManager.Endgame.POLICIA
	CampaignManager.debt_paid = CampaignManager.DEBT_TOTAL
	joined = "\n".join(NarrativeJournal.story_so_far())
	_assert("Dette soldée" in joined and "Chefe de Polícia" in joined, "acte 5 : dette soldée + titre de règne")
	# 7. La maison : mãe et vovó ne disent plus « sobrinho » (mãe = mère, vovó = grand-mère).
	var house: String = FileAccess.get_file_as_string("res://scenes/interiors/HouseInterior.tscn")
	_assert(house.to_lower().count("sobrinho") == 0, "HouseInterior : mãe/vovó ne disent pas « sobrinho »")
	# 8. Nilton (acte 3) et Seu João parlent de 4 patrons, avec les vrais chiffres.
	var d: Dictionary = DialogueBridge.all_dialogues()
	var nilton: String = String(d.get("consortium_act3_intro", {}).get("text", ""))
	_assert("Quatre portes" in nilton and "Magalhães" in nilton, "Nilton acte 3 : quatre portes dont Magalhães")
	_assert(not ("Vingt-cinq mille" in nilton), "Nilton acte 3 : plus de « vingt-cinq mille »")
	var sj: String = String(d.get("seu_joao_evening_what_next", {}).get("text", ""))
	_assert("Magalhães" in sj, "Seu João : nomme aussi Magalhães")
	_reset_campaign_state()
