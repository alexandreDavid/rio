extends CanvasLayer

# Écran de fin véritable — déclenché après que le défilé du Carnaval soit
# qualifié (`quest_completed("act4_carnaval_desfile")`). Présente un texte
# long propre à la voie choisie, puis offre :
# - Nouvelle partie+ : efface la save et redémarre. Préserve un compteur NG+
#   et la liste des entrées journal débloquées dans un fichier méta séparé
#   (`user://ng_plus.json`) — utilisé pour reconnaître le joueur d'un run à
#   l'autre dans des dialogues (Seu João par exemple).
# - Continuer à explorer : ferme l'écran sans rien casser, le joueur peut
#   continuer à se promener en acte 4.

@onready var title_label: Label = $Panel/Margin/Layout/Title
@onready var subtitle_label: Label = $Panel/Margin/Layout/Subtitle
@onready var body_label: Label = $Panel/Margin/Layout/Body
@onready var run_label: Label = $Panel/Margin/Layout/Run
@onready var replay_button: Button = $Panel/Margin/Layout/Buttons/Replay
@onready var continue_button: Button = $Panel/Margin/Layout/Buttons/Continue
@onready var credits_button: Button = $Panel/Margin/Layout/Buttons/Credits

const META_PATH: String = "user://ng_plus.json"
const QUEST_ID: String = "act4_carnaval_desfile"

