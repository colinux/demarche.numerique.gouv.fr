# Change requests via le MCP GitBook

Le contenu publié ne se modifie que par **change request**. `updateChangeRequestContent` accepte du markdown, mais son import perd de l'information sur les pages riches (images supprimées, titres dégradés, liens internes aplatis). Relire la règle d'or et le choix de la voie dans `SKILL.md` avant de toucher une page existante.

Authentification : `mcp__gitbook__authenticate`, puis demander à l'utilisateur d'ouvrir l'URL renvoyée. Les outils apparaissent après l'OAuth.

## Flux

1. `create_change_request({spaceId, subject})` : garder le `changeRequestId` renvoyé.
2. `invoke_operation("updateChangeRequestContent", {path:{spaceId, changeRequestId}, body:{changes:[…]}})` : une entrée par modification (`update_page` / `insert_page` / `delete_page` / `revert_page`). Le lot est atomique : une modification invalide fait rejeter tout le lot.
3. **Ne pas merger** sauf demande explicite : laisser le brouillon à la relecture de l'équipe. Le merge est destructif et se répercute sur le repo GitHub. Pour merger : `submit_or_merge_change_request`.

Navigation et lecture : `list_sites` → `get_site_structure` → lecture des pages. `get_page` fonctionne **par `pageId`** ; **par `path`**, il échoue (« API operation not found ») : passer par l'opération brute `getPageByPath` ou par `get_page({pageId})`. Les sous-pages et leurs ids sont dans le tableau `pages[]` de `getPageInChangeRequestById` / `getPageByPath`.

## Pièges de l'import markdown

| Symptôme après un `update_page` en markdown | Cause | Correction |
|---|---|---|
| Titre de page en double et tous les titres décalés d'un niveau (H4 → **gras**) | Un `# Titre de la page` en tête du markdown | **Omettre le `# Titre`** : GitBook ajoute le titre depuis la propriété de la page. Commencer à `##`. Cela supprime à la fois le doublon et la cascade. |
| Un `####` s'affiche en gras | GitBook ne garde que 3 niveaux de titre | Rester en `##` / `###`. |
| Les images disparaissent | L'import supprime `<figure><img src="../../.gitbook/assets/…">` (et les URL gitbook.io complètes), **même avec le markdown d'origine à l'octet près** | Ne jamais remplacer en entier une page avec images : voir les voies de `SKILL.md`. |
| Un lien interne devient du texte | L'import ne résout pas les liens relatifs `foo.md`, ni un lien vers une page créée dans le **même** lot | Lier par `/pages/<pageId>` (résolu vers le bon chemin). La page cible doit déjà exister : la créer dans un premier lot, lire son id dans le `pages[]` de `getPageInChangeRequestById`, puis ajouter le lien dans un second lot. |

Les niveaux de titre se décalent d'un cran à l'import (`##` envoyé → `###` rendu). Ne pas chercher la correspondance exacte : vérifier (ci-dessous) et ajuster.

## Recettes

Récupérer la source exacte (évite les erreurs de recopie sur les longues URL d'images) :

```
curl -fsS https://raw.githubusercontent.com/betagouv/doc.demarches-simplifiees.fr/main/<git.path> -o page.md
```

Échapper un long markdown sans casse (l'échappement à la main casse sur les tabulations des blocs de code et produit un JSON invalide) : écrire le markdown dans un fichier, puis

```
python3 -c 'import json,pathlib; print(json.dumps(pathlib.Path("page.md").read_text(), ensure_ascii=False))'
```

et coller le résultat en `document.markdown`.

**Vérifier (obligatoire)** : réexporter la page du change request et la comparer à la base publiée avec **la même opération et les mêmes paramètres**, pour distinguer un vrai changement d'une bizarrerie d'export :

```
getPageInChangeRequestById({… , format:"markdown", dereferenced:true})   # version du change request
getPageById({… , format:"markdown", dereferenced:true})                  # base publiée
```

Contrôler que les titres correspondent à la base, que les images sont toujours là et que les liens internes sont toujours des liens. Itérer jusqu'à un résultat propre. Si la page est abîmée, `revert_page` vers la base et changer de voie.

Limiter la taille des réponses : avec le format par défaut, `getPageInChangeRequestById` renvoie un JSON énorme (tronqué vers 6 k tokens). Utiliser `format:"markdown"` + `computed:false` pour n'avoir que la liste des sous-pages, ou `dereferenced:true` pour voir les images et liens résolus.

## Particularités de cette doc

- L'ancienne page de schéma `demarches-simplifiees.fr/graphql/schema/mutation.doc.html` est en **404 sur les deux domaines**. L'explorateur de schéma est sur `https://demarche.numerique.gouv.fr/graphql` ; la doc de chaque mutation sur `https://demarche.numerique.gouv.fr/graphql/schema/mutations/<mutationName>` (camelCase).
- `static.demarches-simplifiees.fr` dans les exemples de réponse JSON est le vrai hôte du stockage objet : ne pas le renommer à l'aveugle en « renommant les URL ».
