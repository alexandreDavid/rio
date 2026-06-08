class_name Act1Dialogues
extends RefCounted

# Knots acte 1 (héritage, prologue, soirées tio Zé) + chatter Ramos/créanciers.
#
# Même forme que PLACEHOLDER_DIALOGUES : key = ink_knot, value =
# {speaker, text, choices, on_choose?}. Le routage est par acte mais la
# résolution runtime se fait par clé globale — l'acte n'a pas d'incidence
# fonctionnelle.

const KNOTS: Dictionary = {
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
}
