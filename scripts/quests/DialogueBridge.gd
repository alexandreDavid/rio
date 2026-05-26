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
	# --- OUVERTURE — joué une fois en début de partie, par-dessus le décor ---
	# (HouseInterior visible en fond, dialogue overlay). MainBoot fire la chaîne
	# via CutsceneRunner sur nouvelle partie tant que `narrative_intro_seen`
	# n'est pas posé. Chaque page chaîne sur la suivante via `next`.
	"game_intro_open": {
		"speaker": "Narrateur",
		"text": "Ce matin, tu te réveilles avec un sentiment étrange.\n\nLe studio du Morro est trop silencieux. Le lit de tio Zé est froid, la porte entrouverte. Dehors, Rio s'éveille déjà — un coq, une radio lointaine, la rumeur de Copacabana en contrebas.\n\nTu ne sais pas encore pourquoi. Mais quelque chose, aujourd'hui, ne tourne pas rond.",
		"choices": ["Continuer"],
		"on_choose": {"0": {"next": "game_intro_disparu"}},
	},
	"game_intro_disparu": {
		"speaker": "Narrateur",
		"text": "Rio de Janeiro. Copacabana. Un matin comme les autres, sauf que Zé — ton oncle, ton parrain, ton problème — a disparu.\n\nIl t'a laissé trois choses : sa carrocinha de milho, les clefs d'un studio au Morro, et une dette de cinquante mille reais.\n\nLe Carnaval est dans un mois. Tu ferais mieux d'avoir réglé la note d'ici là.",
		"choices": ["Continuer"],
		"on_choose": {"0": {"next": "game_intro_voies"}},
	},
	"game_intro_voies": {
		"speaker": "Narrateur",
		"text": "À toi de choisir comment t'en sortir.\n\nDeviens un pilier de la communauté. Entre dans la police. Prends la rue. Ou signe avec le consortium.\n\nSelon les gens que tu aides, les gens que tu trahis, et la tête que tu gardes quand tout dérape, tu finiras Prefeito, Chefe de Polícia, Rei do Tráfico — ou sócio do Consórcio.",
		"choices": ["Continuer"],
		"on_choose": {"0": {"next": "game_intro_controles"}},
	},
	"game_intro_controles": {
		"speaker": "Narrateur",
		"text": "Contrôles :\n\n• Joystick en bas à gauche — se déplacer\n• Bouton E en bas à droite — interagir (parler, prendre, acheter…)\n• Bouton ☰ en haut à droite — voir tes caractéristiques\n\nLes dialogues ont souvent plusieurs choix. Chaque choix modifie tes stats (Respect, Voyou, Police, Touristes, Charisma).\n\nBoa sorte, parceiro.",
		"choices": ["C'est parti"],
	},
	# --- META : Run+ (joueur a déjà bouclé une voie au moins une fois) ---
	"seu_joao_ng_plus_intro": {
		"speaker": "Seu João",
		"text": "*te regarde longuement, comme s'il cherchait à se rappeler* …Sobrinho. T'as les yeux du gamin qui rentre d'un long voyage. *secoue la tête, sourit triste* Bah, ignore-moi. Le matin se ressemble. Ton oncle Zé...",
		"choices": ["…Tio ?"],
	},
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
	# --- PROLOGUE : l'enfant disparu ---
	# La quête n'est plus donnée par Seu João : la mère de Pedrinho aborde le
	# joueur dehors (cutscene MaeAborde). Si le joueur reparle à Seu João avant
	# de l'avoir croisée, il le pousse simplement à descendre.
	"seu_joao_prologue_nudge": {
		"speaker": "Seu João",
		"text": "*te pousse doucement vers la porte* Ne traîne pas ici, sobrinho. La mère du petit Pedrinho t'attend dehors — elle a passé la nuit à hurler dans le morro. Va la voir avant tout le reste. Et personne ne descend à Copa tant que l'enfant n'est pas retrouvé.",
		"choices": ["J'y vais, tio"],
	},
	"seu_joao_prologue_remind": {
		"speaker": "Seu João",
		"text": "*scrute l'escalier vers Copa, inquiet* Le petit Pedrinho, sobrinho. Sa mère ne tient plus. Parle à la vieille qui tricote là-haut, elle voit tout du morro. Et personne ne quitte le morro tant que l'enfant n'est pas là.",
		"choices": ["J'y retourne, tio"],
	},
	# La mère aborde le joueur (cutscene MaeAborde mode "offer"). 2 répliques :
	# la 1re accepte la quête + flag, la 2nde clôt l'objectif ask_mae (elle
	# vient de tout raconter — pas besoin de la recliquer).
	"mae_prologue_offer": {
		"speaker": "Mère de Pedrinho",
		"text": "*surgit d'une ruelle et t'agrippe les deux mains, les yeux rouges, la voix en lambeaux* Sobrinho ! Toi, le neveu de Zé — pitié. Mon Pedrinho, sept ans... il n'est pas rentré cette nuit. La PM dit qu'un gosse du morro qui fugue c'est pas leur affaire. *renifle* Hier un homme est venu — costume clair, propre, des questions sur ce que je dois au consortium. Et ce matin, plus de Pedrinho.",
		"choices": ["Calme-toi. Je le retrouve."],
		"on_choose": {
			"0": {"accept_quest": "prologue_pedrinho", "set_flag": "prologue_started", "next": "mae_prologue_offer_b"},
		},
	},
	"mae_prologue_offer_b": {
		"speaker": "Mère de Pedrinho",
		"text": "*te serre fort, ravale un sanglot* Que Dieu te garde. La vieille qui tricote, là-haut sur le morro — elle voit tout depuis son banc, jour et nuit. Va lui demander, elle l'aura vu passer. Et ne descends pas à Copa sans mon petit, je t'en supplie.",
		"choices": ["Je monte la voir."],
		"on_choose": {
			"0": {"finish_quest": {"quest": "prologue_pedrinho", "objective": "ask_mae", "payout": 0}},
		},
	},
	# La mère rattrape le joueur à la sortie du morro (cutscene MaeAborde
	# mode "plea") — remplace le panneau texte de DistrictExit.
	"mae_prologue_plea": {
		"speaker": "Mère de Pedrinho",
		"text": "*te barre le passage, à bout de souffle, le visage défait* Non — non, tu ne descends pas. Pas toi aussi. Mon fils est quelque part dans ce morro, seul, et toi tu t'en vas vers Copa ? *t'agrippe la manche* Retrouve Pedrinho d'abord. Après, tu descendras la tête haute. Pas avant.",
		"choices": ["Tu as raison. Je le cherche."],
	},
	# --- Soirée 1 : Seu João félicite le 1er acompte (set_flag first_payment_done) ---
	"seu_joao_evening_first_payment": {
		"speaker": "Seu João",
		"text": "*pose sa cachaça, te regarde longuement* Cinq cents reais. Ton oncle Zé, il a mis trente ans à pas pouvoir les rassembler, ces cinq cents. Toi, en une journée. *avale, voix éraillée* Le quartier va parler, sobrinho. Le consortium aussi. Quand ils voient un môme qui paye à temps, ils se demandent d'où vient l'argent. Sois discret. Et fais attention à Ramos — il a senti l'odeur fraîche d'un nouveau visage rentable.",
		"choices": ["Ramos ?", "Et après ?", "Bonne nuit, tio"],
		"on_choose": {
			"0": {"next": "seu_joao_evening_ramos"},
			"1": {"next": "seu_joao_evening_what_next"},
		},
	},
	"seu_joao_evening_ramos": {
		"speaker": "Seu João",
		"text": "Capitão Ramos. Police militaire. Il traîne devant l'Academia le jour, au Bar do Policial le soir. Il aime bien les nouveaux qui montent — il appelle ça \"sa famille bleue\". Si tu lui rends un service, il te laissera respirer. Mais Tito du morro, lui, il aimera moins ça. Choisis tes amis, sobrinho. Pas tes deux côtés.",
		"choices": ["Compris, tio"],
	},
	"seu_joao_evening_what_next": {
		"speaker": "Seu João",
		"text": "Après ? Tu retournes au calçadão demain matin, et tu poses 500 de plus. Et 500 de plus. Et 500 de plus. Cinquante mille avant le Carnaval, sobrinho. *rire amer* Ou tu choisis un parrain. Ramos, Tito, ou le padre de la chapelle. Tous les trois te trouveront avant que tu les trouves.",
		"choices": ["D'accord, tio"],
	},
	# --- Soirée 2 : Seu João après le reveal du Concierge (flag tio_ze_revealed) ---
	"seu_joao_evening_act2_reveal": {
		"speaker": "Seu João",
		"text": "*sa cachaça à mi-chemin de la bouche, suspendue* Tu l'as vu. *long silence* Zé n'est pas mort. Il est concierge au Palace, tu m'as bien entendu. Il a fait croire à sa noyade pour échapper au consortium. Il a laissé sa femme — ta mère — enterrer un cercueil vide. *boit cul sec* Maintenant tu sais. Tu fais ce que tu veux de cette information. Mais ne le dis pas à ta mère. Pas encore.",
		"choices": ["Pourquoi pas ?", "Comment t'as su ?"],
		"on_choose": {
			"0": {"next": "seu_joao_evening_why_silent"},
			"1": {"next": "seu_joao_evening_how_known"},
		},
	},
	"seu_joao_evening_why_silent": {
		"speaker": "Seu João",
		"text": "Parce qu'elle a porté son deuil. Parce que vovó a tricoté un linceul invisible pendant huit ans. Parce que la vérité sans la paix, c'est juste de la cruauté. *te fixe* Quand tu seras Reinado au Sambódromo, alors tu pourras choisir le moment. Pas avant.",
		"choices": ["…D'accord"],
	},
	"seu_joao_evening_how_known": {
		"speaker": "Seu João",
		"text": "*sourire fatigué* Le morro est une seule famille. Le palace embauche dans le morro. Quand mon vieil ami a vu \"un mort\" derrière la réception du Copacabana Palace, le matin même, le morro savait. Et il m'a fait jurer le silence. *hausse les épaules* Je tenais ce serment depuis huit ans. Toi, tu l'as cassé en regardant deux secondes son visage.",
		"choices": ["Pardon, tio"],
	},
	# --- Soirée 3 : Seu João après le choix de voie en acte 3 ---
	"seu_joao_evening_path_chosen": {
		"speaker": "Seu João",
		"text": "*hoche la tête, lentement* Donc c'est fait. T'as choisi ta voie. *boit* Ton oncle aurait choisi pareil. Ou pas. Ce sera ton règne, sobrinho. Pas le sien. *te tend un petit médaillon de bois sculpté* Ton grand-père l'a porté contre le Estado Novo. Zé l'a porté avant sa fausse mort. Maintenant tu le portes. Va au Carnaval la tête haute.",
		"choices": ["Obrigado, tio"],
	},
	# --- Acte 3 : tio Zé recoupe l'intel pour Ramos ---
	# --- Soirée 4 : la veille du Carnaval (acte 5) ---
	"seu_joao_evening_carnaval_eve": {
		"speaker": "Seu João",
		"text": "*ne lève pas les yeux du sol qu'il balaye* Demain c'est la Sapucaí, sobrinho. Trois cent mille personnes vont chanter le nom du Reinado. Si c'est toi… *long silence* …ta mère sera dans la foule, en première ligne. Vovó écoutera la radio en tricotant. Et moi je serai à la fenêtre. *fait une pause* Zé aussi sera là, quelque part. Tu le verras peut-être pas. Mais lui, il te verra.",
		"choices": ["Bonne nuit, tio"],
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
	# --- ACTE 3 : Dom Nilton vient personnellement marquer le pivot ---
	"consortium_act3_intro": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*claque la porte de sa Maverick blanche, traverse l'avenida sans regarder les voitures* Sobrinho. Vingt-cinq mille reais en quelques semaines. Tu m'as surpris — sincèrement. *te plante une carte de visite dans la poche* Maintenant écoute-moi : la moitié restante, tu vas pas la sortir de ton milho. Trois portes s'ouvrent à toi à partir de ce soir. Tu peux te poser dans la maison bleue avec Capitão Ramos. Tu peux porter un sac pour Tito et faire la corrida du Carnaval. Ou tu peux serrer des mains à la chapelle avec le padre et te présenter Prefeito. *recule d'un pas* T'as le Carnaval pour clôturer. Choisis vite.",
		"choices": ["Compris, Dom Nilton"],
	},
	"consortium_settled": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Dette soldée, parceiro. Claudinho, range ta samba funèbre. Tu es un homme libre… pour l'instant.",
		"choices": ["Merci"],
	},
	# --- Visites surprise des créanciers (CreditorVisitManager) ---
	"creditor_visit_soft": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*surgit derrière toi, main sur ton épaule, sourire pas amical* Sobrinho. Je passais dans le quartier. Cent reais, là, tout de suite, ça me ferait plaisir. Une petite goutte sur le tonneau. *attend, la paume ouverte*",
		"choices": ["Poser 100 R$", "Pas maintenant, Dom Nilton"],
		"on_choose": {
			"0": {"pay_debt": 100, "rep": {1: 1}},
			"1": {"rep": {1: -1, 3: -1}},
		},
	},
	"creditor_visit_ultimatum": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*te coupe la route, deux types derrière lui en arrière-plan* Sobrinho, ça fait des semaines. Cinq cents reais sur la table aujourd'hui, ou Claudinho commence à composer ta samba funèbre demain. *jette un coup d'œil aux deux types* Ils dorment mal, eux. Ça les soulagerait, un peu d'action.",
		"choices": ["Poser 500 R$", "Négocier (200 R$, perdre rep)", "Je n'ai pas l'argent"],
		"on_choose": {
			"0": {"pay_debt": 500, "rep": {1: 2}},
			"1": {"pay_debt": 200, "rep": {1: -1, 3: -2}},
			"2": {"rep": {1: -2, 3: -2}, "set_flag": "creditor_ultimatum_refused"},
		},
	},
	# --- Ramos refuse de parler post-commissaire_alerted ---
	"ramos_commissaire_alerted": {
		"speaker": "Capitão Ramos",
		"text": "*ne se retourne pas, continue de regarder l'océan* Sobrinho. *crache un noyau d'olive* Le commissaire du 19e DP m'a appelé hier. Il a ton nom. Il a une liste de trois condomínios sur la Barra. *te regarde enfin, regard glacial* Je peux pas te parler tant que ton dossier monte chez lui. Reviens quand tu auras tranché ta voie pour de bon. D'ici là, je te connais pas.",
		"choices": ["Compris, Capitão"],
	},
	# --- Police shakedown : nouveau scénario CreditorVisitManager post-flag ---
	"creditor_police_shakedown": {
		"speaker": "Tenente Borges (PMERJ)",
		"text": "*tape l'épaule du joueur, sourire faux* Sobrinho. *montre son badge sans le lâcher* Le commissaire Mendonça veut que j'augmente la pression sur les nouveaux entrepreneurs de la Barra. Trois cents reais et je rentre faire mon rapport. Sinon on continue la conversation au 19e DP. Cinco minutos pour décider.",
		"choices": ["Poser 300 R$", "Refuser (le rouer de coups)"],
		"on_choose": {
			"0": {"pay_bribe": 300, "rep": {1: 2}},
			"1": {"raid_pct": 0.15, "rep": {1: -2, 2: 2}},
		},
	},
	"creditor_visit_raid": {
		"speaker": "Cobrador",
		"text": "*deux types t'encadrent, le plus grand a une chaîne en or qu'il fait jouer entre ses doigts* Tu connais le tarif, sobrinho ? On vide les poches, on prend ce qu'il y a, on s'en va. Ou tu sors le couteau et on s'arrange autrement. *l'autre rit sans bruit*",
		"choices": ["Vider mes poches (perdre 50% du cash)", "Tenter de fuir"],
		"on_choose": {
			"0": {"raid_pct": 0.5, "rep": {1: -1}},
			"1": {"raid_pct": 0.7, "rep": {2: 1, 1: -2}},
		},
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
	# --- Side quest Barra Riserva Uno : "protection" du condomínio ---
	"consortium_barra_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*déplie un plan de la Barra* Riserva Uno. Condomínio fermé, six tours, piscines olympiques. Le gérant — Magalhães — il dit toujours non quand on parle « protection ». *te scrute* J'aimerais qu'il dise oui. Tu prends le taxi pour la Barra, tu lui fais comprendre la couleur du ciel. Et tu reviens signer. Huit cents reais et cinq cents de dette en moins.",
		"choices": ["J'y vais", "Pas le moment"],
		"on_choose": {
			"0": {"accept_quest": "consortium_barra_security"},
		},
	},
	"consortium_barra_remind": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Le condomínio Riserva Uno, à la Barra. Sr. Magalhães. *fait un signe vers l'ouest* T'as quelque chose à lui expliquer.",
		"choices": ["J'y vais"],
	},
	"consortium_barra_after_intimidate": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*sourit, allume une cigarette* Tu l'as secoué ? Bom. Retourne le voir maintenant — il sera prêt à signer. Le papier est dans sa main, sobrinho. Reste qu'à fermer.",
		"choices": ["Compris"],
	},
	"consortium_barra_done": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*range le contrat dans une enveloppe en cuir* Premier mois de protection signé. *te tend une liasse* Huit cents reais et cinq cents de dette en moins. Magalhães enverra le suivant tout seul — il a compris le système. Tu es bon dans ce qu'on fait, sobrinho. Trop bon, peut-être.",
		"choices": ["Obrigado, Dom Nilton"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_barra_security", "objective": "close_deal", "payout": 800}, "pay_debt": 500, "rep": {1: 3, 0: -2}},
		},
	},
	# --- Sr. Magalhães au Riserva Uno ---
	"magalhaes_default": {
		"speaker": "Sr. Magalhães",
		"text": "*ajuste sa cravate, regarde sa montre* Vous cherchez quelqu'un, monsieur ? *jette un coup d'œil au garde* Le Riserva Uno ne reçoit pas de visiteurs sans rendez-vous.",
		"choices": ["Pardon, je me suis trompé"],
	},
	"magalhaes_first_visit": {
		"speaker": "Sr. Magalhães",
		"text": "*pâlit en t'apercevant approcher* Vous… vous venez de la part de Dom Nilton, n'est-ce pas ? *se redresse, voix tremblante* Non. NON. Le syndic du condomínio a déjà payé sa sécurité officielle. SP Security, contrat de trois ans. Je ne signerai rien de plus, vous entendez ? Sortez.",
		"choices": ["*sortir le couteau, doucement* Vous allez réfléchir une nuit, Sr. Magalhães. Une nuit.", "*partir sans rien dire*"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_barra_security", "objective": "intimidate_magalhaes", "payout": 0}, "rep": {2: 1, 0: -1}},
		},
	},
	"magalhaes_close_deal": {
		"speaker": "Sr. Magalhães",
		"text": "*signe le contrat sans relever la tête, les mains tremblantes* Quatre mille reais par mois. Premier versement comptant. *te tend une enveloppe épaisse* Vous direz à Dom Nilton que… que je comprends les choses, maintenant. Que je suis un homme raisonnable. *te regarde enfin* Surtout, ne revenez plus jamais en personne. Le syndic poserait des questions.",
		"choices": ["Bien noté, Sr. Magalhães"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_barra_security", "objective": "close_deal", "payout": 0}},
		},
	},
	"magalhaes_after_deal": {
		"speaker": "Sr. Magalhães",
		"text": "*évite ton regard, change de trottoir mentalement* Bonjour, monsieur. *court vers les ascenseurs* Excusez-moi, j'ai une réunion de copropriété.",
		"choices": ["Bonne journée, Sr. Magalhães"],
	},
	# --- Pacto da Barra (MAIN, prereq = consortium_peninsula) ---
	# Magalhães revient — il a vu Carrasco signer, puis Mendonça plier. La peur
	# initiale est devenue calcul. Il propose une rente officielle + un
	# endossement politique tenu en réserve. Pour le joueur : pivot business
	# qui efface un gros morceau de dette sans nouvelle violence. Deux visites :
	# offer (accepte la quête) puis seal (paie + finish + flag).
	"magalhaes_pacto_offer": {
		"speaker": "Sr. Magalhães",
		"text": "*t'attend dans le hall, costume repassé, sourire mesuré* Sobrinho. *te tend la main, geste appris* Carrasco a signé. Mendonça a signé. Les trois plus gros condomínios de la Barra, sous le même drapeau. *baisse la voix* Ce n'est plus une protection — c'est un fief. J'ai parlé au conseil. On veut formaliser : rente officielle, plus… *hésite* une lettre d'endossement politique. À utiliser quand vous en aurez besoin. Cinq mille reais cash, dix mille de votre dette effacée. Vous êtes intéressé ?",
		"choices": ["J'accepte — je reviens demain pour signer", "Pas maintenant"],
		"on_choose": {
			"0": {"accept_quest": "pacto_barra"},
		},
	},
	"magalhaes_pacto_seal": {
		"speaker": "Sr. Magalhães",
		"text": "*sort un dossier en cuir noir, deux exemplaires* Voici. Pacto da Barra — c'est comme ça que le conseil l'a appelé. *pousse un stylo Montblanc vers toi* Vous signez ici, ici, et là. *te regarde* Et vous gardez cette enveloppe en lieu sûr. *te tend une seconde enveloppe scellée* Endossement politique. Le jour où vous voudrez vous présenter — ou faire élire quelqu'un — vous l'ouvrez, et tout Barra suit. *referme le dossier* À partir de ce soir, le consortium n'envoie plus personne. C'est vous, et nous, directement.",
		"choices": ["Pacto scellé"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "pacto_barra", "objective": "seal_pacto", "payout": 5000}, "pay_debt": 10000, "rep": {4: 8}, "set_flag": "barra_pacto_sealed"},
		},
	},
	"magalhaes_after_pacto": {
		"speaker": "Sr. Magalhães",
		"text": "*te salue d'un hochement discret, comme à un égal* Tudo bem, sobrinho. *montre l'enveloppe que tu détiens, sous-entendu* Le jour venu, vous savez où me trouver.",
		"choices": ["Tudo bem, Sr. Magalhães"],
	},
	# --- Niterói : Bruno (ferry) + Helena (MAC) + Yara (étudiante) ---
	"bruno_default": {
		"speaker": "Bruno",
		"text": "*pose son thermos de café, regarde la baie* Cinquante-deux ans de barcas, sobrinho. Je connais chaque vague entre Praça XV et ici. *te scrute* Toi, t'as l'air d'avoir besoin de bouger un truc. Reviens si t'as cinq minutes pour un vieux.",
		"choices": ["Bonne journée, Bruno"],
	},
	"bruno_chat_warm": {
		"speaker": "Bruno",
		"text": "*verse une seconde tasse, te la tend sans demander* Sobrinho. *fait signe vers la baie* Ferry de seize heures, c'est le mien. Si t'as un truc à passer, dis-le maintenant.",
		"choices": ["Pas aujourd'hui, Bruno"],
	},
	"bruno_chat_morning": {
		"speaker": "Bruno",
		"text": "*thermos chaud à la main, regarde le ferry du matin partir* Bom dia. La baie est calme à cette heure, comme une assiette à soupe. Profite avant que le vent du sud arrive.",
		"choices": ["Bom dia, Bruno"],
	},
	"bruno_chat_afternoon": {
		"speaker": "Bruno",
		"text": "*chapeau de paille baissé, écaille un poisson sur le bord du ponton* Boa tarde. Cette heure, c'est la sieste — même les mouettes dorment. *te regarde* Sauf si t'as besoin d'un passage urgent.",
		"choices": ["Pas urgent, Bruno"],
	},
	"bruno_chat_evening": {
		"speaker": "Bruno",
		"text": "*allume sa pipe, regarde Rio s'illuminer de l'autre côté de la baie* Boa noite. À cette heure, Rio brille comme un collier de filles riches. *cligne de l'œil* Je vois ça depuis cinquante-deux ans, c'est jamais lassant.",
		"choices": ["Boa noite, Bruno"],
	},
	"bruno_chat_familiar": {
		"speaker": "Bruno",
		"text": "*te voit, sourit pour la deuxième fois de sa vie* Le sobrinho carioca. *tape la planche à côté de lui* Assieds-toi. *te tend la cachaça déjà décapsulée* Cinquante-deux ans de barcas et personne ne m'a jamais demandé comment je vais. Toi, si.",
		"choices": ["Tu vas comment, Bruno ?"],
	},
	"bruno_offer": {
		"speaker": "Bruno",
		"text": "*pointe un colis en carton près du bollard* Cette caisse, elle attend Helena, la curatrice du MAC, depuis trois jours. *montre ses genoux* Moi je remonte plus la rampe — opération l'an dernier, jamais récupéré. Tu me la portes là-haut ? Cent quatre-vingts reais, et tu fais une heureuse.",
		"choices": ["D'accord, je l'emmène", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bruno_carga"},
		},
	},
	"bruno_remind": {
		"speaker": "Bruno",
		"text": "*lève les yeux, te reconnaît* La caisse pour Helena, sobrinho. *fait un signe vers le MAC* Cinquante mètres et une rampe. Pour moi c'est l'Everest, pour toi c'est deux minutes.",
		"choices": ["J'y vais"],
	},
	"bruno_after_carga": {
		"speaker": "Bruno",
		"text": "*te tend une cachaça artisanale, scellée* Helena m'a appelé. *sourit pour la première fois* Tiens, c'est pour toi. Distillerie de Paraty, ma région. *redevient sérieux* Si t'as encore besoin d'un passage à Rio, je peux t'embarquer gratis. Une fois.",
		"choices": ["Obrigado, Bruno"],
	},
	# --- Bruno : SIDE Pesca da Baía (prereq bruno_carga) ---
	"bruno_pesca_offer": {
		"speaker": "Bruno",
		"text": "*pose sa canne sur la planche, te tend la sienne* Sobrinho. Cette baie, elle a mille robalos par mètre carré, et personne ne les sort plus. *sourit* Sors-en un — un seul — et je te paie de la cachaça. Le ponton là-bas, c'est mon spot depuis trente-quatre ans.",
		"choices": ["J'essaie maintenant", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bruno_pesca_baia"},
		},
	},
	"bruno_pesca_remind": {
		"speaker": "Bruno",
		"text": "*pointe le bout du ponton, l'eau qui clapote* La canne t'attend, sobrinho. Une session, un poisson — t'es bon.",
		"choices": ["J'y vais"],
	},
	"bruno_pesca_done": {
		"speaker": "Bruno",
		"text": "*sort la cachaça promise, la décapsule* Tu l'as sorti. *te tend la bouteille* Trente-quatre ans que je voyais des touristes essayer sans rien attraper. Toi en deux essais. *te scrute* T'es de la famille des pêcheurs, sobrinho. C'est dans le sang ou pas.",
		"choices": ["Obrigado, Bruno"],
	},
	"helena_default": {
		"speaker": "Helena",
		"text": "*pose son catalogue* La pièce du mois ? *fait un signe vers le MAC* « Esquecimento » d'Adriana Varejão. Sang séché sur faïence portugaise. *te regarde* Vous venez d'où ? Du calçadão, d'accord. *léger sourire* Ici on a les mêmes vagues que vous, mais on a aussi le silence. C'est la grosse différence.",
		"choices": ["Bonne visite, Helena"],
	},
	"helena_chat_warm": {
		"speaker": "Helena",
		"text": "*te reconnaît, ferme son catalogue* Rebonjour. *tapote le banc à côté d'elle* Vous revenez pour la sculpture ou pour l'eau ? *léger sourire* La plupart des cariocas viennent pour le café, en fait.",
		"choices": ["Pour les deux, Helena"],
	},
	"helena_chat_familiar": {
		"speaker": "Helena",
		"text": "*pose deux cafés sur le banc avant même que tu t'assoies* Vous êtes le seul Carioca régulier que j'ai. *te tend une tasse* Bruno parle de vous comme d'un sobrinho. Moi aussi maintenant.",
		"choices": ["Obrigado, Helena"],
	},
	"helena_chat_morning": {
		"speaker": "Helena",
		"text": "*ouvre le rideau de fer du MAC, encore une heure avant les visiteurs* Bom dia. *te montre l'intérieur* C'est le seul moment où la sculpture m'appartient. Profitez si vous voulez entrer en avance.",
		"choices": ["Bom dia, Helena"],
	},
	"helena_chat_afternoon": {
		"speaker": "Helena",
		"text": "*compte les billets de l'après-midi dans la caisse* Boa tarde. Quinze visiteurs aujourd'hui, dont trois Cariocas — c'est un record. Niterói existe enfin pour les voisins.",
		"choices": ["Bom record, Helena"],
	},
	"helena_chat_evening": {
		"speaker": "Helena",
		"text": "*tire le rideau, mais te laisse passer* Boa noite. Le MAC ferme officiellement, mais le toit reste ouvert pour les amis. Allez-y une dernière fois.",
		"choices": ["Obrigada, Helena"],
	},
	"yara_chat_morning": {
		"speaker": "Yara",
		"text": "*ouvre son carnet de croquis, lumière dorée du matin* Bom dia. Cette heure, c'est la meilleure pour saisir la courbe — tout est en biais.",
		"choices": ["Bom dia, Yara"],
	},
	"yara_chat_afternoon": {
		"speaker": "Yara",
		"text": "*essuie son fusain avec un chiffon* Boa tarde. Le soleil tape trop fort sur le blanc du MAC, je vois plus rien. Pause-café.",
		"choices": ["Bon repos"],
	},
	"yara_chat_evening": {
		"speaker": "Yara",
		"text": "*allume une lampe au-dessus de son carnet* Boa noite. Je termine au crayon ce que j'ai commencé à l'aquarelle — la lumière artificielle change les couleurs, mais elle sauve les courbes.",
		"choices": ["Boa noite, Yara"],
	},
	"carlos_chat_morning": {
		"speaker": "Carlos",
		"text": "*ouvre le bar, encore en chaussons* Bom dia, sobrinho. Le premier café est sur la maison — j'en bois trois moi-même avant huit heures.",
		"choices": ["Obrigado, Carlos"],
	},
	"carlos_chat_afternoon": {
		"speaker": "Carlos",
		"text": "*sert un caldo glacé à un coureur en sueur* Boa tarde. Les joggers de la Lagoa, c'est mon segment de l'après-midi. Tu veux quelque chose ?",
		"choices": ["Pas pour moi, Carlos"],
	},
	"carlos_chat_evening": {
		"speaker": "Carlos",
		"text": "*allume les guirlandes au-dessus du bar* Boa noite. C'est la meilleure heure ici — la Lagoa reflète les lumières, les couples viennent danser après dîner.",
		"choices": ["Bonne soirée, Carlos"],
	},
	"padaria_chat_morning": {
		"speaker": "Seu Tonio",
		"text": "*sort la première fournée du four, vapeur qui monte* Bom dia ! C'est l'heure du pão fresco, sobrinho. Soixante reais d'ouvriers attendent dehors, mais toi t'as la priorité.",
		"choices": ["Obrigado, seu Tonio"],
	},
	"padaria_chat_afternoon": {
		"speaker": "Seu Tonio",
		"text": "*essuie le comptoir avec une lassitude maîtrisée* Boa tarde. Le rush est passé, c'est l'heure des goûters — coxinha et café gelado, le combo carioca.",
		"choices": ["Tudo bem, seu Tonio"],
	},
	"padaria_chat_evening": {
		"speaker": "Seu Tonio",
		"text": "*éteint le four, garde la lumière de la vitrine allumée* Boa noite. La nuit, je reste pour les habitués. *te montre une chaise* Tu peux t'asseoir si tu veux pas rentrer tout de suite.",
		"choices": ["Boa noite, seu Tonio"],
	},
	"policier_chat_morning": {
		"speaker": "Agente Silva",
		"text": "*café au comptoir, casquette sur la table* Bom dia. La patrouille du matin, c'est la plus tranquille — les voyous dorment encore.",
		"choices": ["Bom dia, agente"],
	},
	"policier_chat_afternoon": {
		"speaker": "Agente Silva",
		"text": "*surveille l'avenue Atlântica, mains dans le dos* Boa tarde. C'est l'heure des pickpockets de plage. Tu vois quelque chose, tu me préviens.",
		"choices": ["Compris, agente"],
	},
	"policier_chat_evening": {
		"speaker": "Agente Silva",
		"text": "*lampe-torche à la ceinture* Boa noite. La nuit, c'est le shift double — agressions, ivresses, taxis qui refusent les courses. Reste prudent toi-même.",
		"choices": ["Obrigado, agente"],
	},
	"helena_receive_carga": {
		"speaker": "Helena",
		"text": "*tu poses la caisse, elle l'ouvre sans hésiter* Ah, enfin. *en sort un châssis enveloppé de papier kraft* La toile de Pape pour l'expo de juin. Bruno m'a appelée hier, paniqué, pensant qu'on l'avait perdue. *signe un reçu en deux exemplaires* Voilà pour vous, et merci. *te tend l'argent* Dites à Bruno que sa caisse était parfaitement emballée — il a toujours eu la main soigneuse.",
		"choices": ["Avec plaisir, Helena"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "bruno_carga", "objective": "deliver_to_helena", "payout": 180}, "rep": {4: 3, 0: 2}},
		},
	},
	"helena_after_carga": {
		"speaker": "Helena",
		"text": "*te reconnaît à travers la vitre, te fait signe* La toile est accrochée. *montre l'étage* Si vous repassez en juin, vous la verrez en place. Et dites bien à Bruno qu'il reste invité au vernissage.",
		"choices": ["Compris"],
	},
	"yara_default": {
		"speaker": "Yara",
		"text": "*ferme son carnet de croquis, te regarde* Trois ans que je viens dessiner ici. *montre la soucoupe* Niemeyer disait que ses bâtiments étaient des sculptures où on entre. *léger sourire* Le truc, c'est que la sculpture est meilleure dehors. Vous allez voir.",
		"choices": ["Bonne séance, Yara"],
	},
	# --- Chaîne consortium 2 : Le Parc Residences ---
	"consortium_le_parc_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*pose une enveloppe sur la table* Riserva Uno a payé. Magalhães a fait passer le mot — c'est tout le bénéfice de la trouille bien placée. *te scrute* Le Parc Residences, à deux cents mètres à l'ouest. Sr. Carrasco, le gérant. Plus combatif, plus ancien, plus connecté. Mais il sait que tu viens, maintenant. Mille reais, sept cents de dette en moins. Tu prends ?",
		"choices": ["J'y vais", "Pas le moment"],
		"on_choose": {
			"0": {"accept_quest": "consortium_le_parc"},
		},
	},
	"consortium_le_parc_remind": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Le Parc Residences, sobrinho. Carrasco. *fait un signe vers la Barra* Il sait que tu arrives. Plus tu attends, plus il prépare une parade.",
		"choices": ["J'y vais"],
	},
	"consortium_le_parc_after_intimidate": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*sourire en coin* Tu l'as déjà secoué ? Bon travail. Retourne signer, sobrinho — il sait maintenant qu'on a un système.",
		"choices": ["Compris"],
	},
	"consortium_le_parc_done": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*compte les billets, glisse une enveloppe vers toi* Mille reais. Sept cents de moins sur la dette. *te regarde longuement* Sobrinho, tu construis quelque chose, là. Deux signatures en deux semaines. La Barra entière va passer à la caisse. *se penche* Mais attention. Plus tu signes, plus tu deviens une cible. Pour la police, pour les rivaux. La trouille marche dans les deux sens.",
		"choices": ["Obrigado, Dom Nilton"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_le_parc", "objective": "close_deal_carrasco", "payout": 1000}, "pay_debt": 700, "rep": {1: 4, 0: -3}},
		},
	},
	# --- Sr. Carrasco au Le Parc ---
	"carrasco_default": {
		"speaker": "Sr. Carrasco",
		"text": "*lève un sourcil, ferme un dossier* Vous êtes résident, monsieur ? Non ? Alors je vous demande de quitter le compound. *fait signe à un agent de sécurité*",
		"choices": ["Je m'en vais"],
	},
	"carrasco_first_visit": {
		"speaker": "Sr. Carrasco",
		"text": "*te reconnaît, ne se lève pas, voix dure* Ah. Magalhães m'a appelé. *referme son dossier d'un coup sec* Je ne suis pas Magalhães, sobrinho. J'ai trente ans de gestion, deux avocats au bureau, un cousin commissaire. Vous savez quoi ? Faites votre numéro, on verra qui tremble en premier.",
		"choices": ["*déposer une photo de sa femme sur le bureau, en silence*", "*partir sans rien dire*"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_le_parc", "objective": "intimidate_carrasco", "payout": 0}, "rep": {2: 2, 0: -2}},
		},
	},
	"carrasco_close_deal": {
		"speaker": "Sr. Carrasco",
		"text": "*signe le contrat sans relever la tête, mâchoire crispée* Six mille reais par mois. *te tend une enveloppe plus épaisse que celle de Magalhães* Et faites en sorte qu'on ne se recroise jamais, vous et moi. Si je revois votre visage à Le Parc, ce sera mon cousin commissaire qui vous accueillera.",
		"choices": ["Bien noté, Sr. Carrasco"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_le_parc", "objective": "close_deal_carrasco", "payout": 0}},
		},
	},
	"carrasco_after_deal": {
		"speaker": "Sr. Carrasco",
		"text": "*sort son téléphone sans relever la tête* Sortez du compound, ou j'appelle.",
		"choices": ["*partir*"],
	},
	# --- Chaîne consortium 3 : Península Privé (cousin commissaire) ---
	"consortium_peninsula_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*pose une bouteille de cachaça, te sert un verre tout petit* Le Parc a payé. Tu deviens une légende, sobrinho. *te regarde longuement* Reste un nom dans le carnet : Sr. Mendonça, Península Privé. Helipad sur le toit. Bodyguards à l'entrée. Et cousin commissaire au 19e DP. *avale son verre* La prochaine signature est la plus chère — quinze cents reais, neuf cents de dette en moins. Mais après ça, la police saura qui tu es. Ramos te lâchera la patte. Tito te recevra peut-être avec moins de méfiance. Ton choix.",
		"choices": ["J'y vais", "Pas le moment"],
		"on_choose": {
			"0": {"accept_quest": "consortium_peninsula"},
		},
	},
	"consortium_peninsula_remind": {
		"speaker": "Dom Nilton (consortium)",
		"text": "Mendonça. Península Privé. *fait un signe vers l'ouest* Cousin commissaire en avance. Vas-y avant qu'il ait posé toutes ses caméras.",
		"choices": ["J'y vais"],
	},
	"consortium_peninsula_after_intimidate": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*sifflement bref* Mendonça secoué. *expression neutre* Il a déjà appelé son cousin, sobrinho. Retourne signer maintenant — sinon la police met en place une opération sur le compound, et tu n'entreras plus jamais.",
		"choices": ["J'y vais tout de suite"],
	},
	"consortium_peninsula_done": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*compte les billets en silence, glisse une grosse enveloppe* Quinze cents reais. Neuf cents de moins sur la dette. *se penche en avant, voix basse* Mendonça a signé, sobrinho. C'est historique. Trois condomínios de la Barra paient maintenant — quarante mille reais par mois récurrents. Tu m'as rendu plus fort que je ne l'étais. *expression change* Mais le commissaire — son cousin — il connaît ton visage maintenant. Évite le calçadão une semaine. Et quand tu reverras Capitão Ramos, il aura une raison de moins de te protéger.",
		"choices": ["Obrigado, Dom Nilton"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_peninsula", "objective": "close_deal_mendonca", "payout": 1500}, "pay_debt": 900, "rep": {1: -5, 0: -4, 2: 3}, "set_flag": "commissaire_alerted"},
		},
	},
	# --- Sr. Mendonça au Península ---
	"mendonca_default": {
		"speaker": "Sr. Mendonça",
		"text": "*pose son verre de scotch, sourire poli, dur* Vous avez perdu votre chemin, monsieur. Le Península est privé. *lève deux doigts — les deux bodyguards convergent* Mes hommes vont vous raccompagner. Sans rancune.",
		"choices": ["Je m'en vais"],
	},
	"mendonca_first_visit": {
		"speaker": "Sr. Mendonça",
		"text": "*ne lève pas les yeux, continue de signer des documents* Carrasco m'a prévenu. Magalhães aussi, indirectement. *signe encore, voix sans émotion* Vous êtes le sobrinho de Zé. Vingt-trois ans, presque pas d'éducation formelle, dette de cinquante mille au consortium. *te regarde enfin* Mon cousin commissaire connaît tout votre dossier. Si vous touchez à un cheveu de mon personnel, vous dormez en prison cette nuit. Donc — qu'est-ce que vous voulez réellement ?",
		"choices": ["*déposer la liste blanchiment sur le bureau, en silence*", "*partir sans rien dire*"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_peninsula", "objective": "intimidate_mendonca", "payout": 0}, "rep": {2: 3, 1: -2}},
		},
	},
	"mendonca_close_deal": {
		"speaker": "Sr. Mendonça",
		"text": "*regarde longuement la liste, repose son verre, soupire* Vous avez beaucoup mieux préparé que je le pensais. *signe le contrat sans relire* Dix mille reais par mois. *te tend une mallette en cuir* Premier semestre payé d'avance — soixante mille. *te regarde droit dans les yeux* Mon cousin sait que j'ai signé. Il ne nous arrêtera ni vous ni moi. Mais il ne nous protégera plus non plus. C'était mon dernier accord avec la police carioca. *te tend la main* Bienvenue dans le système, sobrinho.",
		"choices": ["*serrer la main*"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_peninsula", "objective": "close_deal_mendonca", "payout": 0}},
		},
	},
	"mendonca_after_deal": {
		"speaker": "Sr. Mendonça",
		"text": "*lève son verre dans ta direction* Sobrinho. *boit* Tu fais partie de la machine maintenant. Cigarro ? Whisky ? Évite quand même de revenir trop souvent — les caméras enregistrent tout.",
		"choices": ["Obrigado, Sr. Mendonça"],
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
	"ramos_bench": {
		"speaker": "Capitão Ramos",
		"text": "120 au développé. Et je fais encore un peu de jiu-jitsu. Un vrai capitão, tu vois. Bon, si tu changes d'avis, je suis là.",
		"choices": ["Salut"],
	},
	# --- ACTE 2 : test de loyauté Tito (avant d'ouvrir la voie tráfico finale) ---
	# Tito propose au joueur de défier le consortium en se posant comme protecteur
	# de Dona Vânia, une cliente du consortium en bas du morro. Choix engageant :
	# il faut soit casser avec le consortium publiquement, soit décliner et perdre
	# un peu de crédit dans le morro.
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
	# --- VOIE TRÁFICO : intro acte 2 (échantillon, pas de pacte voie scellé) ---
	"tito_intro_a1_offer": {
		"speaker": "Tito",
		"text": "*te jauge, recrache la fumée* T'as payé tes 500 au consortium. Bom. Tu veux comprendre comment le morro paie ? Porte un paquet pour mon contact du calçadão. Une seule course. Tu fermes ta gueule, tu reviens. Après tu décides — moi, Ramos, le Padre, Magalhães. Mais d'abord tu portes.",
		"choices": ["Je porte ton paquet", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "trafico_a1_livraison", "rep": {2: 1}},
			"1": {"set_flag": "tito_approached"},
		},
	},
	# --- VOIE TRÁFICO : pacte officiel acte 3 (la voie se scelle) ---
	"tito_pacto_trafico_offer": {
		"speaker": "Tito",
		"text": "*te jauge longuement, recrache la fumée* Tu as goûté à tous les camps, sobrinho. Maintenant faut signer. Le morro, c'est une famille — tu portes pour moi, tu fermes ta gueule, et la famille te porte. Comme ton oncle Zé, avant qu'il se dégonfle. *pose une main lourde sur ton épaule* Alors ? T'es du morro, ou t'es un touriste ?",
		"choices": ["Je suis du morro, Tito", "Plus tard — je réfléchis encore"],
		"on_choose": {
			"0": {"accept_quest": ["trafico_a1_livraison", "trafico_a2_pickup"], "set_flag": "voie_trafico", "rep": {2: 4}},
			"1": {"set_flag": "tito_approached"},
		},
	},
	"tito_pacto_trafico_remind": {
		"speaker": "Tito",
		"text": "*sans lever les yeux de ses dominos* Le paquet, sobrinho. Calçadão de Copa, mon contact t'attend près des cocos. Tu le donnes, tu reviens. Le morro regarde.",
		"choices": ["J'y vais, Tito"],
	},
	# Entre A1 livré et A9 (corrida), Tito ne donne plus de missions directes —
	# c'est le contact du calçadão (puis la chaîne de spots) qui prend la main.
	# Ce knot évite qu'il devienne muet et redirige le joueur vers son réseau.
	# --- Acte 4 : option assassinat du consortium (Sicario) ---
	# Voie courte et sanglante : un seul coup, le consortium tombe, la dette
	# s'efface. Mais l'argent du sang ne se lave pas — la rep prend une raclée
	# sur 3 axes (loi, business, communauté).
	"sicario_offer": {
		"speaker": "Sicario",
		"text": "*encapuchonné dans l'ombre du calçadão, voix rauque* Tu portes une dette qui te tuera plus sûrement qu'une balle, garoto. *crache* Y'a une autre voie. Un seul coup. Dom Nilton ne déjeune pas demain, et la maison s'effondre — avec ta dette. 5 000 reais d'acompte, le reste est mon affaire. Tu signes en sang, ou tu continues à courir ?",
		"choices": ["Je signe (5 000 R$)", "Pas mon style"],
		"on_choose": {
			"0": {"accept_quest": "assassinate_consortium", "pay_bribe": 5000, "rep": {2: 2}},
			"1": {"set_flag": "sicario_refused"},
		},
	},
	"sicario_remind": {
		"speaker": "Sicario",
		"text": "*sans lever les yeux* Av. Atlântica, midi. Dom Nilton sirote son café au quiosque. Approche-toi. Le reste se passe tout seul.",
		"choices": ["J'y vais"],
	},
	# Knot de complétion : déclenché par un spot/event à la fin de l'exécution.
	# Pay_debt avec un gros chiffre pour clôturer la dette restante (CampaignManager
	# clamp à debt_remaining donc on peut passer DEBT_TOTAL sans risque).
	"sicario_done": {
		"speaker": "Sicario",
		"text": "*compte les billets sans te regarder* C'est fait. Le consortium n'a plus de tête, le bairro n'a plus de dette. *te rend la moitié de tes 5000* Garde ça. T'en auras besoin pour disparaître quelque temps. Le Carnaval, ça oublie vite — mais la PM, jamais.",
		"choices": ["…"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "assassinate_consortium", "objective": "execute_hit", "payout": 0}, "pay_debt": 50000, "rep": {2: 8, 0: -10, 1: -10, 4: -20}, "set_flag": "consortium_assassinated"},
		},
	},
	"tito_voie_active": {
		"speaker": "Tito",
		"text": "*claque la langue, te jauge* Tu portes bien, sobrinho. Maintenant le morro a son propre rythme — mon contact gère, calçadão de Copa. Va le voir, il sait quoi te confier. Quand viendra la corrida finale du Carnaval, tu reviens me parler. D'ici là, pas de zèle, pas de bavures.",
		"choices": ["Compris, Tito"],
	},
	"tito_trafico_corrida": {
		"speaker": "Tito",
		"text": "*se lève, pose les mains sur tes épaules, grave* Tu as fait tout le chemin, sobrinho. Le consortium est presque payé, la baie est à nous, le morro te respecte. *te regarde droit dans les yeux* Il reste la dernière corrida — celle du Carnaval. Tu la mènes, et le Morro n'a plus de roi : il t'a, toi. Ton oncle Zé a eu cette chance et il a fui. Pas toi. *te tend les clés* Vai, Patrão.",
		"choices": ["Je mène la corrida"],
		"on_choose": {
			"0": {"set_endgame": "TRAFICO", "finish_quest": {"quest": "trafico_a9_corrida", "objective": "execute_run", "payout": 5000}, "rep": {2: 10}},
		},
	},
	# --- VOIE POLÍCIA : intro acte 2 ---
	"ramos_intro_b1_offer": {
		"speaker": "Capitão Ramos",
		"text": "*te jauge par-dessus son café* T'as payé tes 500 au consortium. Un môme du morro ponctuel, c'est rare. *pose sa tasse* Je te demande un seul service avant qu'on parle vraiment : repère un visage utile sur le calçadão et reviens me le rapporter. Pas d'uniforme, pas d'engagement. Après, on verra.",
		"choices": ["Compris, Capitão", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "policia_b1_intel", "rep": {1: 1}},
			"1": {"set_flag": "ramos_approached"},
		},
	},
	# --- VOIE POLÍCIA : pacte officiel acte 3 ---
	"ramos_pacto_policia_offer": {
		"speaker": "Capitão Ramos",
		"text": "*te jauge par-dessus son café, au comptoir du Bar do Policial* Tu as tâté de tous les camps, garoto. Le morro, le consortium, le Padre. Mais c'est moi qui te file le badge. *pose sa tasse* J'ai pas besoin d'un voyou de plus. J'ai besoin d'yeux. Tu bosses pour moi, tu me ramènes ce que je demande, et je te couvre — la dette, le bairro, tout. Alors ?",
		"choices": ["Je suis votre homme, Capitão"],
		"on_choose": {
			"0": {"accept_quest": ["policia_b1_intel", "policia_b2_filature"], "set_flag": "voie_policia", "rep": {1: 5, 2: -2}},
		},
	},
	"ramos_pacto_policia_remind": {
		"speaker": "Capitão Ramos",
		"text": "*tapote la table* Le visage, sobrinho. Calçadão de Copa, mon contact en civil traîne près des cocos. Tu repères, tu rapportes. La loi attend.",
		"choices": ["J'y vais, Capitão"],
	},
	"ramos_policia_madrugada": {
		"speaker": "Capitão Ramos",
		"text": "*boucle son ceinturon, te regarde dans le blanc des yeux* Cette nuit, sobrinho. Le mandat est signé. La PM monte sur le morro à la madrugada et on coupe la tête du réseau. Si tu es là-haut avec moi, le bairro saura à qui il doit sa paix : à toi. Chefe de Polícia honoraire. Ton oncle Zé aurait jamais eu ce cran. *te tend un gilet* On y va.",
		"choices": ["On lance l'Operação Madrugada"],
		"on_choose": {
			"0": {"set_endgame": "POLICIA", "finish_quest": {"quest": "policia_b9_madrugada", "objective": "complete_madrugada", "payout": 5000}, "rep": {1: 10}},
		},
	},
	# --- VOIE CONSORTIUM : intro acte 2 ---
	"magalhaes_intro_c1_offer": {
		"speaker": "Sr. Magalhães",
		"text": "*costume clair, vue mer* Le garçon qui a payé ses 500 à l'heure. *fait tourner un whisky* Une simple démonstration avant qu'on parle vraiment : un commerçant du calçadão a pris du retard. Va le « rappeler poliment ». Pas de menace, juste un sourire et une signature. La maison apprécie l'élégance.",
		"choices": ["J'y vais, Sr. Magalhães", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "consortium_c1_recouvrement", "rep": {4: 1}},
			"1": {"set_flag": "magalhaes_approached"},
		},
	},
	# --- VOIE CONSORTIUM : pacte officiel acte 3 ---
	"magalhaes_pacto_consortium_offer": {
		"speaker": "Sr. Magalhães",
		"text": "*costume clair, vue mer, te fait asseoir dans un fauteuil trop profond* Tu as goûté à toutes les chapelles, sócio. Et tu es revenu chez moi. *fait tourner un whisky* Les autres te proposent un flingue ou une matraque. Moi je te propose un stylo. Le Consórcio ne casse pas les jambes — il fait signer. Tu travailles pour la maison, tu apprends à recouvrer poliment, et ta dette devient une rente. Dans l'autre sens. *te tend le verre*",
		"choices": ["Je signe, Sr. Magalhães"],
		"on_choose": {
			"0": {"accept_quest": ["consortium_c1_recouvrement", "consortium_c2_loyers"], "set_flag": "voie_consortium", "rep": {4: 5, 0: -2}},
		},
	},
	"magalhaes_pacto_consortium_remind": {
		"speaker": "Sr. Magalhães",
		"text": "*sans lever les yeux de ses dossiers* Le recouvrement, mon cher. Calçadão de Copa — un commerçant a pris du retard. Un mot, un sourire, une signature. La maison déteste attendre.",
		"choices": ["Je m'en occupe"],
	},
	"magalhaes_consortium_pacto": {
		"speaker": "Sr. Magalhães",
		"text": "*pose un dossier relié devant toi, dévisse son stylo en or* Tout est là. Trois condomínios alignés, le calçadão sous contrat, la baie blanchie. Le Pacto da Barra : rente mensuelle officielle, endossement politique en réserve, et ta dette… effacée d'un trait. *te tend le stylo* Ton oncle Zé a refusé ce stylo, jadis. Il a préféré fuir et balayer un hall. Toi, tu es plus malin. Signe, et tu es la maison.",
		"choices": ["Je signe le Pacto da Barra"],
		"on_choose": {
			"0": {"set_endgame": "CONSORTIUM", "finish_quest": {"quest": "consortium_c9_pacto", "objective": "seal_pacto", "payout": 5000}, "rep": {4: 10}},
		},
	},
	# Knot uniquement déclenché par Act3FinaleCutscenes (clôture voie Consortium) —
	# pas routé via Magalhaes._pick_knot(). Ne pas s'attendre à le voir en dialogue
	# d'approche standard.
	"magalhaes_consortium_done": {
		"speaker": "Sr. Magalhães",
		"text": "*range le dossier signé dans un coffre, te serre la main longuement* Bienvenue dans la maison, sócio. La casa sempre ganha — et désormais, tu es la casa.",
		"choices": ["…"],
	},
	# --- VOIE PREFEITO : intro acte 2 ---
	"padre_intro_d1_offer": {
		"speaker": "Padre Anselmo",
		"text": "*range les bancs de la chapelle* Le garçon qui a payé sa dette sans voler personne. *pose un cierge* Une seule chose avant qu'on parle vraiment : trois commerçants du calçadão ont oublié de signer la pétition pour l'orfanato. Trois signatures, une parole douce. Va leur parler — ils t'écouteront, toi.",
		"choices": ["J'y vais, mon Père", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "prefeito_d1_peticao", "rep": {0: 1}},
			"1": {"set_flag": "padre_approached"},
		},
	},
	# --- VOIE PREFEITO : pacte officiel acte 3 ---
	"padre_pacto_prefeito_offer": {
		"speaker": "Padre Anselmo",
		"text": "*range les bancs de la chapelle, te regarde avec douceur* Tu as vu les trois autres faces du Rio, mon enfant. *pose un cierge* Les autres te proposeront un flingue, une matraque, un stylo de banquier. Moi, je n'ai rien à te donner — que le bairro. Aide-le, et il te portera. Pas de patron, pas de maison : des voisins. Ton oncle Zé a fui parce qu'il croyait qu'il n'y avait que les trois autres voies. Il avait tort. Tu m'aides à sauver l'orfanato ?",
		"choices": ["Pour le bairro, mon Père"],
		"on_choose": {
			"0": {"accept_quest": ["prefeito_d1_peticao", "prefeito_d2_basquete"], "set_flag": "voie_prefeito", "rep": {0: 6}},
		},
	},
	"padre_pacto_prefeito_remind": {
		"speaker": "Padre Anselmo",
		"text": "*joint les mains* La pétition, mon enfant. Trois commerçants du calçadão hésitent encore. Une signature, c'est un toit pour vingt orphelins. Va leur parler — ils t'écouteront, toi.",
		"choices": ["J'y retourne, mon Père"],
	},
	"padre_prefeito_eleicao": {
		"speaker": "Padre Anselmo",
		"text": "*pose la main sur ton épaule, ému, devant la foule du bairro* Le scrutin est ce soir, mon enfant. Le calçadão, le morro, l'orfanato — tous derrière toi. Pas par peur : par confiance. Si tu l'emportes, tu seras le Coronel do Bairro, et la dette de ton oncle s'effacera au grand jour, par la vérité. Va. Le peuple t'attend aux urnes.",
		"choices": ["On gagne cette élection"],
		"on_choose": {
			"0": {"set_endgame": "PREFEITO", "finish_quest": {"quest": "prefeito_d9_eleicao", "objective": "win_election", "payout": 5000}, "rep": {0: 10}},
		},
	},
	# Knot de base (NPCData.ink_knot) — fallback défensif si le dispatch tombe à
	# travers (jamais en pratique : SeuJoao._pick_knot couvre tous les états).
	# L'ancienne version proposait la quête milho, désormais auto-pilotée par
	# CornCart.gd : on garde une réplique neutre, sans action.
	"seu_joao_intro": {
		"speaker": "Seu João",
		"text": "E aí, sobrinho ! Le morro tient debout, le calçadão tourne. Repasse quand tu veux.",
		"choices": ["Valeu, tio"],
	},
	# Variantes phase de la journée (TimeOfDay) — Seu João, fallback stranger.
	"seu_joao_chat_morning": {
		"speaker": "Seu João",
		"text": "*tisonne les braises du grill* Bom dia, sobrinho. Le matin sur le calçadão, c'est mes meilleures ventes — les touristes joggers achètent un milho pour respirer après leur tour.",
		"choices": ["Bom dia, tio"],
	},
	"seu_joao_chat_afternoon": {
		"speaker": "Seu João",
		"text": "*essuie la sueur de son front avec un torchon* Boa tarde. Le soleil tape dur, hein ? *te tend un verre d'eau* Bois ça si tu marches encore. La chaleur écrase tout.",
		"choices": ["Obrigado, tio"],
	},
	"seu_joao_chat_evening": {
		"speaker": "Seu João",
		"text": "*allume sa petite lampe à pile au-dessus de la charrette* Boa noite, sobrinho. La nuit, les touristes paient plus — ils savent moins compter en cerveja.",
		"choices": ["Boa noite, tio"],
	},
	# Variantes affinité : ces knots remplacent le fallback neutre quand le joueur
	# a parlé plusieurs fois à Seu João (NPCAffinity).
	"seu_joao_chat_warm": {
		"speaker": "Seu João",
		"text": "*te reconnaît, te sourit* Sobrinho ! *fait un signe vers la charrette* Ça avance ?",
		"choices": ["Ça avance, tio"],
	},
	"seu_joao_chat_familiar": {
		"speaker": "Seu João",
		"text": "*ne lève même pas les yeux du grill, te tend déjà un milho beurré* Tiens, gratis pour la maison. *enfin te regarde* T'es comme un fils, parceiro. Sérieux.",
		"choices": ["Obrigado, tio"],
	},
	# --- Variantes affinité (NPCAffinity) pour les NPCs majeurs récurrents ---
	# Acte 1 → 2 : la nuit qui passe à la maison du tio Zé après les 500 R$.
	# Joué par Act1NightCutscene quand le joueur rentre dans la maison en
	# acte 2 sans `act1_closed`. À la fin, set_flag pose `act1_closed` qui
	# déverrouille les pactes de voie et le trigger d'approche de Tito.
	"act1_night_fall": {
		"speaker": "Narrateur",
		"text": "Tu remontes au morro avec les 500 reais en moins et la dette qui pèse toujours. Le soleil se couche derrière le Pão de Açúcar, la maison du tio Zé est silencieuse. Tu fermes la porte. Pour la première fois depuis que Zé a disparu, tu sens combien sa charrette pèse — vraiment.",
		"choices": ["Pousser jusqu'au lit"],
		"on_choose": {"0": {"next": "act1_night_wake"}},
	},
	"act1_night_wake": {
		"speaker": "Narrateur",
		"text": "Matin. Tu as dormi par à-coups. Le morro s'éveille, en bas le calçadão vibre déjà. T'as fait tes preuves face au consortium — au morro les nouvelles montent vite, Tito doit déjà le savoir. Tu te lèves : il est temps de choisir un camp.",
		"choices": ["Sortir"],
		"on_choose": {"0": {"set_flag": "act1_closed"}},
	},
	# Knot de base (data.ink_knot) : 1re rencontre / fallback quand aucune voie
	# ne s'applique. SANS lui, start_dialogue ne montre rien et le jeu se fige
	# (_active_npc_id reste "ramos"). Ne propose rien tant que l'acompte n'est
	# pas payé — Ramos jauge, c'est tout.
	"ramos_intro": {
		"speaker": "Capitão Ramos",
		"text": "*accoudé au comptoir du Bar do Policial, il te détaille sans se lever* Le neveu du vieux Zé. *souffle sur son café* J'entends des choses sur toi, garoto. Reviens me voir quand t'auras réglé tes affaires avec le consortium — un homme qui paie ses dettes, ça, ça se respecte. D'ici là, t'es juste un visage de plus sur le calçadão.",
		"choices": ["À bientôt, Capitão"],
	},
	"ramos_chat_warm": {
		"speaker": "Capitão Ramos",
		"text": "*hoche la tête vers la chaise vide en face* Reposes-toi, sobrinho. Le café est tiède mais il tient debout — comme nous deux.",
		"choices": ["Obrigado, capitão"],
	},
	"ramos_chat_familiar": {
		"speaker": "Capitão Ramos",
		"text": "*pousse une feuille de papier devant toi, signe sa montre* Tu connais l'adresse maintenant, parceiro. Quand t'arrives, je sais déjà ce qu'il faut faire. Vai pra praia, prends ton air.",
		"choices": ["Valeu"],
	},
	"padre_chat_warm": {
		"speaker": "Padre Anselmo",
		"text": "*te bénit d'un signe rapide* Meu filho, le bairro va mieux quand tu passes. Ne reste pas trop loin de la lumière.",
		"choices": ["Amen, padre"],
	},
	"padre_chat_familiar": {
		"speaker": "Padre Anselmo",
		"text": "*sort un café portugais déjà servi, te le tend* La paroisse a deux piliers : la croix et toi. Je l'ai dit hier à la messe, et personne n'a tiqué.",
		"choices": ["Que Dieu te garde"],
	},
	"tito_chat_warm": {
		"speaker": "Tito",
		"text": "*relève les yeux du domino, te fixe* Sobrinho. *fait signe à la chaise* Tu joues une partie ou tu observes ?",
		"choices": ["J'observe, Tito"],
	},
	"tito_chat_familiar": {
		"speaker": "Tito",
		"text": "*pousse une pile de jetons vers toi sans rien dire, comme une évidence* Tu sais quel coup je vais jouer, parceiro. Et moi je sais lequel tu vas jouer après. C'est ça, le Morro.",
		"choices": ["E é isso"],
	},
	"miguel_chat_warm": {
		"speaker": "Miguel",
		"text": "*ferme son cahier, te regarde* Sobrinho. *montre la pente* Tu prends le risque de monter sans qu'on t'appelle. Bom — j'aime ça.",
		"choices": ["E aí, Miguel"],
	},
	"miguel_chat_familiar": {
		"speaker": "Miguel",
		"text": "*te tend un cigare déjà coupé, allumage compris* Patrão. *pause, sourire en coin* Le Morro chante ton nom le soir, sobrinho. Et moi je laisse faire.",
		"choices": ["Valeu, irmão"],
	},
	"carlos_chat_warm": {
		"speaker": "Carlos",
		"text": "*essuie une bouteille, te salue d'un signe* Sobrinho. *fait glisser un caldo de cana sur le comptoir* Maison.",
		"choices": ["Obrigado, Carlos"],
	},
	"carlos_chat_familiar": {
		"speaker": "Carlos",
		"text": "*range ton tabouret habituel, te le pousse* T'as ta place ici, sobrinho. *fait signe à la Lagoa* Le pédalo aussi, si tu veux faire un tour gratis.",
		"choices": ["Valeu, Carlos"],
	},
	"padaria_chat_warm": {
		"speaker": "Seu Tonio",
		"text": "*sort un pão de queijo encore chaud du four, te le tend* Pour toi, sobrinho. Le four ne ment pas — il sait qui rentre.",
		"choices": ["Obrigado, seu Tonio"],
	},
	"padaria_chat_familiar": {
		"speaker": "Seu Tonio",
		"text": "*pose un sac en papier rempli, te le glisse sous le bras* Coxinha, pão, pastel — la maison régale. *te scrute* Tu es un client comme on aimerait en avoir cinquante par jour, parceiro. Et un.",
		"choices": ["Valeu, seu Tonio"],
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
	# Shakedown récurrent — acte 1. Le PM blasé, la rente du calçadão.
	"cop_shakedown_recurring": {
		"speaker": "PM",
		"text": "*soupire, te reconnaît* Ah, c'est encore toi le neveu de Zé. Tu connais la chanson, freguês — la rente du calçadão.",
		"choices": ["Payer R$ 50", "Refuser"],
		"on_choose": {
			"0": {"pay_bribe": 50, "rep": {1: 1}},
			"1": {"rep": {0: 1, 1: -8}},
		},
	},
	# Shakedown récurrent — acte 2. Le PM a entendu parler du joueur, le tarif monte.
	"cop_shakedown_recurring_act2": {
		"speaker": "PM",
		"text": "*claque sa matraque dans sa main, sourit sans humour* Ah, le sobrinho qui paye à Nilton. Tu fais des entrées et des sorties maintenant, eh ? La rente s'ajuste à la prospérité, freguês.",
		"choices": ["Payer R$ 80", "Refuser"],
		"on_choose": {
			"0": {"pay_bribe": 80, "rep": {1: 1}},
			"1": {"rep": {0: 1, 1: -10}},
		},
	},
	# Shakedown récurrent — acte 3+. Le PM sait que le joueur va choisir une voie.
	# La rente devient un investissement de la PM dans un futur "ami".
	"cop_shakedown_recurring_act3": {
		"speaker": "PM",
		"text": "*la voix très basse, presque amicale* Capitão Ramos m'a dit de pas te casser. Mais la rente c'est la rente, sobrinho. Et si tu choisis le bon côté, je redescends à 20.",
		"choices": ["Payer R$ 150", "Refuser"],
		"on_choose": {
			"0": {"pay_bribe": 150, "rep": {1: 2}},
			"1": {"rep": {0: 1, 1: -12}},
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
	# --- ACTE 2 : Operação Carnaval (voie Polícia) ---
	# --- ACTE 2 : Salvem o Orfanato (voie Prefeito) ---
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
	# --- Acte 5 : défilé du Carnaval (couronnement public) ---
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
	# --- ACTE 3 : Le carnet do Capitão (intel intermédiaire, voie Polícia) ---
	# --- ACTE 3 : Operação Madrugada (voie Polícia) ---
	# --- ACTE 3 : Le sac de Botafogo (test pickup, voie Tráfico) ---
	# --- ACTE 3 : Última corrida (voie Tráfico) ---
	# --- ACTE 3 : Trois signatures (endorsements, voie Prefeito) ---
	# Variante Pacto da Barra : Magalhães a déjà glissé une enveloppe au Padre,
	# qui la rétrocède comme « contribution civique ». Routée par Padre.gd
	# quand barra_pacto_sealed est vrai.
	# --- ACTE 3 : Coronel do Bairro (voie Prefeito) ---
	# Variante Pacto da Barra : la Barra alimente la cagnotte. Routée par
	# Padre.gd quand barra_pacto_sealed est vrai.
	# --- ACTE 4 : Audiência do Coronel (voie Prefeito) ---
	# --- ACTE 4 : Purga da Madrugada (voie Polícia) ---
	# --- ACTE 4 : Coleta do Patrão (voie Tráfico) ---
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
	# Variantes phase de la journée — Seu Pedro.
	"pecheur_chat_morning": {
		"speaker": "Seu Pedro",
		"text": "*prépare ses appâts, lampe frontale encore allumée* Bom dia, sobrinho. La marée du matin, c'est la bonne — les robalos sortent juste avant le soleil. Reviens dans une heure si tu veux du frais.",
		"choices": ["Bom dia, Pedro"],
	},
	"pecheur_chat_afternoon": {
		"speaker": "Seu Pedro",
		"text": "*siroterait presque sa cachaça à l'ombre du parasol* Boa tarde. La marée descend, je sors plus la canne avant cinq heures. *sourit* Profite de la plage pendant que t'as la patience.",
		"choices": ["Obrigado, Pedro"],
	},
	"pecheur_chat_evening": {
		"speaker": "Seu Pedro",
		"text": "*allume une seconde lampe à pile, range les hameçons* Boa noite. La nuit sur le calçadão, c'est mon moment — pas de touristes, pas de chiens, juste les vagues. Sit-toi un moment si tu veux.",
		"choices": ["Boa noite, Pedro"],
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
		"text": "Ronaldo devait jouer ce soir. Va lui rappeler qu'on démarre à 20h. Y a un cachet à la clé pour toi.",
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
	# --- Quiz do Maracanã — 3 questions trivia (SIDE, prereq basket) ---
	"ronaldo_quiz_offer": {
		"speaker": "Ronaldo",
		"text": "*assis sur les gradins du Maracanã, te tend une bière* Pause entre deux torcidas. *sourire malicieux* Tu connais ce stade, sobrinho ? Vraiment ? Allez, trois questions. Chaque bonne réponse = du respect du bairro. Une mauvaise = chambrage public.",
		"choices": ["J'accepte le défi", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "quiz_maracana", "next": "ronaldo_quiz_q1"},
		},
	},
	"ronaldo_quiz_remind": {
		"speaker": "Ronaldo",
		"text": "*tape sur le siège à côté* Tu reviens pour le quiz, sobrinho ? Trois questions. T'es prêt ?",
		"choices": ["On y va", "Encore plus tard"],
		"on_choose": {
			"0": {"next": "ronaldo_quiz_q1"},
		},
	},
	"ronaldo_quiz_q1": {
		"speaker": "Ronaldo",
		"text": "Question 1 : En quelle année le Maracanã a-t-il été inauguré ?",
		"choices": ["1942", "1950", "1958", "1968"],
		"on_choose": {
			"0": {"rep": {4: -1}, "next": "ronaldo_quiz_q2"},
			"1": {"rep": {4: 3}, "next": "ronaldo_quiz_q2"},
			"2": {"rep": {4: -1}, "next": "ronaldo_quiz_q2"},
			"3": {"rep": {4: -1}, "next": "ronaldo_quiz_q2"},
		},
	},
	"ronaldo_quiz_q2": {
		"speaker": "Ronaldo",
		"text": "Question 2 : L'attaquant uruguayen qui a marqué le but vainqueur en finale de 1950 ?",
		"choices": ["Ghiggia", "Schiaffino", "Pelé", "Garrincha"],
		"on_choose": {
			"0": {"rep": {4: 3}, "next": "ronaldo_quiz_q3"},
			"1": {"rep": {4: -1}, "next": "ronaldo_quiz_q3"},
			"2": {"rep": {4: -1}, "next": "ronaldo_quiz_q3"},
			"3": {"rep": {4: -1}, "next": "ronaldo_quiz_q3"},
		},
	},
	"ronaldo_quiz_q3": {
		"speaker": "Ronaldo",
		"text": "Question 3 : Combien de Coupes du Monde le Brésil a-t-il gagnées ?",
		"choices": ["3", "5", "7", "9"],
		"on_choose": {
			"0": {"rep": {4: -1}, "next": "ronaldo_quiz_close"},
			"1": {"rep": {4: 3}, "next": "ronaldo_quiz_close"},
			"2": {"rep": {4: -1}, "next": "ronaldo_quiz_close"},
			"3": {"rep": {4: -1}, "next": "ronaldo_quiz_close"},
		},
	},
	"ronaldo_quiz_close": {
		"speaker": "Ronaldo",
		"text": "*ouvre une autre bière, te la tend* Trois questions, c'est tout. *sourit* Le bairro entendra tes scores, sobrinho — bons ou mauvais. Tu reviens quand tu veux pour la torcida.",
		"choices": ["Valeu, mestre"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "quiz_maracana", "objective": "answer_quiz", "payout": 150}, "rep": {0: 1}},
		},
	},
	"ronaldo_quiz_done": {
		"speaker": "Ronaldo",
		"text": "*hoche la tête en signe de complicité* Le quiz est passé, sobrinho. Tu fais partie des connaisseurs maintenant.",
		"choices": ["Valeu"],
	},
	# --- Lucas — duel de surf à Arpoador (ZonaSul) ---
	"lucas_intro": {
		"speaker": "Lucas",
		"text": "*serre sa planche sous le bras, regarde l'horizon* Tu surfes, ou tu poses pour les touristes ? Arpoador, c'est pas pour les frileux. Le poste 7, c'est notre table — on y mange les newbies au petit déjeuner. *te scanne* Tu m'as l'air solide. T'oserais ?",
		"choices": ["Présente-toi"],
		"on_choose": {
			"0": {"next": "lucas_offer"},
		},
	},
	"lucas_offer": {
		"speaker": "Lucas",
		"text": "*sourit, recoiffe ses dreads* Lucas, sobrinho. Arpoador depuis tout petit. Voilà le deal : tu prends ma planche de rechange, tu me prouves que tu sais lire la vague. Une session propre — pas de wipeout sur les trois premiers takeoffs. Si tu réussis, je dis à toute la praia que t'es du sang. 250 reais et le respect du poste 7. La SurfStation est juste là, sur le sable.",
		"choices": ["J'y vais (FAIRE LA SURF SESSION)", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "lucas_arpoador_surf"},
		},
	},
	"lucas_remind": {
		"speaker": "Lucas",
		"text": "*pointe la mer du menton* La SurfStation t'attend. Tiens-toi sur la planche, lis la vague avant qu'elle te lise. Reviens me voir quand t'as bouclé une session.",
		"choices": ["J'y vais"],
	},
	"lucas_done": {
		"speaker": "Lucas",
		"text": "*te tend une noix de coco fraîche* Voilà, sobrinho. Le poste 7 a vu ce que t'as dans les bras. T'es du sang d'Arpoador maintenant. Reviens quand tu veux, la planche est à toi.",
		"choices": ["Obrigado, Lucas"],
	},
	# --- Camila — match volley à Ipanema (ZonaSul) ---
	"camila_intro": {
		"speaker": "Camila",
		"text": "*tape la balle deux fois dans la paume* Eh, sobrinho. Tu joues au volei ou tu regardes ? Pas de filet, sable mou, soleil dans les yeux — Ipanema, c'est notre table à nous.",
		"choices": ["Présente-toi"],
		"on_choose": {
			"0": {"next": "camila_offer"},
		},
	},
	"camila_offer": {
		"speaker": "Camila",
		"text": "*sourit large* Camila, capitaine de l'équipe du poste 9. On joue trois sets, deux gagnants. Pas de pari, juste l'honneur — et 200 reais que mon oncle a mis dans la caisse pour qui nous bat. La VolleyNet est plantée à dix mètres. Tu rentres ?",
		"choices": ["J'y vais (FAIRE LE MATCH)", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "camila_ipanema_volley"},
		},
	},
	"camila_remind": {
		"speaker": "Camila",
		"text": "*attend en regardant la mer* On t'attend sur le sable. Le filet est tendu, mes coéquipières s'échauffent. Reviens quand t'es prêt à enfiler le maillot.",
		"choices": ["J'arrive"],
	},
	"camila_done": {
		"speaker": "Camila",
		"text": "*te claque la main* Bien joué, sobrinho. Tu lis le sable. Si t'as besoin d'une équipe pour un autre tournoi, tu sais où me trouver — poste 9, toujours.",
		"choices": ["Valeu, Camila"],
	},
	# --- Mestre Diego — roda capoeira à Botafogo Praia ---
	"diego_intro": {
		"speaker": "Mestre Diego",
		"text": "*frappe son atabaque, sourire aux dents blanches* Ah, le neveu de Zé. La capoeira, c'est l'âme de la praia, sobrinho. Un petit tip et je te montre ce que mes vingt ans dans la roda valent.",
		"choices": ["Combien ?"],
		"on_choose": {
			"0": {"next": "diego_offer"},
		},
	},
	"diego_offer": {
		"speaker": "Mestre Diego",
		"text": "*tape une fois sur le berimbau* Cent reais. Pas pour moi — pour la roda, pour les jeunes que je forme ici. En échange, tu vois la série meia-lua de compasso → rasteira → armada. Une figure rare, je la garde pour les fins connaisseurs.",
		"choices": ["OK (R$ 100)", "Trop cher"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "diego_botafogo_capoeira", "objective": "tip_diego", "payout": 0}, "pay_bribe": 100, "rep": {0: 3, 4: 2}, "next": "diego_show"},
		},
	},
	"diego_show": {
		"speaker": "Mestre Diego",
		"text": "*lance le berimbau, fait sa série en bord de mer — meia-lua, rasteira, armada — atterrit sans souffle, te salue avec deux mains* Voilà, sobrinho. La capoeira, c'est résister en dansant. Tu retiendras ça.",
		"choices": ["Inoubliable, mestre"],
	},
	"diego_done": {
		"speaker": "Mestre Diego",
		"text": "*te montre son berimbau* La roda continue chaque dimanche, sobrinho. Reviens écouter les chants — celui-là, je le réserve aux amis du sang.",
		"choices": ["Saudações, mestre"],
	},
	# --- Sofia — guide japonaise au bondinho de l'Urca ---
	"sofia_intro": {
		"speaker": "Sofia",
		"text": "*tient un guide froissé, regarde le pylône du bondinho* Sumimasen... vous parlez français ? *consulte son guide* Pão de Açúcar... téléphérique... est-ce sécurisé seule ?",
		"choices": ["Présente-toi"],
		"on_choose": {
			"0": {"next": "sofia_offer"},
		},
	},
	"sofia_offer": {
		"speaker": "Sofia",
		"text": "*soupire de soulagement* Sofia, étudiante en archi de Kyoto, six mois à Rio. Le bondinho, je n'ose pas seule — vertige et la rumeur des touristes pickpockets. Si vous m'accompagnez jusqu'au sommet, je paie nos deux tickets et un pourboire de 180 reais. Coucher de soleil sur le pão, c'est ce que je suis venue voir.",
		"choices": ["D'accord, je vous guide", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "sofia_bondinho_tour"},
		},
	},
	"sofia_remind": {
		"speaker": "Sofia",
		"text": "*regarde le pylône* Le bondinho est juste là — borne orange. Vous êtes prêt ? Le sommet doit être incroyable au coucher.",
		"choices": ["On y va"],
	},
	"sofia_done": {
		"speaker": "Sofia",
		"text": "*te tend l'enveloppe avec les 180 reais, courbette légère* Domo arigato, sobrinho-san. Le pão de açúcar au coucher du soleil, c'est encore plus beau qu'à Hokusai. Si vous passez par Kyoto, demandez après moi à l'académie d'architecture.",
		"choices": ["Boa viagem, Sofia"],
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
	"dubois_default": {
		"speaker": "Madame Dubois",
		"text": "*ajuste son sac à main, regarde l'horizon* Quel vol odieux, monsieur. Le commissariat m'a promis un rapport — j'attends. *te scrute* Vous savez quelque chose ?",
		"choices": ["Pas encore, madame"],
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
	# --- Side quest : zona_sul_envelope — Sra. Caldeira (cobertura Leblon) ---
	"caldeira_offer": {
		"speaker": "Sra. Caldeira",
		"text": "*pose son thé glacé, te scrute* Tu sembles avoir des jambes solides. J'ai une enveloppe à porter à mon avocat, Dr. Bandeira, à Ipanema. Discret. Tu reviens, je paie. Deux cents reais. *léger sourire* Mon défunt mari n'utilisait que des messagers — les téléphones laissent des traces.",
		"choices": ["J'accepte", "Une autre fois"],
		"on_choose": {
			"0": {"accept_quest": "zona_sul_envelope"},
		},
	},
	"caldeira_remind_deliver": {
		"speaker": "Sra. Caldeira",
		"text": "*reverse du thé glacé* L'enveloppe est dans ta poche, sobrinho. Bandeira, Ipanema, deuxième immeuble en partant du calçadão. Ne la rouvre pas.",
		"choices": ["J'y vais"],
	},
	"caldeira_remind_verify": {
		"speaker": "Sra. Caldeira",
		"text": "*regard fixe, calme* Bandeira a lu ? Bien. Maintenant Iván — au bar d'Arpoador. Dis-lui : « la veuve demande si la mer est haute ». Il comprendra.",
		"choices": ["Compris"],
	},
	"caldeira_return": {
		"speaker": "Sra. Caldeira",
		"text": "*ne se retourne pas de la baie vitrée* Iván a confirmé le nom ? *sourit, encore face à l'océan* Bom. Mon défunt mari disait : les concierges savent plus que les juges. *pose deux cents reais sur la table basse* Tu n'as rien vu, rien entendu.",
		"choices": ["Tudo bem, senhora"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "zona_sul_envelope", "objective": "return_to_caldeira", "payout": 200}, "rep": {0: 3}},
		},
	},
	"caldeira_after_done": {
		"speaker": "Sra. Caldeira",
		"text": "*sirote un thé glacé* La discrétion paye, sobrinho. Si j'ai d'autres petites courses, je saurai où te trouver.",
		"choices": ["Obrigada, senhora"],
	},
	# --- Side quest : zona_sul_envelope — Dr. Bandeira (cabinet Ipanema) ---
	"bandeira_receive": {
		"speaker": "Dr. Bandeira",
		"text": "*écarte le dossier, te regarde par-dessus ses lunettes* Sra. Caldeira ? *tend la main, paume vers le haut* Donne. *ouvre l'enveloppe d'un coupe-papier, lit en silence, mâchoire serrée* Hmpf. Le concierge du Palace. Encore lui. *replie la lettre* Tu vas voir Iván au bar d'Arpoador. Mot de passe : « la veuve demande si la mer est haute ». Il confirmera le nom.",
		"choices": ["D'accord, doutor"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "zona_sul_envelope", "objective": "deliver_to_bandeira", "payout": 0}},
		},
	},
	"bandeira_after_received": {
		"speaker": "Dr. Bandeira",
		"text": "*range l'enveloppe dans un tiroir, ferme à clé* Iván d'Arpoador. Mot de passe — « la veuve demande si la mer est haute ». Il te donnera un nom. Tu retournes voir Caldeira. C'est tout.",
		"choices": ["Très bien"],
	},
	"bandeira_after_done": {
		"speaker": "Dr. Bandeira",
		"text": "*soulève à peine les yeux du dossier* La veuve a payé ? Bien. *signe une feuille* Si elle te recontacte, écoute-la. Elle paie comptant.",
		"choices": ["Compris, doutor"],
	},
	"bandeira_default": {
		"speaker": "Dr. Bandeira",
		"text": "*ferme un dossier d'un coup sec* Beaucoup de propriétaires veulent vendre vite ces temps-ci. Sans m'appeler. *te scrute* Si quelqu'un de la famille reçoit une offre — Bandeira, deuxième étage, n'oublie pas.",
		"choices": ["Note"],
	},
	# --- Side quest : zona_sul_envelope — Iván (Bar do Pôr-do-Sol, Arpoador) ---
	"ivan_verify": {
		"speaker": "Iván",
		"text": "*essuie un verre, sourire neutre* Caipirinha ?\n— *tu murmures* La veuve demande si la mer est haute.\n*Iván ne sourit plus. Il pose le verre, se penche très près.* Tu diras à Caldeira : le concierge du Palace est de l'autre côté. Il a déjà encaissé. *se redresse, voix forte de nouveau* Cerveja gelada, gentil ? À la maison cette fois.",
		"choices": ["Obrigado, Iván"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "zona_sul_envelope", "objective": "verify_with_ivan", "payout": 0}},
		},
	},
	"ivan_after_verified": {
		"speaker": "Iván",
		"text": "*range un verre, voix basse* Caldeira t'attend. Va lui dire ce que tu sais. Et ne reviens pas si tu vois quelqu'un te suivre.",
		"choices": ["Compris"],
	},
	"ivan_after_done": {
		"speaker": "Iván",
		"text": "*verse une cachaça* La veuve t'a payé ? Bom. *pose le verre sur le comptoir* Reviens quand tu veux, sobrinho. Ici on entend tout, on raconte rien.",
		"choices": ["Saúde"],
	},
	"ivan_default": {
		"speaker": "Iván",
		"text": "*essuie un verre, sourire fatigué* Chez moi le pôr-do-sol commence à dix-sept heures et finit à minuit. Caipirinha ? Cerveja gelada ? *pose le verre* On parle, on écoute. Tout passe par ce bar.",
		"choices": ["Une cerveja"],
	},
	# --- Conquistas — paragraphes rétrospectifs, marqués read au déblocage ---
	"conquista_first_quest": {"speaker": "Crônica", "text": "Le jour où j'ai accepté ma première mission. Le calçadão était bondé, l'air sentait le milho grillé. Je ne savais pas que c'était le début de quelque chose de plus grand.", "choices": ["Fermer"]},
	"conquista_first_payment": {"speaker": "Crônica", "text": "Premier acompte. Cinq cents reais comptés deux fois avant de les donner. Le consortium a noté la première ligne dans son carnet noir — et moi aussi.", "choices": ["Fermer"]},
	"conquista_debt_cleared": {"speaker": "Crônica", "text": "Cinquante mille remboursés. Dom Nilton n'a pas souri. Mais le carnet noir s'est fermé devant moi — c'est tout ce qui comptait.", "choices": ["Fermer"]},
	"conquista_act_2": {"speaker": "Crônica", "text": "L'acte 2 a commencé un soir comme les autres. Tio Zé m'attendait sur le porche. Il avait quelque chose à me dire — quelque chose qu'il portait depuis huit ans.", "choices": ["Fermer"]},
	"conquista_act_3": {"speaker": "Crônica", "text": "Trois portes ouvertes. Polícia, tráfico, prefeito. Chacune fermait les deux autres. J'ai choisi celle qui faisait le moins de bruit dans ma tête.", "choices": ["Fermer"]},
	"conquista_act_4": {"speaker": "Crônica", "text": "Le règne. Le bairro chantait mon nom à la messe, à la favela, ou au commissariat — selon. J'avais traversé. Le Sambódromo m'attendait.", "choices": ["Fermer"]},
	"conquista_endgame_prefeito": {"speaker": "Crônica", "text": "Coronel do Bairro. Le titre n'existe pas officiellement. Mais quand je passe sur le calçadão, les commerçants se redressent.", "choices": ["Fermer"]},
	"conquista_endgame_policia": {"speaker": "Crônica", "text": "Chefe de Polícia. Ramos m'a tendu sa casquette le dernier matin de l'Operação Madrugada. « Tu en as fait plus que moi en trente ans. »", "choices": ["Fermer"]},
	"conquista_endgame_trafico": {"speaker": "Crônica", "text": "Patrão do Morro. Miguel m'a appelé « irmão » devant tous les jeunes de la favela. Il n'avait jamais fait ça pour personne.", "choices": ["Fermer"]},
	"conquista_pacto_barra": {"speaker": "Crônica", "text": "Magalhães m'a remis l'enveloppe scellée du Riserva Uno. Je ne l'ai pas ouverte. Mais je sais qu'elle est dans la poche intérieure de ma veste — et lui aussi.", "choices": ["Fermer"]},
	"conquista_commissaire_alerted": {"speaker": "Crônica", "text": "Mendonça avait un cousin commissaire. Je ne le savais pas avant d'entrer au Península Privé. Maintenant la PM connaît mon nom — pas encore mon visage.", "choices": ["Fermer"]},
	"conquista_first_familiar": {"speaker": "Crônica", "text": "Quelqu'un m'a appelé sobrinho sans hésiter, comme si on se connaissait depuis des années. C'était presque le cas.", "choices": ["Fermer"]},
	"conquista_three_familiar": {"speaker": "Crônica", "text": "Trois personnes du bairro me considèrent comme de la famille. C'est plus que je n'avais à mon arrivée. C'est plus que la plupart en accumulent.", "choices": ["Fermer"]},
	"conquista_first_photo": {"speaker": "Crônica", "text": "J'ai pris ma première photo. Une vague, un détail du calçadão, le mont du Pão de Açúcar en arrière-plan. On garde ce qu'on voit pour ne pas oublier qu'on l'a vu.", "choices": ["Fermer"]},
	"conquista_pesca_baia": {"speaker": "Crônica", "text": "Bruno m'a tendu sa canne sans rien dire. J'ai sorti un robalo de la baie de Guanabara au troisième essai. Trente-quatre ans qu'il en parlait — et c'est moi qui l'ai sorti.", "choices": ["Fermer"]},
	"conquista_wealthy_10k": {"speaker": "Crônica", "text": "Dix mille reais versés. La cinquième ligne du carnet noir de Dom Nilton. Il a marqué un trait épais dessous — première étape.", "choices": ["Fermer"]},
	"conquista_carnaval_complete": {"speaker": "Crônica", "text": "Le défilé du Sambódromo. J'ai mené ma faction sous les projecteurs jusqu'à l'aube. La Sapucaí chante encore mon nom — ou un nom approchant.", "choices": ["Fermer"]},
	"conquista_chatterbox": {"speaker": "Crônica", "text": "Dix personnes du bairro me reconnaissent et m'ont parlé au moins une fois. À Copacabana, c'est presque une famille élargie.", "choices": ["Fermer"]},
	"conquista_globetrotter": {"speaker": "Crônica", "text": "Cinq quartiers visités. Du Morro à la Barra, du Corcovado à Niterói. Chaque rue m'a appris quelque chose — surtout celles que je n'aurais pas dû prendre.", "choices": ["Fermer"]},
	"conquista_respeitado": {"speaker": "Crônica", "text": "Une réputation qui m'a pris des mois à bâtir. Les gens qui me croisent baissent ou hochent la tête — selon ce qu'on dit de moi.", "choices": ["Fermer"]},
	"conquista_beach_athlete": {"speaker": "Crônica", "text": "J'ai sué sur le sable et dans l'eau. Volley, surf, paddle, basquete — la praia te juge par la sueur, pas par les mots.", "choices": ["Fermer"]},
	"conquista_niteroi_resident": {"speaker": "Crônica", "text": "Bruno m'a embarqué sur deux missions et m'a tendu une cachaça à la fin. Niterói n'est plus l'autre côté — c'est aussi mon côté.", "choices": ["Fermer"]},
	"conquista_shutterbug": {"speaker": "Crônica", "text": "Cinq photos prises. Chaque cadre est un souvenir verrouillé, indépendant de ce qu'on raconte autour de moi.", "choices": ["Fermer"]},
	"conquista_viewpoint_collector": {"speaker": "Crônica", "text": "Trois mirantes admirés. Rio se voit toujours mieux d'en haut — Niemeyer, Christ, Pão. Trois points de vue, trois villes différentes.", "choices": ["Fermer"]},
	"conquista_escape_artist": {"speaker": "Crônica", "text": "Acte 3 atteint sans avoir alerté de commissaire. Mendonça est resté chez lui — ou bien j'ai évité son couloir. Quoi qu'il en soit, la PM ne connaît pas mon visage.", "choices": ["Fermer"]},
	# --- Chaîne Mafia da Baía (Niterói) — Don Vincenzo / Olga / Roberto ---
	"vincenzo_default": {
		"speaker": "Don Vincenzo",
		"text": "*tourne sa cuillère dans son café, lentement, sans te regarder* Je n'ai rien à t'offrir, jeune homme. Pas encore. Repasse quand le café sera moins chaud.",
		"choices": ["Bonne journée"],
	},
	"vincenzo_smuggle_offer": {
		"speaker": "Don Vincenzo",
		"text": "*pose la tasse, te regarde enfin, sourire mesuré* Sobrinho. *fait signe à Olga, deux tables plus loin* Olga a un petit paquet pour toi. Tu le récupères, tu reviens me le poser sur la table. Discret. *baisse la voix* Quatre cents reais. Une seule visite, pas de question. Si tu fais bien, on cause de la suite.",
		"choices": ["J'accepte", "Pas maintenant"],
		"on_choose": {
			"0": {"accept_quest": "baia_smuggle_intro"},
		},
	},
	"vincenzo_smuggle_remind": {
		"speaker": "Don Vincenzo",
		"text": "*regarde sa tasse vide* Olga t'attend, sobrinho. Le paquet, puis ici. Pas de détour.",
		"choices": ["J'y vais"],
	},
	"vincenzo_smuggle_deliver": {
		"speaker": "Don Vincenzo",
		"text": "*tend la main, paume ouverte, sans regarder* Donne. *prend le paquet, l'enfonce dans sa veste, hoche la tête* Bien. *te tend une enveloppe* Quatre cents. Tu reviens demain — j'ai un autre service.",
		"choices": ["Obrigado, Don Vincenzo"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "baia_smuggle_intro", "objective": "deliver_packet", "payout": 400}, "rep": {2: 4, 1: -2}},
		},
	},
	"vincenzo_smuggle_done": {
		"speaker": "Don Vincenzo",
		"text": "*sourit à peine* Sobrinho. *fait signe* Café ? *te scrute* Tu travailles bien. Mais on a un petit problème — viens m'en parler quand t'es prêt.",
		"choices": ["Bien noté"],
	},
	"vincenzo_silence_offer": {
		"speaker": "Don Vincenzo",
		"text": "*pose un dossier sur la table — coupures de journal, photos, notes manuscrites* Un journaliste indépendant. Roberto Maia. Il furète autour du ferry depuis trois semaines. *te scrute* Je veux qu'il ferme son carnet. Tu fais comment tu veux — paie, intimide, négocie, tant que ça s'éteint. Six cents reais à la livraison.",
		"choices": ["Je m'en occupe", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "baia_silence_press"},
		},
	},
	"vincenzo_silence_remind": {
		"speaker": "Don Vincenzo",
		"text": "*tape l'index sur le dossier resté ouvert* Roberto. Plaza de Niterói. Plus tu traînes, plus il écrit.",
		"choices": ["J'y vais"],
	},
	"vincenzo_silence_done": {
		"speaker": "Don Vincenzo",
		"text": "*ferme le dossier, le glisse sous la table* J'ai eu un appel ce matin. *hoche la tête, satisfait* Tu as fait propre. *te tend une enveloppe plus épaisse* Six cents reais. *te scrute, sérieux* Maintenant on parle vraiment.",
		"choices": ["Je t'écoute"],
	},
	"vincenzo_pacto_offer": {
		"speaker": "Don Vincenzo",
		"text": "*deux tasses de café, deux verres d'eau, un cigare entre vous* Pacto da Baía, sobrinho. Tu deviens partenaire. Ferry gratuit pour toi à vie. Trois mille reais effacés de ta dette consortium. Deux mille reais cash. Et — *baisse la voix* — un siège à cette table, chaque fois que t'es à Niterói. Tu acceptes ?",
		"choices": ["J'accepte — pacto scellé", "Je refuse — je ne suis pas des vôtres"],
		"on_choose": {
			"0": {"accept_quest": "baia_pacto", "next": "vincenzo_pacto_seal"},
			"1": {"set_flag": "baia_refused", "rep": {2: -3, 0: 4}, "next": "vincenzo_pacto_refused"},
		},
	},
	"vincenzo_pacto_seal": {
		"speaker": "Don Vincenzo",
		"text": "*signe un papier, te le pousse* Sang à sang, parole à parole. *te tend l'enveloppe la plus épaisse de la soirée* Bienvenue dans la baie, sobrinho. Le ferry de Bruno te reconnaîtra. Olga te respectera. Et si un jour Roberto retrouve sa plume — tu sais qui appeler.",
		"choices": ["Bienvenue dans la baie"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "baia_pacto", "objective": "seal_pacto_baia", "payout": 2000}, "pay_debt": 3000, "rep": {2: 6, 1: -3, 4: 4}, "set_flag": "baia_pacto_sealed"},
		},
	},
	"vincenzo_pacto_refused": {
		"speaker": "Don Vincenzo",
		"text": "*se lève, sans serrer la main, voix neutre* Bonne soirée, sobrinho. *te tourne le dos* Olga, accompagne-le à la porte. La table est fermée.",
		"choices": ["Bonne soirée"],
	},
	"vincenzo_after_pacto": {
		"speaker": "Don Vincenzo",
		"text": "*lève sa tasse vers toi en signe de fraternité* Sobrinho. *montre la chaise* Assieds-toi un moment. La baie est calme aujourd'hui.",
		"choices": ["Saúde, Don"],
	},
	# Olga — la main droite
	"olga_default": {
		"speaker": "Olga Mendez",
		"text": "*souffle la fumée de sa cigarette sans te regarder* Je sers les amis du Don. Pour le reste, tu causes à Vincenzo.",
		"choices": ["Compris"],
	},
	"olga_handover_packet": {
		"speaker": "Olga Mendez",
		"text": "*sort un paquet de papier kraft de son sac, le pousse vers toi en glissant sur la table* Le voilà. *te scrute, voix sèche* Tu le poses sur la table de Vincenzo. Tu ne l'ouvres pas. Tu ne le regardes pas. *écrase son mégot* Compris ?",
		"choices": ["Compris"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "baia_smuggle_intro", "objective": "pickup_packet", "payout": 0}, "rep": {2: 1}},
		},
	},
	"olga_after_pacto": {
		"speaker": "Olga Mendez",
		"text": "*hoche à peine la tête, sans hostilité cette fois* Sobrinho. *montre la chaise à côté de Vincenzo* C'est ta place.",
		"choices": ["Saúde"],
	},
	"olga_hostile": {
		"speaker": "Olga Mendez",
		"text": "*ne lève pas la tête, voix glaciale* Tu fais erreur en restant à Niterói, jeune homme. La baie a une mémoire longue.",
		"choices": ["..."],
	},
	# Roberto — le journaliste
	"roberto_default": {
		"speaker": "Roberto Maia",
		"text": "*pose son carnet, te scrute par-dessus ses lunettes* Vous habitez le bairro ? Je fais une enquête sur les passages clandestins via le ferry. Si vous savez quelque chose, écrivez-moi.",
		"choices": ["Je ne sais rien"],
	},
	"roberto_confront": {
		"speaker": "Roberto Maia",
		"text": "*referme son carnet, méfiant* On me prévient que Vincenzo vous envoie. *te scrute* Vous voulez quoi exactement ? Je vous écoute — mais soyez clair.",
		"choices": [
			"*payer 300 R$ pour qu'il ferme l'enquête*",
			"*intimider* « Tu arrêtes ou ça finit mal. »",
			"*le convaincre* « Vincenzo te livrera un plus gros poisson si tu changes de cible. »",
		],
		"on_choose": {
			"0": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 300}, "pay_bribe": 300, "rep": {2: 2, 0: -2}, "set_flag": "roberto_silenced"},
			"1": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 0}, "rep": {2: 5, 0: -4, 1: -2}, "set_flag": "roberto_silenced"},
			"2": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 0}, "rep": {2: 1, 4: 4, 0: 1}, "set_flag": "roberto_silenced"},
		},
	},
	"roberto_silenced": {
		"speaker": "Roberto Maia",
		"text": "*ne te regarde plus, ferme son carnet quand tu passes* Je n'ai rien à ajouter.",
		"choices": ["..."],
	},
}

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
	# Placeholder : chaîne les knots si l'action a "next", sinon applique et
	# termine. _get_placeholder couvre AUSSI les dialogues runtime (spots
	# ReactiveDialogueSpot) — sinon leurs actions finish_quest/accept_quest
	# ne s'appliquent jamais en jeu (prologue + voies en dépendent).
	var dlg: Dictionary = _get_placeholder(_active_knot)
	var on_choose: Dictionary = dlg.get("on_choose", {})
	var action = on_choose.get(str(choice_index), null)
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
func _try_accept_any(payload) -> bool:
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
	var missing: Array[String] = QuestManager.missing_prerequisites(quest_id)
	var hint: String = ""
	if not missing.is_empty():
		var pretty: Array[String] = []
		for pid in missing:
			var pq: Quest = QuestManager.get_quest(pid)
			pretty.append(pq.display_name if pq != null and pq.display_name != "" else pid)
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
