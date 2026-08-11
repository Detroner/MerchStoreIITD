<#
PowerShell setup helper for Windows dev machines.

Run as: Open PowerShell as Administrator, cd to repo root and run: .\scripts\setup-windows.ps1

This script attempts to install Node.js (OpenJS.Node) and Docker Desktop using winget when available.
If winget isn't available, it prints manual install instructions and exits so you can install prerequisites yourself.
#>

function AbortWith($msg){ Write-Host $msg -ForegroundColor Red; exit 1 }

Write-Host "Checking prerequisites..." -ForegroundColor Cyan

$node = (Get-Command node -ErrorAction SilentlyContinue)
$npm  = (Get-Command npm -ErrorAction SilentlyContinue)
$docker = (Get-Command docker -ErrorAction SilentlyContinue)
$winget = (Get-Command winget -ErrorAction SilentlyContinue)

function TryInstallWithWinget($id, $friendlyName) {
  if (-not $winget) { return $false }
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
  if (-not $isAdmin) {
    Write-Host "Administrator privileges required to install $friendlyName via winget. Please re-run PowerShell as Administrator or install manually." -ForegroundColor Yellow
    return $false
  }
  Write-Host "Installing $friendlyName via winget (this may take a few minutes)..." -ForegroundColor Green
  winget install --accept-package-agreements --accept-source-agreements -e --id $id
  return $LASTEXITCODE -eq 0
}

# Install Node/npm if missing
if (-not $node -or -not $npm) {
  Write-Host "Node.js/npm not found." -ForegroundColor Yellow
  if ($winget) {
    if (TryInstallWithWinget 'OpenJS.Node' 'Node.js (OpenJS)') {
      Write-Host "Node installed. Refreshing session..." -ForegroundColor Green
      $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
      $node = (Get-Command node -ErrorAction SilentlyContinue)
      $npm  = (Get-Command npm -ErrorAction SilentlyContinue)
    } else {
      AbortWith "Automatic Node install failed. Please install Node.js 20+ from https://nodejs.org/ or use winget manually: winget install OpenJS.Node"
    }
  } else {
    AbortWith "Node.js/npm not found and winget not available. Install Node.js 20+ from https://nodejs.org/ then re-run this script."
  }
}

# Install Docker if missing
if (-not $docker) {
  Write-Host "Docker not found." -ForegroundColor Yellow
  if ($winget) {
    if (TryInstallWithWinget 'Docker.DockerDesktop' 'Docker Desktop') {
      Write-Host "Docker Desktop installed. Please start Docker Desktop and ensure WSL2 is enabled if required. Pausing for 5s to allow startup." -ForegroundColor Green
      Start-Sleep -Seconds 5
      $docker = (Get-Command docker -ErrorAction SilentlyContinue)
      if (-not $docker) { Write-Host "Docker CLI not yet available in PATH — you may need to log out/in or open a new shell after installation." -ForegroundColor Yellow }
    } else {
      AbortWith "Automatic Docker install failed. Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    }
  } else {
    AbortWith "Docker not found and winget not available. Install Docker Desktop from https://www.docker.com/products/docker-desktop and ensure it's running. Then re-run this script."
  }
}

Write-Host "Node and Docker detected (or installed). Installing npm packages..." -ForegroundColor Green
# Use npm ci when package-lock.json is present for deterministic installs; fall back to npm install otherwise
if (Test-Path -Path (Join-Path (Get-Location) 'package-lock.json')) {
  npm ci --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { AbortWith "npm ci failed." }
} else {
  Write-Host "package-lock.json not found — running npm install to generate a lockfile." -ForegroundColor Yellow
  npm install --no-audit --no-fund
  if ($LASTEXITCODE -ne 0) { AbortWith "npm install failed." }
}

# Generate admin password hash
[string]$adminPass = $args[0]
if (-not $adminPass) {
  $secure = Read-Host "Enter admin password to hash (input will be hidden)" -AsSecureString
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  $adminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
}
if (-not $adminPass) { AbortWith "No admin password provided." }

Write-Host "Hashing admin password with argon2..." -ForegroundColor Green
$hash = node scripts/hash-password.mjs "$adminPass" 2>$null
if ($LASTEXITCODE -ne 0 -or -not $hash) { AbortWith "Failed to generate admin password hash. Ensure node scripts/hash-password.mjs runs correctly after npm ci." }
$hash = $hash.Trim()
Write-Host "Admin password hash generated." -ForegroundColor Green

# Update .env file
$envPath = Join-Path -Path (Get-Location) -ChildPath '.env'
if (-not (Test-Path $envPath)) { Copy-Item .env.example .env -ErrorAction SilentlyContinue }

# Replace or add ADMIN_PASSWORD_HASH line safely
$text = Get-Content $envPath -Raw
if ($text -match 'ADMIN_PASSWORD_HASH=') {
  $text = $text -replace 'ADMIN_PASSWORD_HASH=.*','ADMIN_PASSWORD_HASH='+$hash
} else {
  $text = $text.TrimEnd() + "`r`nADMIN_PASSWORD_HASH=$hash`r`n"
}
Set-Content -Path $envPath -Value $text -Encoding UTF8
Write-Host "Updated .env with ADMIN_PASSWORD_HASH." -ForegroundColor Green

# Start Postgres via docker compose
Write-Host "Starting Postgres via docker compose..." -ForegroundColor Green
docker compose up -d postgres
if ($LASTEXITCODE -ne 0) { AbortWith "docker compose failed to start Postgres. Ensure Docker Desktop is running and docker compose is available." }

# Wait and check postgres health by attempting TCP connect to port 5432
Write-Host "Waiting for Postgres to become ready (up to 60s)..." -ForegroundColor Yellow
$ready = $false
for ($i=0; $i -lt 12; $i++) {
  try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect('127.0.0.1', 5432)
    if ($tcp.Connected) { $tcp.Close(); $ready = $true; break }
  } catch { }
  Start-Sleep -Seconds 5
}
if (-not $ready) { Write-Host "Postgres did not open port 5432 in time. Check Docker logs: docker compose logs postgres" -ForegroundColor Yellow }

# Run DB migrations
Write-Host "Running DB migrations..." -ForegroundColor Green
npm run db:migrate
if ($LASTEXITCODE -ne 0) { AbortWith "Migrations failed. Check logs above." }

Write-Host "Migrations applied. Starting server in foreground (Ctrl+C to stop)..." -ForegroundColor Green
npm start
