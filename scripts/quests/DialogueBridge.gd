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
const PLACEHOLDER_DIALOGUES: Dictionary = {
	# --- ACTE 1 : L'héritage empoisonné ---
	"seu_joao_heritage": {
		"speaker": "Seu João",
		"text": "Sobrinho ! Ton oncle Zé… il a disparu hier. Et il m'a laissé un mot pour toi. 'Tudo é teu' qu'il a écrit. Sa charrette, ses affaires… et sa dette. Cinquante mille reais, au consortium. Ai, ai, ai.",
		"choices": ["Une dette ? À qui ?", "Je ferai quoi ?"],
		"on_choose": {
			"0": {"next": "seu_joao_debt_who"},
			"1": {"next": "seu_joao_advice"},
		},
	},
	"seu_joao_debt_who": {
		"speaker": "Seu João",
		"text": "Le consortium, tu verras. Trois types qui traînent sur l'Av. Atlântica. Un comptable, un gros monsieur, et un qui chante du pagode. T'as jusqu'au Carnaval pour payer. Commence par la charrette, vends du milho. Cinq cents reais d'acompte les calmeront pour quelques jours.",
		"choices": ["D'accord"],
		"on_choose": {
			"0": {"accept_quest": "act1_heritage", "set_flag": "act1_started"},
		},
	},
	"seu_joao_advice": {
		"speaker": "Seu João",
		"text": "Tu vas bosser, sobrinho. Prends ma carrocinha en attendant. Va voir le consortium aussi, avant qu'ils ne viennent te chercher.",
		"choices": ["D'accord"],
		"on_choose": {
			"0": {"accept_quest": "act1_heritage", "set_flag": "act1_started"},
		},
	},
	"seu_joao_intro_tutorial": {
		"speaker": "Seu João",
		"text": "*pose sa main sur ton épaule* La carrocinha est dehors, à côté de la maison. Charge-la, descends l'escalier vers Copacabana, vends du milho au calçadão. Le consortium veut 500 reais d'acompte cette semaine. Cinquante mille au Carnaval. Boa sorte, sobrinho. Et reviens dîner.",
		"choices": ["Obrigado, tio"],
	},
	"consortium_intro": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Ah, le neveu de Zé. Assieds-toi. Cinquante mille reais. T'as jusqu'au Carnaval. Cinq cents d'acompte et je te laisse respirer une semaine. Sinon…",
		"choices": ["Sinon quoi ?", "Je reviendrai avec l'acompte"],
		"on_choose": {
			"0": {"next": "consortium_threat"},
			"1": {"set_flag": "met_consortium"},
		},
	},
	"consortium_threat": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Sinon… Claudinho écrira une samba sur ton enterrement. Jorge (le videur) plantera la croix. Et moi j'enverrai la facture à ta mère. *rires généraux*",
		"choices": ["Compris, je reviens"],
		"on_choose": {
			"0": {"set_flag": "met_consortium"},
		},
	},
	"consortium_pay": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Combien tu poses sur la table aujourd'hui ?",
		"choices": ["Poser R$ 100", "Poser R$ 500", "Poser tout ce que j'ai (max 5k)", "Rien pour l'instant"],
		"on_choose": {
			"0": {"pay_debt": 100},
			"1": {"pay_debt": 500},
			"2": {"pay_debt": 5000},
		},
	},
	"consortium_after_threshold": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Pas mal, pas mal. Tu tiens la distance. Continue comme ça. On se reverra pour le reste. *un clin d'œil malaisant*",
		"choices": ["D'accord"],
	},
	"consortium_settled": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Dette soldée, parceiro. Claudinho, range ta samba funèbre. Tu es un homme libre… pour l'instant.",
		"choices": ["Merci"],
	},
	# --- Side quest : aller chercher Don Salvatore à Santos Dumont ---
	"consortium_airport_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Sobrinho, j'ai une faveur. Don Salvatore, un padrinho de São Paulo, pose à Santos Dumont dans une heure. Va le chercher, ramène-le-moi, discrètement. Je file 800 reais. Et ton ardoise descend de 500 supplémentaires. Le taxi de l'Av. Atlântica te dépose au terminal.",
		"choices": ["J'y vais", "Pas le moment"],
		"on_choose": {
			"0": {"accept_quest": "consortium_airport_pickup"},
		},
	},
	"consortium_airport_remind": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Don Salvatore t'attend à Santos Dumont. Ramène-le ici en un seul morceau. Le taxi connaît le chemin.",
		"choices": ["J'y vais"],
	},
	"consortium_airport_done": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*serre la main de Don Salvatore* Padrinho, bem-vindo. *au joueur, plus bas* Tu as fait du bon travail, sobrinho. 800 reais et 500 de moins sur la dette. Continue comme ça.",
		"choices": ["Obrigado, Dom Nilton"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_airport_pickup", "objective": "deliver_to_consortium", "payout": 0}, "pay_debt": 500},
		},
	},
	"salvatore_intro": {
		"speaker": "Don Salvatore",
		"text": "*ajuste ses lunettes fumées* Je n'attends personne, ragazzo. Tu te trompes de gentleman.",
		"choices": ["Pardon, monsieur"],
	},
	"salvatore_arrival": {
		"speaker": "Don Salvatore",
		"text": "*regarde son chronographe* Tu es en retard de quatre minutes. Mais tu es là. Bom. Dom Nilton t'attend ? Allons-y. Marche devant — je suis tes pas. Pas un mot pendant le trajet, capisce ?",
		"choices": ["Capisco. Suivez-moi"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_airport_pickup", "objective": "meet_at_airport", "payout": 0}},
		},
	},
	"salvatore_waiting": {
		"speaker": "Don Salvatore",
		"text": "*tape légèrement sa canne sur le sol* Le consortium, ragazzo. Pas le détour touristique. Tu prends le taxi, tu m'amènes à Dom Nilton. Andiamo.",
		"choices": ["Tout de suite, monsieur"],
	},
	"salvatore_done": {
		"speaker": "Don Salvatore",
		"text": "*sourit avec retenue* Tu as bien travaillé, ragazzo. Si je repasse à Rio, je demanderai expressément ton service. Buona fortuna.",
		"choices": ["Buon viaggio"],
	},
	"ramos_intro": {
		"speaker": "Capitão Ramos",
		"text": "*flexion devant le miroir* Toi ! Le neveu de Zé. On surveille la famille, tu sais. Si jamais tu veux aider la Lei et l'Ordem… viens me voir. J'ai peut-être quelque chose pour toi.",
		"choices": ["Ça m'intéresse", "Pas vraiment", "Tu soulèves combien ?"],
		"on_choose": {
			"0": {"accept_quest": "act1_meet_ramos", "set_flag": "met_ramos", "rep": {1: 2}},
			"2": {"next": "ramos_bench", "set_flag": "met_ramos"},
		},
	},
	"ramos_bench": {
		"speaker": "Capitão Ramos",
		"text": "120 au développé. Et je fais encore un peu de jiu-jitsu. Un vrai capitão, tu vois. Bon, si tu changes d'avis, je suis là.",
		"choices": ["Salut"],
	},
	"ramos_active": {
		"speaker": "Capitão Ramos",
		"text": "*fait semblant de ranger son flingue* Bon. Tu veux entrer dans mes bonnes grâces ? Une petite 'cotisation à la caisse de solidarité du poste'. 30 reais. Tu comprends hein ? *clin d'œil*",
		"choices": ["Cotiser (R$ 30)", "Plus tard"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act1_meet_ramos", "objective": "report_to_ramos", "payout": 0}, "pay_bribe": 30, "rep": {1: 5, 2: -2}},
		},
	},
	"ramos_thanks": {
		"speaker": "Capitão Ramos",
		"text": "Eh, mon gars ! T'es officiellement dans la famille bleue. Si tu vois des choses louches, tu sais où me trouver.",
		"choices": ["Compris"],
	},
	"tito_favor_ask": {
		"speaker": "Tito",
		"text": "Simple : tu descends au Bar do Policial et tu glisses 40 reais à Jorge de ma part. Sans discuter. Ensuite tu reviens.",
		"choices": ["OK (R$ 40)", "Je réfléchis"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act1_meet_tito", "objective": "do_tito_favor", "payout": 0}, "pay_bribe": 40, "rep": {2: 5, 1: -2}},
		},
	},
	"tito_thanks": {
		"speaker": "Tito",
		"text": "Beleza, parceiro. T'es un des nôtres maintenant. Si t'as besoin d'un coup de main dans le Morro, tu sais où taper.",
		"choices": ["Valeu"],
	},
	"carlos_intro": {
		"speaker": "Carlos",
		"text": "E aí ! Tu vois mon café, là ? J'ai dix commandes en retard et mon coursier a disparu. 50 reais la livraison si tu prends le vélo derrière moi.",
		"choices": ["J'accepte", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bike_delivery"},
		},
	},
	"carlos_remind": {
		"speaker": "Carlos",
		"text": "Le vélo est juste derrière. Prends-le, file, reviens avec le colis en un morceau.",
		"choices": ["OK"],
	},
	"carlos_thanks": {
		"speaker": "Carlos",
		"text": "Formidável ! Tu peux refaire un tour chaque fois que tu veux. La station vélo est là pour toi.",
		"choices": ["Merci"],
	},
	# --- Side quest : volta na Lagoa (vélo de loisir) ---
	"carlos_lagoa_offer": {
		"speaker": "Carlos",
		"text": "Sobrinho, t'es nerveux à force de pédaler dans la circulation. Va décompresser à la Lagoa Rodrigo de Freitas — taxi de l'Av. Atlântica, dix minutes. Le tour fait quatre kilomètres, plein de touristes qui filent des pourboires aux livreurs sympas. Décompresse et empoche.",
		"choices": ["Bonne idée", "Pas envie"],
		"on_choose": {
			"0": {"accept_quest": "carlos_lagoa_volta"},
		},
	},
	"carlos_lagoa_remind": {
		"speaker": "Carlos",
		"text": "T'as essayé la Lagoa ? La borne de location est juste à côté du chemin. Quatre points cardinaux, dans l'ordre.",
		"choices": ["J'y vais"],
	},
	# --- Église (Padre Anselmo) ---
	"padre_intro": {
		"speaker": "Padre Anselmo",
		"text": "Meu filho. Des gamins ont volé la statue de Nossa Senhora et l'ont planquée sur la plage, côté Forte. Retrouve-la avant le dimanche. 80 reais et la bénédiction du quartier.",
		"choices": ["J'accepte", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "church_statue"},
		},
	},
	"padre_remind": {
		"speaker": "Padre Anselmo",
		"text": "Elle est du côté ouest de la plage, près du Forte. Cherche un reflet blanc dans le sable.",
		"choices": ["OK"],
	},
	"padre_receives": {
		"speaker": "Padre Anselmo",
		"text": "Ah, Nossa Senhora ! Que Dieu te récompense. Voilà tes 80 reais, plus ma bénédiction personnelle.",
		"choices": ["Obrigado"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "church_statue", "objective": "return_statue", "payout": 80}, "rep": {0: 3}},
		},
	},
	"padre_thanks": {
		"speaker": "Padre Anselmo",
		"text": "Que la paix soit sur toi, meu filho. Le Morro parle de toi en bien maintenant.",
		"choices": ["Amen"],
	},
	# --- Side quest : bénédiction de la relique au Corcovado ---
	"padre_corcovado_offer": {
		"speaker": "Padre Anselmo",
		"text": "Meu filho, j'ai une mission délicate. Cette relique de Nossa Senhora doit être bénie au pied du Cristo Redentor pour la procession. Le Corcovado se gravit en taxi depuis l'Av. Atlântica — quinze reais l'aller. Ramène-la bénie, et la paroisse verse deux cents reais pour ta peine.",
		"choices": ["J'y monte, padre", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "padre_corcovado_relic"},
		},
	},
	"padre_corcovado_remind": {
		"speaker": "Padre Anselmo",
		"text": "Le Cristo attend, meu filho. Le taxi sur l'Av. Atlântica te montera au mirante.",
		"choices": ["J'y vais"],
	},
	"padre_corcovado_receives": {
		"speaker": "Padre Anselmo",
		"text": "*tend les mains, ému* Tu l'as bénie, je sens la lumière sur le tissu. Que Dieu te récompense, meu filho. Voilà deux cents reais — la paroisse n'oublie pas son monde.",
		"choices": ["De rien, padre"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "padre_corcovado_relic", "objective": "return_relic", "payout": 0}},
		},
	},
	# --- Pharmacie (Dona Carmen) ---
	"farma_intro": {
		"speaker": "Dona Carmen",
		"text": "Mon neveu Tito est malade dans le Morro. J'ai son médicament mais je ne peux pas monter là-haut. Si tu le lui apportes, 60 reais à ton retour.",
		"choices": ["J'accepte", "Refuser"],
		"on_choose": {
			"0": {"accept_quest": "pharmacy_tito", "finish_quest": {"quest": "pharmacy_tito", "objective": "receive_medicine", "payout": 0}},
		},
	},
	"farma_remind": {
		"speaker": "Dona Carmen",
		"text": "Tito attend son médicament. Le Morro est au nord-ouest, tu ne peux pas le rater.",
		"choices": ["OK"],
	},
	"farma_reward": {
		"speaker": "Dona Carmen",
		"text": "Tu as livré ? Merci, mon grand ! Voilà tes 60 reais. Passe quand tu veux, j'ai toujours du travail.",
		"choices": ["Merci"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "pharmacy_tito", "objective": "deliver_medicine", "payout": 60}, "rep": {0: 2}},
		},
	},
	"farma_thanks": {
		"speaker": "Dona Carmen",
		"text": "Tito va mieux grâce à toi. Je te garde une place dans mes prières.",
		"choices": ["De rien"],
	},
	"tito_receives_medicine": {
		"speaker": "Tito",
		"text": "Ah, Dona Carmen t'a envoyé ! Passe-moi ça. *avale* Beleza. Dis-lui merci, et retourne encaisser.",
		"choices": ["OK"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "pharmacy_tito", "objective": "deliver_medicine", "payout": 0}},
		},
	},
	# --- Escort / accompagnement (Contessa Bianchi) ---
	"contessa_intro": {
		"speaker": "Contessa Bianchi",
		"text": "*mi-amusée, mi-ennuyée* Carioca. J'offre 200 reais à qui veut bien m'accompagner. Le Bar do Policial, puis retour au palace. On se tient, on sourit, on rentre. Ça te parle ?",
		"choices": ["Con piacere, Contessa", "Refuser"],
		"on_choose": {
			"0": {"accept_quest": "escort_contessa"},
		},
	},
	"contessa_snob": {
		"speaker": "Contessa Bianchi",
		"text": "*te regarde de haut en bas* Mmm non. Reviens quand tu auras un peu plus… de charme. (Charisma requis : 10)",
		"choices": ["Compris"],
	},
	"contessa_waiting": {
		"speaker": "Contessa Bianchi",
		"text": "Le Bar do Policial, ragazzo. Jorge sert un caipira à tomber. Je te suis du regard, on se retrouve là-bas.",
		"choices": ["J'y vais"],
	},
	"contessa_back_at_palace": {
		"speaker": "Contessa Bianchi",
		"text": "Parfait, on rentre. *glisse un billet plié avec un clin d'œil* Grazie mille, carioca. Tu étais charmant.",
		"choices": ["Buona notte, Contessa"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_back_to_palace", "payout": 200}, "rep": {3: 3, 4: 1}},
		},
	},
	"contessa_farewell": {
		"speaker": "Contessa Bianchi",
		"text": "Ciao, bello. On se reverra peut-être à Milan. Ou pas.",
		"choices": ["Tchau"],
	},
	"jorge_escort_arrival": {
		"speaker": "Jorge",
		"text": "*lève un sourcil en voyant la Contessa* Tiens, tiens… on fait dans le luxe ce soir ? Je vous sers quoi, signora ?",
		"choices": ["Deux caipirinhas, merci", "On passait juste saluer"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_to_bar", "payout": 0}, "pay_bribe": 20, "rep": {3: 1}},
			"1": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_to_bar", "payout": 0}},
		},
	},
	"tito_meet": {
		"speaker": "Tito",
		"text": "Ton oncle Zé, il bossait pour nous aussi, tu sais. Je peux te filer un coup de main si tu rendresservice. Rien de compliqué.",
		"choices": ["Je suis intéressé", "Pas maintenant"],
		"on_choose": {
			"0": {"accept_quest": "act1_meet_tito", "set_flag": "met_tito", "rep": {2: 2}},
		},
	},
	"seu_joao_intro": {
		"speaker": "Seu João",
		"text": "E aí, parceiro ! Tá querendo ganhar um troco ?",
		"choices": ["Aceitar", "Refuser"],
		"on_choose": {
			"0": {"accept_quest": "quest_milho_01"},
		},
	},
	"seu_joao_reminder": {
		"speaker": "Seu João",
		"text": "Pega a carrocinha ali e se vira, parceiro.",
		"choices": ["OK"],
	},
	"seu_joao_return": {
		"speaker": "Seu João",
		"text": "Volta aí ! Vamos fazer as contas.",
		"choices": ["Rendre la charrette"],
		"on_choose": {
			"0": {"return_cart": true},
		},
	},
	"haggle_with_tourist": {
		"speaker": "Gringa",
		"text": "How much for the corn?",
		"choices": ["R$ 5 (juste)", "R$ 15 (arnaque)", "Refuser"],
		"on_choose": {
			"0": {"sell_at": 5, "rep": {0: 1}},
			"1": {"sell_at": 15, "rep": {0: -2, 3: -3}},
		},
	},
	"haggle_with_local": {
		"speaker": "Carioca",
		"text": "Um milho, por favor.",
		"choices": ["R$ 5", "Refuser"],
		"on_choose": {
			"0": {"sell_at": 5, "rep": {2: 1}},
		},
	},
	"kid_asks": {
		"speaker": "Gamin",
		"text": "Moço, me dá um milho ?",
		"choices": ["Lui offrir", "Refuser"],
		"on_choose": {
			"0": {"give_away": true, "rep": {0: 2, 2: 1}},
			"1": {"rep": {2: -1}},
		},
	},
	"cop_shakedown": {
		"speaker": "PM",
		"text": "Alvará de vendedor ambulante ? Me deixa ver…",
		"choices": ["Payer R$ 20", "Refuser"],
		"on_choose": {
			"0": {"pay_bribe": 20, "rep": {1: 3, 0: -2}},
			"1": {"rep": {0: 2, 1: -5}},
		},
	},
	"customer_satisfied": {
		"speaker": "Cliente",
		"text": "Já comprei, obrigado !",
		"choices": ["OK"],
	},
	"miguel_intro": {
		"speaker": "Miguel",
		"text": "Eh, parceiro. T'as fini avec le milho ? J'ai un truc qui pourrait t'intéresser.",
		"choices": ["Quoi ?", "Pas intéressé"],
		"on_choose": {
			"0": {"next": "miguel_offer"},
		},
	},
	"miguel_offer": {
		"speaker": "Miguel",
		"text": "Un colis à livrer derrière les immeubles, côté rue. 50 reais. Pas de questions.",
		"choices": ["J'accepte", "Refuser", "Je préviens la police"],
		"on_choose": {
			"0": {"accept_quest": "deliver_package_01", "rep": {2: 2, 0: -3}},
			"1": {"rep": {0: 1}},
			"2": {"rep": {0: 3, 1: 3, 2: -5}},
		},
	},
	"miguel_waiting": {
		"speaker": "Miguel",
		"text": "Le colis, parceiro. Tu le déposes et tu reviens pas. C'est tout.",
		"choices": ["OK"],
	},
	"miguel_done": {
		"speaker": "Miguel",
		"text": "Boa. On se reverra peut-être.",
		"choices": ["OK"],
	},
	# --- ACTE 2 : Convoi favela (voie Tráfico) ---
	"miguel_act2_offer": {
		"speaker": "Miguel",
		"text": "Sobrinho, tu m'as trouvé là-haut. Bonne nouvelle : la maison te connaît maintenant. J'ai un sac à faire descendre jusqu'au terrain vague côté Forte. Six cents reais cash à la livraison. Tu prends ?",
		"choices": ["Six cents reais ? J'embarque", "C'est quoi dedans ?", "Trop chaud pour moi"],
		"on_choose": {
			"0": {"accept_quest": "act2_miguel_favela"},
			"1": {"next": "miguel_act2_warning"},
		},
	},
	"miguel_act2_warning": {
		"speaker": "Miguel",
		"text": "*il te fixe sans cligner* Justement, tu poses pas la question. Tu portes, tu poses, tu rentres. Si t'as un doute, tu refuses maintenant — après c'est trop tard.",
		"choices": ["OK, j'embarque", "Je laisse tomber"],
		"on_choose": {
			"0": {"accept_quest": "act2_miguel_favela"},
		},
	},
	"miguel_act2_remind": {
		"speaker": "Miguel",
		"text": "Le terrain vague, sobrinho. Côté Forte, derrière les rochers. Tu déposes, tu pars. Pas de selfie.",
		"choices": ["J'y vais"],
	},
	"miguel_act2_done": {
		"speaker": "Miguel",
		"text": "Beleza, parceiro. Le patron est content. Repose-toi, je te recontacte quand y'aura un autre coup.",
		"choices": ["Valeu"],
	},
	# --- ACTE 2 : Operação Carnaval (voie Polícia) ---
	"ramos_act2_offer": {
		"speaker": "Capitão Ramos",
		"text": "*pose son haltère* Sobrinho, j'ai besoin d'un service décisif. Tito du Morro — tu le connais maintenant. Il prépare un gros coup pour la semaine du Carnaval. Sa position, et on coupe court. 800 reais et tu rentres dans la maison bleue. Sinon, on saura que t'as choisi la rue.",
		"choices": ["Je donne Tito (R$ 800)", "Non, je couvre Tito", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act2_ramos_operacao", "next": "ramos_act2_rat"},
			"1": {"accept_quest": "act2_ramos_operacao", "next": "ramos_act2_protect"},
		},
	},
	"ramos_act2_rat": {
		"speaker": "Capitão Ramos",
		"text": "Bom garoto. La maison bleue te paye, et la maison bleue n'oublie pas. *te tend une enveloppe* Tito ne reverra pas le sable cette saison. Tu viens d'acheter un peu de respect.",
		"choices": ["Que justiça seja feita."],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_ramos_operacao", "objective": "answer_ramos", "payout": 800}, "set_flag": "ratted_on_tito", "rep": {1: 8, 2: -8}},
		},
	},
	"ramos_act2_protect": {
		"speaker": "Capitão Ramos",
		"text": "*croise les bras* Choix de petit. Tu portes le maillot du Morro maintenant, garoto. Cette porte est fermée pour toi. Bonne chance dehors.",
		"choices": ["J'assume."],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_ramos_operacao", "objective": "answer_ramos", "payout": 0}, "rep": {1: -3, 2: 3}},
		},
	},
	"ramos_act2_done_loyal": {
		"speaker": "Capitão Ramos",
		"text": "Sobrinho ! La maison bleue parle de toi. Continue à payer ta dette propre, on te tient l'épaule.",
		"choices": ["Compreendido"],
	},
	"ramos_act2_done_cold": {
		"speaker": "Capitão Ramos",
		"text": "*ne te regarde pas* Tu cherches quoi ici, garoto ? File ailleurs.",
		"choices": ["…"],
	},
	# --- ACTE 2 : Salvem o Orfanato (voie Prefeito) ---
	"padre_act2_offer": {
		"speaker": "Padre Anselmo",
		"text": "Meu filho, le bairro a besoin de toi. La mairie veut raser l'orfanato Nossa Senhora pour un parking. Trois commerçants doivent signer la pétition pour qu'on bloque le projet : Carlos du café, Beatriz de Rio Style, Dona Carmen de la pharmacie. Quatre cents reais sur la cagnotte de la paroisse pour ta peine.",
		"choices": ["J'accepte, padre", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act2_padre_orfanato"},
		},
	},
	"padre_act2_remind": {
		"speaker": "Padre Anselmo",
		"text": "Carlos, Beatriz, Dona Carmen. Trois signatures. La cloche sonne, meu filho.",
		"choices": ["J'y vais"],
	},
	"padre_act2_done": {
		"speaker": "Padre Anselmo",
		"text": "L'orfanato est sauvé, meu filho. Les enfants prient pour toi à chaque messe. Le quartier saura à qui il doit ça.",
		"choices": ["Amen"],
	},
	"carlos_act2_petition": {
		"speaker": "Carlos",
		"text": "*lit la pétition* Le Padre m'envoie un héros maintenant ? Bon. Si on perd l'orfanato, on perd les gamins qui me ramènent les vélos. Je signe. *gribouille*",
		"choices": ["Obrigado, Carlos"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_padre_orfanato", "objective": "signed_carlos", "payout": 0}},
		},
	},
	"beatriz_act2_petition": {
		"speaker": "Beatriz",
		"text": "Une pétition pour l'orfanato ? *prend le stylo* Mon frère y a grandi avant de partir à São Paulo. Voilà. Et dis au Padre que Rio Style donnera dix maillots pour la kermesse.",
		"choices": ["Tu es la meilleure"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_padre_orfanato", "objective": "signed_beatriz", "payout": 0}},
		},
	},
	"carmen_act2_petition": {
		"speaker": "Dona Carmen",
		"text": "Le maire veut un parking, c'est ça ? *signe sans hésiter* Tito m'a parlé de toi, mon grand. Tu fais bien. Voilà ma signature, et un sirop pour la toux des enfants.",
		"choices": ["Que Dieu vous garde"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_padre_orfanato", "objective": "signed_carmen", "payout": 0}},
		},
	},
	# --- ACTE 2 : O que vi no mar (Pêcheur) ---
	"pecheur_act2_offer": {
		"speaker": "Seu Pedro",
		"text": "Sobrinho, écoute. Cette nuit, à 3h du matin, j'ai vu trois canots noirs faire la navette du large jusqu'à la pointe de Leme. Pas de pêcheurs — des hommes en treillis. Mes filets en ont senti l'odeur de l'essence pendant deux heures. Je sais pas à qui en parler. Toi, peut-être. Tu prends l'info ?",
		"choices": ["J'écoute, Seu Pedro", "Pas mes oignons"],
		"on_choose": {
			"0": {"accept_quest": "act2_pecheur_secret", "next": "pecheur_act2_choose"},
		},
	},
	"pecheur_act2_choose": {
		"speaker": "Seu Pedro",
		"text": "Trois choix, mon gars. Tu en parles à Ramos — la Polícia coupera le robinet et te paiera bien. Tu en parles à Miguel — le Morro saura, et il y a peut-être quelque chose à grappiller. Ou tu te tais, et tu rentres chez toi dormir. Que Dieu te guide.",
		"choices": ["Je vais voir Ramos (R$ 400)", "Je préviens Miguel (R$ 300)", "Je me tais"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 400}, "set_flag": "pecheur_to_ramos", "rep": {1: 5, 2: -2}},
			"1": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 300}, "set_flag": "pecheur_to_miguel", "rep": {2: 5, 0: -2}},
			"2": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 0}, "rep": {0: -1}},
		},
	},
	"pecheur_act2_remind": {
		"speaker": "Seu Pedro",
		"text": "Tu décides quand tu veux, sobrinho. Mais les canots reviennent chaque nuit.",
		"choices": ["Je réfléchis"],
		"on_choose": {
			"0": {"next": "pecheur_act2_choose"},
		},
	},
	"pecheur_act2_done": {
		"speaker": "Seu Pedro",
		"text": "*tire un dernier filet* La mer parle moins fort cette nuit. Obrigado, sobrinho.",
		"choices": ["Bonne pêche"],
	},
	# --- Side quest : tour des Cagarras en stand-up paddle ---
	"pecheur_cagarras_offer": {
		"speaker": "Seu Pedro",
		"text": "*pointe l'horizon* Tu vois les quatre rochers là-bas ? Cagarras. J'ai aperçu une botija coloniale coincée entre deux rochers de l'îlot du milieu. La marée est calme aujourd'hui. Loue un SUP au Posto 6, contourne les quatre îlots, ramène un croquis. Je te file 250 reais et la moitié de ce que vaut la jarre si tu la rapportes un jour.",
		"choices": ["J'y vais", "Pas le moment"],
		"on_choose": {
			"0": {"accept_quest": "pedro_cagarras_sup"},
		},
	},
	"pecheur_cagarras_remind": {
		"speaker": "Seu Pedro",
		"text": "Le taxi de l'Av. Atlântica te dépose au Posto 6. La borne SUP est juste sur le sable. Quatre îlots, dans l'ordre. Et fais gaffe au courant — il pousse vers l'ouest.",
		"choices": ["Já vou"],
	},
	"pecheur_cagarras_done": {
		"speaker": "Seu Pedro",
		"text": "*déplie le croquis et siffle* Bom mapa, sobrinho. La prochaine fois je viens avec toi et on remonte la jarre. La mer t'aime bien.",
		"choices": ["Valeu, Seu Pedro"],
	},
	# --- Acte 4 : défilé du Carnaval (couronnement public) ---
	"seu_joao_carnaval_offer": {
		"speaker": "Seu João",
		"text": "Sobrinho ! L'école de samba veut te mettre devant pour le défilé. Une vrai bagunça : tamborim, surdo, cuíca, agogô. Tu mènes le bloc, la foule te porte. C'est ton couronnement, comprends ? Va au Sambódromo, le taxi t'y dépose. Et tu rentres reinado pour de bom.",
		"choices": ["J'y vais, tio", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act4_carnaval_desfile"},
		},
	},
	"seu_joao_carnaval_remind": {
		"speaker": "Seu João",
		"text": "Le Sambódromo t'attend, reinado. Tape juste, garde la foule debout — score 240, c'est suffisant. Le taxi de l'Av. Atlântica te mène à l'avenue Marquês de Sapucaí.",
		"choices": ["Já vou"],
	},
	"seu_joao_carnaval_done": {
		"speaker": "Seu João",
		"text": "*essuie une larme* J'ai vu ça à la télé, sobrinho. Toute la Sapucaí qui chante ton nom. Ton oncle Zé serait fier. Maintenant tu peux dormir tranquille — Copacabana est à toi.",
		"choices": ["Obrigado, tio"],
	},
	# --- ACTE 2 : Gala da Contessa ---
	"contessa_act2_offer": {
		"speaker": "Contessa Bianchi",
		"text": "*sirote un Aperol* Carioca. J'organise un gala pour le bairro — caritatif, télévisé, tout. Mais la production patine. Trouve-moi : une voix (ce Ronaldo qui joue dans la rue), un sponsor café (ton ami Carlos), et une sécurité solide (Jorge du Bar do Policial). 1500 reais et l'invitation d'honneur si tu réussis.",
		"choices": ["Con piacere, Contessa", "Pas pour moi"],
		"on_choose": {
			"0": {"accept_quest": "act2_contessa_gala"},
		},
	},
	"contessa_act2_remind": {
		"speaker": "Contessa Bianchi",
		"text": "Ronaldo, Carlos, Jorge. Trois oui, et le gala se monte. La presse arrive vendredi, ragazzo.",
		"choices": ["Je file"],
	},
	"contessa_act2_done": {
		"speaker": "Contessa Bianchi",
		"text": "*lève sa coupe* Parfait, carioca. Le gala fera la une de Veja. Tu as gagné Rio cette semaine. *te glisse une enveloppe avec un clin d'œil*",
		"choices": ["Grazie, Contessa"],
	},
	# --- Side quest : date privée avec la Contessa (après le gala) ---
	"contessa_date_offer": {
		"speaker": "Contessa Bianchi",
		"text": "*touche ton épaule du bout des doigts* Carioca... le gala m'a charmée plus que je ne devrais l'admettre. J'aimerais te revoir ce soir. Je te laisse choisir où, quoi, comment. Surprends-moi.",
		"choices": ["Avec plaisir, Contessa", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "contessa_date", "next": "contessa_date_restaurant"},
		},
	},
	"contessa_date_remind": {
		"speaker": "Contessa Bianchi",
		"text": "*tape doucement du pied* Tu m'as fait attendre, carioca. On reprend où on en était ?",
		"choices": ["Reprenons"],
		"on_choose": {
			"0": {"next": "contessa_date_restaurant"},
		},
	},
	"contessa_date_restaurant": {
		"speaker": "Contessa Bianchi",
		"text": "*ajuste sa robe en soie* Alors, ragazzo... où m'emmènes-tu ce soir ?",
		"choices": [
			"Cantinho Carioca — feijoada autentica",
			"Rooftop du Copa Palace — vue mer",
			"Bar do Policial — Jorge nous fera un caipira",
		],
		"on_choose": {
			"0": {"next": "contessa_date_dinner", "rep": {4: 2}},
			"1": {"next": "contessa_date_dinner", "rep": {4: -1}},
			"2": {"next": "contessa_date_dinner", "rep": {3: 1}},
		},
	},
	"contessa_date_dinner": {
		"speaker": "Contessa Bianchi",
		"text": "*sirote son verre, le regard intense par-dessus la flamme de la bougie* Parle-moi, carioca. De toi, de cette ville... de quelque chose qui sort de l'ordinaire.",
		"choices": [
			"Pourquoi tu as quitté Milan ?",
			"Tu as déjà tout vu du Carnaval ?",
			"Tu pourrais me présenter à tes amis ?",
		],
		"on_choose": {
			"0": {"next": "contessa_date_sunset", "rep": {4: 2}},
			"1": {"next": "contessa_date_sunset", "rep": {3: 1}},
			"2": {"next": "contessa_date_sunset", "rep": {4: -2}},
		},
	},
	"contessa_date_sunset": {
		"speaker": "Contessa Bianchi",
		"text": "*se penche par-dessus la rambarde du mirante, le ciel est rouge sang* Le soleil tombe sur Cristo. Que dis-tu, ragazzo ?",
		"choices": [
			"Lui prendre la main : « Contessa, vous êtes belle. »",
			"Faire une blague pour briser la glace",
			"Lui demander de te recommander à ses amis riches",
		],
		"on_choose": {
			"0": {"finish_quest": {"quest": "contessa_date", "objective": "complete_date", "payout": 600}, "set_flag": "contessa_smitten", "rep": {4: 5, 3: 3}},
			"1": {"finish_quest": {"quest": "contessa_date", "objective": "complete_date", "payout": 200}, "rep": {4: 1}},
			"2": {"finish_quest": {"quest": "contessa_date", "objective": "complete_date", "payout": 0}, "rep": {4: -3}},
		},
	},
	"contessa_date_done": {
		"speaker": "Contessa Bianchi",
		"text": "*polite distance* Carioca. Bonne soirée.",
		"choices": ["Buona sera"],
	},
	"contessa_date_done_smitten": {
		"speaker": "Contessa Bianchi",
		"text": "*sourit en glissant ses lunettes sur le front* Mio carioca... Milan ne te mérite pas, mais Rio si. Reviens quand tu veux — la chambre du Palace est ouverte pour toi.",
		"choices": ["Buona sera, mia Contessa"],
	},
	# --- Side quest : tour guidé pour le touriste VIP ---
	"tourist_vip_tour_offer": {
		"speaker": "Touriste VIP",
		"text": "*ajuste son chapeau de paille trop neuf* Hey amigo ! Tu parle français ? Je veux voir le vrai Rio — le Cristo, le Pão de Açúcar, la Lagoa. Pas les pièges à touristes du Palace. Tu m'emmènes ? Je donne 100 reais à chaque arrêt et 600 de plus à la fin. C'est bon pour toi ?",
		"choices": ["Marché conclu, monsieur", "Non merci"],
		"on_choose": {
			"0": {"accept_quest": "tourist_vip_tour"},
		},
	},
	"tourist_vip_tour_remind": {
		"speaker": "Touriste VIP",
		"text": "*tape sur la carte qu'il tient à l'envers* Cristo, Pão de Açúcar, Lagoa. Le taxi de l'Av. Atlântica fait tout ça. Reviens me voir entre les arrêts si tu veux — je te paie au fur et à mesure.",
		"choices": ["OK"],
	},
	"tourist_vip_tour_done": {
		"speaker": "Touriste VIP",
		"text": "*sourit, lunettes de soleil et appareil photo en bandoulière* Quel quartier merveilleux ! Mes amis vont être jaloux. Voilà ton bonus, amigo, comme promis. Si je reviens l'an prochain, tu seras mon guide officiel.",
		"choices": ["Bon retour, monsieur"],
	},
	"ronaldo_act2_gala": {
		"speaker": "Ronaldo",
		"text": "Un gala chic ? *gratte son violão* Avec micro et lumières ? Bom, je joue. Dis à la signora que mon cachet c'est trois caipirinhas et un taxi de retour. Et un slot pour 'Garota de Ipanema' en rappel.",
		"choices": ["Compris, maestro"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_contessa_gala", "objective": "secured_band", "payout": 0}},
		},
	},
	"carlos_act2_gala": {
		"speaker": "Carlos",
		"text": "Un gala télévisé ? *éclate de rire* L'expresso ISSIMO en pause publicitaire ? Cher confrère, tu fais une bonne affaire à mon café aujourd'hui. Je sponsorise. Préviens la Contessa : trois machines, deux baristas et l'enseigne sur la scène.",
		"choices": ["Marché conclu"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_contessa_gala", "objective": "secured_sponsor", "payout": 0}},
		},
	},
	"jorge_act2_gala": {
		"speaker": "Jorge",
		"text": "*croise les bras* Contessa veut Jorge à l'entrée ? J'amène trois costauds et personne entre sans liste. Tarif d'ami pour toi, sobrinho — dis-lui que c'est plié.",
		"choices": ["Tu es le boss"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_contessa_gala", "objective": "secured_security", "payout": 0}},
		},
	},
	# --- ACTE 3 : Operação Madrugada (voie Polícia) ---
	"ramos_act3_offer": {
		"speaker": "Capitão Ramos",
		"text": "*regard sec* Sobrinho, le mandat est signé. Cette nuit, on entre dans le Morro. Si tu m'accompagnes, demain Copacabana se réveille avec un nouveau Chefe — toi à mes côtés. Cinq mille reais, et la maison bleue reconnaît son sang. Tu signes ?",
		"choices": ["J'y vais avec toi (FIN POLÍCIA)", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act3_policia_madrugada", "next": "ramos_act3_close"},
		},
	},
	"ramos_act3_close": {
		"speaker": "Capitão Ramos",
		"text": "*serre la main* Bem-vindo à la famille bleue, Chefe. La sirène sonne dans dix minutes. Que les caïds dorment mal cette nuit.",
		"choices": ["Por Copacabana"],
		"on_choose": {
			"0": {"set_endgame": "POLICIA", "finish_quest": {"quest": "act3_policia_madrugada", "objective": "complete_madrugada", "payout": 5000}, "rep": {1: 10}},
		},
	},
	"ramos_act3_done": {
		"speaker": "Capitão Ramos",
		"text": "*salue* Chefe. Tout le poste est à toi.",
		"choices": ["Continue à veiller"],
	},
	# --- ACTE 3 : Última corrida (voie Tráfico) ---
	"miguel_act3_offer": {
		"speaker": "Miguel",
		"text": "*pose son béret* Sobrinho. C'est la course de l'année — un convoi du Morro à Niterói pendant le Carnaval. Si tu pilotes, le Morro te remet les clés. Cinq mille en cash, et Copacabana saura qu'un nouveau roi tient la rue. Tu prends le volant ?",
		"choices": ["Je pilote (FIN TRÁFICO)", "Pas ce soir"],
		"on_choose": {
			"0": {"accept_quest": "act3_trafico_corrida", "next": "miguel_act3_close"},
		},
	},
	"miguel_act3_close": {
		"speaker": "Miguel",
		"text": "*tape ton épaule* Beleza, parceiro. La caravane part à minuit. Quand le soleil se lève, Niterói est à nous.",
		"choices": ["Vamos."],
		"on_choose": {
			"0": {"set_endgame": "TRAFICO", "finish_quest": {"quest": "act3_trafico_corrida", "objective": "execute_run", "payout": 5000}, "rep": {2: 10}},
		},
	},
	"miguel_act3_done": {
		"speaker": "Miguel",
		"text": "*lève la bière* Roi du Morro. Os caras te suivent maintenant.",
		"choices": ["Valeu, parceiro"],
	},
	# --- ACTE 3 : Coronel do Bairro (voie Prefeito) ---
	"padre_act3_offer": {
		"speaker": "Padre Anselmo",
		"text": "Meu filho, le bairro a confiance en toi. Le scrutin pour la sous-préfecture est dans trois jours — notre candidat civique a besoin d'un visage qui parle aux quatre rues. Si tu fais campagne avec lui, Copacabana te reconnaît Coronel do Bairro. Cinq mille reais de la cagnotte, et plus jamais personne ne te marchera sur les pieds.",
		"choices": ["Je fais campagne (FIN PREFEITO)", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act3_prefeito_eleicao", "next": "padre_act3_close"},
		},
	},
	"padre_act3_close": {
		"speaker": "Padre Anselmo",
		"text": "*pose la main sur ton épaule* Que la paix descend sur toi, meu Coronel. Les voix sont scellées. Le quartier respire grâce à toi.",
		"choices": ["Amen, padre"],
		"on_choose": {
			"0": {"set_endgame": "PREFEITO", "finish_quest": {"quest": "act3_prefeito_eleicao", "objective": "win_election", "payout": 5000}, "rep": {0: 10}},
		},
	},
	"padre_act3_done": {
		"speaker": "Padre Anselmo",
		"text": "*sourit largement* Coronel ! Le bairro chante ton nom à la messe.",
		"choices": ["Que Dieu te garde"],
	},
	# --- ACTE 4 : Audiência do Coronel (voie Prefeito) ---
	"padre_act4_audiencia": {
		"speaker": "Padre Anselmo",
		"text": "Coronel, le bairro a confiance en toi. Trois commerçants demandent une audience publique : Carlos, Beatriz, Dona Carmen. Écoute leurs doléances — chacun te confortera dans ton règne.",
		"choices": ["Je tiens audience", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act4_prefeito_audiencia"},
		},
	},
	"padre_act4_remind": {
		"speaker": "Padre Anselmo",
		"text": "Carlos, Beatriz, Dona Carmen — chacun a une doléance. Va les recevoir.",
		"choices": ["J'y vais"],
	},
	"padre_act4_done": {
		"speaker": "Padre Anselmo",
		"text": "*joint les mains* Tu as écouté le bairro. Voilà la cagnotte de la paroisse. Le règne grandit.",
		"choices": ["Obrigado, padre"],
	},
	"carlos_act4_audiencia": {
		"speaker": "Carlos",
		"text": "Coronel ! La mairie veut nous taxer les terrasses. Tu peux faire pression ? Ça étoufferait la moitié des cafés du bairro.",
		"choices": ["Je vais m'en occuper"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_prefeito_audiencia", "objective": "heard_carlos", "payout": 0}},
		},
	},
	"beatriz_act4_audiencia": {
		"speaker": "Beatriz",
		"text": "Coronel, mon loyer triple parce que le syndic a vendu à un promoteur. On va perdre Rio Style. Tu peux parler au consortium des bâtiments ?",
		"choices": ["Je m'en charge"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_prefeito_audiencia", "objective": "heard_beatriz", "payout": 0}},
		},
	},
	"carmen_act4_audiencia": {
		"speaker": "Dona Carmen",
		"text": "Coronel, le service municipal retient mes médicaments à la douane depuis trois semaines. Le Morro toussera fort cet hiver si rien ne bouge.",
		"choices": ["Je débloque ça"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_prefeito_audiencia", "objective": "heard_carmen", "payout": 0}},
		},
	},
	# --- ACTE 4 : Purga da Madrugada (voie Polícia) ---
	"ramos_act4_purga": {
		"speaker": "Capitão Ramos",
		"text": "Chefe, trois nids restent à boucler avant la fin du mois. Morro, calçadão, Av. Atlântica. Tu passes, tu marques le terrain, on ferme. Un signe à chaque point pour confirmer ta présence.",
		"choices": ["J'y vais", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act4_policia_purga"},
		},
	},
	"ramos_act4_remind": {
		"speaker": "Capitão Ramos",
		"text": "Trois points marqués sur la carte. Tu sais où aller. Reviens quand c'est plié.",
		"choices": ["Compris"],
	},
	"ramos_act4_done": {
		"speaker": "Capitão Ramos",
		"text": "*salue* Trois nids fermés, Chefe. Le bairro respire. La maison bleue te paie.",
		"choices": ["Por Copacabana"],
	},
	# --- ACTE 4 : Coleta do Patrão (voie Tráfico) ---
	"miguel_act4_tributo": {
		"speaker": "Miguel",
		"text": "Patrão, les commerçants doivent te connaître maintenant. Carlos, Beatriz, le Chef. Passe les voir, encaisse le tribut. Pas de violence — juste un rappel.",
		"choices": ["Je passe les voir", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "act4_trafico_tributo"},
		},
	},
	"miguel_act4_remind": {
		"speaker": "Miguel",
		"text": "Carlos, Beatriz, le Chef. Chacun te doit sa part. Reviens avec le tout.",
		"choices": ["OK"],
	},
	"miguel_act4_done": {
		"speaker": "Miguel",
		"text": "*tape ton épaule* Beleza, Patrão. Le Morro te suit. Continue à tenir la rue.",
		"choices": ["Valeu, parceiro"],
	},
	"carlos_act4_tributo": {
		"speaker": "Carlos",
		"text": "*sort une enveloppe sans broncher* Patrão. Voilà la part de la semaine. On respecte les règles.",
		"choices": ["Sage décision"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_trafico_tributo", "objective": "tribute_carlos", "payout": 0}},
		},
	},
	"beatriz_act4_tributo": {
		"speaker": "Beatriz",
		"text": "*ton sec* Le Patrão. Voilà ce qui te revient. J'attends que la rue reste calme en échange.",
		"choices": ["Tu peux dormir tranquille"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_trafico_tributo", "objective": "tribute_beatriz", "payout": 0}},
		},
	},
	"chef_act4_tributo": {
		"speaker": "Chef",
		"text": "*essuie ses mains* Patrão. Tiens, la part du restaurant. La moqueca reste à l'abri.",
		"choices": ["Bien"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act4_trafico_tributo", "objective": "tribute_chef", "payout": 0}},
		},
	},
	"concierge_intro": {
		"speaker": "Concierge",
		"text": "Bem-vindo ao Copacabana Palace. Vous êtes attendu ?",
		"choices": ["Juste de passage", "Belle bâtisse", "Besoin d'aide ?"],
		"on_choose": {
			"1": {"rep": {3: 1}},
			"2": {"next": "concierge_offer"},
		},
	},
	"concierge_offer": {
		"speaker": "Concierge",
		"text": "Ah, peut-être. Une cliente a perdu son bracelet sur la plage. 30 reais si vous le retrouvez.",
		"choices": ["J'accepte", "Non merci"],
		"on_choose": {
			"0": {"accept_quest": "find_bracelet_01"},
		},
	},
	"concierge_remind": {
		"speaker": "Concierge",
		"text": "Le bracelet est quelque part sur le sable. Bonne chance.",
		"choices": ["OK"],
	},
	"concierge_return": {
		"speaker": "Concierge",
		"text": "Vous l'avez trouvé ! Merveilleux. Voici 30 reais, comme promis.",
		"choices": ["Merci"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "find_bracelet_01", "objective": "return_bracelet", "payout": 30}, "rep": {0: 3, 3: 5}},
		},
	},
	"concierge_done": {
		"speaker": "Concierge",
		"text": "La cliente est ravie. Merci encore.",
		"choices": ["Pas de quoi"],
	},
	"musicien_intro": {
		"speaker": "Ronaldo",
		"text": "🎶 Mas que nada... Un peu de choro pour la rue, parceiro ?",
		"choices": ["Donner 2 reais", "Passer mon chemin"],
		"on_choose": {
			"0": {"pay_bribe": 2, "rep": {0: 1, 2: 1}},
		},
	},
	"pecheur_intro": {
		"speaker": "Seu Pedro",
		"text": "A maré tá forte hoje. Les poissons se cachent.",
		"choices": ["Bonne chance", "Tu pêches quoi ?", "Tout va bien ?"],
		"on_choose": {
			"1": {"next": "pecheur_fish"},
			"2": {"next": "pecheur_worried"},
		},
	},
	"pecheur_fish": {
		"speaker": "Seu Pedro",
		"text": "Tainha, pescadinha, parfois une belle anchova. Reviens demain, peut-être que j'aurai du rab.",
		"choices": ["Merci"],
	},
	"pecheur_worried": {
		"speaker": "Seu Pedro",
		"text": "Mon fils Tito est parti jouer dans le Morro ce matin et il n'est pas rentré. Tu peux aller voir s'il va bien ? 40 reais pour toi.",
		"choices": ["J'y vais", "Pas maintenant"],
		"on_choose": {
			"0": {"accept_quest": "pedros_son"},
		},
	},
	"pecheur_remind": {
		"speaker": "Seu Pedro",
		"text": "Tu as trouvé mon Tito ? Il joue dans la Favela do Morro, côté ouest.",
		"choices": ["J'y vais"],
	},
	"pecheur_thanks": {
		"speaker": "Seu Pedro",
		"text": "Muito obrigado, parceiro. Tito est rentré. Une âme comme toi, ça se trouve pas tous les jours.",
		"choices": ["De rien"],
	},
	"tito_playing": {
		"speaker": "Tito",
		"text": "Oi moço ! Je joue ici avec mes amis. Tu vas où ?",
		"choices": ["Juste de passage"],
	},
	"tito_encounter": {
		"speaker": "Tito",
		"text": "Pai m'a envoyé ? Ah bon, je rentre alors. Merci moço !",
		"choices": ["Rentre vite"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "pedros_son", "objective": "find_tito", "payout": 0}},
		},
	},
	# Bar do Policial — Jorge
	"jorge_intro": {
		"speaker": "Jorge",
		"text": "E aí parceiro ! Bem-vindo ao Bar do Policial. Une caipirinha ?",
		"choices": ["Caipirinha (R$ 10)", "Tu as un truc ?", "Plus tard"],
		"on_choose": {
			"0": {"pay_bribe": 10, "rep": {2: 1, 0: 1}},
			"1": {"next": "jorge_offer"},
		},
	},
	"jorge_offer": {
		"speaker": "Jorge",
		"text": "*se penche* Écoute, j'ai un petit problème sentimental. Beatriz, la vendeuse de Rio Style, je... enfin. Tu lui remettrais un bouquet de ma part ? Discrètement. 25 reais.",
		"choices": ["Avec plaisir", "Pas mon genre"],
		"on_choose": {
			"0": {"accept_quest": "flowers_for_beatriz"},
		},
	},
	"jorge_remind": {
		"speaker": "Jorge",
		"text": "Tu as vu Beatriz ? Elle est à sa boutique Rio Style, côté Leme.",
		"choices": ["J'y vais"],
	},
	"jorge_done": {
		"speaker": "Jorge",
		"text": "Obrigado amigo. Elle m'a envoyé un clin d'œil hier soir. Tu as bien fait ton boulot.",
		"choices": ["De rien"],
	},
	"beatriz_receives_flowers": {
		"speaker": "Beatriz",
		"text": "Oh… des fleurs ? De Jorge ? *rougit* Dis-lui que j'accepte de boire un verre vendredi.",
		"choices": ["Je transmettrai"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "flowers_for_beatriz", "objective": "deliver_flowers", "payout": 0}},
		},
	},
	"tourist_vip_intro": {
		"speaker": "Madame Dubois",
		"text": "This beach is wonderful ! Is it always so... lively ?",
		"choices": ["Quase sempre !", "Je ne parle pas anglais"],
		"on_choose": {
			"0": {"rep": {3: 2}},
		},
	},
	"coconut_intro": {
		"speaker": "Dona Lúcia",
		"text": "Água de coco gelada ! Três reais o coco, freguês.",
		"choices": ["J'en prends un (R$ 3)", "Plus tard"],
		"on_choose": {
			"0": {"pay_bribe": 3, "rep": {0: 1, 2: 1}},
		},
	},
	"military_pm_intro": {
		"speaker": "Soldado",
		"text": "Parado ! Zone militaire. Vos papiers, civil.",
		"choices": ["Voici", "J'ai oublié", "Demi-tour"],
		"on_choose": {
			"0": {"rep": {1: 2, 0: 1}},
			"1": {"rep": {1: -3}},
			"2": {"rep": {1: -1}},
		},
	},
	"joggeur_intro": {
		"speaker": "Joggeur",
		"text": "Bom dia ! *haletant*",
		"choices": ["Bom dia"],
	},
	# Bar — Quiosque do Zé
	"ze_intro": {
		"speaker": "Zé",
		"text": "Salve, parceiro ! Bem-vindo ao quiosque. Uma cerveja gelada ?",
		"choices": ["Cerveja (R$ 8)", "Tu as du boulot ?", "Plus tard"],
		"on_choose": {
			"0": {"pay_bribe": 8, "rep": {2: 1, 0: 1}},
			"1": {"next": "ze_offer"},
		},
	},
	"ze_offer": {
		"speaker": "Zé",
		"text": "Ronaldo devait jouer ce soir. Va lui rappeler qu'on démarre à 20h. 20 reais pour toi.",
		"choices": ["J'y vais", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "ze_invitation"},
		},
	},
	"ze_remind": {
		"speaker": "Zé",
		"text": "T'as vu Ronaldo ? Le public attend, parceiro.",
		"choices": ["OK"],
	},
	"ze_done": {
		"speaker": "Zé",
		"text": "Boa ! Reviens boire une cerveja quand tu veux. La maison offre.",
		"choices": ["Obrigado"],
	},
	"ronaldo_invitation": {
		"speaker": "Ronaldo",
		"text": "Zé m'invite ce soir ? Parfait, j'apporte mon violão. Dis-lui que j'y serai à 20h pile.",
		"choices": ["OK"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "ze_invitation", "objective": "tell_ronaldo", "payout": 0}},
		},
	},
	# --- Side quest : DJ au coucher de soleil au Pão de Açúcar ---
	"ronaldo_dj_offer": {
		"speaker": "Ronaldo",
		"text": "Eh sobrinho, t'as l'oreille toi. DJ Paçoca, du mirante du Pão de Açúcar, m'a appelé : il a chopé une grippe carioca. Le set du coucher de soleil est ce soir, et le bondinho monte du monde. Si tu remplaces, les pourboires sont bons. Tu prends le taxi jusqu'à la base, le bondinho fait le reste.",
		"choices": ["J'y monte", "Pas mon truc"],
		"on_choose": {
			"0": {"accept_quest": "ronaldo_dj_paoacucar"},
		},
	},
	"ronaldo_dj_remind": {
		"speaker": "Ronaldo",
		"text": "Le set t'attend, sobrinho. Le mirante du Pão de Açúcar — taxi puis bondinho.",
		"choices": ["J'y vais"],
	},
	"ronaldo_dj_done": {
		"speaker": "Ronaldo",
		"text": "*sourit largement* J'ai eu des nouvelles : la foule du mirante chante encore ton mix. DJ Paçoca te garde la place pour la semaine prochaine si tu veux. Bom som, sobrinho.",
		"choices": ["Valeu, mestre"],
	},
	# --- Side quest : torcida au Maracanã ---
	"ronaldo_torcida_offer": {
		"speaker": "Ronaldo",
		"text": "*tape sur sa caisse* Ça va te plaire, sobrinho. Le Brésil joue ce soir au Maracanã contre l'Argentine. Le chef de torcida cherche un tambourineiro pour mener la tribune nord. Les supporters paient bien le rythme — plus tu déchires, plus le pourboire enfle. Le taxi de l'Av. Atlântica te dépose à l'esplanade.",
		"choices": ["Eu vou nessa", "Pas mon truc"],
		"on_choose": {
			"0": {"accept_quest": "ronaldo_maracana_torcida"},
		},
	},
	"ronaldo_torcida_remind": {
		"speaker": "Ronaldo",
		"text": "Le match a déjà commencé, sobrinho. Le tambour t'attend dans la tribune. Taxi puis stand de la torcida.",
		"choices": ["J'y vais"],
	},
	"ronaldo_torcida_done": {
		"speaker": "Ronaldo",
		"text": "*éclate de rire* J'ai vu la rediff sur Globoesporte ! La caméra a balayé ta tribune trois fois — t'es un fenômeno, sobrinho. Reviens quand tu veux mener la torcida.",
		"choices": ["Bom som"],
	},
	# --- Side quest : basket de rue à l'Aterro do Flamengo ---
	"ronaldo_basket_offer": {
		"speaker": "Ronaldo",
		"text": "Sobrinho, j'ai un autre tuyau. À l'Aterro do Flamengo, les gamins du quartier organisent des duels de basket trois-points face à la baie. Pot des paris bien rempli. Si tu rentres dix tirs, la moitié pour toi. Le taxi de l'Av. Atlântica te dépose au terrain.",
		"choices": ["Ça marche", "Pas mon truc"],
		"on_choose": {
			"0": {"accept_quest": "ronaldo_aterro_basket"},
		},
	},
	"ronaldo_basket_remind": {
		"speaker": "Ronaldo",
		"text": "Le terrain de l'Aterro t'attend. Vise la jauge verte, c'est tout. Taxi puis terrain.",
		"choices": ["J'y vais"],
	},
	"ronaldo_basket_done": {
		"speaker": "Ronaldo",
		"text": "*tape dans tes mains* Le pot tient encore parole, sobrinho. Tu peux y retourner quand tu veux — les gamins recommencent chaque après-midi.",
		"choices": ["Valeu, mestre"],
	},
	# Restaurante — Cantinho Carioca
	"chef_intro": {
		"speaker": "Chef",
		"text": "Bom dia freguês ! Feijoada, moqueca, escondidinho... votre faim ?",
		"choices": ["Moqueca (R$ 15)", "Besoin d'aide ?", "Plus tard"],
		"on_choose": {
			"0": {"pay_bribe": 15, "rep": {0: 2, 3: 1}},
			"1": {"next": "chef_offer"},
		},
	},
	"chef_offer": {
		"speaker": "Chef",
		"text": "Ma Dona Lúcia vend du coco sur le sable. Va lui dire que sa moqueca est prête. 25 reais.",
		"choices": ["J'y vais", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "livraison_cocos"},
		},
	},
	"chef_remind": {
		"speaker": "Chef",
		"text": "Tu as prévenu Lúcia pour la moqueca ?",
		"choices": ["OK"],
	},
	"chef_done": {
		"speaker": "Chef",
		"text": "Obrigado ! La maison te doit un dessert. Passe quand tu veux.",
		"choices": ["De rien"],
	},
	"lucia_to_chef": {
		"speaker": "Dona Lúcia",
		"text": "Ah, la moqueca est prête ? Oba ! Je file. Merci, parceiro.",
		"choices": ["OK"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "livraison_cocos", "objective": "talk_lucia", "payout": 0}},
		},
	},
	# Boutique — Rio Style
	"vendeuse_intro": {
		"speaker": "Beatriz",
		"text": "Oi querido ! Bem-vindo a Rio Style. Besoin d'un t-shirt pour briller sur le calçadão ?",
		"choices": ["T-shirt Copacabana (R$ 25)", "Maillot de bain (R$ 40)", "Juste un coup d'œil"],
		"on_choose": {
			"0": {"pay_bribe": 25, "rep": {3: 2}},
			"1": {"pay_bribe": 40, "rep": {3: 3, 2: 1}},
		},
	},
	# Poste de police — Agente Silva
	"policier_intro": {
		"speaker": "Agente Silva",
		"text": "Bom dia, cidadão. Une petite mission pour vous si vous êtes disponible.",
		"choices": ["Laquelle ?", "Pas maintenant"],
		"on_choose": {
			"0": {"next": "policier_offer"},
		},
	},
	"policier_offer": {
		"speaker": "Agente Silva",
		"text": "Une touriste a signalé un vol sur le calçadão. Ce rapport doit lui parvenir — elle est près du Copacabana Palace. 30 reais pour vos efforts.",
		"choices": ["J'accepte", "Trop de paperasse"],
		"on_choose": {
			"0": {"accept_quest": "police_report"},
		},
	},
	"policier_remind": {
		"speaker": "Agente Silva",
		"text": "Vous avez trouvé Madame Dubois ? Elle est près du Palace, au milieu du calçadão.",
		"choices": ["J'y vais"],
	},
	"policier_done": {
		"speaker": "Agente Silva",
		"text": "Merci pour votre coopération, cidadão. Une bonne journée.",
		"choices": ["Obrigado"],
	},
	"dubois_receives_report": {
		"speaker": "Madame Dubois",
		"text": "Oh, le rapport de police ? Enfin ! Je commençais à désespérer. Merci beaucoup.",
		"choices": ["De rien"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "police_report", "objective": "deliver_report", "payout": 0}},
		},
	},
	# --- Bar do Policial : recrutement serveur ---
	"patrao_intro": {
		"speaker": "Patrão",
		"text": "Eh garoto, t'as l'air vif. Mon serveur s'est barré à Niterói, j'ai besoin d'un coup de main pour les soirs chargés. Ça t'intéresse ? 40 reais le service, et après on causera shifts.",
		"choices": ["J'accepte", "Tu paies combien ?", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bar_waiter"},
			"1": {"next": "patrao_pay_detail"},
		},
	},
	"patrao_pay_detail": {
		"speaker": "Patrão",
		"text": "40 reais le premier service, le temps que je voie si tu casses pas trop de verres. Après c'est 25 reais le shift, plus les pourboires des touristes pompettes. Alors ?",
		"choices": ["OK, j'embauche", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bar_waiter"},
		},
	},
	"patrao_first_shift": {
		"speaker": "Patrão",
		"text": "Tu reviens au bon moment, le bar se remplit. Prêt à enchaîner les commandes ?",
		"choices": ["Allons-y", "Pas tout de suite"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "bar_waiter", "objective": "first_shift", "payout": 0}},
		},
	},
	"patrao_shift_offer": {
		"speaker": "Patrão",
		"text": "Salve, garçom ! On a du monde ce soir. Tu prends un shift ?",
		"choices": ["Shift normal (R$ 25)", "Shift de nuit (R$ 45)", "Pas ce soir"],
		"on_choose": {
			"0": {"earn": 25, "rep": {2: 1}},
			"1": {"earn": 45, "rep": {2: 1, 4: 1}},
		},
	},
	# --- Dona Irene : chien perdu + promenade ---
	"irene_intro": {
		"speaker": "Dona Irene",
		"text": "Oh querido, tu peux m'aider ? Mon petit Bingo a filé sur la plage en chassant un crabe. Il est tout petit, marron, avec une oreille tombante. Il doit avoir peur, le pauvre.",
		"choices": ["Je vais le chercher", "Où ça exactement ?", "Désolé, pas le temps"],
		"on_choose": {
			"0": {"accept_quest": "lost_dog"},
			"1": {"next": "irene_where"},
		},
	},
	"irene_where": {
		"speaker": "Dona Irene",
		"text": "Du côté du Posto 4, je crois. Il aboyait après les mouettes. Ramène-le moi et je te donnerai de quoi t'acheter une bonne moqueca.",
		"choices": ["J'y vais", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "lost_dog"},
		},
	},
	"irene_remind": {
		"speaker": "Dona Irene",
		"text": "Tu as retrouvé Bingo ? J'ai le cœur serré, querido. Cherche bien sur le sable.",
		"choices": ["J'y retourne"],
	},
	"irene_receives_dog": {
		"speaker": "Dona Irene",
		"text": "Bingo ! Ai meu Deus, tu l'as retrouvé ! Viens là mon petit. Merci, querido, vraiment merci. Tiens, prends ça pour ta peine.",
		"choices": ["De rien, Dona Irene"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "lost_dog", "objective": "return_dog", "payout": 0}},
		},
	},
	"irene_walk_offer": {
		"speaker": "Dona Irene",
		"text": "Ah, querido ! Mes jambes ne suivent plus, et Bingo a besoin de courir. Tu veux le promener sur le calçadão ? Je te donne quelques reais.",
		"choices": ["Petit tour (R$ 20)", "Grande promenade (R$ 35)", "Une autre fois"],
		"on_choose": {
			"0": {"earn": 20, "rep": {0: 1}},
			"1": {"earn": 35, "rep": {0: 1, 4: 1}},
		},
	},
	"irene_receives_bread": {
		"speaker": "Dona Irene",
		"text": "Oh ! Le pain de Seu Tonio, encore chaud ! *respire la croûte* Tu es un ange, querido. Tiens, prends un peu de monnaie pour ta course.",
		"choices": ["De rien, Dona Irene"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "padaria_delivery", "objective": "deliver_bread", "payout": 0}},
		},
	},
	# --- Padaria São Sebastião (Seu Tonio) ---
	"padaria_intro": {
		"speaker": "Seu Tonio",
		"text": "Bom dia ! Pão de queijo direct du four, café com leite, et le pastel du jour. Sers-toi.",
		"choices": ["Pão de queijo (R$ 4)", "Café com leite (R$ 6)", "Pastel (R$ 8)", "Une mission ?", "Plus tard"],
		"on_choose": {
			"0": {"pay_bribe": 4, "rep": {0: 1, 2: 1}},
			"1": {"pay_bribe": 6, "rep": {0: 1}},
			"2": {"pay_bribe": 8, "rep": {2: 1, 0: 1}},
			"3": {"next": "padaria_offer"},
		},
	},
	"padaria_offer": {
		"speaker": "Seu Tonio",
		"text": "Justement. Dona Irene me commande son pain chaque matin, mais aujourd'hui ses jambes ne descendent pas. Monte-lui ça avant qu'il refroidisse — calçadão devant le Palace, tu peux pas la rater. 30 reais.",
		"choices": ["Je m'en occupe", "Pas le temps"],
		"on_choose": {
			"0": {"accept_quest": "padaria_delivery"},
		},
	},
	"padaria_remind": {
		"speaker": "Seu Tonio",
		"text": "Le pain refroidit, sobrinho. Dona Irene, devant le Palace.",
		"choices": ["J'y vais"],
	},
	"padaria_baking_offer": {
		"speaker": "Seu Tonio",
		"text": "Tu m'as bien dépanné avec Dona Irene. Tu veux apprendre le métier ? Le four, la plaque, les ingrédients — tout est là. Tu sors une fournée, tu remplis le panier, tu gardes les pourboires.",
		"choices": ["J'enfile le tablier", "Comment ça marche ?", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "padaria_baking"},
			"1": {"next": "padaria_baking_explain"},
		},
	},
	"padaria_baking_explain": {
		"speaker": "Seu Tonio",
		"text": "Bin de farine, robinet d'eau, boîte de queijo — tu prends, tu poses sur la plaque. Trois ingrédients sur la plaque et tu l'enfournes. Tu surveilles, tu sors au bon moment — trop court c'est cru, trop long c'est carbonisé. Puis tu vas au panier de vente. Plus la fournée est belle, plus les clients tipent.",
		"choices": ["Ça me va", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "padaria_baking"},
		},
	},
	"padaria_baking_remind": {
		"speaker": "Seu Tonio",
		"text": "Le fournil est juste là, sobrinho. La pâte attend.",
		"choices": ["J'y vais"],
	},
	# --- Valet du Copa Palace (Otávio) ---
	"otavio_intro": {
		"speaker": "Otávio",
		"text": "Sobrinho ! T'as déjà conduit une Mercedes ? Non, ne réponds pas. On manque de bras au stand valet. Tu prends un service d'essai, je te paye au mérite — chaque tip est à toi. Bem-vindo si tu te lances.",
		"choices": ["Je prends le service", "Comment ça marche ?", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "valet_palace"},
			"1": {"next": "otavio_explain"},
		},
	},
	"otavio_explain": {
		"speaker": "Otávio",
		"text": "Tu vois la borne juste là ? Tu pointes, t'es en service. Une voiture arrive, tu la prends, tu la gares. Le client ressort, il veut sa voiture — tu cours. Plus tu es rapide, plus le tip grimpe. 90 secondes par service, jusqu'à cinq clients. Ça te tente ?",
		"choices": ["Je m'inscris", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "valet_palace"},
		},
	},
	"otavio_remind": {
		"speaker": "Otávio",
		"text": "La borne, sobrinho ! Tu pointes là-bas, et le service démarre. Les Mercedes attendent pas.",
		"choices": ["Compris"],
	},
	"otavio_done": {
		"speaker": "Otávio",
		"text": "Sobrinho ! Le bairro parle de toi. Reviens quand tu veux pour un shift, la borne est ouverte 24/7.",
		"choices": ["Valeu, Otávio"],
	},
	# --- ACTE 2 : Os verdadeiros rostos ---
	"concierge_act2_reveal": {
		"speaker": "Concierge",
		"text": "*il te dévisage longuement, baisse la voix* Sobrinho. Pose ta carte, on va parler. Tu me reconnais maintenant ?",
		"choices": ["Tio… Zé ?!", "Vous me confondez."],
		"on_choose": {
			"0": {"next": "concierge_act2_explain"},
			"1": {"next": "concierge_act2_force"},
		},
	},
	"concierge_act2_force": {
		"speaker": "Concierge",
		"text": "*sourit tristement* Allez, tombe pas dans le panneau, je suis ton oncle. Le Concierge, c'était mon couvert. Le consortium me croit mort, et c'est très bien comme ça.",
		"choices": ["Tu m'as fait porter ta dette ?!"],
		"on_choose": {
			"0": {"next": "concierge_act2_explain"},
		},
	},
	"concierge_act2_explain": {
		"speaker": "tio Zé",
		"text": "Pas porter — partager. Cette dette c'est la mienne, mais Dom Nilton t'aurait égorgé si je m'étais rendu. Tu as gagné du temps, et tu m'as trouvé. Maintenant écoute : trois portes sont ouvertes pour finir le travail. Ramos pour la Polícia, Tito pour le Tráfico, le Padre pour le Prefeito. Choisis bien — Copacabana se souvient longtemps.",
		"choices": ["Tu vas où, toi ?", "Et la dette ?"],
		"on_choose": {
			"0": {"next": "concierge_act2_farewell"},
			"1": {"next": "concierge_act2_debt"},
		},
	},
	"concierge_act2_debt": {
		"speaker": "tio Zé",
		"text": "Tu continues. Verse encore au consortium jusqu'à 25 000 reais et Dom Nilton lâchera la pression. Après ça, on règlera la fin ensemble. Mais d'abord — choisis ton camp.",
		"choices": ["D'accord, tio."],
		"on_choose": {
			"0": {"next": "concierge_act2_farewell"},
		},
	},
	"concierge_act2_farewell": {
		"speaker": "tio Zé",
		"text": "*il glisse derrière le comptoir et disparaît par une porte de service* Je te recontacterai. Joga limpo, sobrinho.",
		"choices": ["Até logo, tio."],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_intro", "objective": "uncover_tio_ze", "payout": 0}, "set_flag": "tio_ze_revealed", "rep": {4: 5, 0: 3}},
		},
	},
}

