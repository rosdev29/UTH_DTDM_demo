Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Rollback: switch traffic to app-blue"
$nginxConf = ".\nginx\nginx.conf"
if (-not (Test-Path $nginxConf)) {
  throw "nginx.conf not found at $nginxConf"
}

$content = Get-Content $nginxConf -Raw
$content = $content -replace "(?m)^\s*#\s*server app-blue:80;", "    server app-blue:80;"
$content = $content -replace "(?m)^\s*server app-green:80;", "    # server app-green:80;"
Set-Content -Path $nginxConf -Value $content -NoNewline

docker compose restart nginx

Write-Host "Stopping app-green and ensuring app-blue is running"
docker compose up -d app-blue
docker compose stop app-green

Write-Host "Rollback completed."
