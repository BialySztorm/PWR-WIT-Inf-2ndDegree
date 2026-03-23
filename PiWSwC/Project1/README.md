# PWR Cloud Systems Project 1

Projekt składa się z:
- backendu Django (API)
- frontendu React + TypeScript (Vite)
- bazy PostgreSQL

## Wymagania
- Docker Desktop
- Docker Compose
- Node.js 20+ (tylko przy uruchamianiu frontendu lokalnie bez Dockera)

## Konfiguracja
W katalogu głównym projektu utwórz plik `.env` na bazie `.env.example`:

```powershell
Copy-Item .env.example .env
```

## Uruchomienie całości przez Docker
Uruchamiaj komendy z katalogu głównego projektu:

```powershell
docker compose up -d --build
docker compose exec backend python manage.py migrate
```

Aplikacja będzie dostępna pod adresami:
- Frontend: http://localhost:5173
- Backend healthcheck: http://localhost:8000/health/
- API wiadomości: http://localhost:8000/api/messages/
- API plików: http://localhost:8000/api/media/

## Uruchomienie tylko backendu (Django + Postgres)
Uruchamiaj komendy z katalogu głównego projektu:

```powershell
docker compose up -d --build db backend
docker compose exec backend python manage.py migrate
```

Backend będzie dostępny pod adresem:
- http://localhost:8000/health/

## Uruchomienie tylko frontendu lokalnie (bez Dockera)

```powershell
cd frontend
npm install
npm run dev
```

Frontend będzie dostępny pod adresem:
- http://localhost:5173

## Przydatne komendy

```powershell
# logi wszystkich usług
docker compose logs -f

# zatrzymanie i usunięcie kontenerów
docker compose down

# zatrzymanie i usunięcie kontenerów + wolumenów
docker compose down -v
```