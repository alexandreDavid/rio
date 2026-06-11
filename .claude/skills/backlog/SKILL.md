---
name: backlog
description: Tenir la trace des besoins de design du jeu Rio dans docs/BACKLOG.md — à utiliser quand l'utilisateur exprime un besoin/une idée non immédiate, demande « où on en est », ou quand un chantier se termine (mettre à jour les statuts).
---

# Backlog — garder la trace des besoins

Source de vérité : `docs/BACKLOG.md` (versionné dans le repo).

## Quand l'utiliser

- L'utilisateur exprime un besoin, une idée ou une frustration qui ne sera pas traitée
  immédiatement → l'ajouter dans la bonne section avec une ligne datée.
- Un chantier se termine → passer l'entrée en `[x]` avec la date, sans la supprimer.
- L'utilisateur demande « où on en est » / « qu'est-ce qui reste » → lire le fichier
  et résumer par horizon.

## Format des entrées

```
- [ ] **Titre court** — description en une phrase. Pourquoi : <le besoin d'origine>. (ajouté 2026-06-11)
- [x] **Titre court** — ... (livré 2026-06-11)
```

## Règles

- Trois horizons : Quick wins / Moyen terme / Gros chantiers. Ne pas créer d'autres sections.
- Une entrée = un besoin testable en jeu, pas une tâche technique (« le soir doit être
  différent du matin », pas « ajouter un signal »).
- Toujours conserver le *pourquoi* d'origine — c'est la trace du besoin, pas juste du travail.
- Ne jamais réécrire l'historique : les entrées livrées restent cochées dans le fichier.
