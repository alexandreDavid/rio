extends Node

# Cerveau de guidage. Source de vérité unique pour « quel est mon objectif
# MAINTENANT, et où est-il ? ». Toutes les surfaces UI (boussole, bandeau
# d'objectif) ne font que LIRE ce cerveau — elles ne recalculent plus rien
# chacune de leur côté. Autoload name: NavigationDirector.
#
# Deux niveaux :
#   1. La SÉLECTION (_sel) — quel objectif, recalculée uniquement aux
#      changements d'état (quêtes, dette, acte, district, charrette…). Donne le
#      texte (QUOI), le district cible et un ancrage spatial (OÙ).
#   2. La RÉSOLUTION LIVE (get_live) — convertit la sélection en cible écran à
#      chaque frame (positions de PNJ/charrette qui bougent), sans relancer la
#      priorité. C'est ce que la boussole consomme.

signal nav_target_changed()

enum Kind { NONE, POINT, TRAVEL }

# Sentinelle « pas de position résoluble ».
const NO_POS: Vector2 = Vector2(INF, INF)
# Au-delà, on considère que le nœud est dans un AUTRE district (les districts
# sont instanciés très loin, 6000..16000 px) — on ne pointe pas une flèche à
# travers la carte, on bascule en mode voyage.
const MAX_POINT_DIST: float = 5000.0

# Ancrages fixes de Copacabana (cf. CopacabanaGenerator + Copacabana.tscn).
const ANCHOR_CALCADAO: Vector2 = Vector2(1000, 104)
const ANCHOR_ATLANTICA: Vector2 = Vector2(1550, 48)
const ANCHOR_PALACE: Vector2 = Vector2(1700, -18)
const ANCHOR_TAXI: Vector2 = Vector2(1700, 30)
const ANCHOR_CONSORTIUM: Vector2 = Vector2(1550, 48)
# Porte de l'église (Copa) — le Padre vit dans ChurchInterior, on pointe le
# bâtiment à entrer plutôt que le nœud lointain de l'intérieur. CHURCH_X=1500,
# CHURCH_Y=SECOND_ROW_Y(-160) dans CopacabanaGenerator.
const ANCHOR_CHURCH: Vector2 = Vector2(1500, -150)

# Les 4 patrons à goûter en acte 2 (mission intro, sans pacte) puis à sceller en
# acte 3 (pacte = vrai choix de voie). Ordre = priorité de recommandation :
# Copa d'abord (Ramos, Padre) pour un premier pas sans taxi, puis Favela, Barra.
const PATRONS: Array = [
	{"q": "policia_b1_intel",          "dist": "copacabana",   "anchor": "npc:ramos",      "short": "Ramos · Academia (Copa)"},
	{"q": "prefeito_d1_peticao",       "dist": "copacabana",   "anchor": "church",         "short": "Padre · l'église"},
	{"q": "trafico_a1_livraison",      "dist": "favela_morro", "anchor": "npc:tito",       "short": "Tito · Favela"},
	{"q": "consortium_c1_recouvrement","dist": "barra_tijuca", "anchor": "npc:magalhaes",  "short": "Magalhães · Barra"},
]

