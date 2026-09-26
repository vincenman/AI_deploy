# Load .env into this session (PowerShell env vars do not persist across terminals)
. "$PSScriptRoot\scripts\setVariable.ps1"

$required = @(
    'NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY',
    'AWS_ACCOUNT_ID',
    'DEFAULT_AWS_REGION'
)
$missing = $required | Where-Object {
    [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
}
if ($missing) {
    throw "Missing required values in .env: $($missing -join ', ')"
}

$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) {
    $candidate = Join-Path $env:LOCALAPPDATA 'Programs\Amazon\AWSCLIV2\aws.exe'
    if (Test-Path $candidate) { $aws = $candidate }
}
if (-not $aws) { throw "AWS CLI not found. Install it or add it to PATH." }

$registry = "$env:AWS_ACCOUNT_ID.dkr.ecr.$env:DEFAULT_AWS_REGION.amazonaws.com"
$image = "$registry/consultation-app:latest"

# 1. Authenticate Docker to ECR
& $aws ecr get-login-password --region $env:DEFAULT_AWS_REGION `
  | docker login --username AWS --password-stdin $registry
if ($LASTEXITCODE -ne 0) { throw "ECR login failed (exit $LASTEXITCODE)" }

# 2. Build for Linux/AMD64 (Lambda container images must be amd64)
docker build `
  --platform linux/amd64 `
  --provenance=false `
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$env:NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" `
  -t consultation-app .
if ($LASTEXITCODE -ne 0) { throw "docker build failed (exit $LASTEXITCODE)" }

# 3. Tag your image
docker tag consultation-app:latest $image
if ($LASTEXITCODE -ne 0) { throw "docker tag failed (exit $LASTEXITCODE)" }

# 4. Push to ECR
docker push $image
if ($LASTEXITCODE -ne 0) { throw "docker push failed (exit $LASTEXITCODE)" }

Write-Host "Pushed $image"
