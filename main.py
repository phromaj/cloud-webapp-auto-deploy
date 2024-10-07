import os
import platform
import psycopg2
import fastapi
from fastapi import FastAPI, Depends, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from models import Base, VisitCounter
from fastapi.templating import Jinja2Templates

DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://user:password@localhost:5432/mydatabase')

# Configuration de la base de données
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Créer les tables
Base.metadata.create_all(bind=engine)

app = FastAPI()

# Configurer Jinja2 et le dossier des templates
templates = Jinja2Templates(directory="templates")

# Dépendance pour obtenir la session de la base de données
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root(request: Request, db: Session = Depends(get_db)):
    # Vérifier si un compteur existe
    counter = db.query(VisitCounter).first()
    if not counter:
        counter = VisitCounter(count=1)
        db.add(counter)
    else:
        counter.count += 1
    db.commit()

    # Récupérer les informations dynamiques
    # Informations sur la base de données
    db_info = "PostgreSQL"
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()
        db_info = db_version[0]
        cursor.close()
        conn.close()
    except Exception as e:
        db_info = f"Erreur lors de la récupération des informations : {e}"

    # Informations sur le framework
    framework_info = f"FastAPI {fastapi.__version__}"

    # Informations sur le serveur
    server_info = os.getenv("SERVER_SOFTWARE", "Uvicorn")

    # Informations sur le système d'exploitation
    os_info = platform.system()

    # Informations sur le port
    port_info = os.getenv("PORT", "8000")

    # Informations sur le conteneur
    container_info = os.getenv("CONTAINER_NAME", "FastAPI App")

    # Renvoyer le template Jinja2 avec le compteur et les informations
    return templates.TemplateResponse("index.html", {
        "request": request,
        "count": counter.count,
        "db_info": db_info,
        "framework_info": framework_info,
        "server_info": server_info,
        "os_info": os_info,
        "port_info": port_info,
        "container_info": container_info
    })
