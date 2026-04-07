Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Deploy: start app-green"
docker compose up -d app-green

Write-Host "Run health check through nginx endpoint"
& ".\scripts\health-check.ps1" -Url "http://localhost:8080"
if ($LASTEXITCODE -ne 0) {
  throw "Health check failed."
}

Write-Host "Health check passed. Switch traffic to app-green"
$nginxConf = ".\nginx\nginx.conf"
if (-not (Test-Path $nginxConf)) {
  throw "nginx.conf not found at $nginxConf"
}

$content = Get-Content $nginxConf -Raw
$content = $content -replace "(?m)^\s*server app-blue:80;", "    # server app-blue:80;"
$content = $content -replace "(?m)^\s*#\s*server app-green:80;", "    server app-green:80;"
Set-Content -Path $nginxConf -Value $content -NoNewline

docker compose restart nginx

Write-Host "Stop app-blue after switch"
docker compose stop app-blue

Write-Host "Deploy completed successfully."
