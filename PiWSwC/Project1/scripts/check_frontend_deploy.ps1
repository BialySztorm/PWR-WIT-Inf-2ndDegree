<#
PowerShell helper to validate frontend deployment on Elastic Beanstalk (or any static host).
Usage:
  .\check_frontend_deploy.ps1 -EnvUrl 'http://your-env.us-east-1.elasticbeanstalk.com' -JsName 'assets/index-D0dHShHe.js' -CssName 'assets/index-BZ_Vcs0M.css'
Optional: provide -S3Bucket and -S3Key to download the bundle from S3 and list its contents (requires AWS CLI + Python).
#>
param(
    [Parameter(Mandatory=$true)][string]$EnvUrl,
    [string]$JsName = 'assets/index-D0dHShHe.js',
    [string]$CssName = 'assets/index-BZ_Vcs0M.css',
    [string]$S3Bucket = '',
    [string]$S3Key = ''
)

function Head-Url($url) {
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -ErrorAction Stop
        return @{Status = $resp.StatusCode; Length = $resp.Headers['Content-Length']; Type = $resp.Headers['Content-Type']}
    } catch {
        if ($_.Exception.Response -ne $null) {
            $code = $_.Exception.Response.StatusCode.Value__
            return @{Status = $code; Length = 0; Type = ''}
        }
        return @{Status = 'ERR'; Length = 0; Type = ''}
    }
}

Write-Host "Checking root page: $EnvUrl" -ForegroundColor Cyan
$indexPath = Join-Path (Get-Location) 'deployed_index.html'
try {
    Invoke-WebRequest -Uri $EnvUrl -UseBasicParsing -OutFile $indexPath -ErrorAction Stop
    Write-Host "Saved index to $indexPath" -ForegroundColor Green
    Get-Content $indexPath -TotalCount 40 | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "Failed to GET $EnvUrl : $_" -ForegroundColor Red
}

Write-Host "`nChecking assets:" -ForegroundColor Cyan
$jsUrl = "$EnvUrl/$JsName"
$cssUrl = "$EnvUrl/$CssName"

foreach ($pair in @(@{url=$jsUrl; name='JS'}, @{url=$cssUrl; name='CSS'})) {
    $u = $pair.url; $n = $pair.name
    Write-Host "\n-- $n -> $u" -ForegroundColor Yellow
    $h = Head-Url $u
    Write-Host ("Status: {0}  Content-Length: {1}  Content-Type: {2}" -f $h.Status, $h.Length, $h.Type)
    if ($h.Status -eq 200) {
        $outf = Join-Path (Get-Location) ([IO.Path]::GetFileName($u))
        try {
            Invoke-WebRequest -Uri $u -UseBasicParsing -OutFile $outf -ErrorAction Stop
            $sz = (Get-Item $outf).Length
            Write-Host "Downloaded to $outf (size: $sz)" -ForegroundColor Green
        } catch {
            Write-Host "Failed to download $u : $_" -ForegroundColor Red
        }
    }
}

if ($S3Bucket -and $S3Key) {
    Write-Host "`nS3 bundle check requested: downloading s3://$S3Bucket/$S3Key" -ForegroundColor Cyan
    $localBundle = Join-Path (Get-Location) 'eb_frontend_bundle.zip'
    try {
        aws s3 cp "s3://$S3Bucket/$S3Key" $localBundle --only-show-errors
        Write-Host "Downloaded bundle to $localBundle" -ForegroundColor Green
        # List contents using Python if available
        python - << 'PY'
import zipfile
z = zipfile.ZipFile('eb_frontend_bundle.zip')
for i, e in enumerate(z.infolist()):
    if i < 200:
        print(e.filename, e.file_size)
    else:
        break
PY
    } catch {
        Write-Host "Failed to download or inspect S3 bundle: $_" -ForegroundColor Red
    }
}

Write-Host "\nDone. If asset status is 404 or assets missing, check EB logs (eb-engine.log) and S3 bundle contents." -ForegroundColor Cyan

