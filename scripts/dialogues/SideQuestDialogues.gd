class_name SideQuestDialogues
extends RefCounted

# Knots des activités libres (mini-jeux, side quests, variantes affinité, conquistas).
#
# Même forme que PLACEHOLDER_DIALOGUES : key = ink_knot, value =
# {speaker, text, choices, on_choose?}. Le routage est par acte mais la
# résolution runtime se fait par clé globale — l'acte n'a pas d'incidence
# fonctionnelle.

const KNOTS: Dictionary = {
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
