class_name Act4Dialogues
extends RefCounted

# Knots spécifiques à l'acte 4 (Os Grandes Lances) + couronnements de voies
# (acte 4 → 5). Extraits de DialogueBridge pour alléger ce dernier (qui passe
# 2900 lignes). Le DialogueBridge les enregistre via `register_runtime_dialogue`
# dans son `_ready` — du point de vue du gameplay, c'est identique à des
# entrées de PLACEHOLDER_DIALOGUES.
#
# Convention de splitting : un seul const KNOTS, structure identique à
# PLACEHOLDER_DIALOGUES (key = ink_knot, value = {speaker, text, choices, on_choose?}).

const KNOTS: Dictionary = {
	# Knot stub pour le journal narratif. Le vrai dialogue d'offre se fait
	# via la variante `assassinate_offer` du FixerSpot.
	"fixer_offer_assassinate": {
		"speaker": "Le Fixer",
		"text": "*baisse la voix, voix rauque* Y'a une voie courte, garoto. Un seul coup. Dom Nilton ne déjeune pas demain, et la maison s'effondre — avec ta dette. 5 000 reais d'acompte, le reste est mon affaire. Suave.",
		"choices": ["…"],
	},
	# --- Couronnements de voie (set_endgame → bascule en acte 5 Reinado) ---
	"tito_trafico_corrida": {
		"speaker": "Tito",
		"text": "*se lève, pose les mains sur tes épaules, grave* Tu as fait tout le chemin, sobrinho. Le consortium est presque payé, la baie est à nous, le morro te respecte — é nóis. *te regarde droit dans les yeux* Il reste la dernière corrida — celle du Carnaval. Tu la mènes, et le Morro n'a plus de roi : il t'a, toi. Ton oncle Zé a eu cette chance et il a fui. Pas toi. *te tend les clés* Vai, Patrão.",
		"choices": ["Je mène la corrida"],
		"on_choose": {
			"0": {"set_endgame": "TRAFICO", "finish_quest": {"quest": "trafico_a9_corrida", "objective": "execute_run", "payout": 5000}, "rep": {2: 10}},
		},
	},
	"ramos_policia_madrugada": {
		"speaker": "Capitão Ramos",
		"text": "*boucle son ceinturon, te regarde dans le blanc des yeux* Cette nuit, garoto. Le mandat est signé. La PM monte sur le morro à la madrugada et on coupe la tête du réseau. Si tu es là-haut avec moi, le bairro saura à qui il doit sa paix : à toi. Chefe de Polícia honoraire. Ton oncle Zé aurait jamais eu ce cran. *te tend un gilet* On y va.",
		"choices": ["On lance l'Operação Madrugada"],
		"on_choose": {
			"0": {"set_endgame": "POLICIA", "finish_quest": {"quest": "policia_b9_madrugada", "objective": "complete_madrugada", "payout": 5000}, "rep": {1: 10}},
		},
	},
	"magalhaes_consortium_pacto": {
		"speaker": "Sr. Magalhães",
		"text": "*pose un dossier relié devant toi, dévisse son stylo en or* Tout est là. Trois condomínios alignés, le calçadão sous contrat, la baie blanchie. Le Pacto da Barra : rente mensuelle officielle, endossement politique en réserve, et ta dette… effacée d'un trait. *te tend le stylo* Ton oncle Zé a refusé ce stylo, jadis. Il a préféré fuir et balayer un hall. Toi, tu es plus malin. Signe, et tu es la maison.",
		"choices": ["Je signe le Pacto da Barra"],
		"on_choose": {
			"0": {"set_endgame": "CONSORTIUM", "finish_quest": {"quest": "consortium_c9_pacto", "objective": "seal_pacto", "payout": 5000}, "rep": {4: 10}},
		},
	},
	# Knot uniquement déclenché par Act3FinaleCutscenes (clôture voie Consortium).
	"magalhaes_consortium_done": {
		"speaker": "Sr. Magalhães",
		"text": "*range le dossier signé dans un coffre, te serre la main longuement* Bienvenue dans la maison, sócio. La casa sempre ganha — et désormais, tu es la casa.",
		"choices": ["…"],
	},
	"padre_prefeito_eleicao": {
		"speaker": "Padre Anselmo",
		"text": "*pose la main sur ton épaule, ému, devant la foule du bairro* Le scrutin est ce soir, mon enfant. Le calçadão, le morro, l'orfanato — tous derrière toi. Pas par peur : par confiance. Si tu l'emportes, tu seras le Coronel do Bairro, et la dette de ton oncle s'effacera au grand jour, par la vérité. Va. Le peuple t'attend aux urnes.",
		"choices": ["On gagne cette élection"],
		"on_choose": {
			"0": {"set_endgame": "PREFEITO", "finish_quest": {"quest": "prefeito_d9_eleicao", "objective": "win_election", "payout": 5000}, "rep": {0: 10}},
		},
	},
	# --- Solde de la dette : Dom Nilton vient en personne au couronnement. ---
	# La dette ne fond plus silencieusement dans le code : le créancier s'incline,
	# différemment selon la voie. Joué par Act3FinaleCutscenes avant le panneau de fin.
	"nilton_settlement_trafico": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*il vient seul. Sans Claudinho, sans pagode, sans sourire. Il pose une mallette à tes pieds, sur le sable.* Le solde de Zé. Effacé — c'est nous qui apportons, cette fois. Le consortium reconnaît le morro et son Patrão. *il recule d'un pas, remet ses lunettes noires* On se reverra, sobrinho. Les machines ont de la mémoire.",
		"choices": ["Le morro aussi."],
	},
	"nilton_settlement_policia": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*encadré par deux PM, il signe le registre de dissolution sans qu'on le lui demande deux fois* La dette de Zé ? Quelle dette, Chefe — les écritures sont propres, vérifiez. *range son stylo, sourit sans joie* Claudinho chante dans un autre État désormais. Belle carrière. La vôtre aussi, paraît-il.",
		"choices": ["Circulez, Nilton."],
	},
	"nilton_settlement_consortium": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*il t'accueille d'un abraço appuyé, deux tapes dans le dos* Sócio ! La dette de ton oncle ? Un instrument interne, désormais — on efface, on réinvestit, on n'en parle plus entre nous. *il te tend son propre stylo* Première signature de ta nouvelle vie. Zé refusait ce stylo. Toi, tu l'as pris. La maison s'en souviendra.",
		"choices": ["*signer*"],
	},
	"nilton_settlement_prefeito": {
		"speaker": "Dom Nilton (consortium)",
		"text": "*il attend devant la chapelle, chapeau à la main — tu ne l'as jamais vu sans son sourire avant ce soir* Coronel. *il pose l'échéancier déchiré en deux sur les marches* Le conseil a voté : pertes et profits. La dette de Zé n'existe plus. *il remet son chapeau* T'as gagné proprement, garoto. C'est la manière la plus chère de gagner — et la seule qu'on ne peut pas racheter.",
		"choices": ["Adeus, Dom Nilton."],
	},
}
