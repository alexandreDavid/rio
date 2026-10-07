class_name SideBaiaDialogues
extends RefCounted

# Niterói & baie de Guanabara : pêche de Bruno, chaîne Mafia da Baía.
# Extrait de SideQuestDialogues (re-split par domaine). Préchargé par chemin
# dans DialogueBridge ; résolution runtime par clé, le fichier n'a pas
# d'incidence fonctionnelle.

const KNOTS: Dictionary = {
	# --- Bruno : SIDE Pesca da Baía (prereq bruno_carga) ---
	"bruno_pesca_offer": {
		"speaker": "Bruno",
		"text": "*pose sa canne sur la planche, te tend la sienne* Sobrinho. Cette baie, elle a mille robalos par mètre carré, et personne ne les sort plus. *sourit* Sors-en un — un seul — et je te paie de la cachaça, beleza ? Le ponton là-bas, c'est mon spot depuis trente-quatre ans.",
		"choices": ["J'essaie maintenant", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bruno_pesca_baia"},
		},
	},
	"bruno_pesca_remind": {
		"speaker": "Bruno",
		"text": "*pointe le bout du ponton, l'eau qui clapote* La canne t'attend, sobrinho. Une session, un poisson — demorô.",
		"choices": ["J'y vais"],
	},
	"bruno_pesca_done": {
		"speaker": "Bruno",
		"text": "*sort la cachaça promise, la décapsule* Tu l'as sorti. *te tend la bouteille* Trente-quatre ans que je voyais des touristes essayer sans rien attraper. Caraca — toi, en deux essais. *te scrute* T'es de la famille des pêcheurs, sobrinho. C'est dans le sang ou pas.",
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
		"text": "*pose deux cafés sur le banc avant même que tu t'assoies* Vous êtes le seul carioca da gema régulier que j'ai. *te tend une tasse* Bruno parle de vous comme d'un sobrinho. Moi aussi maintenant.",
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
		"text": "*essuie son fusain avec un chiffon* Boa tarde. Fala sério, le soleil tape trop fort sur le blanc du MAC — je vois plus rien. Pause-café.",
		"choices": ["Bon repos"],
	},
	"yara_chat_evening": {
		"speaker": "Yara",
		"text": "*allume une lampe au-dessus de son carnet* Boa noite. Je termine au crayon ce que j'ai commencé à l'aquarelle — la lumière artificielle change les couleurs, mais elle sauve les courbes.",
		"choices": ["Boa noite, Yara"],
	},
	"carlos_chat_morning": {
		"speaker": "Carlos",
		"text": "*ouvre le bar, encore en chaussons* Bom dia, sobrinho. Le premier café est sur la maison — pô, j'en bois trois moi-même avant huit heures.",
		"choices": ["Obrigado, Carlos"],
	},
	"carlos_chat_afternoon": {
		"speaker": "Carlos",
		"text": "*sert un caldo glacé à un coureur en sueur* Boa tarde. Les joggers de la Lagoa, c'est mon segment de l'après-midi. Tu veux quelque chose, freguês ?",
		"choices": ["Pas pour moi, Carlos"],
	},
	"carlos_chat_evening": {
		"speaker": "Carlos",
		"text": "*allume les guirlandes au-dessus du bar* Boa noite. C'est la meilleure heure ici — la Lagoa reflète les lumières, les couples viennent danser après dîner.",
		"choices": ["Bonne soirée, Carlos"],
	},
	"padaria_chat_morning": {
		"speaker": "Seu Tonio",
		"text": "*sort la première fournée du four, vapeur qui monte* Bom dia ! C'est l'heure du pão fresco, sobrinho. Une torcida d'ouvriers attend dehors, mais toi t'as la priorité.",
		"choices": ["Obrigado, seu Tonio"],
	},
	"padaria_chat_afternoon": {
		"speaker": "Seu Tonio",
		"text": "*essuie le comptoir avec une lassitude maîtrisée* Boa tarde. Le rush est passé, c'est l'heure des goûters — coxinha et café gelado, le combo carioca.",
		"choices": ["Tudo bem, seu Tonio"],
	},
	"padaria_chat_evening": {
		"speaker": "Seu Tonio",
		"text": "*éteint le four, garde la lumière de la vitrine allumée* Boa noite. La nuit, je reste pour les habitués. *te montre une chaise* Tranquilo, tu peux t'asseoir si tu veux pas rentrer tout de suite.",
		"choices": ["Boa noite, seu Tonio"],
	},
	"policier_chat_morning": {
		"speaker": "Agente Silva",
		"text": "*café au comptoir, casquette sur la table* Bom dia. La patrouille du matin, c'est la plus tranquille — les voyous dorment encore.",
		"choices": ["Bom dia, agente"],
	},
	"policier_chat_afternoon": {
		"speaker": "Agente Silva",
		"text": "*surveille l'avenue Atlântica, mains dans le dos* Boa tarde. C'est l'heure des malandros de plage. Tu vois quelque chose, tu me préviens.",
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
			"*en ami* « Roberto. C'est moi. Fais-moi confiance : pas cette une-là. »",
		],
		"on_choose": {
			"0": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 300}, "pay_bribe": 300, "rep": {2: 2, 0: -2}, "set_flag": "roberto_silenced"},
			"1": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 0}, "rep": {2: 5, 0: -4, 1: -2}, "set_flag": "roberto_silenced"},
			"2": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 0}, "rep": {2: 1, 4: 4, 0: 1}, "set_flag": "roberto_silenced"},
			"3": {"jeitinho": {"npc": "roberto_maia", "tier": 1,
				"ok": {"finish_quest": {"quest": "baia_silence_press", "objective": "silence_journalist", "payout": 0}, "rep": {4: 3, 0: 1}, "set_flag": "roberto_silenced"},
				"ko_speaker": "Roberto Maia",
				"ko_text": "*fronce les sourcils* « C'est moi » ? On s'est croisés une fois, jeune homme. L'amitié, ça ne s'invoque pas — ça se prouve. Sortez de mon bureau."}},
		},
	},
	"roberto_silenced": {
		"speaker": "Roberto Maia",
		"text": "*ne te regarde plus, ferme son carnet quand tu passes* Je n'ai rien à ajouter.",
		"choices": ["..."],
	},
	# --- Marina da Glória : l'escolinha de vela de Lia (projet social) ---
	"lia_intro": {
		"speaker": "Professora Lia",
		"text": "*un sifflet autour du cou, elle hisse la voile d'un Optimist plus petit qu'elle* Escolinha de vela da Glória. Ici, les gosses du morro apprennent à lire le vent — le seul patron qui ne ment jamais. *elle te jauge* Tu sais naviguer, toi ? Le ponton est là. Bia t'attend, si t'as le courage.",
		"choices": ["Plus tard, professora"],
	},
	"lia_offer": {
		"speaker": "Professora Lia",
		"text": "*elle compte des gilets de sauvetage ; il en manque un* Il me reste une place à l'escolinha, cette saison. On m'a parlé d'un gamin du morro — Pedrinho, celui que tu as sorti de la citerne. *elle relève les yeux* Je ne confie pas un enfant à quelqu'un qui ne sait pas ce qu'est le vent. Termine la régate, et la place est à lui.",
		"choices": ["Je vais lire le vent", "Pas maintenant"],
		"on_choose": {
			"0": {"accept_quest": "vela_pedrinho"},
		},
	},
	"lia_remind": {
		"speaker": "Professora Lia",
		"text": "Le ponton, la régate, Bia. Finis le parcours — deux bords de près, pas de raccourci face au vent. Le vent ne négocie pas, querido.",
		"choices": ["J'y vais"],
	},
	"lia_inscrever": {
		"speaker": "Professora Lia",
		"text": "*elle sort un petit gilet rouge, taille enfant, et écrit un nom au marqueur : PEDRINHO* Tu as lu le vent ; il pourra apprendre. *elle sourit pour la première fois* Samedi, je monte au morro avec le gilet. Dis à sa mãe que la mer, ça fait peur une semaine — et qu'après, ça fait des gens libres.",
		"choices": ["Il sera là, professora"],
		"on_choose": {
			"0": {"finish_quest": {"quest": "vela_pedrinho", "objective": "inscrever_pedrinho", "payout": 0}, "set_flag": "pedrinho_vela", "rep": {0: 4}},
		},
	},
	"lia_done": {
		"speaker": "Professora Lia",
		"text": "*au loin, un Optimist zigzague entre les bouées, un petit gilet rouge à la barre* Regarde-le. Trois semaines, et il vire déjà plus proprement que toi. *elle siffle* PEDRINHO ! Borda, borda ! *elle rit* Il me fait penser à toi. En plus doué.",
		"choices": ["…Valeu, professora"],
	},
}