var _active_npc_id: String = ""
var _active_knot: String = ""
var _loader: InkStoryLoader = null

# Dialogues injectés à la volée (Viewpoint, StreetVendor, StreetEvent...).
# Godot 4 interdit l'index-assignment sur un const Dictionary, donc les knots
# dynamiques passent par ce dico runtime à part.
var _runtime_dialogues: Dictionary = {}

# Enregistre un knot éphémère utilisable par start_dialogue. La donnée a la
# même forme qu'une entrée de PLACEHOLDER_DIALOGUES.
func register_runtime_dialogue(knot_id: String, data: Dictionary) -> void:
	_runtime_dialogues[knot_id] = data

func _has_placeholder(knot_id: String) -> bool:
	return PLACEHOLDER_DIALOGUES.has(knot_id) or _runtime_dialogues.has(knot_id)

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
		line_shown.emit(d.speaker, d.text)
		choices_presented.emit(d.choices)

func choose(choice_index: int) -> void:
	print("[DialogueBridge] choose(%d) called" % choice_index)
	if _loader and _loader.is_ready():
		_loader.choose(choice_index)
		return
	# Placeholder : chaîne les knots si l'action a "next", sinon applique et termine.
	var dlg: Dictionary = PLACEHOLDER_DIALOGUES.get(_active_knot, {})
	var on_choose: Dictionary = dlg.get("on_choose", {})
	var action = on_choose.get(str(choice_index), null)
	if action != null and action.has("next"):
		# Effets latéraux applicables avant de chaîner sur le knot suivant.
		if action.has("accept_quest"):
			QuestManager.accept(action.accept_quest)
		if action.has("set_flag"):
			set_flag(String(action.set_flag))
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		_active_knot = action.next
		NarrativeJournal.mark_read(_active_knot)
		if _has_placeholder(_active_knot):
			var d: Dictionary = _get_placeholder(_active_knot)
			line_shown.emit(d.speaker, d.text)
			choices_presented.emit(d.choices)
		return
	if action != null:
		_apply_placeholder_action(action)
	end_dialogue()

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
	var cart: CornCart = get_tree().get_first_node_in_group("corn_cart") as CornCart
	var inv: Inventory = null
	if GameManager.player:
		inv = GameManager.player.get_node_or_null("Inventory") as Inventory

	if action.has("accept_quest"):
		QuestManager.accept(action.accept_quest)
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
	if action.has("pay_bribe"):
		if inv and inv.spend_money(action.pay_bribe):
			for axis_key in action.get("rep", {}):
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("finish_quest"):
		var info: Dictionary = action.finish_quest
		# Pot-de-vin requis en préalable : si le joueur n'a pas l'argent, on annule.
		if action.has("pay_bribe"):
			if inv == null or not inv.spend_money(int(action.pay_bribe)):
				push_warning("[DialogueBridge] pay_bribe %d failed — quest not completed" % int(action.pay_bribe))
				return
		if inv and info.get("payout", 0) > 0:
			inv.add_money(info.payout)
		QuestManager.complete_objective(info.quest, info.objective)
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("pay_debt"):
		pay_debt(int(action.pay_debt))
		return
	if action.has("earn"):
		# Gain direct, hors quête (jobs répétables : shifts au bar, promenade du chien…).
		if inv:
			inv.add_money(int(action.earn))
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		return
	if action.has("set_endgame"):
		# Finale acte 3 : la voie est scellée, dette purgée, écran de fin déclenché.
		# Paiement et finish_quest restent dispo dans la même action pour cumuler les effets.
		var path: int = _endgame_path_for_string(String(action.set_endgame))
		if action.has("finish_quest"):
			var info: Dictionary = action.finish_quest
			if inv and info.get("payout", 0) > 0:
				inv.add_money(info.payout)
			QuestManager.complete_objective(info.quest, info.objective)
		if action.has("rep"):
			for axis_key in action.rep:
				ReputationSystem.modify(int(axis_key), action.rep[axis_key])
		CampaignManager.complete_endgame(path)
		return
	if action.has("set_flag"):
		set_flag(String(action.set_flag))
		return
	if action.has("rep"):
		for axis_key in action.rep:
			ReputationSystem.modify(int(axis_key), action.rep[axis_key])

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
		_:          return CampaignManager.Endgame.NONE