# Texte d'épilogue par voie. Chaque entrée :
#   title    : titre principal (en haut, gros)
#   subtitle : sous-titre / honneur public
#   body     : 4-5 paragraphes de fin (immédiat + lendemain + famille + horizon)
const EPILOGUES: Dictionary = {
	CampaignManager.Endgame.PREFEITO: {
		"title": "Coronel do Bairro",
		"subtitle": "« Para o povo, pelo povo »",
		"body": "L'avenue Marquês de Sapucaí t'a porté en triomphe, écharpe verte en travers de la poitrine, le Padre à ta droite, la Contessa à ta gauche. Trois cent mille voix ont scandé ton nom jusqu'à l'aube.\n\nLe lendemain, les unes accrochent ton portrait : « Le neveu de Zé prend le bairro. » Le Padre ouvre la chapelle plus tôt qu'à l'habitude. Vovó découpe l'article du Globo et le glisse sous le verre du buffet, à côté de la photo jaunie de ton oncle.\n\nMãe a posé sa louche pour la première fois en six mois. Elle te regarde droit dans les yeux. « Mon fils. Mon fils Coronel. » Tu n'as plus jamais à descendre la favela à pied — mais tu le fais quand même, chaque dimanche, pour serrer les mains et écouter les doléances.\n\nLe Consortium a déménagé à São Paulo. Officiellement, ils respectent le territoire. Officieusement, Dom Nilton t'a envoyé un cigare cubain pour ton premier décret. Tu l'as fumé sur le balcon, en regardant les lumières du Cristo.\n\nTio Zé, derrière la réception du Palace, a relevé une seule fois la tête quand tu es passé en cortège. Il a souri, à peine. La famille tient debout par les mains qui travaillent. Et maintenant aussi par celles qui signent.",
	},
	CampaignManager.Endgame.POLICIA: {
		"title": "Chefe de Polícia",
		"subtitle": "« A maison bleue ne ferme jamais »",
		"body": "L'Operação Madrugada a duré quatre heures. À 7h, la presse braquait ses caméras sur Capitão Ramos — et toi, deux pas derrière, casquette plate, bras croisés. Le Morro a perdu trois caches d'armes et une tonne de poudre. Tito a disparu vers Niterói.\n\nLe lendemain, t'as ta plaque officielle, ton bureau au poste, et un bureau secondaire à l'Academia (Ramos insiste). La famille bleue te tape dans le dos jusqu'à te laisser des bleus. Le Padre te bénit dans la rue, mãe pleure de soulagement et te repasse ton uniforme à la vapeur tous les soirs.\n\nVovó, elle, n'a rien dit. Elle a simplement éteint la radio quand le journaliste a parlé d'« opération exemplaire ». Elle tricote toujours, mais plus lentement. Tu sais qu'elle pense à tio Zé, à l'oncle qui a fui ce que tu as embrassé.\n\nLe Consortium s'est dissous officiellement. Officieusement, Dom Nilton tient une nouvelle blanchisserie à Botafogo, en règle, taxée. Tu lui as fait passer le mot que la rente du calçadão s'arrêtait. Il t'a répondu d'un clin d'œil malaisant.\n\nLe Palace a un nouveau Concierge — Zé est parti la veille de l'opération. Personne ne sait où. Tu ne demandes pas. La maison bleue ne ferme jamais. Et toi non plus.",
	},
	CampaignManager.Endgame.CONSORTIUM: {
		"title": "Sócio do Consórcio",
		"subtitle": "« A casa sempre ganha »",
		"body": "Le Pacto da Barra a été paraphé dans un bureau climatisé du Riserva Uno, vue mer, sans un témoin du bairro. Magalhães a glissé le stylo dans ta poche de poitrine comme on épingle une médaille. Plus de dette : une rente, dans l'autre sens.\n\nLe lendemain, tu ne descends plus la favela — une berline aux vitres teintées t'y conduit quand il le faut. Les commerçants signent des « partenariats » avant même que tu demandes. Le calçadão baisse les yeux. Le Bar do Morro a retiré la photo de tio Zé du mur, par prudence.\n\nMãe a accepté l'argent sans le compter, le regard ailleurs. Vovó a posé son tricot quand tu es entré avec la voiture en bas, et ne l'a pas repris. « Tu paies plus, maintenant. Tu fais payer. » Elle n'a pas dit si c'était une fierté.\n\nLe Consortium ne va nulle part : il a un nouveau sócio carioca, présentable, né dans le morro — toi, sa meilleure vitrine. Dom Nilton et Magalhães trinquent à São Paulo et à Barra le même soir.\n\nTio Zé, derrière la réception du Palace, t'a vu passer en berline une seule fois. Il n'a pas balayé plus lentement, pas relevé la tête. Il a juste arrêté, une seconde, comme quelqu'un qui reconnaît une histoire qu'il a déjà vécue — et il a continué à balayer. La casa sempre ganha. Et tu es la casa.",
	},
	CampaignManager.Endgame.TRAFICO: {
		"title": "Patrão do Morro",
		"subtitle": "« O sangue do Zé corre nesta calçada »",
		"body": "La corrida a traversé Niterói et le pont Rio-Niterói à 4h du matin, sirènes lointaines, sans une éraflure. Au lever du soleil, le Morro a planté un drapeau rouge devant ta maison. Miguel a posé sa kalachnikov sur le pas de ta porte et est rentré dormir. Tito t'a craché à la base du cou — sa version de l'accolade royale.\n\nLe lendemain, le calçadão t'évite, te respecte, te paye. Les commerçants viennent chez toi, pas l'inverse. Le Bar do Morro affiche ton portrait sur la porte de la cuisine. La Padaria t'envoie le pain du jour gratis. Tu ne descends plus jamais sans escorte — Beto, le gamin de la voisine, court devant toi en criant ton nom.\n\nMãe a brûlé l'enveloppe à croix noire dans le foyer, sans rien te dire. Vovó a tricoté un drapeau rouge en silence et l'a accroché à la fenêtre. Quand tu lui as demandé si elle était fière, elle a dit : « Sang de mon sang. Comme Zé. »\n\nLe Consortium a déposé son tribut au pied du Cristo, comme exigé par la coutume. Dom Nilton a repris la route de São Paulo le lendemain. Le morro tient debout, et il tient à ton nom.\n\nTio Zé n'est jamais venu. Tu sais qu'il a vu les feux d'artifice du Cristo depuis sa fenêtre du Palace. Il est descendu une seule fois jusqu'au calçadão, à l'aube, pour glisser une enveloppe sous ta porte. Une photo de toi à six ans, sur ses épaules, devant le Pão de Açúcar. Pas de mot.",
	},
}

