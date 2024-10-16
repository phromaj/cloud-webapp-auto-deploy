# Documentation du Projet "cloud-webapp-auto-deploy"

## Table des matières

1. [Introduction](#introduction)
2. [Prérequis](#prérequis)
3. [Lancement du projet en local](#lancement-du-projet-en-local)
   - [Cloner le dépôt](#cloner-le-dépôt)
   - [Configurer les variables d'environnement](#configurer-les-variables-denvironnement)
   - [Construire et lancer les conteneurs Docker](#construire-et-lancer-les-conteneurs-docker)
   - [Accéder à l'application](#accéder-à-lapplication)
4. [Explication des pipelines CI/CD](#explication-des-pipelines-cicd)
   - [Pipeline de construction et de publication de l'image Docker](#pipeline-de-construction-et-de-publication-de-limage-docker)
   - [Pipeline de déploiement Terraform sur GCP](#pipeline-de-déploiement-terraform-sur-gcp)
5. [Provisionnement de clusters Kubernetes](#provisionnement-de-clusters-kubernetes)
   - [Azure Kubernetes Service (AKS)](#azure-kubernetes-service-aks)
   - [Google Kubernetes Engine (GKE)](#google-kubernetes-engine-gke)
6. [Annexes](#annexes)
   - [Structure du projet](#structure-du-projet)

---

## Introduction

Le projet **"cloud-webapp-auto-deploy"** est une application web développée avec **FastAPI** qui utilise une base de données **PostgreSQL**. L'application affiche un compteur de visites et fournit des informations sur l'application et le système.

Ce projet est configuré pour être exécuté en local à l'aide de **Docker** et **Docker Compose**, et il est également configuré pour être déployé automatiquement sur le cloud en utilisant des pipelines CI/CD avec **GitHub Actions** et **Terraform**.

## Prérequis

Avant de commencer, assurez-vous d'avoir les éléments suivants installés sur votre machine :

- **Git** : pour cloner le dépôt.
- **Docker** : pour construire et exécuter les conteneurs Docker.
- **Docker Compose** : pour orchestrer les conteneurs.
- **Python 3.12** (facultatif) : si vous souhaitez exécuter l'application sans Docker.
- **Terraform** (facultatif) : pour déployer l'infrastructure sur GCP ou Azure si nécessaire.

## Lancement du projet en local

### Cloner le dépôt

Commencez par cloner le dépôt GitHub du projet sur votre machine locale :

```bash
git clone https://github.com/phromaj/cloud-webapp-auto-deploy.git
cd cloud-webapp-auto-deploy
```

### Configurer les variables d'environnement

Assurez-vous que le fichier `docker-compose.yml` contient les bonnes configurations. Dans ce cas, le fichier définit déjà les variables d'environnement nécessaires pour la base de données.

Vérifiez que les variables d'environnement pour la base de données sont correctes :

```yaml
environment:
  - DATABASE_URL=postgresql://postgres:password@db:5432/mydatabase
```

Si vous souhaitez modifier les informations de connexion à la base de données, mettez à jour ces valeurs en conséquence.

### Construire et lancer les conteneurs Docker

Pour construire et lancer l'application en local, utilisez Docker Compose :

```bash
docker-compose up --build
```

Ce fichier `docker-compose.yml` définit trois services :

- **fastapi** : le conteneur de l'application FastAPI.
- **db** : le conteneur de la base de données PostgreSQL.
- **caddy** : le serveur web Caddy pour servir l'application.

Docker Compose va construire les images nécessaires et lancer les conteneurs.

### Accéder à l'application

Une fois les conteneurs en cours d'exécution, vous pouvez accéder à l'application web en ouvrant votre navigateur et en naviguant vers :

```
http://localhost
```

L'application devrait afficher une page avec le compteur de visites et diverses informations sur le système.

## Explication des pipelines CI/CD

Le projet utilise GitHub Actions pour automatiser la construction et le déploiement de l'application. Deux workflows principaux sont définis :

1. **docker-image.yml** : Ce workflow construit et publie l'image Docker de l'application sur GitHub Container Registry (GHCR).
2. **gcp-tf-deploy.yml** : Ce workflow déploie l'application sur Google Cloud Platform (GCP) en utilisant Terraform.

### Pipeline de construction et de publication de l'image Docker

#### Fichier : `.github/workflows/docker-image.yml`

Ce workflow est déclenché dans les cas suivants :

- Lorsqu'il y a un push sur la branche `main`.
- Lorsqu'une pull request est ouverte sur la branche `main`.
- Lorsqu'une release est publiée.

**Étapes du workflow :**

1. **Checkout du dépôt :**

   ```yaml
   - uses: actions/checkout@v4
   ```

   Cette étape clone le dépôt dans l'environnement GitHub Actions.

2. **Construction et publication de l'image Docker :**

   ```yaml
   - name: Build and publish a Docker image for ${{ github.repository }}
     uses: macbre/push-to-ghcr@master
     with:
       image_name: ${{ github.repository }}
       github_token: ${{ secrets.GH_TOKEN }}
   ```

   Cette étape utilise l'action `macbre/push-to-ghcr` pour construire l'image Docker et la pousser vers GitHub Container Registry (GHCR).

   - `image_name` : le nom de l'image, basé sur le nom du dépôt GitHub.
   - `github_token` : le jeton GitHub pour authentifier la poussée de l'image vers GHCR.

**Remarque :**

- Assurez-vous que le secret `GH_TOKEN` est configuré dans les secrets du dépôt GitHub. Ce jeton doit avoir les autorisations nécessaires pour publier des packages.

### Pipeline de déploiement Terraform sur GCP

#### Fichier : `.github/workflows/gcp-tf-deploy.yml`

Ce workflow est déclenché lors d'un push ou d'une pull request sur la branche `main`.

**Étapes du workflow :**

1. **Permissions :**

   ```yaml
   permissions:
     contents: read
   ```

   Le workflow a uniquement besoin de permissions en lecture sur le contenu du dépôt.

2. **Configuration de l'environnement et du shell :**

   ```yaml
   defaults:
     run:
       shell: bash
       working-directory: ./terraform-gcp
   ```

   Toutes les commandes s'exécuteront dans le répertoire `terraform-gcp` en utilisant le shell Bash.

3. **Checkout du dépôt :**

   ```yaml
   - name: Checkout
     uses: actions/checkout@v3
   ```

   Cette étape clone le dépôt dans l'environnement GitHub Actions.

4. **Installation de Terraform :**

   ```yaml
   - name: Setup Terraform
     uses: hashicorp/setup-terraform@v1
   ```

   Installe la dernière version de Terraform pour exécuter les commandes suivantes.

5. **Initialisation de Terraform :**

   ```yaml
   - name: Terraform Init
     run: terraform init
     env:
       GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
   ```

   Initialise le répertoire de travail Terraform, télécharge les plugins nécessaires, etc.

6. **Planification de l'infrastructure :**

   ```yaml
   - name: Terraform Plan
     run: terraform plan -input=false
     env:
       GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
   ```

   Génère un plan d'exécution pour Terraform, montrant les actions qui seront effectuées.

7. **Application des changements (uniquement sur la branche `main` lors d'un push) :**

   ```yaml
   - name: Terraform Apply
     if: github.ref == 'refs/heads/main' && github.event_name == 'push'
     run: terraform apply -auto-approve -input=false
     env:
       GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
   ```

   Applique les changements planifiés, déployant l'infrastructure sur GCP.

**Remarques :**

- **Authentification GCP :** Le secret `GOOGLE_CREDENTIALS` doit être configuré dans les secrets du dépôt GitHub. Il doit contenir les informations d'authentification nécessaires pour accéder à votre compte GCP.

- **Variables Terraform :** Assurez-vous que les variables nécessaires sont définies dans le fichier `terraform.tfvars` ou via des variables d'environnement.

- **Conditions d'exécution :** La commande `terraform apply` n'est exécutée que lors d'un push sur la branche `main`, pas lors des pull requests.

## Provisionnement de clusters Kubernetes

Le projet inclut des configurations Terraform pour provisionner des clusters Kubernetes dans Azure et GCP.

### Azure Kubernetes Service (AKS)

Le dossier `terraform-az` contient la configuration pour déployer un cluster AKS sur Azure.

Fichier principal : `azure_deployment.tf`

Ce fichier Terraform définit les ressources suivantes :
- Un groupe de ressources Azure
- Un cluster AKS
- Un serveur Azure Database pour PostgreSQL
- Une base de données PostgreSQL
- Des règles de pare-feu pour la base de données
- Un déploiement Kubernetes pour l'application web
- Un service Kubernetes pour exposer l'application
- Un contrôleur d'entrée Nginx

Pour déployer sur Azure, suivez ces étapes :

1. Assurez-vous d'avoir Azure CLI installé et configuré sur votre machine.

2. Connectez-vous à votre compte Azure avec une souscription active :
   ```bash
   az login
   ```

3. Sélectionnez la souscription que vous souhaitez utiliser :
   ```bash
   az account set --subscription "Nom_ou_ID_de_votre_souscription"
   ```

4. Naviguez dans le dossier `terraform-az` :
   ```bash
   cd terraform-az
   ```

5. Créez un fichier `terraform.tfvars` et ajoutez la variable `postgres_password` :
   ```hcl
   postgres_password = "votre_mot_de_passe_securise"
   ```

6. Initialisez Terraform :
   ```bash
   terraform init
   ```

7. Planifiez le déploiement :
   ```bash
   terraform plan
   ```

8. Appliquez la configuration :
   ```bash
   terraform apply
   ```

### Google Kubernetes Engine (GKE)

Le dossier `terraform-gcp` contient la configuration pour déployer un cluster GKE sur Google Cloud Platform.

Fichiers principaux :
- `main.tf` : Configuration principale
- `variables.tf` : Définition des variables
- `terraform.tfvars` : Valeurs des variables (à remplir)

Ces fichiers Terraform définissent les ressources suivantes :
- Un cluster GKE
- Une instance Cloud SQL PostgreSQL
- Une base de données PostgreSQL
- Un déploiement Kubernetes pour l'application web
- Un service Kubernetes pour exposer l'application
- Un déploiement Nginx comme équilibreur de charge
- Des déploiements pour Prometheus et Grafana pour la surveillance

Pour plus de détails sur le déploiement GKE, veuillez consulter le fichier `README.md` dans le dossier `terraform-gcp`.

Pour déployer sur GCP, naviguez dans le dossier `terraform-gcp` et suivez les instructions du README :

```bash
cd terraform-gcp
cat README.md
```

**Note** : Assurez-vous d'avoir configuré les credentials appropriés pour Azure et GCP avant d'exécuter Terraform. 

- Pour Azure, vous devez être connecté via Azure CLI avec une souscription active, comme indiqué dans les étapes ci-dessus. 
- Pour GCP, vous devrez configurer une clé de compte de service et définir la variable d'environnement `GOOGLE_APPLICATION_CREDENTIALS`.

## Annexes

### Structure du projet

La structure du projet est la suivante :

```
/cloud-webapp-auto-deploy
├── .github/
│   └── workflows/
│       ├── docker-image.yml
│       └── gcp-tf-deploy.yml
├── Caddyfile
├── Dockerfile
├── LICENSE
├── README.md
├── codebase.md
├── collect_debug_info.sh
├── docker-compose.yml
├── main.py
├── models.py
├── requirements.txt
├── templates/
│   └── index.html
├── terraform-az/
│   └── azure_deployment.tf
├── terraform-gcp/
│   ├── README.md
│   ├── captures/
│   │   ├── image-1.png
│   │   ├── image-2.png
│   │   ├── image-3.png
│   │   └── image.png
│   ├── main.tf
│   ├── terraform.tfvars
│   └── variables.tf
├── terraform.tfstate
├── terraform.tfstate.backup
└── terraform.tfvars
```

