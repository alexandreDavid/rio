extends RefCounted

# Préchargé par chemin depuis Phone.gd (const NewsFeed) — pas de class_name global.

# Contenu de l'app Notícias — manchettes réactives selon l'état narratif.
# Extrait de Phone.gd (god object 1100+ lignes) : la DONNÉE (état → manchettes)
# vit ici, la VUE (cartes UI) reste dans Phone._build_news_row. Pur : ne lit que
# les autoloads, aucune dépendance aux nodes du téléphone → testable isolément.
# Premier palier de la décomposition de Phone par app (cf. tech-debt #8).

const COLOR_AMBIENT: Color = Color(0.85, 0.85, 0.80)
const COLOR_CIVIC: Color = Color(0.55, 0.95, 0.55)
const COLOR_POLICE: Color = Color(0.55, 0.78, 0.95)
const COLOR_WARN: Color = Color(0.95, 0.62, 0.45)
const COLOR_SOCIETY: Color = Color(0.85, 0.55, 0.95)
const COLOR_WIN: Color = Color(0.95, 0.85, 0.40)

# Renvoie un tableau de Dictionaries {text, source, color}, du plus récent (haut)
# au plus contextuel (bas). Filtré sur l'état campagne / quêtes / dette.
static func build_items() -> Array:
	var out: Array = []
	var act: int = CampaignManager.current_act
	var debt: int = CampaignManager.debt_remaining()
	var day: int = TimeOfDay.day_count
	var endgame: int = CampaignManager.chosen_endgame

	# Manchettes endgame (acte 5 — règne).
	if act >= 5:
		match endgame:
			CampaignManager.Endgame.PREFEITO:
				out.append({"text": "Subprefeitura civica anunciada — Coronel do Bairro recebe a faixa", "source": "O Globo Rio", "color": COLOR_WIN})
			CampaignManager.Endgame.POLICIA:
				out.append({"text": "Operação Madrugada encerra ciclo de violência — Chefe de Polícia condecorado", "source": "Jornal do Brasil", "color": COLOR_WIN})
			CampaignManager.Endgame.TRAFICO:
				out.append({"text": "Hierarquia do Morro consolidada — novo Patrão silencia o bairro", "source": "Extra", "color": COLOR_WIN})

	# Pacto da Barra — pivot business.
	if CampaignManager.has_flag("barra_pacto_sealed"):
		out.append({"text": "Riserva Uno formaliza parceria de segurança privada — três condomínios alinhados", "source": "Veja Rio", "color": COLOR_SOCIETY})

	# Mendonça / commissaire — danger.
	if CampaignManager.has_flag("commissaire_alerted"):
		out.append({"text": "PM intensifica rondas na Barra após denúncia anônima de extorsão", "source": "Extra", "color": COLOR_WARN})

	# Endorsements — campagne politique (voie Prefeito en cours).
	if CampaignManager.has_flag("voie_prefeito"):
		out.append({"text": "Coalizão civica reúne padre, comerciantes e padaria histórica", "source": "O Globo Rio", "color": COLOR_CIVIC})

	# Pivot acte 2 — révélation Concierge.
	if CampaignManager.has_flag("tio_ze_revealed"):
		out.append({"text": "Concierge do Palace mantém perfil discreto — vizinhos surpreendem", "source": "Sociedade Rio", "color": COLOR_SOCIETY})

	# Operação Carnaval — voie Polícia engagée.
	if CampaignManager.has_flag("voie_policia"):
		out.append({"text": "PM divulga balanço de Operação Carnaval — silêncio sobre fontes", "source": "Jornal do Brasil", "color": COLOR_POLICE})

	# Crise dette élevée (joueur en retard).
	if act >= 2 and debt > 30000:
		out.append({"text": "Jovens cariocas enfrentam dívidas familiares herdadas — fenômeno cresce", "source": "Folha Rio", "color": COLOR_WARN})
	elif act >= 3 and debt > 0 and debt <= 5000:
		out.append({"text": "Histórias de superação no calçadão — perseverança paga dívidas", "source": "Diário do Bairro", "color": COLOR_CIVIC})

	# Niterói — chaîne consortium boucle vers la baie.
	if QuestManager.is_completed("bruno_carga"):
		out.append({"text": "MAC Niemeyer prepara exposição de junho — curadoria recebe peça inédita", "source": "Veja Rio", "color": COLOR_AMBIENT})

	# Réputation extrême.
	if ReputationSystem.get_value(ReputationSystem.Axis.POLICE) >= 50:
		out.append({"text": "Comunidade elogia 'cidadão exemplar' anônimo — PM agradece", "source": "Jornal do Brasil", "color": COLOR_POLICE})
	if ReputationSystem.get_value(ReputationSystem.Axis.STREET) >= 50:
		out.append({"text": "Lendas urbanas no Morro — sobrinho misterioso protege os pequenos", "source": "Extra", "color": COLOR_SOCIETY})

	# Carnaval — proche pendant acte 5 (reinado).
	if act >= 5:
		out.append({"text": "Sambódromo afinado — ensaios técnicos liberam ingressos do bloco", "source": "O Globo Rio", "color": COLOR_AMBIENT})
	else:
		out.append({"text": "Carnaval 2026 — preparativos começam nos blocos do bairro", "source": "O Globo Rio", "color": COLOR_AMBIENT})

	# Météo & vie de quartier — toujours présents pour donner du grain.
	out.append({"text": "Posto 5 registra recorde de surfistas no fim de semana", "source": "Extra", "color": COLOR_AMBIENT})
	out.append({"text": "Tempo na praia : sol forte, 32°C, ventos leves de sul", "source": "Diário do Bairro", "color": COLOR_AMBIENT})
	if day >= 5:
		out.append({"text": "Vendedores de milho assados disputam território no calçadão", "source": "Sociedade Rio", "color": COLOR_AMBIENT})
	return out