# Destinations par étape de quête. Clé = "quest_id/obj_id".
# { text, dist (id district cible), anchor (ancrage local si dist == courant), short }
# anchor : "" | "calcadao" | "atlantica" | "palace" | "consortium" | "cart" | "npc:<id>"
# Repris/structuré depuis l'ancien ObjectiveBanner.QUEST_NEXT_HINT — désormais
# source unique ici (le bandeau lit ce cerveau).
const STEP: Dictionary = {
	# --- PROLOGUE : recherche de Pedrinho (1re quête principale) ---
	# Ancres `spot:<npc_id>` : les témoins du prologue sont des ReactiveDialogueSpot
	# de FavelaDoMorro.tscn — la boussole les pointe (playtest 2026-10-07, F2).
	"prologue_pedrinho/ask_mae": {"text": "🎯 Parle à la mère de Pedrinho (favela)", "dist": "favela_morro", "anchor": "spot:vizinha", "short": "La mère"},
	"prologue_pedrinho/ask_vovo": {"text": "🎯 Demande à la vovó du morro ce qu'elle a vu (sur son tabouret, près de la maison)", "dist": "favela_morro", "anchor": "spot:vovo_morro", "short": "Vovó do morro"},
	"prologue_pedrinho/ask_garoto": {"text": "🎯 Juca a la balle : tiens une roda avec lui et il parlera (favela)", "dist": "favela_morro", "anchor": "spot:juca_morro", "short": "Juca"},
	"prologue_pedrinho/find_pedrinho": {"text": "🎯 Cherche Pedrinho dans la vieille citerne (haut du morro, près de la chapelle)", "dist": "favela_morro", "anchor": "spot:pedrinho", "short": "La citerne"},
	"prologue_pedrinho/bring_home": {"text": "🎯 Ramène Pedrinho à sa mère", "dist": "favela_morro", "anchor": "spot:vizinha", "short": "La mère"},
	# --- VOIE TRÁFICO (A1 → A9) ---
	"trafico_a1_livraison/drop_calcadao": {"text": "🎯 → Copa (calçadão, face mer) : déposer le paquet au contact", "dist": "copacabana", "anchor": "spot:trafico_contact", "short": "Calçadão"},
	"trafico_a2_pickup/pickup_palace": {"text": "🎯 → Copa Palace : récupérer la sacoche chez le groom", "dist": "copacabana", "anchor": "node:PalaceSacoche", "short": "Copa Palace"},
	"trafico_a2_pickup/despistar_pm": {"text": "🎯 Copa : sème la PM dans les transversales !", "dist": "copacabana", "anchor": "", "short": "Copa"},
	"trafico_a3_chauffeur/drive_botafogo": {"text": "🎯 → Botafogo (Bondinho) : livrer le coffre AVANT la relève de la PM !", "dist": "botafogo_flamengo", "anchor": "", "short": "Botafogo ⏱"},
	"trafico_a4_ipanema/deal_ipanema": {"text": "🎯 → Zona Sul (Ipanema, posto 9) : refourguer la marchandise", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"trafico_a4_ipanema/fugir_praia": {"text": "🎯 Ipanema : sème la PM en civil — quitte la plage !", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"trafico_a5_intim/silence_voisin": {"text": "🎯 → Favela : faire taire le voisin qui t'a vu", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"trafico_a5_intim/fugir_morro": {"text": "🎯 Favela : sème la patrouille alertée par les cris !", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"trafico_a6_cagarras/receive_cargo": {"text": "🎯 → Zona Sul (plage) : prendre une prancha de SUP et rallier les Cagarras", "dist": "zona_sul", "anchor": "", "short": "Cagarras"},
	"trafico_a7_tioze/ask_temoin": {"text": "🎯 → Favela : fais parler Dona Zilda, la doyenne du morro", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"trafico_a7_tioze/porter_lembranca": {"text": "🎯 → Copa (colônia, Posto 6) : le souvenir de Zé chez Seu Firmino", "dist": "copacabana", "anchor": "", "short": "Colônia Z-13"},
	"trafico_a7_tioze/semer_sombra": {"text": "🎯 Copa : sème l'ombre qui te suit — ne la mène pas au Palace !", "dist": "copacabana", "anchor": "", "short": "Copa"},
	"trafico_a7_tioze/heed_warning": {"text": "🎯 → Copa Palace : montrer la photo au vieux concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"trafico_a8_baia/feu_vert_mafia": {"text": "🎯 → Niterói (Estação das Barcas) : le feu vert de la Mafia da Baía", "dist": "niteroi", "anchor": "", "short": "Barcas"},
	"trafico_a8_baia/reperer_crique": {"text": "🎯 → Niterói (Icaraí, pedra de Itapuca) : repérer la crique de débarque", "dist": "niteroi", "anchor": "", "short": "Icaraí"},
	"trafico_a8_baia/cross_baia": {"text": "🎯 → Niterói : traverser la baie avec la grosse livraison", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"trafico_a8_baia/semer_flagrante": {"text": "🎯 Niterói : échappe au flagrante — sème la PM des quais !", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"trafico_a9_corrida/execute_run": {"text": "🎯 → Favela : retrouver Tito pour la corrida finale", "dist": "favela_morro", "anchor": "npc:tito", "short": "Tito (Favela)"},
	# --- VOIE POLÍCIA (B1 → B9) ---
	"policia_b1_intel/report_face": {"text": "🎯 → Copa (calçadão) : rapporter le visage à l'agent en civil", "dist": "copacabana", "anchor": "spot:policia_contact", "short": "Calçadão"},
	"policia_b2_filature/map_network": {"text": "🎯 → Favela : filer l'olheiro de Tito (planque, haut du morro)", "dist": "favela_morro", "anchor": "", "short": "Morro"},
	"policia_b3_escorte/escort_patrol": {"text": "🎯 → Botafogo : mener la patrouille au garage aux volets verts (elle te suit)", "dist": "botafogo_flamengo", "anchor": "", "short": "Botafogo"},
	"contessa_fundo/filer_ferretti": {"text": "🎯 → Copa Palace : filer Ferretti, l'administrateur de la Contessa", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"contessa_fundo/ecouter_colombo": {"text": "🎯 → Forte : Ferretti est entré au Café Colombo — écoute son rendez-vous", "dist": "forte", "anchor": "", "short": "Café Colombo (Forte)"},
	"contessa_fundo/decidir_fundo": {"text": "🎯 → Copa Palace : tout rapporter à la Contessa", "dist": "copacabana", "anchor": "npc:contessa", "short": "La Contessa"},
	"vela_pedrinho/terminar_regata": {"text": "🎯 → Marina da Glória : finir la Regata au ponton de l'escolinha", "dist": "marina_gloria", "anchor": "", "short": "Marina da Glória"},
	"vela_pedrinho/inscrever_pedrinho": {"text": "🎯 → Marina da Glória : inscrire Pedrinho chez Lia", "dist": "marina_gloria", "anchor": "npc:lia_vela", "short": "Lia (Marina)"},
	"policia_b4_descente/filer_dealer": {"text": "🎯 → Zona Sul (Arpoador) : filer le dealer jusqu'à sa planque (planque)", "dist": "zona_sul", "anchor": "", "short": "Arpoador"},
	"policia_b4_descente/bust_dealer": {"text": "🎯 → Zona Sul (Arpoador) : coffrer le dealer à sa planque", "dist": "zona_sul", "anchor": "", "short": "Arpoador"},
	"policia_b5_reperage/scout_corcovado": {"text": "🎯 → Corcovado : filer le contremaître au mirante", "dist": "corcovado", "anchor": "", "short": "Corcovado"},
	"policia_b6_tioze/ask_temoin": {"text": "🎯 → Copa (Bar do Policial) : fais parler le vieux garçom", "dist": "copacabana", "anchor": "spot:policia_garcom", "short": "Bar do Policial"},
	"policia_b6_tioze/porter_lembranca": {"text": "🎯 → Copa (calçadão) : le souvenir de Zé chez Seu Osmar, PM réformé", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"policia_b6_tioze/reperer_sombra": {"text": "🎯 → Copa Palace : repère le guetteur qui surveille le concierge (planque)", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"policia_b6_tioze/hear_concierge": {"text": "🎯 → Copa Palace : poser la chope devant le concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"policia_b7_saisie/seize_cargo": {"text": "🎯 → Niterói : saisir la cargaison", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"policia_b8_seguranca/briefing_pm": {"text": "🎯 → Maracanã (poste PM, esplanade) : prendre le briefing du sergent", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"policia_b8_seguranca/reperer_batedores": {"text": "🎯 → Maracanã : repérer l'éclaireur des batedores dans la foule (planque)", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"policia_b8_seguranca/secure_crowd": {"text": "🎯 → Maracanã : sécuriser la foule", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"policia_b9_madrugada/complete_madrugada": {"text": "🎯 → Morro (favela) : rejoindre les colonnes de la PM pour la Madrugada", "dist": "favela_morro", "anchor": "", "short": "Morro"},
	"act2_pecheur_secret/observe_canots": {"text": "🎯 → Botafogo (mureta da Urca) : observer les canots à la nuit", "dist": "botafogo_flamengo", "anchor": "", "short": "Mureta"},
	"act2_contessa_gala/secured_trio": {"text": "🎯 → Zona Sul (Garota de Ipanema) : engager le trio bossa", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	# --- VOIE CONSORTIUM (C1 → C9) ---
	"consortium_c1_recouvrement/collect_calcadao": {"text": "🎯 → Copa (calçadão) : recouvrer auprès des vendeurs", "dist": "copacabana", "anchor": "spot:consortium_contact", "short": "Calçadão"},
	"consortium_c2_loyers/collect_condos": {"text": "🎯 → Barra (Riserva Uno) : faire la tournée des loyers", "dist": "barra_tijuca", "anchor": "spot:consortium_barra", "short": "Riserva Uno"},
	"consortium_c3_partenariat/force_signature": {"text": "🎯 → Zona Sul (Ipanema) : faire signer le restaurateur — lis-le avant de choisir", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"consortium_c4_vip/drive_vip": {"text": "🎯 → Santos Dumont : réceptionner le VIP — il n'attend pas !", "dist": "santos_dumont", "anchor": "", "short": "Santos Dumont ⏱"},
	"consortium_c5_mac/launder_mac": {"text": "🎯 → Niterói (MAC) : négocier la donation — lis l'attachée avant de choisir", "dist": "niteroi", "anchor": "", "short": "MAC Niterói"},
	"consortium_c6_tioze/ask_temoin": {"text": "🎯 → Copa Palace : fais parler Dona Neusa, la gouvernante", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"consortium_c6_tioze/porter_lembranca": {"text": "🎯 → Copa Palace : la fiche de Zé chez Seu Ataíde — ni argent ni ordre, trouve le vrai levier", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"consortium_c6_tioze/hear_concierge": {"text": "🎯 → Copa Palace : montrer la fiche au concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"consortium_c7_condos/align_condos": {"text": "🎯 → Barra (Riserva Uno) : aligner les trois copros — lis le président récalcitrant", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	"consortium_c8_menace/break_holdout": {"text": "🎯 → Copa (calçadão) : faire signer la dernière commerçante — lis-la avant de parler", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"consortium_c9_pacto/seal_pacto": {"text": "🎯 → Barra : sceller le pacte avec Magalhães", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	# --- VOIE PREFEITO (D1 → D9) ---
	"prefeito_d1_peticao/gather_signatures": {"text": "🎯 → Copa : faire signer la pétition au calçadão", "dist": "copacabana", "anchor": "spot:prefeito_contact", "short": "Calçadão"},
	"prefeito_d2_basquete/run_tournament": {"text": "🎯 → Aterro (Botafogo) : organiser le tournoi de basket", "dist": "aterro_flamengo", "anchor": "", "short": "Aterro"},
	"prefeito_d3_mediation/ouvir_familia": {"text": "🎯 → Favela : écouter Dona Cléo, la mère de famille", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"prefeito_d3_mediation/ouvir_capanga": {"text": "🎯 → Favela : trouver le bon levier avec Neném — écoute avant de menacer", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"prefeito_d3_mediation/defuse_conflict": {"text": "🎯 → Favela : mener la médiation entre Cléo et Neném", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"prefeito_d4_procession/escort_procession": {"text": "🎯 → Zona Sul (Ipanema) : mener la procession jusqu'à la capelinha", "dist": "zona_sul", "anchor": "", "short": "Ipanema"},
	"prefeito_d5_rally/convencer_marta": {"text": "🎯 → Maracanã : convaincre Dona Marta (acarajé)", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"prefeito_d5_rally/convencer_valter": {"text": "🎯 → Maracanã : convaincre Seu Válter (pipoca)", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"prefeito_d5_rally/convencer_rogerio": {"text": "🎯 → Maracanã : convaincre Rogério (torcida)", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"prefeito_d6_mac/inaugurate_expo": {"text": "🎯 → Niterói (MAC) : inaugurer l'expo — pèse chaque mot de ton discours", "dist": "niteroi", "anchor": "", "short": "MAC Niterói"},
	"prefeito_d7_tioze/ask_temoin": {"text": "🎯 → Copa (parvis de l'église) : fais parler Dona Ivone, la beata", "dist": "copacabana", "anchor": "", "short": "L'église"},
	"prefeito_d7_tioze/porter_lembranca": {"text": "🎯 → Copa (église) : la médaille de Zé chez Seu Expedito — viens pour écouter, pas pour demander", "dist": "copacabana", "anchor": "", "short": "L'église"},
	"prefeito_d7_tioze/receive_dossier": {"text": "🎯 → Copa Palace : ouvrir la main devant le concierge", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	# --- REINADO (acte 5) — 2 quêtes de règne par voie, climax au Sambódromo ---
	"reinado_a_pedagio/collect_pedagio": {"text": "🎯 → Copa (calçadão) : la tournée du pedágio chez les camelôs", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_a_pedagio/fugir_blitz": {"text": "🎯 Copa : sème la blitz de la PM non alignée !", "dist": "copacabana", "anchor": "", "short": "Copa"},
	"reinado_a_carga/entregar_carga": {"text": "🎯 → Sambódromo : livrer la carga AVANT l'ouverture des portões !", "dist": "sambodromo", "anchor": "", "short": "Sapucaí ⏱"},
	"reinado_b_ronda/vigiar_bloco": {"text": "🎯 → Copa (calçadão) : repérer le batedor dans le bloco (planque)", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_b_ronda/prender_batedor": {"text": "🎯 → Copa (calçadão) : le faire cueillir proprement", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_b_camarote/varrer_sapucai": {"text": "🎯 → Sambódromo : balayer la foule — le second batedor (planque, seul)", "dist": "sambodromo", "anchor": "", "short": "Sapucaí"},
	"reinado_b_camarote/report_camarote": {"text": "🎯 → Sambódromo : rendre compte au poste de commandement", "dist": "sambodromo", "anchor": "", "short": "Sapucaí"},
	"reinado_c_vitrine/dobrar_barraqueiro": {"text": "🎯 → Copa (plage) : le dernier barraqueiro libre — lis-le avant de choisir", "dist": "copacabana", "anchor": "", "short": "La plage"},
	"reinado_c_camarote/convencer_presidente": {"text": "🎯 → Sambódromo : la présidente de l'école — trouve ce qui s'échange", "dist": "sambodromo", "anchor": "", "short": "Sapucaí"},
	"reinado_d_bloco/convencer_costureira": {"text": "🎯 → Copa (calçadão) : convaincre Dona Filó, la costureira", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_d_bloco/convencer_puxador": {"text": "🎯 → Copa (calçadão) : le bon levier avec Careca — écoute Dona Filó", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_d_bloco/sair_bloco": {"text": "🎯 → Copa (calçadão) : faire défiler le Bloco do Bairro", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"reinado_d_alas/alinhar_alas": {"text": "🎯 → Sambódromo : régler l'ordre des alas avec le mestre", "dist": "sambodromo", "anchor": "", "short": "Sapucaí"},
	"prefeito_d8_campagne/buscar_padre": {"text": "🎯 → Copa (parvis de l'église) : convaincre le Padre de descendre en campagne", "dist": "copacabana", "anchor": "", "short": "L'église"},
	"prefeito_d8_campagne/cortejo_calcadao": {"text": "🎯 → Copa (calçadão) : traverser en cortège avec le Padre jusqu'à la tribune", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"prefeito_d8_campagne/flip_calcadao": {"text": "🎯 → Copa (calçadão) : retourner les commerçants", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"prefeito_d9_eleicao/win_election": {"text": "🎯 → Copa (église) : remporter l'élection aux côtés du Padre", "dist": "copacabana", "anchor": "npc:padre", "short": "L'église"},
	# --- SIDE inter-districts ---
	"feijoada_bondinho/deliver_summit": {"text": "🎯 → Pão de Açúcar : livrer la feijoada (bondinho de Botafogo)", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ipanema_yoga/fetch_mat": {"text": "🎯 → Zona Sul (Ipanema/Leblon) : récup' du tapis chez le resto", "dist": "zona_sul", "anchor": "", "short": "Zona Sul"},
	"cristo_photo/shoot_cristo": {"text": "🎯 → Corcovado : déclencher la photo au mirante", "dist": "corcovado", "anchor": "", "short": "Corcovado"},
	"niteroi_envelope/deliver_envelope": {"text": "🎯 → Niterói : remettre l'enveloppe face au MAC", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"maracana_jersey/find_jersey": {"text": "🎯 → Botafogo (Aterro) : maillot 71 chez le revendeur", "dist": "aterro_flamengo", "anchor": "", "short": "Aterro"},
	"maracana_jersey/return_jersey": {"text": "🎯 → Maracanã : rendre le maillot à Seu Wanderley", "dist": "maracana", "anchor": "", "short": "Maracanã"},
	"sambo_plumes/fetch_plumes": {"text": "🎯 → Niterói : récupérer les plumes chez Tomé (face MAC)", "dist": "niteroi", "anchor": "", "short": "Niterói"},
	"sambo_plumes/deliver_plumes": {"text": "🎯 → Sambódromo : ramener les plumes à Dona Lurdes", "dist": "sambodromo", "anchor": "", "short": "Sambódromo"},
	"barra_brief/deliver_brief": {"text": "🎯 → Zona Sul (Leblon) : faire signer Bertoluci", "dist": "zona_sul", "anchor": "", "short": "Leblon"},
	"barra_brief/confirm_back": {"text": "🎯 → Barra (Riserva Uno) : retour chez l'avocate", "dist": "barra_tijuca", "anchor": "", "short": "Barra"},
	"beto_lost/find_beto": {"text": "🎯 → Copacabana (calçadão) : coincer Beto chez les Ray-Ban", "dist": "copacabana", "anchor": "calcadao", "short": "Calçadão"},
	"beto_lost/tell_vizinha": {"text": "🎯 → Favela : rapporter à Seu Jorge", "dist": "favela_morro", "anchor": "", "short": "Favela"},
	"sofia_bondinho_tour/guide_to_summit": {"text": "🎯 → Pão de Açúcar : guide Sofia au sommet (bondinho)", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ronaldo_dj_paoacucar/play_set": {"text": "🎯 → Pão de Açúcar : jouer le set DJ", "dist": "pao_acucar", "anchor": "", "short": "Pão de Açúcar"},
	"ze_invitation/tell_ronaldo": {"text": "🎯 → Copa (calçadão, à deux pas du quiosque do Zé) : prévenir Ronaldo", "dist": "copacabana", "anchor": "npc:musicien", "short": "Ronaldo"},
	"consortium_airport_pickup/meet_at_airport": {"text": "🎯 → Santos Dumont : récupérer Don Salvatore", "dist": "santos_dumont", "anchor": "", "short": "Santos Dumont"},
	"consortium_airport_pickup/deliver_to_consortium": {"text": "🎯 → Copacabana : ramener à Dom Nilton", "dist": "copacabana", "anchor": "consortium", "short": "Consortium"},
	"escort_contessa/escort_to_bar": {"text": "🎯 → Copacabana : escorter la Contessa jusqu'au bar", "dist": "copacabana", "anchor": "atlantica", "short": "Bar"},
	"escort_contessa/escort_back_to_palace": {"text": "🎯 → Copacabana Palace : raccompagner la Contessa", "dist": "copacabana", "anchor": "palace", "short": "Copa Palace"},
	"bruno_carga/deliver_to_helena": {"text": "🎯 → Niterói : livrer la carga à Helena (MAC)", "dist": "niteroi", "anchor": "", "short": "Niterói"},
}

# Sélection courante (recalculée aux événements). Voir _S().
var _sel: Dictionary = {}

func _ready() -> void:
	# Mêmes signaux que l'ancien ObjectiveBanner : tout ce qui peut changer
	# l'objectif courant déclenche un recalcul de la sélection.
	EventBus.quest_accepted.connect(_on_event)
	EventBus.quest_updated.connect(_on_quest_updated)
	EventBus.quest_completed.connect(_on_event)
	EventBus.debt_paid.connect(_on_debt_paid)
	EventBus.act_changed.connect(_on_act_changed)
	EventBus.corn_cart_state_changed.connect(_on_cart_state)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.time_of_day_changed.connect(_on_phase_changed)
	EventBus.day_elapsed.connect(_on_day_elapsed)
	# La feijoada du samedi pose un flag sans émettre d'événement de quête.
	EventBus.dialogue_ended.connect(_on_event)
	DistrictManager.district_changed.connect(_on_district_changed)
	_recompute()

# --- API publique (lue par ObjectiveBanner + Compass) ---

# Texte du QUOI (peut être vide). Lu par le bandeau d'objectif.
func current_text() -> String:
	return _sel.get("text", "")

# Cible résolue pour la frame courante. Lu par la boussole.
# { text, kind, world_pos, label, color }
func get_live() -> Dictionary:
	var out: Dictionary = {
		"text": _sel.get("text", ""),
		"kind": Kind.NONE,
		"world_pos": Vector2.ZERO,
		"label": _sel.get("short", ""),
		"color": Color(0.96, 0.82, 0.36, 1.0),
	}
	if _sel.is_empty() or out.text == "":
		return out
	out.color = voie_color()
	var dist: String = _sel.get("dist", "")
	var cur: String = DistrictManager.current()
	# Cible dans un autre district → mode voyage (la boussole pointe le taxi).
	if dist != "" and dist != cur:
		out.kind = Kind.TRAVEL
		if out.label == "":
			out.label = _short_district(dist)
		return out
	# Même district (ou inconnu) → tente une position précise.
	var pos: Vector2 = _resolve_point(_sel.get("anchor", ""), cur)
	if pos != NO_POS:
		out.kind = Kind.POINT
		out.world_pos = pos
	return out

# --- Calcul de la sélection ---

func _S(text: String, dist: String = "", anchor: String = "", short: String = "") -> Dictionary:
	return {"text": text, "dist": dist, "anchor": anchor, "short": short}

func _recompute() -> void:
	_sel = _route_via_bondinho(_compute_selection())
	nav_target_changed.emit()

# Le Pão de Açúcar n'a pas de taxi : on dit comment y aller (Botafogo, puis la
# borne du bondinho) au lieu de laisser la boussole sur un taxi qui refuse
# (playtest 2026-10-08, F10 : 17 à 28 min de bandeau sans issue).
func _route_via_bondinho(sel: Dictionary) -> Dictionary:
	if sel.is_empty() or String(sel.get("dist", "")) != "pao_acucar":
		return sel
	var cur: String = DistrictManager.current()
	if cur == "pao_acucar":
		return sel
	var out: Dictionary = sel.duplicate()
	if cur == "botafogo_flamengo":
		out["text"] = String(sel.text) + " — prends le bondinho (borne au sud-est de Botafogo)"
		out["dist"] = "botafogo_flamengo"
		out["anchor"] = "class:BondinhoLauncher"
		out["short"] = "Bondinho"
	else:
		out["text"] = String(sel.text) + " — pas de taxi là-haut : Botafogo d'abord, puis le bondinho"
		out["dist"] = "botafogo_flamengo"
		out["short"] = "Botafogo (bondinho)"
	return out

# Porté depuis ObjectiveBanner._compute_hint : l'ordre des conditions == priorité.
# Différence clé : quand le macro-hint d'acte est générique (acte 3/4, fallback),
# on préfère l'étape précise de la quête active (STEP) — c'est ce qui corrigeait
# le « avance dans ta voie » trop vague.
func _compute_selection() -> Dictionary:
	var act: int = CampaignManager.current_act
	var district: String = DistrictManager.current()
	var debt_paid: int = CampaignManager.debt_paid
	var money: int = _player_money()
	var carrying: bool = _cart_carrying()
	var is_evening: bool = TimeOfDay.current_phase == TimeOfDay.Phase.EVENING

	# --- Prologue : la recherche de Pedrinho prime sur tout, quel que soit
	#     l'ordre des flags (le bump de Seu João pose act1_started AVANT que la
	#     mère n'aborde le joueur — la branche ci-dessous ne suffisait pas). ---
	if QuestManager.is_active("prologue_pedrinho"):
		var pro0: Dictionary = _active_step()
		if not pro0.is_empty():
			return pro0

	# --- Prologue + Acte 1 : démarrage ---
	if not CampaignManager.has_flag("act1_started"):
		# La recherche de Pedrinho EST la première quête principale : tant qu'elle
		# est active, on guide ses étapes plutôt que de pousser vers Seu João.
		if QuestManager.is_active("prologue_pedrinho"):
			var pro: Dictionary = _active_step()
			if not pro.is_empty():
				return pro
		if not CampaignManager.has_flag("intro_bump_seen"):
			return _S("🎯 Sors de la maison — Seu João arrive avec des nouvelles")
		return _S("🎯 Parle à Seu João, le compadre de Zé (maison)", "", "npc:seu_joao", "Seu João")

	# --- Soir : la famille attend pour le jantar — une fois par jour (le flag
	#     `jantar_day` = jour du dernier dîner, posé par la variante de mãe) ;
	#     dans la favela on pointe la porte de la maison, pas l'escalier. ---
	var jantar_done: bool = int(CampaignManager.flags.get("jantar_day", 0)) == TimeOfDay.day_count
	if is_evening and act <= 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE \
			and not jantar_done:
		if district != "favela_morro":
			return _S("🌙 Rentre dîner — mãe a mis le couvert (maison du morro)", "favela_morro", "", "Maison")
		if BuildingManager.is_inside:
			return _S("🌙 À table — mãe a servi, va la voir", "", "spot:mae", "Mãe")
		return _S("🌙 Rentre dîner — mãe a mis le couvert, entre dans la maison", "", "node:TioZeDoor", "Maison")

	# --- Acte 1 — clôture : acompte payé (act1_heritage finie) mais retour maison
	#     + nuit dans la maison de Zé pas encore faits → rentrer parler à Seu João. C'est CE
	#     retour qui ferme l'acte 1 et ouvre l'acte 2. ---
	if act == 1 and QuestManager.is_completed("act1_heritage") \
			and not CampaignManager.has_flag("act1_closed"):
		if district == "favela_morro":
			return _S("🎯 Rentre dans la maison parler à Seu João (la nuit va tomber)", "", "npc:seu_joao", "Maison · Seu João")
		return _S("🎯 Acompte payé — rentre à la maison du morro parler à Seu João", "favela_morro", "", "Maison · Seu João")

	# --- Dans la favela ---
	if district == "favela_morro":
		# « Prends la carrocinha » est une instruction d'acte 1 (démarrage du milho).
		# En acte 2+, ne pas la ressortir : la logique d'acte (famille / nuit /
		# patrons) doit prendre la main.
		if act == 1 and not carrying and not CampaignManager.has_flag("first_sale_done"):
			return _S("🎯 Prends la carrocinha de Zé, à côté de la maison", "", "cart", "Carrocinha")
		if CampaignManager.has_flag("should_visit_home") and not CampaignManager.has_flag("home_visit_done"):
			return _S("🎯 Monte voir Seu João et la famille (maison)", "", "npc:seu_joao", "Seu João")
		# En acte 1, le défaut favela = redescendre vendre. En acte 2+, on laisse
		# la logique d'acte décider (Tito est ici : _patron_target le ciblera).
		if act == 1:
			return _S("🎯 ↓ Descends l'escalier vers Copacabana", "copacabana", "", "↓ Copa")

	# --- Acte 1 sur Copacabana ---
	if act == 1 and district == "copacabana":
		if not CampaignManager.has_flag("met_consortium"):
			return _S("🎯 Va voir Dom Nilton (consortium) sur l'Av. Atlântica", "", "consortium", "Consortium")
		if debt_paid < CampaignManager.ACT1_THRESHOLD:
			var still_to_pay: int = CampaignManager.ACT1_THRESHOLD - debt_paid
			if money >= still_to_pay:
				return _S("🎯 Va déposer %d R$ d'acompte au consortium" % still_to_pay, "", "consortium", "Consortium")
			if not carrying and not CampaignManager.has_flag("first_sale_done"):
				return _S("🎯 Prends la carrocinha (favela) puis vends au calçadão", "favela_morro", "cart", "Favela")
			if carrying:
				return _S("🎯 Sers les clients du calçadão (R$ %d / %d)" % [money, still_to_pay], "", "calcadao", "Calçadão")
			return _S("🎯 Continue de gagner R$ — il manque %d pour l'acompte" % (still_to_pay - money), "", "calcadao", "Calçadão")
		return _S("🎯 Acompte payé — rentre à la maison du morro parler à Seu João", "favela_morro", "", "Maison · Seu João")

	# --- Acte 2 : échantillon des 4 patrons (1re mission de chaque voie) ---
	# La clôture de l'acte 1 (retour maison + nuit dans la maison de Zé) est désormais un
	# prérequis de l'acte 2 — plus besoin de la gérer ici.
	if act == 2:
		if not CampaignManager.has_flag("tito_approached") \
				and not CampaignManager.has_flag("ratted_on_tito") \
				and _no_voie_chosen():
			if district == "favela_morro":
				return _S("🎯 Sors de la maison — Tito veut te parler")
		if debt_paid < CampaignManager.ACT2_THRESHOLD:
			# Si une mission intro de patron est en cours → guider vers SON étape.
			var st2: Dictionary = _active_step(true)
			if not st2.is_empty():
				return st2
			# Voie déjà scellée → continuer CETTE voie (ne pas renvoyer vers un
			# autre patron qui rejetterait le joueur).
			if not _no_voie_chosen():
				var vc2: Dictionary = _voie_continue()
				if not vc2.is_empty():
					return vc2
			# Sinon → diriger vers un patron concret à goûter (le plus proche).
			var pt2: Dictionary = _patron_target(false)
			if not pt2.is_empty():
				return pt2
			# Tous goûtés → reste à réunir l'argent (milho, missions) ; si on l'a
			# déjà en poche, on le dit (playtest 2026-10-07 : 13 000 R$ en poche et
			# un bandeau qui disait encore « Réunis »).
			var side2: Dictionary = _active_step(false, true)
			var still: int = CampaignManager.ACT2_THRESHOLD - debt_paid
			if money < still and not side2.is_empty():
				return side2
			if money >= still:
				return _S("🎯 Tu as de quoi : va verser %s R$ à Dom Nilton (Av. Atlântica) pour ouvrir l'acte 3" % still, "copacabana", "consortium", "Consortium")
			return _S("🎯 Réunis %s R$ (milho au calçadão, missions) pour ouvrir l'acte 3" % still, "", "calcadao", "Calçadão")

	# --- Acte 3 : nudge tant qu'aucune voie n'est scellée ---
	if act == 3 and CampaignManager.chosen_endgame == CampaignManager.Endgame.NONE:
		if _no_voie_chosen():
			var ptp: Dictionary = _patron_target(true)
			if not ptp.is_empty():
				return ptp
			return _S("🎯 Le vrai choix : scelle un pacte — Tito (morro), Ramos (Academia), Magalhães (Barra) ou le Padre (église)")
		var st3: Dictionary = _active_step(true)
		if not st3.is_empty():
			return st3
		# Pas de mission active mais voie scellée → renvoyer vers le patron de la voie.
		var vc3: Dictionary = _voie_continue()
		if not vc3.is_empty():
			return vc3
		var side3: Dictionary = _active_step(false, true)
		if not side3.is_empty():
			return side3
		if debt_paid < CampaignManager.ACT3_THRESHOLD:
			var still3: int = CampaignManager.ACT3_THRESHOLD - debt_paid
			if money >= still3:
				return _S("🎯 Tu as de quoi : va verser %s R$ à Dom Nilton (Av. Atlântica) — les Grands Lances t'attendent" % still3, "copacabana", "consortium", "Consortium")
			return _S("🎯 Avance dans ta voie — chaque mission crédite ta dette ; encore %s R$ avant les Grands Lances (acte 4)" % still3)

	# --- Acte 4 : Os Grandes Lances ---
	if act == 4:
		# Finale Polícia : la Madrugada se lance chez Ramos (flag madrugada_lancee)
		# AVANT de monter au morro — sinon la PM en faction dit « pas encore »
		# (playtest 2026-10-08 : 22 min au point de ralliement sans signal).
		if QuestManager.is_active("policia_b9_madrugada") and not CampaignManager.has_flag("madrugada_lancee"):
			return _S("🎯 → Copa (Academia) : Ramos donne le signal de la Madrugada", "copacabana", "npc:ramos", "Ramos · Academia")
		var st4: Dictionary = _active_step(true)
		if not st4.is_empty():
			return st4
		# Entre deux missions, on pointe le donneur de la suivante (comme en
		# acte 3) : « retrouve ton parrain » sans flèche laissait le joueur en
		# plan après C7 (playtest 2026-11-18).
		var vc4: Dictionary = _voie_continue()
		if not vc4.is_empty():
			return vc4
		var side4: Dictionary = _active_step(false, true)
		if not side4.is_empty():
			return side4
		return _S("🎯 Os Grandes Lances — retrouve ton parrain : le gros coup, puis le couronnement")

	# --- Acte 5 : reinado — les quêtes de règne d'abord, le desfile en climax ---
	if act == 5:
		# La trame d'abord : une activité libre qui traîne depuis l'acte 1 ne
		# doit pas masquer l'offre du règne (playtest 2026-11-19 : « prévenir
		# Ronaldo » affiché 58 min après le couronnement, R1 jamais proposé).
		var st5: Dictionary = _active_step(true)
		if not st5.is_empty():
			return st5
		if not CampaignManager.has_flag("pos_carnaval"):
			for rid in REINADO_SPOTS:
				if QuestManager.is_available(rid):
					return _S("🎯 Ton règne t'attend — les tiens te cherchent sur le sable de Copa", "copacabana", "spot:" + String(REINADO_SPOTS[rid]), "Copacabana")
			# Le défilé ne compte qu'une fois la quête prise chez Seu João : le
			# bandeau envoyait droit à la Sapucaí, où l'on menait le bloc pour
			# rien (playtest 2026-11-19 : trois défilés joués, aucun validé).
			if QuestManager.is_active(CarnavalCalendar.DESFILE_QUEST):
				return _S("🎯 → Sambódromo : mène le défilé — c'est ton couronnement", "sambodromo", "node:SambaStage", "Sapucaí")
			if QuestManager.is_available(CarnavalCalendar.DESFILE_QUEST):
				return _S("🎯 Rentre au morro : Seu João a un mot pour toi avant le défilé", "favela_morro", "npc:seu_joao", "Seu João (maison)")
		var side5: Dictionary = _active_step(false, true)
		if not side5.is_empty():
			return side5
		# Depois do Carnaval : plus de cap narratif, juste le rythme du bairro.
		if CampaignManager.has_flag("pos_carnaval"):
			if CarnavalCalendar.is_cinzas():
				return _S("🎯 Quarta de Cinzas — rentre au morro, la famille t'attend", "favela_morro", "", "La maison")
			if CarnavalCalendar.is_sabado() and int(CampaignManager.flags.get("feijoada_day", 0)) != TimeOfDay.day_count:
				return _S("🎯 Sábado — feijoada à la maison, avec les tiens", "favela_morro", "", "Feijoada (maison)")
			return _S("✦ Copa est à toi — rodas, altinha, et la feijoada du samedi")
		return _S("🎯 Mène ton règne — défilé du Carnaval au Sambódromo", "sambodromo", "", "Sambódromo")

	# Fallback : prochaine étape d'une quête active connue.
	var side: Dictionary = _active_step()
	if not side.is_empty():
		return side
	return {}

# Première étape non close d'une quête active (MAIN prioritaire) présente dans STEP.
# `main_only` : n'accepte que la trame. À partir de l'acte 2, une activité
# libre en cours ne doit pas confisquer le bandeau à la trame (playtest
# 2026-11-18 : « prévenir Ronaldo » affiché 287 min pendant que l'acte 2
# attendait ses patrons) ; elle ne reprend la main que s'il ne reste que de
# l'argent à réunir.
func _active_step(main_only: bool = false, side_only: bool = false) -> Dictionary:
	var ids: Array[String] = QuestManager.get_active_ids()
	var mains: Array[String] = []
	var sides: Array[String] = []
	for id in ids:
		var q: Quest = QuestManager.get_quest(id)
		if q != null and q.quest_type == Quest.QuestType.MAIN:
			mains.append(id)
		else:
			sides.append(id)
	var ordered: Array[String] = mains + sides
	if main_only:
		ordered = mains
	elif side_only:
		ordered = sides
	for qid in ordered:
		var state: Dictionary = QuestManager.get_objectives_state(qid)
		for obj_id in state:
			if state[obj_id]:
				continue  # objectif déjà clos
			var key: String = "%s/%s" % [qid, obj_id]
			if STEP.has(key):
				return _with_auto_anchor(STEP[key], qid, obj_id)
	return {}

# Une étape sans ancre pointe le spot qui PORTE
# son objectif : le ReactiveDialogueSpot dont une variante agissante attend
# cet objectif. Sans ça, 67 étapes n'affichaient qu'un nom de quartier, sans
# flèche — dont des missions chronométrées (playtest 2026-11-18, A3 ratée 66
# fois faute de savoir où est « le garage sous le Bondinho »).
# Les ancres fixes de Copa (calcadao, atlantica, palace) cèdent aussi au spot
# quand il y en a un seul : « palace » pointait la PORTE alors que les témoins
# des pivots tio Zé sont postés sur le trottoir — on entrait dans le hall pour
# rien (C6 : 13 min perdues, D7 idem, playtest du 2026-11-19). Elles restent
# le repli quand aucun spot n'attend l'objectif (PNJ mobile, lieu voulu).
const _GENERIC_ANCHORS: Array = ["", "palace", "calcadao", "atlantica"]
var _spot_list: Array = []   # ReactiveDialogueSpot du monde (les districts sont instanciés une fois)

func _with_auto_anchor(step: Dictionary, qid: String, obj_id: String) -> Dictionary:
	if not _GENERIC_ANCHORS.has(String(step.get("anchor", ""))):
		return step
	var anchor: String = _spot_anchor_for(qid, obj_id)
	if anchor == "":
		return step
	var out: Dictionary = step.duplicate()
	out["anchor"] = anchor
	return out

# Le spot dont la variante ACTUELLEMENT servie attend cet objectif (l'état des
# flags compte : la procession D4 part d'un spot et se clôt à un autre). On
# préfère une variante qui agit ; à défaut, l'unique spot qui en parle.
func _spot_anchor_for(qid: String, obj_id: String) -> String:
	var root: Node = get_tree().current_scene
	if root == null:
		return ""
	if _spot_list.is_empty() or not is_instance_valid(_spot_list[0]):
		_spot_list.clear()
		for n in root.find_children("*", "Node2D", true, false):
			if n is ReactiveDialogueSpot:
				_spot_list.append(n)
	var acting: Array = []
	var talking: Array = []
	for n in _spot_list:
		if not is_instance_valid(n):
			continue
		var v: Dictionary = n._pick_variant()
		var pending: Variant = v.get("objective_pending")
		if not (pending is Array) or pending.size() < 2 \
				or String(pending[0]) != qid or String(pending[1]) != obj_id:
			continue
		var npc_id: String = String(n.get("npc_id"))
		if v.has("actions") or v.has("choice_actions") or v.has("set_flag_after"):
			if not acting.has(npc_id):
				acting.append(npc_id)
		elif not talking.has(npc_id):
			talking.append(npc_id)
	if acting.size() == 1:
		return "spot:" + String(acting[0])
	if acting.is_empty() and talking.size() == 1:
		return "spot:" + String(talking[0])
	return ""

# --- Résolution spatiale ---

func _resolve_point(anchor: String, cur: String) -> Vector2:
	if anchor == "":
		return NO_POS
	if anchor == "cart":
		return _node_pos_guard(get_tree().get_first_node_in_group("corn_cart"))
	if anchor.begins_with("npc:"):
		return _node_pos_guard(_entrance_or_self(NPCScheduler.get_npc(anchor.substr(4))))
	# `spot:<npc_id>` = ReactiveDialogueSpot ; `node:<name>` = nœud du monde par nom.
	if anchor.begins_with("spot:") or anchor.begins_with("node:") or anchor.begins_with("class:"):
		return _node_pos_guard(_entrance_or_self(_find_world_node(anchor)))
	# Ancrages fixes valides uniquement quand on est physiquement à Copacabana.
	if cur == "copacabana":
		match anchor:
			"calcadao": return ANCHOR_CALCADAO
			"atlantica": return ANCHOR_ATLANTICA
			"palace": return ANCHOR_PALACE
			"taxi": return ANCHOR_TAXI
			"consortium": return ANCHOR_CONSORTIUM
			"church": return ANCHOR_CHURCH
	return NO_POS

# Recommande UN patron concret à rejoindre (corrige l'acte 2 « goûte aux 4
# patrons » sans cible). `pacto` = true en acte 3 (sceller la voie : tous les
# patrons restent candidats) ; false en acte 2 (échantillon : on saute ceux dont
# la mission intro est déjà prise ou finie). Préfère un patron du district courant
# pour un pas immédiat, sinon le premier de l'ordre (Copa d'abord).
func _patron_target(pacto: bool) -> Dictionary:
	# Les 4 patrons ne PARLENT qu'une fois la nuit de l'acte 1 passée (act1_closed) :
	# y envoyer le joueur avant = il interagit et le patron ne propose rien. On ne
	# recommande donc un patron qu'à partir de ce moment.
	if not CampaignManager.has_flag("act1_closed"):
		return {}
	# Une voie déjà scellée → on ne suggère plus de patrons (les voies sont
	# mutuellement exclusives ; sinon on envoie le joueur voir un patron qui le
	# rejettera, ex. Ramos après avoir choisi Tito).
	if not _no_voie_chosen():
		return {}
	var cur: String = DistrictManager.current()
	var pool: Array = []
	for p in PATRONS:
		if not pacto and (QuestManager.is_completed(p.q) or QuestManager.is_active(p.q)):
			continue
		pool.append(p)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = {}
	for p in pool:
		if p.dist == cur:
			chosen = p
			break
	if chosen.is_empty():
		chosen = pool[0]
	var verb: String = "sceller un pacte avec" if pacto else "voir"
	return _S("🎯 Va %s %s" % [verb, chosen.short], chosen.dist, chosen.anchor, chosen.short)

# Quête de règne → spot qui l'offre (les quatre recruteurs attendent sur le
# sable de Copa, y = 268 — pas sur le calçadão comme le disait le bandeau).
const REINADO_SPOTS: Dictionary = {
	"reinado_a_pedagio": "reinado_trafico", "reinado_a_carga": "reinado_trafico",
	"reinado_b_ronda": "reinado_policia", "reinado_b_camarote": "reinado_policia",
	"reinado_c_vitrine": "reinado_consortium", "reinado_c_camarote": "reinado_consortium",
	"reinado_d_bloco": "reinado_prefeito", "reinado_d_alas": "reinado_prefeito",
}

# Cache des ancres `spot:`/`node:` (les districts sont instanciés une fois).
var _anchor_cache: Dictionary = {}

func _find_world_node(anchor: String) -> Node:
	var cached: Node = _anchor_cache.get(anchor)
	if cached != null and is_instance_valid(cached) and cached.is_inside_tree():
		return cached
	var root: Node = get_tree().current_scene
	if root == null:
		return null
	var found: Node = null
	if anchor.begins_with("node:"):
		var wanted: String = anchor.substr(5)
		for n in root.find_children(wanted, "", true, false):
			found = n
			break
	elif anchor.begins_with("class:"):
		var cls: String = anchor.substr(6)
		for n in root.find_children("*", "Node2D", true, false):
			if n.get_script() != null and String(n.get_script().get_global_name()) == cls:
				found = n
				break
	else:
		var npc_id: String = anchor.substr(5)
		for n in root.find_children("*", "Node2D", true, false):
			if n is ReactiveDialogueSpot and String(n.get("npc_id")) == npc_id:
				found = n
				break
	if found != null:
		_anchor_cache[anchor] = found
	return found

# Un PNJ qui vit dans un intérieur (Ramos à l'Academia, le Padre à l'église…) :
# la boussole doit pointer la PORTE de son bâtiment, pas le nœud posé hors
# carte (playtest 2026-10-08 : 62 min de flèche vers le vide au nord de Copa).
# On cherche la BuildingDoor d'entrée dont la destination tombe près du PNJ.
var _entrance_cache: Dictionary = {}

func _entrance_or_self(npc: Node) -> Node:
	if npc == null or not is_instance_valid(npc) or not (npc is Node2D):
		return npc
	var key: int = npc.get_instance_id()
	if _entrance_cache.has(key):
		var cached: Node = _entrance_cache[key]
		if cached == null:
			return npc
		if is_instance_valid(cached) and cached.is_inside_tree():
			return cached
	var root: Node = get_tree().current_scene
	if root == null:
		return npc
	var pos: Vector2 = (npc as Node2D).global_position
	var best: Node = null
	var best_d: float = 400.0
	for d in root.find_children("*", "", true, false):
		if not (d is BuildingDoor) or bool(d.get("is_exit")):
			continue
		var dest: Vector2 = d.get("destination")
		if dest == Vector2.ZERO:
			continue
		var dd: float = dest.distance_to(pos)
		if dd < best_d:
			best_d = dd
			best = d
	_entrance_cache[key] = best
	return best if best != null else npc

# Position d'un nœud, ou NO_POS s'il est invalide / trop loin (= autre district).
func _node_pos_guard(n: Node) -> Vector2:
	if n == null or not is_instance_valid(n) or not (n is Node2D):
		return NO_POS
	var p: Vector2 = (n as Node2D).global_position
	if GameManager.player != null and p.distance_to(GameManager.player.global_position) > MAX_POINT_DIST:
		return NO_POS
	return p

# --- Helpers d'état (repris d'ObjectiveBanner) ---

func _player_money() -> int:
	if GameManager.player == null:
		return 0
	var inv: Inventory = GameManager.player.get_node_or_null("Inventory") as Inventory
	if inv == null:
		return 0
	return inv.money

func _cart_carrying() -> bool:
	var cart: Node = get_tree().get_first_node_in_group("corn_cart")
	if cart == null or not cart.has_method("is_carrying"):
		return false
	return cart.call("is_carrying")

# Quand une voie est scellée mais qu'aucune mission n'est active, renvoie vers
# le DONNEUR de la prochaine mission disponible de la chaîne (souvent un spot
# de district, pas le patron — playtest 2026-10-08 : « retrouve Ramos » 60 min
# alors que B3 s'offrait au spot de filature du morro) ; sinon vers le patron.
const VOIE_PREFIX: Dictionary = {
	"voie_trafico": ["trafico_a", "Tráfico"],
	"voie_policia": ["policia_b", "Polícia"],
	"voie_consortium": ["consortium_c", "Consórcio"],
	"voie_prefeito": ["prefeito_d", "Prefeito"],
}

func _voie_continue() -> Dictionary:
	for flag in VOIE_PREFIX:
		if not CampaignManager.has_flag(flag):
			continue
		var next: Dictionary = _next_voie_quest_target(String(VOIE_PREFIX[flag][0]), String(VOIE_PREFIX[flag][1]))
		if not next.is_empty():
			return next
	if CampaignManager.has_flag("voie_trafico"):
		return _S("🎯 Continue ta voie Tráfico — retrouve Tito à la Favela", "favela_morro", "npc:tito", "Tito · Favela")
	if CampaignManager.has_flag("voie_policia"):
		return _S("🎯 Continue ta voie Polícia — retrouve Ramos", "copacabana", "npc:ramos", "Ramos · Academia (Copa)")
	if CampaignManager.has_flag("voie_consortium"):
		return _S("🎯 Continue ta voie Consórcio — retrouve Magalhães (Barra)", "barra_tijuca", "npc:magalhaes", "Magalhães · Barra")
	if CampaignManager.has_flag("voie_prefeito"):
		return _S("🎯 Continue ta voie Prefeito — retrouve le Padre (église)", "copacabana", "church", "Padre · l'église")
	return {}

# Prochaine MAIN disponible de la chaîne (ordre des ids) → son donneur.
func _next_voie_quest_target(prefix: String, voie_label: String) -> Dictionary:
	var ids: Array = []
	for id in QuestManager._quests.keys():
		var q: Quest = QuestManager.get_quest(id)
		# Une mission de voie ÉCHOUÉE (chrono dépassé) se relance chez son
		# donneur : sans ça le guide renvoyait au patron, qui n'a rien à dire
		# (playtest 2026-11-18, A3 ratée → 10 min à tourner autour de Tito).
		if q != null and q.quest_type == Quest.QuestType.MAIN and String(id).begins_with(prefix) \
				and (QuestManager.is_available(id) or QuestManager.is_failed(id)):
			ids.append(id)
	if ids.is_empty():
		return {}
	ids.sort()
	var quest: Quest = QuestManager.get_quest(ids[0])
	var giver: String = quest.giver_npc_id
	if giver == "":
		return {}
	var node: Node = NPCScheduler.get_npc(giver)
	var anchor: String = "npc:" + giver
	if node == null:
		node = _find_world_node("spot:" + giver)
		anchor = "spot:" + giver
	if node == null:
		return {}
	var dist: String = _district_of_node(node)
	var where: String = _short_district(dist) if dist != "copacabana" else "Copa"
	return _S("🎯 Voie %s — « %s » : retourne voir ton contact (%s)" % [voie_label, quest.display_name, where],
			dist, anchor, where)

# District qui contient un nœud (enfant direct de World portant une scène de
# district), sinon Copacabana. Les ids partageant une scène (Aterro/Botafogo)
# se départagent par l'absence de spawn_marker (l'id « principal »).
func _district_of_node(node: Node) -> String:
	var n: Node = node
	var world: Node = get_tree().current_scene.get_node_or_null("World") if get_tree().current_scene else null
	while n != null and n.get_parent() != null and n.get_parent() != world:
		n = n.get_parent()
	if n == null:
		return "copacabana"
	var fallback: String = ""
	for id in DistrictManager.DISTRICTS:
		if String(DistrictManager.DISTRICTS[id].get("node_name", "")) == n.name:
			if not DistrictManager.DISTRICTS[id].has("spawn_marker"):
				return id
			fallback = id
	return fallback if fallback != "" else "copacabana"

func _no_voie_chosen() -> bool:
	for f in CampaignManager.VOIE_FLAGS:
		if CampaignManager.has_flag(f):
			return false
	return true

# Couleur d'identité de la voie scellée (boussole + bord du panneau Objectif).
# Doré tant qu'aucune voie n'est choisie.
func voie_color() -> Color:
	if CampaignManager.has_flag("voie_trafico"):
		return Color(0.92, 0.55, 0.3, 1.0)   # orange — morro
	if CampaignManager.has_flag("voie_policia"):
		return Color(0.4, 0.62, 0.95, 1.0)    # bleu — police
	if CampaignManager.has_flag("voie_consortium"):
		return Color(0.62, 0.38, 0.62, 1.0)   # violet — consórcio
	if CampaignManager.has_flag("voie_prefeito"):
		return Color(0.55, 0.85, 0.55, 1.0)   # vert — prefeito
	return Color(0.96, 0.82, 0.36, 1.0)        # doré — pas encore de voie

# Label court d'un district (« Niterói — barcas… » → « Niterói »).
func _short_district(dist: String) -> String:
	var label: String = DistrictManager.get_label(dist)
	var dash: int = label.find(" —")
	return label.substr(0, dash) if dash > 0 else label

# --- Réactions aux événements ---

func _on_event(_id: String) -> void: _recompute()
func _on_quest_updated(_q: String, _o: String) -> void: _recompute()
func _on_debt_paid(_a: int, _r: int) -> void: _recompute()
func _on_act_changed(_act: int) -> void: _recompute()
func _on_district_changed(_d: String) -> void: _recompute()
func _on_cart_state(_c: bool) -> void: _recompute()
func _on_money_changed(_a: int) -> void: _recompute()
func _on_customer_served(_id: String) -> void: _recompute()
func _on_phase_changed(_p: int) -> void: _recompute()
# Différé : CarnavalCalendar (autoload chargé après) pose les flags du jour
# (Cendres, jogo) sur le même signal.
func _on_day_elapsed(_d: int) -> void: call_deferred("_recompute")
