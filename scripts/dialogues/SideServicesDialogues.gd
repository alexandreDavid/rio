class_name SideServicesDialogues
extends RefCounted

# Services du quartier : padre/relique, pharmacie, bar, padaria, valet, chien, enveloppes Zona Sul, conquistas.
# Extrait de SideQuestDialogues (re-split par domaine). Préchargé par chemin
# dans DialogueBridge ; résolution runtime par clé, le fichier n'a pas
# d'incidence fonctionnelle.

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
		"text": "Tu as livré ? Valeu, mon grand ! Voilà tes 60 reais. Passe quand tu veux, j'ai toujours du travail.",
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
	# --- Bar do Policial : recrutement serveur ---
	"patrao_intro": {
		"speaker": "Patrão",
		"text": "Eh garoto, t'as l'air vif. Mon serveur s'est barré à Niterói, j'ai besoin d'un coup de main pour les soirs chargés. Ça t'intéresse ? 40 reais le service, et après on causera shifts. Beleza ?",
		"choices": ["J'accepte", "Tu paies combien ?", "Plus tard"],
		"on_choose": {
			"0": {"accept_quest": "bar_waiter"},
			"1": {"next": "patrao_pay_detail"},
		},
	},
	"patrao_pay_detail": {
		"speaker": "Patrão",
		"text": "40 reais le premier service, le temps que je voie si tu casses pas trop de verres. Après c'est 25 reais le shift, plus les pourboires des gringos pompettes. Alors ?",
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
	# --- Feijoada du samedi : le jalon d'affinité où le quartier t'adopte. ---
	# Offerte une seule fois, à tier FAMILIAR (NPCAffinity), après lost_dog.
	# Aucune récompense monétaire : la comida est sociale (skill ame-carioca).
	"irene_feijoada_invite": {
		"speaker": "Dona Irene",
		"text": "*pose son tricot, te regarde longtemps* Querido… ça fait des semaines que tu passes, que tu promènes Bingo, que tu demandes de mes nouvelles. *sourit* Samedi, je fais ma feijoada. Celle avec la couenne, le chou, l'orange coupée fine — la recette de ma mère, de Madureira. Il y aura les voisines, Seu Tonio, peut-être le Padre. *te prend la main* Tu viens ? Pas comme livreur. Comme convive.",
		"choices": ["Avec honneur, Dona Irene", "Je ne voudrais pas déranger…"],
		"on_choose": {
			"0": {"next": "irene_feijoada_scene"},
			"1": {"next": "irene_feijoada_insiste"},
		},
	},
	"irene_feijoada_insiste": {
		"speaker": "Dona Irene",
		"text": "*fronce les sourcils, faussement sévère* Déranger ? *agite sa cuillère en bois* Querido, à Rio, refuser une feijoada c'est comme insulter la grand-mère de quelqu'un. Samedi. Midi. Et tu as intérêt à venir le ventre vide.",
		"choices": ["D'accord, d'accord — j'y serai"],
		"on_choose": {
			"0": {"next": "irene_feijoada_scene"},
		},
	},
	"irene_feijoada_scene": {
		"speaker": "Narrateur",
		"text": "Samedi, midi. La table déborde sur le trottoir — la marmite noire au centre, le riz, la farofa, les oranges. Seu Tonio raconte trois fois la même histoire et tout le monde rit quand même. Bingo dort sous la table, le museau sur ton pied.\n\nDona Irene te ressert sans te demander. Quelqu'un t'appelle par ton prénom — pas « le neveu de Zé », pas « le gamin du milho ». Ton prénom.\n\nC'est peut-être ça, payer une dette : exister ici.",
		"choices": ["*rester jusqu'au soir*"],
		"on_choose": {
			"0": {"set_flag": "feijoada_irene", "rep": {0: 3, 4: 2}},
		},
	},
	"irene_after_feijoada": {
		"speaker": "Dona Irene",
		"text": "*lève les yeux de son tricot, le visage qui s'éclaire* Querido ! Les voisines me demandent encore quand tu reviens manger. *baisse la voix* J'ai gardé un tupperware de feijoada pour toi. Ne le dis pas à Seu Tonio.",
		"choices": ["Vous êtes la meilleure, Dona Irene", "Bingo a besoin de courir ?"],
		"on_choose": {
			"1": {"next": "irene_walk_offer"},
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
		"text": "Bom dia, freguês ! Pão de queijo direct du four, café com leite, et le pastel du jour. Sers-toi.",
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
		"text": "Tu m'as bien dépanné avec Dona Irene — valeu. Tu veux apprendre le métier ? Le four, la plaque, les ingrédients — tout est là. Tu sors une fournée, tu remplis le panier, tu gardes les pourboires.",
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
		"text": "Tu vois la borne juste là ? Tu pointes, t'es en service. Une voiture arrive, tu la prends, tu la gares, suave. Le client ressort, il veut sa voiture — tu cours. Plus tu es rapide, plus le tip grimpe. 90 secondes par service, jusqu'à cinq clients. Ça te tente ?",
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
		"text": "*range un verre, voix basse* Caldeira t'attend. Va lui dire ce que tu sais, tranquilo. Et ne reviens pas si tu vois quelqu'un te suivre.",
		"choices": ["Compris"],
	},
	"ivan_after_done": {
		"speaker": "Iván",
		"text": "*verse une cachaça* La veuve t'a payé ? Bom. *pose le verre sur le comptoir* Reviens quand tu veux, sobrinho. Ici on entend tout, on raconte rien.",
		"choices": ["Saúde"],
	},
	"ivan_default": {
		"speaker": "Iván",
		"text": "*essuie un verre, sourire fatigué* Chez moi le pôr-do-sol commence à dix-sept heures et finit à minuit. Caipirinha, freguês ? Cerveja gelada ? *pose le verre* On parle, on écoute. Tout passe par ce bar.",
		"choices": ["Une cerveja"],
	},
	# --- Conquistas — paragraphes rétrospectifs, marqués read au déblocage ---
	"conquista_first_quest": {"speaker": "Crônica", "text": "Le jour où j'ai accepté ma première mission. Le calçadão était bondé, l'air sentait le milho grillé. Je ne savais pas que c'était le début de quelque chose de plus grand.", "choices": ["Fermer"]},
	"conquista_first_payment": {"speaker": "Crônica", "text": "Premier acompte. Cinq cents reais comptés deux fois avant de les donner. Le consortium a noté la première ligne dans son carnet noir — et moi aussi.", "choices": ["Fermer"]},
	"conquista_debt_cleared": {"speaker": "Crônica", "text": "Cinquante mille remboursés. Dom Nilton n'a pas souri. Mais le carnet noir s'est fermé devant moi — c'est tout ce qui comptait.", "choices": ["Fermer"]},
	"conquista_act_2": {"speaker": "Crônica", "text": "L'acte 2 a commencé un matin comme les autres. Cinq cents reais chez Nilton, une nuit dans la maison de Zé — et au réveil, quatre patrons qui connaissaient déjà mon nom. Chacun voulait me voir porter, avant de me voir choisir.", "choices": ["Fermer"]},
	"conquista_act_3": {"speaker": "Crônica", "text": "Quatre portes ouvertes. Polícia, tráfico, prefeito, consórcio. Chacune fermait les trois autres. J'ai choisi celle qui faisait le moins de bruit dans ma tête.", "choices": ["Fermer"]},
	"conquista_act_4": {"speaker": "Crônica", "text": "Le règne. Le bairro chantait mon nom à la messe, à la favela, ou au commissariat — selon. J'avais traversé. Le Sambódromo m'attendait.", "choices": ["Fermer"]},
	"conquista_endgame_prefeito": {"speaker": "Crônica", "text": "Coronel do Bairro. Le titre n'existe pas officiellement. Mais quand je passe sur le calçadão, les commerçants se redressent.", "choices": ["Fermer"]},
	"conquista_endgame_policia": {"speaker": "Crônica", "text": "Chefe de Polícia. Ramos m'a tendu sa casquette le dernier matin de l'Operação Madrugada. « Tu en as fait plus que moi en trente ans. »", "choices": ["Fermer"]},
	"conquista_endgame_trafico": {"speaker": "Crônica", "text": "Patrão do Morro. Miguel m'a appelé « irmão » devant tous les jeunes de la favela. Il n'avait jamais fait ça pour personne.", "choices": ["Fermer"]},
	"conquista_pacto_barra": {"speaker": "Crônica", "text": "Magalhães m'a remis l'enveloppe scellée du Riserva Uno. Je ne l'ai pas ouverte. Mais je sais qu'elle est dans la poche intérieure de ma veste — et lui aussi.", "choices": ["Fermer"]},
	"conquista_commissaire_alerted": {"speaker": "Crônica", "text": "Mendonça avait un cousin commissaire. Je ne le savais pas avant d'entrer au Península Privé. Maintenant la PM connaît mon nom — pas encore mon visage.", "choices": ["Fermer"]},
	"conquista_first_familiar": {"speaker": "Crônica", "text": "Quelqu'un m'a appelé sobrinho sans hésiter, comme si on se connaissait depuis des années. C'était presque le cas.", "choices": ["Fermer"]},
	"conquista_three_familiar": {"speaker": "Crônica", "text": "Trois personnes du bairro me considèrent comme de la famille. C'est plus que je n'avais à mon arrivée. C'est plus que la plupart en accumulent.", "choices": ["Fermer"]},
	"conquista_first_photo": {"speaker": "Crônica", "text": "J'ai pris ma première photo. Une vague, un détail du calçadão, le mont du Pão de Açúcar en arrière-plan. On garde ce qu'on voit pour ne pas oublier qu'on l'a vu.", "choices": ["Fermer"]},
	"conquista_pesca_baia": {"speaker": "Crônica", "text": "Bruno m'a tendu sa canne sans rien dire. J'ai sorti un robalo de la baie de Guanabara au troisième essai. Trente-quatre ans qu'il en parlait — et c'est moi qui l'ai sorti. Caraca.", "choices": ["Fermer"]},
	"conquista_wealthy_10k": {"speaker": "Crônica", "text": "Dix mille reais versés. La cinquième ligne du carnet noir de Dom Nilton. Il a marqué un trait épais dessous — première étape.", "choices": ["Fermer"]},
	"conquista_carnaval_complete": {"speaker": "Crônica", "text": "Le défilé du Sambódromo. J'ai mené ma faction sous les projecteurs jusqu'à l'aube. La Sapucaí chante encore mon nom — ou un nom approchant.", "choices": ["Fermer"]},
	"conquista_chatterbox": {"speaker": "Crônica", "text": "Dix personnes du bairro me reconnaissent et m'ont parlé au moins une fois. À Copacabana, c'est presque une famille élargie. É nóis.", "choices": ["Fermer"]},
	"conquista_globetrotter": {"speaker": "Crônica", "text": "Cinq quartiers visités. Du Morro à la Barra, du Corcovado à Niterói. Chaque rue m'a appris quelque chose — surtout celles que je n'aurais pas dû prendre.", "choices": ["Fermer"]},
	"conquista_respeitado": {"speaker": "Crônica", "text": "Une réputation qui m'a pris des mois à bâtir. Les gens qui me croisent baissent ou hochent la tête — selon ce qu'on dit de moi.", "choices": ["Fermer"]},
	"conquista_beach_athlete": {"speaker": "Crônica", "text": "J'ai sué sur le sable et dans l'eau. Volley, surf, paddle, basquete — la praia te juge par la sueur, pas par les mots.", "choices": ["Fermer"]},
	"conquista_niteroi_resident": {"speaker": "Crônica", "text": "Bruno m'a embarqué sur deux missions et m'a tendu une cachaça à la fin. Niterói n'est plus l'autre côté — c'est aussi mon côté.", "choices": ["Fermer"]},
	"conquista_shutterbug": {"speaker": "Crônica", "text": "Cinq photos prises. Chaque cadre est un souvenir verrouillé, indépendant de ce qu'on raconte autour de moi.", "choices": ["Fermer"]},
	"conquista_viewpoint_collector": {"speaker": "Crônica", "text": "Trois mirantes admirés. Rio se voit toujours mieux d'en haut — Niemeyer, Christ, Pão. Trois points de vue, trois villes différentes.", "choices": ["Fermer"]},
	"conquista_escape_artist": {"speaker": "Crônica", "text": "Acte 3 atteint sans avoir alerté de commissaire. Mendonça est resté chez lui — ou bien j'ai évité son couloir. Quoi qu'il en soit, la PM ne connaît pas mon visage.", "choices": ["Fermer"]},
}
