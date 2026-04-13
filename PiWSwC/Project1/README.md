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

## Reset chatu / bazy (PostgreSQL)
### Opcja A (najprostsza): usuń wolumeny Dockera (kasuje całą bazę)
Uwaga: to usunie wszystkie wiadomości i pliki z bazy.

```powershell
docker compose down -v
docker compose up -d --build
docker compose exec backend python manage.py migrate
```

### Opcja B: wyczyść tylko tabele (zostawia wolumeny)
Jeśli chcesz zachować wolumeny, ale skasować dane aplikacji:

```powershell
docker compose exec backend python manage.py shell
```

W shellu:

```python
from api.models import Message, UploadedMedia, UserProfile

Message.objects.all().delete()
UploadedMedia.objects.all().delete()
UserProfile.objects.all().delete()
```

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

## Terraform (infrastruktura AWS)
Folder `infra/` zawiera Terraform do utworzenia zasobów w AWS (m.in. Cognito).

### Wymagania
- Terraform zainstalowany lokalnie
- Dane dostępowe do AWS ustawione jako zmienne środowiskowe (np. z AWS Learner Lab)

Przykład (PowerShell):

```powershell
$env:AWS_ACCESS_KEY_ID="..."
$env:AWS_SECRET_ACCESS_KEY="..."
$env:AWS_SESSION_TOKEN="..."
$env:AWS_DEFAULT_REGION="us-east-1"   # lub inny region
```

### Uruchomienie Terraform
```powershell
cd infra
terraform init
terraform apply
```

### Przydatne outputy (do konfiguracji frontendu/backendu)
```powershell
terraform output -raw aws_region
terraform output -raw cognito_user_pool_id
terraform output -raw cognito_app_client_id
terraform output -raw cognito_domain_full
terraform output -raw cognito_issuer
```

### Usunięcie infrastruktury
```powershell
cd infra
terraform destroy
```

## Zmienne środowiskowe frontendu

Frontend Vite czyta `VITE_*` w czasie budowania obrazu, więc dla uruchomienia przez `docker compose` wartości muszą być dostępne w rootowym `.env` projektu i przekazane jako `build.args`.

Dla uruchomienia lokalnie bez Dockera używaj pliku `frontend/.env.local`.
Dla builda produkcyjnego frontendu używaj `frontend/.env.production`.

Jeśli zmieniasz `VITE_COGNITO_*`, zrób ponowny build:

```powershell
docker compose up -d --build frontend
```

## Przydatne komendy

```powershell
# logi wszystkich usług
docker compose logs -f

# zatrzymanie i usunięcie kontenerów
docker compose down

# zatrzymanie i usunięcie kontenerów + wolumenów
docker compose down -v
```

## Przygotowanie paczek do Elastic Beanstalk (frontend-src.zip / backend-src.zip)

Elastic Beanstalk wymaga źródła aplikacji w postaci ZIP. Poniżej znajdziesz dwa bezpieczne sposoby na przygotowanie plików:

1) Szybkie spakowanie źródła (użyj gdy posiadasz w katalogach `frontend/` i `backend/` pliki `Dockerfile` lub `Dockerrun.aws.json`)

- Frontend (spakuje pliki frontendowe + Dockerfile):
```powershell
# z katalogu projektu
Remove-Item -Force deploy\frontend-src.zip -ErrorAction SilentlyContinue
# wejdź do katalogu frontend
Push-Location frontend
# (opcjonalnie) zainstaluj zależności i zbuduj jeśli potrzebujesz (np. generujesz dist dla Dockerfile)
npm ci
npm run build
# wróć do katalogu głównego i spakuj wybrane pliki/foldery
Pop-Location
Compress-Archive -Path frontend\Dockerfile, frontend\dist, frontend\package.json, frontend\public -DestinationPath deploy\frontend-src.zip -Force
```

- Backend (spakuje kod backendu + Dockerfile):
```powershell
Remove-Item -Force deploy\backend-src.zip -ErrorAction SilentlyContinue
Push-Location backend
# (opcjonalnie) przygotuj pliki, np. zbierz statyczne lub wygeneruj potrzebne artefakty
# python -m pip install -r requirements.txt  (jeśli lokalnie testujesz)
Pop-Location
# Spakuj wybrane pliki/foldery (dostosuj listę jeśli masz inne struktury)
Compress-Archive -Path backend\Dockerfile, backend\manage.py, backend\requirements.txt, backend\api, backend\config -DestinationPath deploy\backend-src.zip -Force
```

Uwaga: Compress-Archive nie ma prostego exclude; dlatego dobieramy konkretne pliki/foldery do spakowania. Jeśli chcesz spakować *wszystko* z katalogu (szybko), możesz użyć:
```powershell
Push-Location frontend
Compress-Archive -Path * -DestinationPath ..\deploy\frontend-src.zip -Force
Pop-Location
```
ale pamiętaj, że to też spakuje `node_modules` i inne duże katalogi — lepiej spakować tylko potrzebne pliki.

2) Alternatywa: pakowanie gotowego buildu frontendu (jeśli frontend jest statyczny)

Jeśli frontend tworzy statyczne pliki (`dist`), możesz spakować tylko `dist` i ewentualny `Dockerfile` lub prosty `nginx` Dockerfile.

```powershell
Push-Location frontend
npm ci
npm run build
Pop-Location
Remove-Item -Force deploy\frontend-src.zip -ErrorAction SilentlyContinue
Compress-Archive -Path frontend\dist, frontend\Dockerfile -DestinationPath deploy\frontend-src.zip -Force
```

3) Sprawdzenie zawartości ZIP

Po stworzeniu ZIP-a możesz sprawdzić zawartość poleceniem (jeśli masz 7zip lub unzip). Przy użyciu PowerShell:
```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::OpenRead("deploy\frontend-src.zip").Entries | Select-Object FullName
```

4) Upload i deploy (przykład z Terraform / ręcznie)

- Jeżeli używasz Terraform z `aws_s3_object` i `aws_elastic_beanstalk_application_version` (jak w `infra/`), po utworzeniu ZIP-ów uruchom zwykły `terraform apply` (Terraform wyśle pliki do S3 i utworzy wersję aplikacji).
- Możesz też ręcznie wrzucić `deploy/frontend-src.zip` i `deploy/backend-src.zip` do S3 i wskazać je w Elastic Beanstalk jako Source Bundle.

Jeśli chcesz, dopiszę skrypt PowerShell (`scripts/build_and_pack.ps1`) do repozytorium, który automatyzuje te kroki (build frontendu, stworzenie ZIP-ów). Czy chcesz, żebym go utworzył?
