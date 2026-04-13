param(
  [string]$backendImage = "mydockerhubuser/chat-backend:latest",
  [string]$frontendImage = "mydockerhubuser/chat-frontend:latest"
)

$deploy = Join-Path (Join-Path $PSScriptRoot "..") "deploy"
if (-not (Test-Path $deploy)) { New-Item -ItemType Directory -Path $deploy | Out-Null }

# Prepare backend Dockerrun
$backendTpl = Join-Path $deploy "Dockerrun.backend.json.template"
$backendOut = Join-Path $deploy "Dockerrun.backend.json"
(Get-Content $backendTpl) -replace '<BACKEND_IMAGE>', $backendImage | Set-Content $backendOut -Encoding UTF8
Write-Host "Created $backendOut"

# Prepare frontend Dockerrun (if needed)
$frontendTpl = Join-Path $deploy "Dockerrun.frontend.json.template"
$frontendOut = Join-Path $deploy "Dockerrun.frontend.json"
if (Test-Path $frontendTpl) {
  (Get-Content $frontendTpl) -replace '<FRONTEND_IMAGE>', $frontendImage | Set-Content $frontendOut -Encoding UTF8
  Write-Host "Created $frontendOut"
}

Write-Host "Done. Now build/push images to Docker Hub (or ECR) and update terraform to use Dockerrun if you prefer prebuilt images."
