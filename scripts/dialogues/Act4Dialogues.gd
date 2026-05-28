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
		"text": "*baisse la voix, voix rauque* Y'a une voie courte, garoto. Un seul coup. Dom Nilton ne déjeune pas demain, et la maison s'effondre — avec ta dette. 5 000 reais d'acompte, le reste est mon affaire.",
		"choices": ["…"],
	},
	# --- Couronnements de voie (set_endgame → bascule en acte 5 Reinado) ---
	"tito_trafico_corrida": {
		"speaker": "Tito",
		"text": "*se lève, pose les mains sur tes épaules, grave* Tu as fait tout le chemin, sobrinho. Le consortium est presque payé, la baie est à nous, le morro te respecte. *te regarde droit dans les yeux* Il reste la dernière corrida — celle du Carnaval. Tu la mènes, et le Morro n'a plus de roi : il t'a, toi. Ton oncle Zé a eu cette chance et il a fui. Pas toi. *te tend les clés* Vai, Patrão.",
		"choices": ["Je mène la corrida"],
		"on_choose": {
			"0": {"set_endgame": "TRAFICO", "finish_quest": {"quest": "trafico_a9_corrida", "objective": "execute_run", "payout": 5000}, "rep": {2: 10}},
		},
	},
	"ramos_policia_madrugada": {
		"speaker": "Capitão Ramos",
		"text": "*boucle son ceinturon, te regarde dans le blanc des yeux* Cette nuit, sobrinho. Le mandat est signé. La PM monte sur le morro à la madrugada et on coupe la tête du réseau. Si tu es là-haut avec moi, le bairro saura à qui il doit sa paix : à toi. Chefe de Polícia honoraire. Ton oncle Zé aurait jamais eu ce cran. *te tend un gilet* On y va.",
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
}
