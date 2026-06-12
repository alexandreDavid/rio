class_name Act2Dialogues
extends RefCounted

# Knots acte 2 (échantillon des 4 voies, chaîne consortium, missions intro).
#
# Même forme que PLACEHOLDER_DIALOGUES : key = ink_knot, value =
# {speaker, text, choices, on_choose?}. Le routage est par acte mais la
# résolution runtime se fait par clé globale — l'acte n'a pas d'incidence
# fonctionnelle.

const KNOTS: Dictionary = {
	# --- Side quest Barra Riserva Uno : "protection" du condomínio ---
	"consortium_barra_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*déplie un plan de la Barra* Riserva Uno. Condomínio fermé, six tours, piscines olympiques. Le gérant — Magalhães — il dit toujours non quand on parle « protection ». *te scrute* J'aimerais qu'il dise oui. Tu prends le taxi pour la Barra, tu lui fais comprendre la couleur du ciel. Et tu reviens signer. Huit cents reais et cinq cents de dette en moins. Beleza ?",
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
		"text": "*range le contrat dans une enveloppe en cuir* Demorô. Premier mois de protection signé. *te tend une liasse* Huit cents reais et cinq cents de dette en moins. Magalhães enverra le suivant tout seul — il a compris le système. Tu es bon dans ce qu'on fait, sobrinho. Trop bon, peut-être.",
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
		"text": "*pointe un colis en carton près du bollard* Cette caisse, elle attend Helena, la curatrice du MAC, depuis trois jours. *montre ses genoux* Pô, moi je remonte plus la rampe — opération l'an dernier, jamais récupéré. Tu me la portes là-haut ? Cent quatre-vingts reais, et tu fais une heureuse.",
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
		"text": "*te tend une cachaça artisanale, scellée* Helena m'a appelé. Valeu, hein. *sourit pour la première fois* Tiens, c'est pour toi. Distillerie de Paraty, ma région. *redevient sérieux* Si t'as encore besoin d'un passage à Rio, je peux t'embarquer gratis. Une fois.",
		"choices": ["Obrigado, Bruno"],
	},
	# --- Chaîne consortium 2 : Le Parc Residences ---
	"consortium_le_parc_offer": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*pose une enveloppe sur la table* Riserva Uno a payé. Magalhães a fait passer le mot — c'est tout le bénéfice de la trouille bien placée. *te scrute* Le Parc Residences, à deux cents mètres à l'ouest. Sr. Carrasco, le gérant. Plus combatif, plus ancien, plus connecté. Mais il sait que tu viens, maintenant. Mille reais, sept cents de dette en moins. Tu prends, malandro ?",
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
		"text": "*sourire en coin* Tu l'as déjà secoué ? Golaço. Retourne signer, sobrinho — il sait maintenant qu'on a un système.",
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
		"text": "*compte les billets en silence, glisse une grosse enveloppe* Quinze cents reais. Neuf cents de moins sur la dette. *se penche en avant, voix basse* Mendonça a signé, sobrinho. Caraca — c'est historique. Trois condomínios de la Barra paient maintenant — quarante mille reais par mois récurrents. Tu m'as rendu plus fort que je ne l'étais. *expression change* Mais le commissaire — son cousin — il connaît ton visage maintenant. Évite le calçadão une semaine. Et quand tu reverras Capitão Ramos, il aura une raison de moins de te protéger.",
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
		"choices": ["*déposer la liste blanchiment sur le bureau, en silence*", "*partir sans rien dire*", "« Dom Salvatore et moi avons des amis communs. Demandez-lui. »"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "consortium_peninsula", "objective": "intimidate_mendonca", "payout": 0}, "rep": {2: 3, 1: -2}},
			"2": {"jeitinho": {"npc": "don_salvatore", "tier": 1,
				"ok": {"finish_quest": {"quest": "consortium_peninsula", "objective": "intimidate_mendonca", "payout": 0}, "rep": {4: 3}},
				"ko_speaker": "Sr. Mendonça",
				"ko_text": "*décroche son téléphone, deux mots, raccroche* Salvatore ne vous connaît pas, monsieur. *sourire froid* Première règle du système : ne jamais invoquer un nom qui ne répond pas."}},
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
		"text": "120 au développé. Et je fais encore un peu de jiu-jitsu. Un vrai capitão, tu vois. Bon, si tu changes d'avis, je suis là. Tranquilo.",
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
		"text": "Maneiro demais ! Tu peux refaire un tour chaque fois que tu veux. La station vélo est là pour toi.",
		"choices": ["Merci"],
	},
	# --- VOIE TRÁFICO : intro acte 2 (échantillon, pas de pacte voie scellé) ---
	"tito_intro_a1_offer": {
		"speaker": "Tito",
		"text": "*te jauge, recrache la fumée* T'as payé tes 500 au consortium. Bom. Tu veux comprendre comment le morro paie ? Porte un paquet pour mon contact du calçadão. Une seule course, mermão. Tu fermes ta gueule, tu reviens. Après tu décides — moi, Ramos, le Padre, Magalhães. Mais d'abord tu portes.",
		"choices": ["Je porte ton paquet", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "trafico_a1_livraison", "rep": {2: 1}},
			"1": {"set_flag": "tito_approached"},
		},
	},
	# --- VOIE POLÍCIA : intro acte 2 ---
	"ramos_intro_b1_offer": {
		"speaker": "Capitão Ramos",
		"text": "*te jauge par-dessus son café* T'as payé tes 500 au consortium. Un môme du morro ponctuel, c'est rare. *pose sa tasse* Je te demande un seul service avant qu'on parle vraiment : repère un visage utile sur le calçadão et reviens me le rapporter. Pas d'uniforme, pas d'engagement — suave. Après, on verra.",
		"choices": ["Compris, Capitão", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "policia_b1_intel", "rep": {1: 1}},
			"1": {"set_flag": "ramos_approached"},
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
	# --- ACTE 2 : Convoi favela (voie Tráfico) ---
	# --- ACTE 2 : Operação Carnaval (voie Polícia) ---
	# --- ACTE 2 : Salvem o Orfanato (voie Prefeito) ---
	# --- ACTE 2 : O que vi no mar (Pêcheur) ---
	"pecheur_act2_offer": {
		"speaker": "Seu Pedro",
		"text": "Sobrinho, écoute. Cette nuit, à 3h du matin, j'ai vu trois canots noirs faire la navette du large jusqu'à la pointe de Leme. Pas de pêcheurs — des hommes en treillis. Mes filets en ont senti l'odeur de l'essence pendant deux heures. Je sais pas à qui en parler. Toi, peut-être. Tu prends l'info ?",
		"choices": ["J'écoute, Seu Pedro", "Pas mes oignons"],
		"on_choose": {
			"0": {"accept_quest": "act2_pecheur_secret", "next": "pecheur_act2_go_see"},
		},
	},
	"pecheur_act2_go_see": {
		"speaker": "Seu Pedro",
		"text": "Mais me crois pas sur parole, cara — un vieux qui parle de canots fantômes, on l'écoute poliment et on l'oublie. *pointe l'est, au-delà du Leme* Va voir de tes propres yeux. La mureta da Urca, à Botafogo, domine toute l'entrée de la baie. Attends la nuit, regarde le large. Après, tu reviendras me dire à qui on parle.",
		"choices": ["J'y vais"],
	},
	"pecheur_act2_choose": {
		"speaker": "Seu Pedro",
		"text": "Trois choix, cara. Tu en parles à Ramos — la Polícia coupera le robinet et te paiera bien. Tu en parles à Miguel — le Morro saura, et il y a peut-être quelque chose à grappiller. Ou tu te tais, et tu rentres chez toi dormir. Que Dieu te guide.",
		"choices": ["Je vais voir Ramos (R$ 400)", "Je préviens Miguel (R$ 300)", "Je me tais"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 400}, "set_flag": "pecheur_to_ramos", "rep": {1: 5, 2: -2}},
			"1": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 300}, "set_flag": "pecheur_to_miguel", "rep": {2: 5, 0: -2}},
			"2": {"finish_quest": {"quest": "act2_pecheur_secret", "objective": "decide_pecheur", "payout": 0}, "rep": {0: -1}},
		},
	},
	"pecheur_act2_remind": {
		"speaker": "Seu Pedro",
		"text": "*répare ses filets sans lever la tête* La mureta da Urca, sobrinho. Botafogo. Tant que t'as pas vu les canots de tes yeux, on a rien à se dire — et après, faudra choisir vite.",
		"choices": ["J'y retourne"],
	},
	"pecheur_act2_done": {
		"speaker": "Seu Pedro",
		"text": "*tire un dernier filet* La mer parle moins fort cette nuit. Obrigado, sobrinho.",
		"choices": ["Bonne pêche"],
	},
	# --- ACTE 2 : Gala da Contessa ---
	"contessa_act2_offer": {
		"speaker": "Contessa Bianchi",
		"text": "*sirote un Aperol* Carioca. J'organise un gala pour le bairro — caritatif, télévisé, tout. Mais la production patine. Trouve-moi : une voix (ce Ronaldo qui joue dans la rue), un sponsor café (ton ami Carlos), une sécurité solide (Jorge du Bar do Policial)… et la touche finale : le trio bossa qui joue devant le Garota de Ipanema. Pas une reprise, ragazzo — l'original, là où la chanson est née. 1500 reais et l'invitation d'honneur si tu réussis.",
		"choices": ["Con piacere, Contessa", "Pas pour moi"],
		"on_choose": {
			"0": {"accept_quest": "act2_contessa_gala"},
		},
	},
	"contessa_act2_remind": {
		"speaker": "Contessa Bianchi",
		"text": "Ronaldo, Carlos, Jorge — et mon trio d'Ipanema. Quatre oui, et le gala se monte. La presse arrive vendredi, ragazzo.",
		"choices": ["Je file"],
	},
	"contessa_act2_done": {
		"speaker": "Contessa Bianchi",
		"text": "*lève sa coupe* Parfait, carioca. Le gala fera la une de Veja. Tu as gagné Rio cette semaine. *te glisse une enveloppe avec un clin d'œil*",
		"choices": ["Grazie, Contessa"],
	},
	# --- ACTE 2 : Os verdadeiros rostos ---
}
