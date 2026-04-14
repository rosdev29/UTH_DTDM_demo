param(
  [string]$Url = "http://localhost:8080",
  [int]$Retries = 3,
  [int]$SleepSec = 2,
  [switch]$UseNginxNetwork
)

for ($i = 1; $i -le $Retries; $i++) {
  if ($UseNginxNetwork) {
    docker compose exec -T nginx sh -c "wget -q -O /dev/null $Url"
    if ($LASTEXITCODE -eq 0) {
      Write-Host "Health check passed at attempt $i"
      exit 0
    }
  } else {
    try {
      $res = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -TimeoutSec 10
      if ($res.StatusCode -ge 200 -and $res.StatusCode -lt 400) {
        Write-Host "Health check passed at attempt $i"
        exit 0
      }
    } catch {
      # ignore and retry
    }
  }

  Write-Host "Attempt $i failed, retrying..."
  Start-Sleep -Seconds $SleepSec
}

Write-Host "Health check failed after $Retries attempts"
exit 1
