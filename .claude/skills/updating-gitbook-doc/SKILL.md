---
name: updating-gitbook-doc
description: Use when changing the demarche.numerique.gouv.fr GitBook documentation (doc.demarche.numerique.gouv.fr, repo betagouv/doc.demarches-simplifiees.fr) — editing or adding pages, fixing links, renaming URLs, opening a GitBook change request, or when the user asks to audit, refresh or capture its screenshots (.gitbook/assets) from the local app.
argument-hint: "[page de doc, ex. tutoriels/tutoriel-usager.md]"
---

# Documentation GitBook de demarche.numerique

## Coordonnées

- Repo source, synchronisé avec GitBook dans les deux sens (**public**) : `betagouv/doc.demarches-simplifiees.fr`, branche `main`. Accès en **lecture seule** : on passe par un fork.
- Clone local : `~/code/doc.demarches-simplifiees.fr`, dont `origin` est le fork. Il est hors du repo de l'app : utiliser des chemins absolus et `git -C`.
- Source brute d'une page : `https://raw.githubusercontent.com/betagouv/doc.demarches-simplifiees.fr/main/<git.path>` (ex. `api-graphql/jeton-dauthentification/README.md`).
- Site publié : `https://doc.demarche.numerique.gouv.fr` (jumeau sur l'ancien domaine `doc.demarches-simplifiees.fr`, même contenu).
- GitBook : organisation `-L7_aClyGhmMzzsqtO4_`, site `site_WoSO1` (ancien domaine `site_Z1BDB`), space `-L7_aKvpAJdAIEfxHudA` (editMode `locked`).

## Règle d'or

Une page avec des images, des tableaux ou des onglets ne se remplace **jamais** en markdown via le MCP GitBook : l'import supprime les figures `../../.gitbook/assets/…`, même si on renvoie le markdown d'origine à l'octet près. `update_page` n'a pas de mode ajout.

## Choisir la voie de livraison, la plus fidèle d'abord

1. **PR sur le repo source** (via le fork) : le markdown fait l'aller-retour sans perte, images comprises. Voie par défaut, et seule voie pour les screenshots.
2. **Nouvelle sous-page** (`insert_page` en change request) : sans risque si le contenu n'a pas d'image.
3. **Snippet à coller dans l'éditeur GitBook**, à fournir à l'utilisateur (un `{% hint %}` y devient un bloc `/hint`).
4. **`update_page` complet en markdown** : seulement pour une page en texte seul (ni image, ni tableau, ni onglet), et toujours vérifier après.

Livrer par PR (le fork est le remote `origin` du clone : `git -C ~/code/doc.demarches-simplifiees.fr remote get-url origin`) :
- Synchroniser le fork avant de créer la branche : `gh repo sync <owner-du-fork>/doc.demarches-simplifiees.fr --source betagouv/doc.demarches-simplifiees.fr`, puis `git -C ~/code/doc.demarches-simplifiees.fr pull` sur `main`.
- `git -C ~/code/doc.demarches-simplifiees.fr add <page>.md .gitbook/assets/<image>`, puis commit signé (`git commit -S`) et `git push -u origin <branche>`.
- `gh pr create --repo betagouv/doc.demarches-simplifiees.fr --head <owner-du-fork>:<branche>`.
- Supprimer les images devenues inutiles : `git rm` **uniquement** les fichiers suivis par git et référencés nulle part (grep sur les `.md`). Beaucoup d'assets du clone sont des copies locales non suivies.

## Rendu de `{% hint %}`

Le markdown du repo source et l'import markdown du MCP comprennent `{% hint style="warning" %}…{% endhint %}`. L'éditeur WYSIWYG et docsify l'affichent en texte brut.

## Selon la tâche, lire

- Audit ou capture de screenshots : `screenshots.md`. Page cible : `$ARGUMENTS`.
- Change request via le MCP GitBook (flux, pièges de l'import, vérification) : `change-requests.md`.
