# Documentation du projet Terraform GKE

## 1. Explication des fichiers

### main.tf

Ce fichier est le cœur de la configuration Terraform. Il définit les ressources à créer dans Google Cloud Platform (GCP). Voici un aperçu des principales ressources :

- Configuration du provider Google Cloud
- Activation des APIs nécessaires (Kubernetes Engine et SQL Admin)
- Création d'un cluster GKE (Google Kubernetes Engine)
- Création d'une instance Cloud SQL PostgreSQL
- Déploiement d'une application web personnalisée dans le cluster GKE
- Configuration d'un load balancer Nginx

Le fichier configure également les interconnexions entre ces différents services, comme la connexion de l'application web à la base de données PostgreSQL.


### terraform.tfvars
Ce fichier contient les variables spécifiques au projet :
- `project_id` : L'ID du projet Google Cloud 
- `region` : La région où déployer les ressources

### variables.tf
Ce fichier définit les variables utilisées dans la configuration :
- `project_id` : L'ID du projet Google Cloud
- `region` : La région par défaut (us-central1, mais surchargée dans terraform.tfvars)
- `gke_num_nodes` : Le nombre de nœuds dans le cluster GKE (par défaut 2)

## 2. Prérequis

- Avoir un environnement fonctionnel avec [Terraform](https://developer.hashicorp.com/terraform/install?product_intent=terraform) ([Guide d'installation windows](https://stackoverflow.com/a/78325348)).
- Avoir un environnement avec [Google SDK](https://cloud.google.com/sdk/docs/install-sdk) installé et [configuré](https://cloud.google.com/sdk/docs/initializing).
- Avoir cloné ce repository Github

## 3. Comment lancer les commandes Terraform

1. **Placez vous dans le répertoire `./terraform-gcp`**

2. **Récupération des secrets**

   Assurez-vous d'avoir configuré correctement vos credentials Google Cloud et d'avoir les permissions nécessaires avant d'exécuter ces commandes. Le fichier `credentials.json` mentionné dans `main.tf` doit être présent dans le répertoire de travail.

   Pour récupérer ce fichier `credentials.json`, rendez vous sur la console de gcp > IAM & Admin > Service Accounts

   ![alt text](./captures/image.png)

   Cliquez sur le service account déjà créé.

   ![alt text](./captures/image-1.png)

   Ensuite Keys > Add Key > Create new key

   ![alt text](./captures/image-2.png)

   Choissisez le JSON et il va vous télécharger le `credentials.json`.

   ![alt text](./captures/image-3.png)

   Ensuite changez votre `"project_id"` et `"region"` dans le fichier `terraform.tfvars`
   
4. **Initialisation du projet**
   ```
   terraform init
   ```
   Cette commande initialise le répertoire de travail Terraform, télécharge les plugins nécessaires pour les fournisseurs Google et Kubernetes.

5. **Planification des changements**
   ```
   terraform plan
   ```
   Cette commande crée un plan d'exécution, vous montrant ce que Terraform va faire sans réellement appliquer les changements.

6. **Application des changements**
   ```
   terraform apply
   ```
   Cette commande applique les changements nécessaires pour atteindre l'état désiré de la configuration. Terraform vous demandera de confirmer avant d'appliquer les changements.

   Après un `terraform apply` réussi, vous pourrez accéder à votre application via l'IP du load balancer Nginx, qui sera affichée dans la sortie Terraform.

7. **Destruction de l'infrastructure (si nécessaire)**
   ```
   terraform destroy
   ```
   Cette commande détruit toutes les ressources créées par Terraform. Utilisez-la avec précaution et seulement quand vous voulez vraiment tout supprimer. Vérifiez que `"deletion_protection"` est `false` dans votre fichier `terraform.tfstate`