func _ready() -> void:
	visible = false
	if replay_button:
		replay_button.pressed.connect(_on_replay)
	if continue_button:
		continue_button.pressed.connect(_on_continue)
	if credits_button:
		credits_button.pressed.connect(_on_credits)
	EventBus.quest_completed.connect(_on_quest_completed)
	# Au chargement d'une save, si la run est terminée (Carnaval done) mais
	# l'épilogue jamais vu (ex. fermeture pendant l'épilogue), on le re-déclenche.
	SaveSystem.save_loaded.connect(_on_save_loaded)

func _on_save_loaded() -> void:
	if QuestManager.is_completed(QUEST_ID) and CampaignManager.chosen_endgame != CampaignManager.Endgame.NONE:
		_show_epilogue()

func _on_quest_completed(quest_id: String) -> void:
	if quest_id != QUEST_ID:
		return
	_show_epilogue()

func _show_epilogue() -> void:
	var path: int = CampaignManager.chosen_endgame
	if not EPILOGUES.has(path):
		return
	var data: Dictionary = EPILOGUES[path]
	if title_label:
		title_label.text = data.title
	if subtitle_label:
		subtitle_label.text = data.subtitle
	if body_label:
		body_label.text = _with_ze_fate(data.body)
	if run_label:
		var ng_count: int = _read_ng_count()
		if ng_count > 0:
			run_label.text = "Run %d · %d entrées de codex débloquées" % [ng_count + 1, NarrativeJournal.unlocked_count()]
		else:
			run_label.text = "Première run · %d entrées de codex débloquées" % NarrativeJournal.unlocked_count()
	visible = true
	get_tree().paused = true

func _on_continue() -> void:
	visible = false
	get_tree().paused = false

func _on_credits() -> void:
	var credits: Node = get_tree().current_scene.get_node_or_null("CreditsScreen")
	if credits and credits.has_method("open"):
		visible = false  # masque l'épilogue pendant les credits
		credits.open()

func _on_replay() -> void:
	# Sauvegarde méta : NG+ count + entrées journal débloquées (pour usage futur).
	_write_ng_meta()
	# Efface la save et recharge la scène. Le boot relancera une nouvelle partie.
	SaveSystem.discard_save()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _read_ng_count() -> int:
	if not FileAccess.file_exists(META_PATH):
		return 0
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return 0
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data is Dictionary:
		return int(data.get("ng_plus_count", 0))
	return 0

func _write_ng_meta() -> void:
	var data: Dictionary = {
		"ng_plus_count": _read_ng_count() + 1,
		"completed_paths": _read_completed_paths() + [_path_label(CampaignManager.chosen_endgame)],
		"last_codex_count": NarrativeJournal.unlocked_count(),
	}
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func _read_completed_paths() -> Array:
	if not FileAccess.file_exists(META_PATH):
		return []
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return []
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data is Dictionary:
		var arr: Array = data.get("completed_paths", [])
		return arr.duplicate()
	return []

func _path_label(path: int) -> String:
	match path:
		CampaignManager.Endgame.PREFEITO: return "prefeito"
		CampaignManager.Endgame.POLICIA: return "policia"
		CampaignManager.Endgame.TRAFICO: return "trafico"
		CampaignManager.Endgame.CONSORTIUM: return "consortium"
	return "unknown"

# Le dernier paragraphe (le sort de Zé au Palace) n'est vrai que si Zé y est
# encore : s'il a été démasqué (tio_ze_revealed) sans être secouru
# (ze_rescued), la Mafia da Baía l'a repris — l'épilogue l'assume.
func _with_ze_fate(body: String) -> String:
	if not CampaignManager.has_flag("tio_ze_revealed") or CampaignManager.has_flag("ze_rescued"):
		return body
	var parts: PackedStringArray = body.split("\n\n")
	if parts.is_empty() or parts[parts.size() - 1].find("Palace") == -1:
		return body
	parts[parts.size() - 1] = "La réception du Palace a un nouveau concierge, jeune, efficace, sans histoire. Personne n'a revu le vieux balayeur. Tu sais où il est — de l'autre côté de la baie, dans une pièce qui sent le tabac froid. Tu savais, et tu n'es pas allé. C'est la seule dette que personne ne viendra jamais te réclamer."
	return "\n\n".join(parts)
