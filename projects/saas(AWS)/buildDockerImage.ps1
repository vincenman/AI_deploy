# Load .env into this session (PowerShell env vars do not persist across terminals)
. "$PSScriptRoot\scripts\setVariable.ps1"

if ([string]::IsNullOrWhiteSpace($env:NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY)) {
    throw "NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY is missing (check .env) - Next.js will fail with 'Missing publishableKey'"
}

docker build `
  --build-arg NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY="$env:NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY" `
  -t consultation-app .
if ($LASTEXITCODE -ne 0) { throw "docker build failed (exit $LASTEXITCODE)" }

Write-Host "Built consultation-app:latest"
