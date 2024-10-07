# Utiliser une image Python minimale
FROM python:3.12-slim

# Installer les dépendances pour PostgreSQL et build-essential
RUN apt-get update && apt-get install -y \
    libpq-dev build-essential

# Créer un répertoire pour l'application
WORKDIR /app

# Copier le fichier requirements.txt et installer les dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le reste du code dans le conteneur
COPY . .

# Exposer le port 8000 pour FastAPI
EXPOSE 8000

# Commande pour lancer l'application FastAPI avec Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

