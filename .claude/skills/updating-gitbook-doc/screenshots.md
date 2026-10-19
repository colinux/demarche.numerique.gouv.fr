# Screenshots de la documentation

Workflow interactif pour **auditer** les screenshots existants d'une page, ou en **produire de nouveaux** (nouvelle fonctionnalité). Les images sont dans `~/code/doc.demarches-simplifiees.fr/.gitbook/assets/`.

## Mise en route

1. Vérifier que l'app Rails tourne sur `localhost:3000`, sinon demander à l'utilisateur de la lancer.
2. Ouvrir l'app dans le navigateur du MCP Playwright (`http://localhost:3000?locale=fr`) et le redimensionner à **1440x900** (`browser_resize`).
3. Demander à l'utilisateur d'ancrer cette fenêtre à droite de son écran et d'ouvrir la page de doc dans son propre navigateur, à gauche : la page publiée sur `doc.demarche.numerique.gouv.fr`, ou docsify en local s'il l'a lancé (`bunx docsify-cli serve . --port 4000` depuis le clone).

Notes de navigation :
- Les pages accessibles sans connexion (accueil, login…) se capturent sur la prod (`https://demarche.numerique.gouv.fr/...`) plutôt qu'en local.
- À la première navigation sur un domaine (local ou prod), ajouter `?locale=fr` (la locale reste ensuite en session) et fermer le bandeau `.fr-notice.fr-notice--info` (« demarches-simplifiees.fr s'appelle maintenant… ») en cliquant sur « Masquer le message ».

## Page cible

Si aucune page n'est donnée, demander laquelle auditer, par priorité :
- P0 : `tutoriels/tutoriel-administrateur.md`, `tutoriels/tutoriel-instructeur.md`
- P1 : `tutoriels/tutoriel-usager.md`, `pour-aller-plus-loin/routage.md`
- P2 : pages de l'API GraphQL

## Déroulé de l'audit

1. Lire le `.md` (Read) pour lister tous les screenshots dans l'ordre.
2. Pour chaque screenshot :
   1. Donner à l'utilisateur le lien vers la section de l'image (`https://doc.demarche.numerique.gouv.fr/{page}#{ancre}`) pour qu'il l'ait sous les yeux.
   2. Lire l'image (Read sur le fichier dans `.gitbook/assets/`), puis annoncer : numéro, nom du fichier, ce que montre l'image.
   3. **Annotation `"skip": true`** : passer à l'image suivante sans rien faire (service externe).
   4. **Annotation présente** : si sa `date` a moins de 30 jours, passer à la suivante. Sinon, naviguer directement vers son `url` et aller à l'étape 6.
   5. **Pas d'annotation** : déduire la page de l'app du contexte du tutoriel et du contenu de l'image. Si la route est sûre, y naviguer ; **sinon, demander à l'utilisateur** plutôt que chercher. Une fois sur la bonne page, identifier les vues et composants rendus (layout, vue, partiels, ViewComponents) dans le code de l'app.
   6. Demander à l'utilisateur si l'image est périmée, en restant concis : il voit les deux côte à côte.
   7. **Image à jour** : l'annoter si ce n'est pas fait, passer à la suivante.
   8. **Image périmée** :
      1. Lister les différences concrètes avec la page actuelle (éléments ajoutés, retirés, déplacés, style…).
      2. Proposer l'annotation complète, la faire valider.
      3. Capturer la nouvelle image (voir « Capture Playwright fiable ») dans `.gitbook/assets/`, nommée en dash-case, en **reproduisant le cadrage de l'ancienne** sans demander.
      4. Lire l'image capturée et la montrer. Recapturer si le cadrage ne convient pas, avant de toucher au `.md`.
      5. Mettre à jour la référence (`src`, `alt`) et l'annotation dans le `.md`.
      6. Faire valider le résultat par l'utilisateur.
      7. Commiter et ouvrir la PR (voir « Une PR par image »).
3. Après chaque image, afficher la progression (ex. « Image 3/49 traitée »).

Ne jamais remplacer une image ni modifier le `.md` sans accord explicite. Avancer image par image, sans sauter d'étape. Dans le doute, le dire et demander.

## Annotations

Commentaire HTML juste avant la balise `<figure>` ou `![]` de chaque screenshot traité :

```html
<!--screenshot
{
  "url": "/admin/procedures/:procedure_id/mail_templates/received_mail/edit",
  "selector": ".css-selector-si-capture-partielle",
  "steps": ["click:.element", "fill:#champ:valeur"],
  "view": ["app/views/layouts/application.html.erb", "app/views/chemin/vers/la/vue.html.erb", "app/components/mon_component.rb"],
  "date": "YYYY-MM-DD",
  "viewport": "1440x900",
  "hash": null,
  "preconditions": "état des données nécessaire",
  "authenticated_as": "test@exemple.fr",
  "crop": null,
  "data_sensitivity": false,
  "replaced": "ancien-nom-de-fichier.png",
  "gitbook_section": "### Titre de la section parente"
}
-->
```

- Obligatoires : `url`, `date`. Le reste est optionnel ; remplir ce qu'on peut, l'utilisateur complète.
- Le repo est **public** : pour une page capturée en local, `url` est un chemin sans hôte ni id local, complété par `preconditions`, jamais un `http://localhost:3000/...` avec un id de démarche local. Pour une page capturée sur la prod, `url` est l'URL complète `https://demarche.numerique.gouv.fr/...`.
- Services externes qu'on ne contrôle pas (FranceConnect, ProConnect…) : annotation réduite, ignorée aux audits suivants.

```html
<!--screenshot
{
  "skip": true,
  "reason": "Service externe concerné",
  "date": "YYYY-MM-DD"
}
-->
```

Nommage des nouvelles images : `{section}-{description}.png`, ex. `tuto-usager-connexion-franceconnect.png`, `tuto-instructeur-liste-dossiers.png`.

## Connexion et données de test

- Compte de seed avec tous les rôles : `test@exemple.fr` (mot de passe dans `db/seeds.rb`), connexion via `/users/sign_in?locale=fr`.
- Pour trouver une démarche au bon profil de champs (ex. un obligatoire, un facultatif **et** un conditionné, nécessaire au toggle « Voir les champs facultatifs et/ou conditionnés ») : `bin/rails runner` qui parcourt `admin.procedures` et inspecte `revision.root_types_de_champ_public` via `mandatory?` et `condition.present?`.
- Éditeur des modèles d'e-mail : `/admin/procedures/:procedure_id/mail_templates/:slug/edit`, slugs `initiated_mail`, `received_mail`, `closed_mail`, `refused_mail`, `without_continuation`, `re_instructed_mail`.

## Capture Playwright fiable

- Capturer avec `browser_run_code_unsafe` et `page.screenshot({ path, clip })` : les captures par `ref`/`element` expirent souvent.
- Cadrage précis : mesurer via `evaluate` (`getBoundingClientRect().y + window.scrollY`, largeur, hauteur) ou `boundingBox()`, puis passer les coordonnées en `clip`.
- Un `clip` **sous la ligne de flottaison** échoue (« Clipped area is either empty or outside the resulting image ») sans `fullPage: true`.
- Masquer les éléments flottants avant la capture (`addStyleTag`) : `.fixed-footer`, widget Crisp, mini-profiler, `nav[aria-label="Actions flottantes"]`.
- `file://` est bloqué par le MCP : servir une page locale en HTTP (`python3 -m http.server <port> --directory <dir>`).

## Une PR par image

1. Chaque image donne une PR indépendante : branche depuis `main` à jour (ex. `audit-screenshots/tuto-usager-commencer-demarche`), commit signé, push sur le fork, PR vers `betagouv`, puis retour sur `main` avant l'image suivante.
2. De retour sur `main`, le `.md` n'a plus les annotations des PR non mergées : c'est normal. Relire le fichier et ne modifier que la partie de l'image en cours.
3. Message de commit :

   ```
   docs({page}): mise à jour screenshot {description}

   Image: {ancien-fichier} → {nouveau-fichier}

   Différences visuelles:
   - {diff 1}
   - {diff 2}
   ```

4. Corps de la PR :

   ```markdown
   ## Mise à jour des captures d'écran — {Titre de la page}

   Page de la doc : [{titre}](https://doc.demarche.numerique.gouv.fr/{page})

   ### {N}. {Description du screenshot}

   📄 [Voir dans la doc](https://doc.demarche.numerique.gouv.fr/{page}#{ancre-de-la-section})

   **Diff :**
   - {diff 1}
   - {diff 2}

   **Après :**

   ![après](https://raw.githubusercontent.com/{owner-du-fork}/doc.demarches-simplifiees.fr/{branche}/.gitbook/assets/{nouvelle-image})

   **Avant :**

   ![avant](https://raw.githubusercontent.com/betagouv/doc.demarches-simplifiees.fr/main/.gitbook/assets/{ancienne-image})
   ```

## Aperçu d'un rendu GitBook pour la PR

docsify ne rend pas les `{% hint %}`. Pour un aperçu fidèle, construire un petit HTML « façon GitBook » (callout stylé, figures), le capturer, et l'héberger avec le skill `screenshot-gist` pour l'insérer dans la PR.
