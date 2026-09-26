# Load .env into this session (PowerShell env vars do not persist across terminals)
. "$PSScriptRoot\scripts\setVariable.ps1"

$required = @(
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

# Requires the new image to already be in ECR - run pushECR.ps1 first.
$image = "$env:AWS_ACCOUNT_ID.dkr.ecr.$env:DEFAULT_AWS_REGION.amazonaws.com/consultation-app:latest"

& $aws lambda update-function-code `
  --function-name consultation-app `
  --image-uri $image `
  --region $env:DEFAULT_AWS_REGION
if ($LASTEXITCODE -ne 0) { throw "lambda update-function-code failed (exit $LASTEXITCODE)" }

Write-Host "Lambda consultation-app now runs $image"
