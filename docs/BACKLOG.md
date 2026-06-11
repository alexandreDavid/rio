# Backlog — âme carioca

Trace des besoins de design issus de la critique du 2026-06-11 (« le jeu manque
d'intérêt, il doit représenter plus l'âme carioca »). Voir `.claude/skills/ame-carioca`
pour les principes. Mise à jour via le skill `backlog`.

## Quick wins

- [x] **Time de coração** — choisir son équipe à l'intro (Flamengo/Vasco/Flu/Botafogo) ; les NPCs et événements y réagissent. Pourquoi : le futebol est une identité carioca, pas un mini-jeu. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Événements de rue par phase** — roda de pagode le soir, altinha l'après-midi, dispute Fla x Flu qui te prend à témoin. Pourquoi : la rue est un théâtre, la vie n'attend pas le joueur. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Soirée vivante à Copacabana** — roda de samba au quiosque do Zé (le Musicien y migre au lieu de disparaître), futevôlei au posto. Pourquoi : le soir doit être différent du matin. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Passe gírias** — doser le lexique carioca dans tous les dialogues (texte uniquement). Pourquoi : 7 mentions culturelles dans tout le jeu, le parler fait l'âme. (ajouté 2026-06-11, livré 2026-06-11)

## Moyen terme

- [x] **Voie jeitinho** — sur ~10 quêtes clés, une 3e solution « tu connais quelqu'un » débloquée par l'affinité (`NPCAffinity`). Pourquoi : à Rio on résout par la relation avant l'argent ; l'affinité ne sert presque à rien aujourd'hui. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Feijoada de Dona Irene** — invitation comme jalon d'affinité : le moment où le quartier t'adopte. Pourquoi : la comida est sociale, pas un heal. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Blocos progressifs par acte** — des répétitions de bloco de plus en plus présentes à mesure qu'on approche du Carnaval. Pourquoi : rendre visible le compte à rebours annoncé à l'intro. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Souvenirs muets de Zé** — banc de dominos, chope marquée au bar, NPC qui t'appelle Zé par erreur. Pourquoi : la saudade est le cœur émotionnel du jeu, elle n'existe qu'en objectifs de quête. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Mureta da Urca animée le soir** — figurants assis, bières, guitare (BotafogoFlamengo.tscn, nécessite un toggle de phase dans le district). Pourquoi : c'est LE rituel carioca du soir. (ajouté 2026-06-11, livré 2026-06-11)

## Gros chantiers

- [ ] **Littoral continu Copa–Arpoador–Ipanema–Leblon** — étendre la bande à l'ouest du Forte au lieu de téléporter vers ZonaSul ; l'Arpoador en charnière, Lagoa/Jardim restent téléportés. Pourquoi : l'utilisateur veut moins de zones cloisonnées ; c'est LE seul raccord géographiquement honnête (littoral réellement continu), la fusion totale des 13 zones est rejetée (géographie de Rio non planaire, référentiels par district, gating narratif). (ajouté 2026-06-11)
- [ ] **Transitions sensorielles entre districts** — traverser le Túnel Velho à pied (pan caméra dans le noir), embarquement réel sur la barca de Niterói, au lieu du fondu-téléport. Pourquoi : gommer les coutures du modèle hub sans le casser. (ajouté 2026-06-11)

- [x] **Calendrier hebdomadaire** — jours de la semaine ; dimanche = plage bondée + messe + jour de match (ambiance du monde changée, NPCs euphoriques/en deuil selon le résultat). Pourquoi : transformer « le Carnaval est dans un mois » de phrase d'intro en pression jouée. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Coût humain des voies sombres** — tráfico/consórcio dégradent visiblement le quartier et les NPCs. Pourquoi : les contrastes morro/asfalto doivent être assumés, pas cosmétiques. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Récompenses non fongibles** — différencier ce que rapportent les activités (réputation par axe, items, invitations) pour que choisir ait du sens. Pourquoi : tout rapporte des R$ identiques, donc aucun choix n'a de saveur. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Histoire — tranche A (réparations)** — canon Zé recousu (révélation au médaillon → re-capture → rescue → retour au Palace), épilogues conditionnés, solde de dette incarné par Dom Nilton (4 scènes par voie). Pourquoi : incohérence concierge/captif, révélation jamais déclenchée en jeu, dette soldée par du code. (ajouté 2026-06-11, livré 2026-06-11)
- [x] **Histoire — tranche B (créations)** — la mère réagit au secret (chemise, hibiscus), scène de Zé au banc de dominos la veille de la Sapucaí (récompense du rescue), payoffs du pêcheur (2 événements), callback Pedrinho dans D8. Pourquoi : la saudade n'avait pas de présent, seulement des épilogues. (ajouté 2026-06-11, livré 2026-06-11)
- [ ] **Contessa après le gala** — une suite acte 3+ où elle devient une alliée/un levier (elle disparaît après son propre chef-d'œuvre). Pourquoi : personnage à voix, arc orphelin. (ajouté 2026-06-11)
