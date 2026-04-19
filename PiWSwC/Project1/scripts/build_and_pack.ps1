<#
PowerShell script to build frontend/backend and create deploy/*.zip
Usage examples:
  # Build both
  .\build_and_pack.ps1 -All
  # Only frontend
  .\build_and_pack.ps1 -Frontend
  # Only backend
  .\build_and_pack.ps1 -Backend
  # Skip npm install and build (useful if you only want to package existing dist)
  .\build_and_pack.ps1 -All -SkipBuild
#>
param(
    [switch]$Frontend,
    [switch]$Backend,
    [switch]$All,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Resolve-Path (Join-Path $scriptDir "..")
$projectRoot = $projectRoot.Path
$deployDir = Join-Path $projectRoot "deploy"
if (-not (Test-Path $deployDir)) { New-Item -ItemType Directory -Path $deployDir | Out-Null }

if (-not ($All -or $Frontend -or $Backend)) {
    Write-Host "No target specified. Defaulting to -All" -ForegroundColor Yellow
    $All = $true
}

function Pack-Frontend {
    Write-Host "==> Packaging frontend" -ForegroundColor Cyan
    $frontendDir = Join-Path $projectRoot "frontend"
    if (-not (Test-Path $frontendDir)) { Write-Error "Frontend directory not found: $frontendDir"; return }

    if (-not $SkipBuild) {
        if (Test-Path (Join-Path $frontendDir 'package.json')) {
            Push-Location $frontendDir
            try {
                Write-Host "Installing frontend dependencies..."
                npm ci
                Write-Host "Building frontend..."
                npm run build
            } catch {
                Write-Error "Frontend build failed: $_"
                Pop-Location
                throw
            }
            Pop-Location
        } else {
            Write-Host "No package.json found in frontend; skipping npm build" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Skipping frontend build (SkipBuild = true)" -ForegroundColor Yellow
    }

    # Create temp folder to collect files to zip
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $tmp = Join-Path $env:TEMP "frontend_package_$timestamp"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy Dockerfile if present
    $dockerfile = Join-Path $frontendDir 'Dockerfile'
    if (Test-Path $dockerfile) { Copy-Item $dockerfile -Destination $tmp }

    # If build output exists, prefer packaging it
    $buildDir = Join-Path $frontendDir 'dist'
    if (Test-Path $buildDir) {
        Write-Host "Found frontend build at 'dist', packaging dist" -ForegroundColor Green
        # Copy the entire dist directory CONTENTS into temp\dist so the 'assets' subdirectory is preserved
        $destDist = Join-Path $tmp 'dist'
        if (Test-Path $destDist) { Remove-Item $destDist -Recurse -Force }
        New-Item -ItemType Directory -Path $destDist | Out-Null
        Copy-Item -Path (Join-Path $buildDir '*') -Destination $destDist -Recurse -Force
        # If we are packaging prebuilt dist, create a simple Dockerfile that copies dist into nginx
        $tmpDocker = Join-Path $tmp 'Dockerfile'
        $dockerContents = @'
FROM httpd:2.4-alpine

# Instalacja openssl i generowanie certyfikatu
RUN apk add --no-cache openssl && \
    mkdir -p /usr/local/apache2/conf/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /usr/local/apache2/conf/ssl/selfsigned.key \
    -out /usr/local/apache2/conf/ssl/selfsigned.crt \
    -subj "/CN=localhost"

# Kopiowanie plików aplikacji
COPY dist/. /usr/local/apache2/htdocs/
RUN chmod -R 755 /usr/local/apache2/htdocs && chown -R www-data:www-data /usr/local/apache2/htdocs

RUN sed -i '/^#LoadModule ssl_module/s/^#//' /usr/local/apache2/conf/httpd.conf

COPY ssl.conf /usr/local/apache2/conf/extra/ssl.conf
RUN echo "Include conf/extra/ssl.conf" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80 443
'@
        Set-Content -Path $tmpDocker -Value $dockerContents -Encoding UTF8
        python (Join-Path $scriptDir 'remove_bom.py') $tmpDocker

        $tmpSSLConf = Join-Path $tmp 'ssl.conf'
        $sslConfContents = @'
<VirtualHost *:443>
    DocumentRoot "/usr/local/apache2/htdocs"
    SSLEngine on
    SSLCertificateFile "/usr/local/apache2/conf/ssl/selfsigned.crt"
    SSLCertificateKeyFile "/usr/local/apache2/conf/ssl/selfsigned.key"
    <Directory "/usr/local/apache2/htdocs">
        Require all granted
        Options -Indexes
    </Directory>
</VirtualHost>
'@
        Set-Content -Path $tmpSSLConf -Value $sslConfContents -Encoding UTF8
        python (Join-Path $scriptDir 'remove_bom.py') $tmpSSLConf
        # Do NOT include package.json or tsconfig when packaging prebuilt dist: prefer using prebuilt files
        # (including package.json/tsconfig would cause Dockerfile to try building on EB)

    } else {
        Write-Host "No dist directory found; packaging sources (selective)" -ForegroundColor Yellow
        # Copy selective source folders
        $pathsToCopy = @('src','public','package.json','package-lock.json','vite.config.ts','tsconfig.json')
        foreach ($p in $pathsToCopy) {
            $srcPath = Join-Path $frontendDir $p
            if (Test-Path $srcPath) {
                Copy-Item -Path $srcPath -Destination $tmp -Recurse -Force
            }
        }
    }

    $zipPath = Join-Path $deployDir 'frontend-src.zip'
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    # Use pack_zip.py to create zip with POSIX separators
    python (Join-Path $scriptDir 'pack_zip.py') $tmp -o $zipPath
    Write-Host "Created $zipPath" -ForegroundColor Green

    Remove-Item $tmp -Recurse -Force
}

function Pack-Backend {
    Write-Host "==> Packaging backend" -ForegroundColor Cyan
    $backendDir = Join-Path $projectRoot "backend"
    if (-not (Test-Path $backendDir)) { Write-Error "Backend directory not found: $backendDir"; return }

    # Create temp folder
    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    $tmp = Join-Path $env:TEMP "backend_package_$timestamp"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Path $tmp | Out-Null

    # Copy Dockerfile or Dockerrun if exists
    $dockerfile = Join-Path $backendDir 'Dockerfile'
    if (Test-Path $dockerfile) { Copy-Item $dockerfile -Destination $tmp }
    # DO NOT auto-copy deploy/backend/Dockerrun.aws.json - that file may contain ECR references and break EB builds

    # Copy python app files
    $pathsToCopy = @('manage.py','requirements.txt','api','config','Dockerfile')
    foreach ($p in $pathsToCopy) {
        $srcPath = Join-Path $backendDir $p
        if (Test-Path $srcPath) { Copy-Item -Path $srcPath -Destination $tmp -Recurse -Force }
    }

    # If migrations or other artifacts exist, include them
    $extra = @('migrations','.ebextensions')
    foreach ($p in $extra) {
        $srcPath = Join-Path $backendDir $p
        if (Test-Path $srcPath) { Copy-Item -Path $srcPath -Destination $tmp -Recurse -Force }
    }

    $zipPath = Join-Path $deployDir 'backend-src.zip'
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    # Use pack_zip.py to create zip with POSIX separators
    python (Join-Path $scriptDir 'pack_zip.py') $tmp -o $zipPath
    Write-Host "Created $zipPath" -ForegroundColor Green

    Remove-Item $tmp -Recurse -Force
}

try {
    if ($All -or $Frontend) { Pack-Frontend }
    if ($All -or $Backend) { Pack-Backend }
    Write-Host "Done." -ForegroundColor Green
} catch {
    Write-Error "Error during packaging: $_"
    exit 1
}

exit 0

