class_name SidePlageDialogues
extends RefCounted

# Activités plage/sport/tourisme : Lagoa, surf, volley, capoeira, DJ, basket, torcida, quiz, tours, Contessa.
# Extrait de SideQuestDialogues (re-split par domaine). Préchargé par chemin
# dans DialogueBridge ; résolution runtime par clé, le fichier n'a pas
# d'incidence fonctionnelle.

const KNOTS: Dictionary = {
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
		"text": "Pô, t'as toujours pas essayé la Lagoa ? La borne de location est juste à côté du chemin. Quatre points cardinaux, dans l'ordre.",
		"choices": ["J'y vais"],
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
		"choices": ["Compris", "« Le concierge du Palace répond de moi, Contessa. »"],
		"on_choose": {
			"1": {"jeitinho": {"npc": "concierge", "tier": 1,
				"ok": {"accept_quest": "escort_contessa", "rep": {4: 1}},
				"ko_speaker": "Contessa Bianchi",
				"ko_text": "*lève un sourcil amusé* Curieux. Le concierge ne m'a jamais parlé de toi. *agite la main* Les références, ragazzo, ça se cultive."}},
		},
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
		"text": "*lève un sourcil en voyant la Contessa* Caraca… on fait dans le luxe ce soir ? Je vous sers quoi, signora ?",
		"choices": ["Deux caipirinhas, merci", "On passait juste saluer", "« Jorge, c'est pour moi que tu les fais. »"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_to_bar", "payout": 0}, "pay_bribe": 20, "rep": {3: 1}},
			"1": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_to_bar", "payout": 0}},
			"2": {"jeitinho": {"npc": "jorge", "tier": 2,
				"ok": {"finish_quest": {"quest": "escort_contessa", "objective": "escort_to_bar", "payout": 0}, "rep": {3: 1, 4: 1}},
				"ko_speaker": "Jorge",
				"ko_text": "*rit en essuyant un verre* Pour toi ? Freguês, je connais ton visage, pas ton nom. La maison offre aux habitués — deviens-en un."}},
		},
	},
	# --- Variantes affinité (NPCAffinity) pour les NPCs majeurs récurrents ---
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
		"text": "*ajuste son chapeau de paille trop neuf* Hey amigo ! Tu parle français ? Je veux voir le vrai Rio — le Cristo, le Pão de Açúcar, la Lagoa. Pas les pièges à touristes du Palace. Tu m'emmènes ? Je donne 100 reais à chaque arrêt et 600 de plus à la fin. C'est bon pour toi ? « Bélézza », comme vous dites !",
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
		"text": "*sourit, lunettes de soleil et appareil photo en bandoulière* Quel quartier merveilleux ! « Caraca », comme dit mon chauffeur ! Mes amis vont être jaloux. Voilà ton bonus, amigo, comme promis. Si je reviens l'an prochain, tu seras mon guide officiel.",
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
		"text": "Un gala télévisé ? *éclate de rire* Fala sério ! L'expresso ISSIMO en pause publicitaire ? Cher confrère, tu fais une bonne affaire à mon café aujourd'hui. Je sponsorise. Préviens la Contessa : trois machines, deux baristas et l'enseigne sur la scène.",
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
		"text": "*tape sur sa caisse* Ça va te plaire, sobrinho. Le Brésil joue ce soir au Maracanã contre l'Argentine. Le chef de torcida cherche un tambourineiro pour mener la tribune nord. Les supporters paient bien le rythme — plus tu déchires, plus le pourboire enfle. Et te fatigue pas à dire que t'es {time} : ce soir, tout le monde est Brésil. Le taxi de l'Av. Atlântica te dépose à l'esplanade.",
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
		"text": "Le terrain de l'Aterro t'attend. Vise la jauge verte et reste tranquilo, c'est tout. Taxi puis terrain.",
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
		"text": "*serre sa planche sous le bras, regarde l'horizon* Tu surfes, ou tu poses pour les gringos ? Arpoador, c'est pas pour les frileux. Le poste 7, c'est notre table — on y mange les newbies au petit déjeuner. *te scanne* Tu m'as l'air solide. T'oserais ?",
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
		"text": "*pointe la mer du menton* La SurfStation t'attend. Reste suave sur la planche, lis la vague avant qu'elle te lise. Reviens me voir quand t'as bouclé une session.",
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
		"text": "*attend en regardant la mer* On t'attend sur le sable, mermão. Le filet est tendu, mes coéquipières s'échauffent. Reviens quand t'es prêt à enfiler le maillot.",
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
		"choices": ["OK (R$ 100)", "Trop cher", "« Mestre, la roda connaît déjà mon nom. »"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "diego_botafogo_capoeira", "objective": "tip_diego", "payout": 0}, "pay_bribe": 100, "rep": {0: 3, 4: 2}, "next": "diego_show"},
			"2": {"jeitinho": {"npc": "diego", "tier": 1,
				"ok": {"finish_quest": {"quest": "diego_botafogo_capoeira", "objective": "tip_diego", "payout": 0}, "rep": {0: 2, 2: 2}, "next": "diego_show"},
				"ko_speaker": "Mestre Diego",
				"ko_text": "*sourit sans s'arrêter de jouer* La roda connaît ton nom ? *regarde ses élèves, qui haussent les épaules* Pas encore, sobrinho. Reviens t'asseoir, écoute le berimbau, salue les anciens. Après on parlera famille."}},
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
		"text": "Valeu ! La maison te doit un dessert. Passe quand tu veux.",
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
		"text": "Oi querido ! Bem-vindo a Rio Style. Besoin d'un t-shirt maneiro pour briller sur le calçadão ?",
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
}
