# ecf-bilan-c6-k8s-apps

Ce dépôt contient le déploiement Kubernetes d'une application PostgreSQL via Helm, avec intégration CI/CD (GitHub Actions), authentification OIDC vers Azure, et sauvegarde/restauration via Velero.

## Sommaire

- [Structure du projet](#structure-du-projet)
- [Déploiement](#déploiement)
- [Test de persistance](#test-de-persistance)
- [Test de backup Velero](#test-backup-velero-sur-namespace-postgres-ns)

---

## Structure du projet

```
ecf-bilan-c6-k8s-apps/
├── .github/
│   └── workflows/
│       └── ci.yaml                  # Pipeline CI (Validation & Linting Helm)
├── argocd-apps/
│   └── postgres-app.yaml            # Déclaration de l'Application ArgoCD
├── helm/
│   └── postgres/
│       ├── templates/
│       │   ├── deployment.yaml      # StatefulSet / Deployment PostgreSQL
│       │   ├── pvc.yaml             # PersistentVolumeClaim (Azure Files NFS v4.1)
│       │   ├── secrets.yaml         # Secret Kubernetes (identifiants PostgreSQL)
│       │   ├── service.yaml         # Service ClusterIP (port 5432)
│       │   ├── storageClass.yaml    # StorageClass (file.csi.azure.com, nfsvers=4.1)
│       │   └── velero-schedule.yaml # Planification automatique des sauvegardes
│       ├── Chart.yaml               # Métadonnées du Chart Helm
│       └── values.yaml              # Configuration (mots de passe, volumes, cron)
├── scripts/
│   └── oidc.sh                      # Provisionnement Workload Identity & Velero
└── README.md                        # Documentation du projet
```

---

## Déploiement

### Prérequis

- Un cluster Kubernetes opérationnel avec accès `kubectl`
- Helm installé (v3+)
- Velero installé et configuré sur le cluster
- Un accès Azure valide (via authentification OIDC)

### 1. Authentification (Azure OIDC)

Le script `scripts/oidc.sh` gère l'authentification via OIDC vers Azure, nécessaire pour interagir avec les ressources cloud depuis le runner github.

```bash
./scripts/oidc.sh
```

### 2. Déploiement automatisé (CI/CD)

1. Authentification vers Azure via OIDC
2. Connexion au cluster Kubernetes
3. Déploiement/mise à jour du chart Helm

---

## Test de persistance

### A. Se connecter à PostgreSQL et créer une donnée

**Se connecter au pod PostgreSQL :**

```bash
kubectl exec -it deployment/postgres -n postgres-ns -- psql -U postgres
```

Une fois dans le prompt `postgres=#` :

```sql
-- 1. Créer une table de test
CREATE TABLE test_persistence (id INT, status TEXT);

-- 2. Insérer une ligne
INSERT INTO test_persistence VALUES (1, 'Le stockage Azure NFS fonctionne !');

-- 3. Vérifier l'insertion
SELECT * FROM test_persistence;

-- 4. Quitter psql
\q
```

### B. Supprimer le pod PostgreSQL (simuler une panne)

```bash
kubectl delete pod -n postgres-ns -l app=postgres
```

**Reconnecter au psql :**

```bash
kubectl exec -it deployment/postgres -n postgres-ns -- psql -U postgres
```

```sql
SELECT * FROM test_persistence;
```

> Si la donnée insérée précédemment est toujours présente, la persistance des données via le PVC/StorageClass est validée.

---

## Test backup Velero sur namespace postgres-ns

```bash
# 1. Créer un backup Velero du namespace
velero backup create test-postgres-backup \
  --include-namespaces postgres-ns \
  --wait

# 2. Simuler une perte totale (suppression du namespace et des volumes)
kubectl delete namespace postgres-ns
kubectl delete pv -l app.kubernetes.io/name=postgres

# 3. Restaurer depuis le backup
velero restore create --from-backup test-postgres-backup --wait

# 4. Vérifier que les données ont bien été restaurées
kubectl exec -it deployment/postgres -n postgres-ns -- psql -U postgres

SELECT * FROM test_persistence;
```

> Si les données insérées avant la suppression sont bien présentes après restauration, le mécanisme de backup/restore Velero est validé.