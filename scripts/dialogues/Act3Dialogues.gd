class_name Act3Dialogues
extends RefCounted

# Knots acte 3 (pivot Dom Nilton, pactes de voie scellés, missions A/B/C/D + défilé).
#
# Même forme que PLACEHOLDER_DIALOGUES : key = ink_knot, value =
# {speaker, text, choices, on_choose?}. Le routage est par acte mais la
# résolution runtime se fait par clé globale — l'acte n'a pas d'incidence
# fonctionnelle.

const KNOTS: Dictionary = {
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
	# (Knots acte 4 + couronnements voies déplacés vers scripts/dialogues/
	# Act4Dialogues.gd — fusionnés via register_runtime_dialogue dans _ready.)
	"tito_voie_active": {
		"speaker": "Tito",
		"text": "*claque la langue, te jauge* Tu portes bien, sobrinho. Maintenant le morro a son propre rythme — mon contact gère, calçadão de Copa. Va le voir, il sait quoi te confier. Quand viendra la corrida finale du Carnaval, tu reviens me parler. D'ici là, pas de zèle, pas de bavures.",
		"choices": ["Compris, Tito"],
	},
	# (tito_trafico_corrida → Act4Dialogues.gd)
	# --- VOIE POLÍCIA : pacte officiel acte 3 ---
	"ramos_pacto_policia_offer": {
		"speaker": "Capitão Ramos",
		"text": "*te jauge par-dessus son café, au comptoir du Bar do Policial* Tu as tâté de tous les camps, garoto. Le morro, le consortium, le Padre. Mais c'est moi qui te file le badge. *pose sa tasse* J'ai pas besoin d'un voyou de plus. J'ai besoin d'yeux. Tu bosses pour moi, tu me ramènes ce que je demande, et je te couvre — la dette, le bairro, tout. Alors ?",
		"choices": ["Je suis votre homme, Capitão", "Plus tard — je réfléchis encore"],
		"on_choose": {
			"0": {"accept_quest": ["policia_b1_intel", "policia_b2_filature"], "set_flag": "voie_policia", "rep": {1: 5, 2: -2}},
		},
	},
	"ramos_pacto_policia_remind": {
		"speaker": "Capitão Ramos",
		"text": "*tapote la table* Le visage, sobrinho. Calçadão de Copa, mon contact en civil traîne près des cocos. Tu repères, tu rapportes. La loi attend.",
		"choices": ["J'y vais, Capitão"],
	},
	# (ramos_policia_madrugada → Act4Dialogues.gd)
	# --- VOIE CONSORTIUM : pacte officiel acte 3 ---
	"magalhaes_pacto_consortium_offer": {
		"speaker": "Sr. Magalhães",
		"text": "*costume clair, vue mer, te fait asseoir dans un fauteuil trop profond* Tu as goûté à toutes les chapelles, sócio. Et tu es revenu chez moi. *fait tourner un whisky* Les autres te proposent un flingue ou une matraque. Moi je te propose un stylo. Le Consórcio ne casse pas les jambes — il fait signer. Tu travailles pour la maison, tu apprends à recouvrer poliment, et ta dette devient une rente. Dans l'autre sens. *te tend le verre*",
		"choices": ["Je signe, Sr. Magalhães", "Plus tard — je réfléchis encore"],
		"on_choose": {
			"0": {"accept_quest": ["consortium_c1_recouvrement", "consortium_c2_loyers"], "set_flag": "voie_consortium", "rep": {4: 5, 0: -2}},
		},
	},
	"magalhaes_pacto_consortium_remind": {
		"speaker": "Sr. Magalhães",
		"text": "*sans lever les yeux de ses dossiers* Le recouvrement, mon cher. Calçadão de Copa — un commerçant a pris du retard. Un mot, un sourire, une signature. La maison déteste attendre.",
		"choices": ["Je m'en occupe"],
	},
	# (magalhaes_consortium_pacto + magalhaes_consortium_done → Act4Dialogues.gd)
	# --- VOIE PREFEITO : pacte officiel acte 3 ---
	"padre_pacto_prefeito_offer": {
		"speaker": "Padre Anselmo",
		"text": "*range les bancs de la chapelle, te regarde avec douceur* Tu as vu les trois autres faces du Rio, mon enfant. *pose un cierge* Les autres te proposeront un flingue, une matraque, un stylo de banquier. Moi, je n'ai rien à te donner — que le bairro. Aide-le, et il te portera. Pas de patron, pas de maison : des voisins. Ton oncle Zé a fui parce qu'il croyait qu'il n'y avait que les trois autres voies. Il avait tort. Tu m'aides à sauver l'orfanato ?",
		"choices": ["Pour le bairro, mon Père", "Plus tard — je réfléchis encore"],
		"on_choose": {
			"0": {"accept_quest": ["prefeito_d1_peticao", "prefeito_d2_basquete"], "set_flag": "voie_prefeito", "rep": {0: 6}},
		},
	},
	"padre_pacto_prefeito_remind": {
		"speaker": "Padre Anselmo",
		"text": "*joint les mains* La pétition, mon enfant. Trois commerçants du calçadão hésitent encore. Une signature, c'est un toit pour vingt orphelins. Va leur parler — ils t'écouteront, toi.",
		"choices": ["J'y retourne, mon Père"],
	},
	# (padre_prefeito_eleicao → Act4Dialogues.gd)
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
}
