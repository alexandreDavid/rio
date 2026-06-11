---
name: ame-carioca
description: Principes de design « âme carioca » du jeu Rio — à lire AVANT d'écrire ou modifier du contenu (dialogues, quêtes, NPCs, événements, mini-jeux). Garantit que tout nouveau contenu renforce la relation, le rythme et l'appartenance plutôt que la transaction.
---

# Âme carioca — boussole de design

Le jeu ne doit pas seulement se passer *à* Rio, il doit se passer *en carioca*.
Avant d'ajouter du contenu, vérifier qu'il touche au moins UN des piliers ci-dessous.

## Les piliers

1. **Le jeitinho** — la relation avant l'argent. Toute quête importante devrait offrir
   une solution par la débrouille/connaissance (`NPCAffinity`) en plus du cash ou de la force.
   Question test : « est-ce qu'on peut résoudre ça parce qu'on connaît quelqu'un ? »
2. **Le time de coração** — le flag `time_coracao` (flamengo/vasco/fluminense/botafogo,
   posé à l'intro) est une identité. Les NPCs peuvent y réagir ; les événements Fla x Flu
   l'utilisent. Placeholder `{time_coracao}` substitué par DialogueBridge.
3. **La rue comme théâtre** — la vie n'attend pas le joueur : rodas, altinha, blocos,
   disputes de bar. Utiliser `RandomEventManager` (filtre par phase) et les groupes
   `evening_only`. Le soir DOIT être différent du matin.
4. **La comida sociale** — la nourriture est un jalon relationnel (être invité à la
   feijoada = le quartier t'adopte), jamais un simple item.
5. **La saudade de Zé** — l'oncle disparu vit dans les détails muets : objets, lieux,
   lapsus des NPCs. La mélancolie douce est le contre-chant du soleil.
6. **Les contrastes assumés** — morro/asfalto. Les voies sombres (tráfico, consórcio)
   ont un coût humain visible chez les NPCs du quartier.

## Lexique gírias (dosage : max ~1 gíria toutes les 2-3 répliques)

Le jeu est en français avec un parfum portugais carioca. Déjà en usage : parceiro, salve.
À doser naturellement : caraca, maneiro, valeu, beleza, é nóis, mermão, pô, suave,
tranquilo, demorô, fala sério, cara, freguês, gringo, malandro, carioca da gema.
Football : Mengão (Flamengo), Fla x Flu, torcida, pelada, golaço, artilheiro.
JAMAIS : sous-titrer ou traduire une gíria dans le texte — le contexte suffit.

## Interdits

- Pas de récompense purement monétaire sur un contenu « culturel » (roda, feijoada,
  match) : préférer réputation, affinité, invitation, info.
- Ne pas toucher aux clés de knots, aux `choices` (index utilisés par les tests) ni
  aux `on_choose` lors d'une passe d'écriture — uniquement les valeurs `text`.
- Pas de cliché carte postale sans fonction (le décor est déjà fait) : tout ajout
  culturel doit être un comportement ou une relation, pas une image.

## Suivi

Les besoins/idées non implémentés vont dans `docs/BACKLOG.md` (voir skill `backlog`).
