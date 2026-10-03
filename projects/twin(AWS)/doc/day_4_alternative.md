# Day 4 (Alternative): Terraform Practice Lab — Keep Your Twin, Learn IaC Risk-Free

> **What this file is:** an alternative to `doc/day4.md` for anyone who wants to keep their live Digital Twin running while learning Infrastructure as Code. You will build a small, disposable practice project with Terraform instead of deleting your twin. The Terraform skills are exactly the same — this lab just applies them to throwaway resources.

---

## Why You Can Skip the "Clean Slate" (Day 4, Part 1)

`day4.md` starts by asking you to delete everything you built manually in Days 2–3 (Lambda, API Gateway, S3 buckets, CloudFront). The teacher asks for this because Terraform's job is to create **and manage** your infrastructure from scratch:

- If old manual resources linger, it gets confusing which Lambda/bucket/API is "the real one".
- You would pay twice for duplicate infrastructure (two Lambdas, two CloudFront distributions).
- The course wants a clean console so Terraform's `plan` output matches exactly what you see in AWS.

That is fine when your twin is a throwaway exercise. **Your twin is not.** It is live, it has the daily/monthly quota system you built, and you may be sharing it as a demo. Deleting it would undo Days 2–3 of work.

**So here is the replacement plan:** you build a brand-new, minimal project called **`iac-lab`** in its own folder, with its own Terraform state and its own resource names. It teaches `init → plan → apply → change → workspaces → destroy` on a tiny API that costs nothing. When you run `terraform destroy` on the lab, only the lab is deleted — your twin is untouched by design.

### The 5 Safety Rules (read before running any Terraform command)

1. **Separate folder:** the lab lives in `D:\Training\AI_deploy\projects\iac-lab` — completely separate from `twin` and `twin(AWS)`. Never run `terraform` commands from your twin folders.
2. **Unique names:** every lab resource starts with `iac-lab-` (e.g. `iac-lab-dev-api`). If you ever see `twin-...` in a `terraform plan` or `terraform destroy` output — **STOP**, you are in the wrong folder or using wrong variables.
3. **Separate state:** Terraform only manages resources recorded in *its own* state file. The lab's state lives in the lab's `terraform/` folder. It has never seen your twin and has no way to delete it.
4. **Never `terraform import`** your twin's resources into this lab.
5. **Guard rail:** the lab's destroy script refuses to run if the plan mentions any `twin-` resource (see Part 6).

✅ **Checkpoint:** you understand that the lab is a sandbox. Your twin stays live the whole time.

---

## What You'll Build

A tiny "greeting API" — intentionally simple so you can focus on Terraform, not application code:

```
You (curl / browser)
   │
   ▼
HTTP API Gateway  (iac-lab-dev-api-gateway)
   │  AWS_PROXY integration
   ▼
Lambda (Python 3.12)  (iac-lab-dev-api)
   │
   ▼
JSON responses:  GET /   GET /health   GET|POST /greet?name=You
```

Optional extension: a static practice page on **S3** (and optionally **CloudFront**), mirroring Day 4's frontend.

**Skills you will practice** (the same ones Day 4 teaches):

- `terraform init` / `plan` / `apply` / `destroy`
- Providers, resources, locals, variables, outputs, tags
- State files and `terraform state list`
- Workspaces for dev/test isolation
- `source_code_hash` so Terraform notices new Lambda code
- Reading a plan (create `+`, update `~`, destroy `-`)

---

## Part 0: Prerequisites

### 0.1 Install Terraform (not installed on this machine yet)

**Option A — winget (recommended on Windows 11):**

```powershell
winget install --id Hashicorp.Terraform --exact
```

Then **close and reopen your terminal** (PATH changes only apply to new terminals) and verify:

```powershell
terraform --version
```

You should see something like `Terraform v1.x.x`. If `winget` is not available, use Option B.

**Option B — manual download (same instructions as `day4.md`, Part 2):**

1. Visit https://developer.hashicorp.com/terraform/install
2. Download the Windows package (zip)
3. Extract `terraform.exe` to a folder, e.g. `C:\Tools\terraform`
4. Add that folder to your `PATH` (Start → "Environment Variables" → edit `Path` → add `C:\Tools\terraform`)
5. Reopen the terminal and run `terraform --version`

### 0.2 Check your AWS CLI

```powershell
aws sts get-caller-identity
```

It should show your `aiengineer` user (that's the account the twin lives in). One region note:

- Your CLI **default region is currently `us-east-1`**, but your twin actually lives in **`us-east-2`**.
- The lab pins its region **explicitly in code** (`aws_region = "us-east-2"` in `terraform.tfvars`), so Terraform does not care about the CLI default.
- For ad-hoc `aws` commands in this lab, add `--region us-east-2`. Optional convenience: `aws configure set region us-east-2` to make that the default for all future commands.

### 0.3 Check Python

```powershell
python --version
```

Needs to be Python 3.9+ (you have 3.13 — fine). It is only used to build the Lambda zip.

### 0.4 Create the project folder

In Cursor: right-click `D:\Training\AI_deploy\projects` → **New Folder** → name it `iac-lab`.

Final structure you are aiming for:

```
iac-lab/
├── .gitignore
├── lambda/
│   ├── handler.py
│   └── build.py
├── terraform/
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── site/                 (optional extension, Part 7)
│   └── index.html
└── scripts/              (optional extension, Part 6)
    ├── deploy.ps1
    └── destroy.ps1
```

---

## Part 1: Terraform Concepts in 60 Seconds

If you want the full explanations, read **Part 2 of `day4.md`** — it is tool-agnostic and still applies. Here is the cheat sheet you will use today:

| Concept | What it means | Where you'll see it |
|---|---|---|
| **Configuration** | `.tf` files describing what you want | Part 2 of this guide |
| **Provider** | Plugin that talks to AWS (`hashicorp/aws`) | `versions.tf` |
| **Resource** | One AWS object (`aws_lambda_function`, `aws_s3_bucket`, …) | `main.tf` |
| **Variable** | Input you can change without editing logic | `variables.tf` + `terraform.tfvars` |
| **Local** | Computed value reused in many places (`name_prefix`, tags) | `main.tf` |
| **Output** | Value printed after `apply` (URLs, names) | `outputs.tf` |
| **State** | Terraform's record of what it created | `terraform.tfstate.d/<workspace>/` |
| **Workspace** | Separate state for dev/test/prod | Part 5 of this guide |

---

## Part 2: Create the Lab Files

Create each file in Cursor with the exact content below.

### 2.1 `.gitignore` (in the `iac-lab` root)

```gitignore
# Terraform state and cache — never commit these
.terraform/
*.tfstate
*.tfstate.*
.terraform.lock.hcl
terraform.tfstate.d/

# Lambda build output (rebuilt by lambda/build.py)
lambda/lambda-deployment.zip

# IDE / OS
.vscode/
.DS_Store
```

> Why this matters: the state file is the map between your config and real AWS resources. It must never be hand-edited or committed. The provider binary cache (`.terraform/`) is big and machine-specific.

### 2.2 `lambda/handler.py`

```python
import json
import os
from datetime import datetime, timezone

GREETING = os.environ.get("GREETING", "Hello from Terraform!")


def handler(event, context):
    """Tiny JSON API: /, /health, /greet (GET ?name= or POST {"name": "..."})."""
    http = event.get("requestContext", {}).get("http", {})
    method = http.get("method", "GET")
    path = event.get("rawPath", "/")

    if path == "/":
        status, body = 200, {"message": GREETING, "managed_by": "terraform"}
    elif path == "/health":
        status, body = 200, {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}
    elif path == "/greet":
        query = event.get("queryStringParameters") or {}
        name = (query.get("name") or "").strip()
        if not name and event.get("body"):
            try:
                name = (json.loads(event["body"]).get("name") or "").strip()
            except (json.JSONDecodeError, AttributeError):
                name = ""
        message = f"{GREETING} Nice to meet you, {name}!" if name else GREETING
        status, body = 200, {"message": message, "method": method}
    else:
        status, body = 404, {"message": f"No route for {method} {path}"}

    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
```

No third-party libraries — uses only the Python standard library, so the zip stays tiny and simple.

### 2.3 `lambda/build.py`

```python
"""Build lambda-deployment.zip from handler.py. Run: python build.py"""
import zipfile
from pathlib import Path

here = Path(__file__).resolve().parent
zip_path = here / "lambda-deployment.zip"

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.write(here / "handler.py", arcname="handler.py")

print(f"Built {zip_path} ({zip_path.stat().st_size} bytes)")
```

### 2.4 `terraform/versions.tf`

```hcl
terraform {
  required_version = ">= 1.9"   # 1.9+ allows multiple validation blocks per variable

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # Explicit region — the lab must not depend on your CLI default region.
  region = var.aws_region
}
```

### 2.5 `terraform/variables.tf`

```hcl
variable "project_name" {
  description = "Name prefix for all lab resources"
  type        = string
  default     = "iac-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = var.project_name != "twin"
    error_message = "This lab must use its own prefix so it can never collide with your live twin."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "aws_region" {
  description = "AWS region for the lab (same as your twin is fine — names never collide)"
  type        = string
  default     = "us-east-2"
}

variable "greeting_text" {
  description = "Text the API returns — change it and re-apply to watch Terraform update the Lambda"
  type        = string
  default     = "Hello from Terraform!"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle steady-state rate (requests per second)"
  type        = number
  default     = 5
}
```

### 2.6 `terraform/main.tf`

```hcl
data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "day4-practice"
  }
}

# --- IAM: the role the Lambda assumes -------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# --- Lambda function (zip built by lambda/build.py) -----------------------
resource "aws_lambda_function" "api" {
  filename         = "${path.module}/../lambda/lambda-deployment.zip"
  function_name    = "${local.name_prefix}-api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.handler"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda-deployment.zip")
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  tags             = local.common_tags

  environment {
    variables = {
      GREETING = var.greeting_text
    }
  }
}

# --- HTTP API -------------------------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api-gateway"
  protocol_type = "HTTP"
  tags          = local.common_tags

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = ["*"]
    max_age           = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
  tags        = local.common_tags

  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# --- Routes (each route key is METHOD + path) -----------------------------
resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_greet" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /greet"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "post_greet" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /greet"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# --- Allow API Gateway to invoke the Lambda -------------------------------
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
```

### 2.7 `terraform/outputs.tf`

```hcl
output "api_url" {
  description = "Base URL of the lab API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "health_url" {
  description = "Health check URL"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/health"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "api_gateway_id" {
  description = "API Gateway ID (handy for debugging and cleanup)"
  value       = aws_apigatewayv2_api.main.id
}
```

### 2.8 `terraform/terraform.tfvars`

```hcl
project_name             = "iac-lab"
environment              = "dev"
aws_region               = "us-east-2"
greeting_text            = "Hello from Terraform!"
lambda_timeout           = 10
api_throttle_burst_limit = 10
api_throttle_rate_limit  = 5
```

✅ **Checkpoint:** your folder matches the tree in Part 0.4 (site/ and scripts/ can come later).

---

## Part 3: First Deploy (dev)

### Step 1: Build the Lambda zip

```powershell
cd D:\Training\AI_deploy\projects\iac-lab\lambda
python build.py
```

Expected: `Built ...\lambda-deployment.zip (xxxx bytes)`.

> Git Bash users: same command works from `D:/Training/AI_deploy/projects/iac-lab/lambda`.

### Step 2: Initialize Terraform

```powershell
cd ..\terraform
terraform init
```

Expected: `Terraform has been successfully initialized!` — this downloads the AWS provider (a few tens of MB, once per project).

### Step 3: Create the dev workspace, format, validate

```powershell
terraform workspace new dev
terraform fmt
terraform validate
```

- `workspace new dev` creates **and selects** a workspace named `dev`.
- `fmt` rewrites your files in canonical style (a good habit).
- `validate` checks syntax without touching AWS.

### Step 4: Read the plan (the most important habit)

```powershell
terraform plan
```

You should see a summary like `Plan: 11 to add, 0 to change, 0 to destroy.` (exact count can vary with provider version). All addresses look like `aws_lambda_function.api`, `aws_apigatewayv2_stage.default`, … and all names start with `iac-lab-dev-`.

**Read the plan before every apply.** Symbols: `+` create, `~` update in place, `-/+` replace, `-` destroy. If you ever see a resource named `twin-...` in a destroy list, stop and ask why.

### Step 5: Apply

```powershell
terraform apply
```

Type `yes` when prompted. First apply takes ~1–2 minutes (IAM role + Lambda + HTTP API).

### Step 6: Test it

```powershell
terraform output
$api = terraform output -raw api_url

curl.exe -s "$api/"
curl.exe -s "$api/health"
curl.exe -s "$api/greet?name=Vincent"
curl.exe -s -X POST "$api/greet" -H "Content-Type: application/json" -d '{"name":"Vincent"}'
```

Expected responses (yours will differ in wording only):

```json
{"message": "Hello from Terraform!", "managed_by": "terraform"}
{"status": "ok", "time": "2026-..."}
{"message": "Hello from Terraform! Nice to meet you, Vincent!", "method": "GET"}
{"message": "Hello from Terraform! Nice to meet you, Vincent!", "method": "POST"}
```

> In PowerShell use `curl.exe` (not `curl` — that's an alias for `Invoke-WebRequest`). In Git Bash: `API=$(terraform output -raw api_url); curl -s "$API/health"`.

### Step 7: Verify in the console — and verify your twin is still alive

```powershell
# The lab resources exist:
aws lambda list-functions --region us-east-2 `
  --query "Functions[?starts_with(FunctionName, 'iac-lab')].FunctionName" --output table

aws apigatewayv2 get-apis --region us-east-2 `
  --query "Items[?starts_with(Name, 'iac-lab')].Name" --output table

# Your twin is untouched:
aws lambda get-function --function-name twin-api --region us-east-2 `
  --query "Configuration.FunctionName" --output text

curl.exe -s https://geqmekl6zk.execute-api.us-east-2.amazonaws.com/health
```

You should see the lab functions AND `twin-api` AND a 200 from the twin health check. Two separate worlds, same account.

### Step 8: Peek into the state

```powershell
terraform state list
terraform workspace show
```

`state list` shows Terraform's inventory of what it owns — this is how it knows what to update and delete later. `workspace show` prints `dev`.

### Step 9: Confirm idempotence

```powershell
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.` This is the heart of IaC — the config, the state, and the real infrastructure agree.

✅ **Checkpoint:** dev environment deployed, tested, and stable — and your twin never noticed.

---

## Part 4: Change It and Watch Terraform Update It

### Step 1: Change a variable (no code rebuild needed)

Open `terraform/terraform.tfvars` and change:

```hcl
greeting_text = "Hello again from Terraform!"
```

Then:

```powershell
terraform plan
```

Read the plan: it should show `~ update in-place` on `aws_lambda_function.api` (the `environment` block changed), with `0 to add, 1 to change, 0 to destroy`.

```powershell
terraform apply
curl.exe -s "$(terraform output -raw api_url)/"
```

The greeting changed. You just modified production infrastructure by editing a text file.

### Step 2 (extra credit): Add a new route + new code

This teaches how Terraform notices *code* changes (`source_code_hash`) and *infra* changes in the same apply.

1. In `lambda/handler.py`, add a branch before `else:`:

   ```python
       elif path == "/version":
           status, body = 200, {"version": "1.0", "deployed_with": "terraform"}
   ```

2. In `terraform/main.tf`, add:

   ```hcl
   resource "aws_apigatewayv2_route" "get_version" {
     api_id    = aws_apigatewayv2_api.main.id
     route_key = "GET /version"
     target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
   }
   ```

3. Rebuild the zip and apply:

   ```powershell
   python ..\lambda\build.py
   terraform plan      # shows: + new route, ~ lambda update (source_code_hash changed)
   terraform apply
   curl.exe -s "$(terraform output -raw api_url)/version"
   ```

Why the Lambda updates: `source_code_hash` is a fingerprint of the zip. New code → new fingerprint → Terraform uploads it. (Environment-only changes, like Step 1, don't need a rebuild.)

And the new route works immediately because the stage has `auto_deploy = true` — the same "deployment" concept you met earlier when you set API Gateway throttling by hand.

✅ **Checkpoint:** you have made both a config change and a code change, and watched Terraform plan and apply each of them.

---

## Part 5: A Second Environment with Workspaces

Your twin taught you why environments matter (you would never test on the live demo). Terraform workspaces give each environment its own state and its own resource names.

### Step 1: Create and deploy the test workspace

```powershell
terraform workspace new test
terraform apply -var="environment=test"
```

Note the `-var` override: the workspace is `test`, and the variable makes names `iac-lab-test-*` (the `terraform.tfvars` default of `dev` is overridden). **Rule of thumb: the `environment` variable and the workspace should always match.**

### Step 2: Compare the two environments

```powershell
terraform output -raw api_url        # a NEW, different API URL (test)
curl.exe -s "$(terraform output -raw api_url)/health"

terraform workspace list
terraform workspace show
```

```powershell
aws lambda list-functions --region us-east-2 `
  --query "Functions[?starts_with(FunctionName, 'iac-lab')].FunctionName" --output table
```

You should now see **four** lambda-ish names: `iac-lab-dev-api` and `iac-lab-test-api`, plus their roles. Fully isolated — same as the "different conversations in different tabs" trick from `day4.md`, but here you own both sides.

### Step 3: How the state stays separate

```
terraform/
└── terraform.tfstate.d/
    ├── dev/
    │   └── terraform.tfstate     ← only dev resources
    └── test/
        └── terraform.tfstate     ← only test resources
```

Switching workspace switches which state file Terraform reads: `terraform workspace select dev` and the outputs point back at the dev URL.

✅ **Checkpoint:** two isolated environments, one configuration.

---

## Part 6 (Optional): One-Command Scripts

Once you trust the manual flow, wrap it up like `day4.md` does. Create `scripts/deploy.ps1`:

```powershell
param(
    [string]$Environment = "dev",
    [string]$ProjectName = "iac-lab"
)
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent

Write-Host "Building Lambda package..." -ForegroundColor Yellow
Set-Location (Join-Path $root "lambda")
python build.py

Write-Host "Applying Terraform ($Environment)..." -ForegroundColor Yellow
Set-Location (Join-Path $root "terraform")
terraform init -input=false

if (-not (terraform workspace list | Select-String $Environment)) {
    terraform workspace new $Environment
} else {
    terraform workspace select $Environment
}

terraform apply -var="project_name=$ProjectName" -var="environment=$Environment" -auto-approve

$apiUrl = terraform output -raw api_url
Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "API URL : $apiUrl" -ForegroundColor Cyan
Write-Host "Health  : $apiUrl/health" -ForegroundColor Cyan
```

And `scripts/destroy.ps1` — note the built-in twin guard:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    [string]$ProjectName = "iac-lab"
)
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
Set-Location (Join-Path $root "terraform")

if (-not (terraform workspace list | Select-String $Environment)) {
    Write-Host "Workspace '$Environment' does not exist." -ForegroundColor Red
    exit 1
}
terraform workspace select $Environment

# Safety guard: never destroy anything that mentions twin resources
$planText = terraform plan -destroy -no-color `
    -var="project_name=$ProjectName" -var="environment=$Environment" | Out-String
if ($planText -match "twin-") {
    Write-Host "STOP: the destroy plan mentions twin resources. Check your folder/variables." -ForegroundColor Red
    exit 1
}

# Empty the site bucket if the website extension (Part 7) was applied here
if (terraform state list | Select-String "aws_s3_bucket.site") {
    $bucket = terraform output -raw site_bucket
    Write-Host "Emptying $bucket ..." -ForegroundColor Yellow
    aws s3 rm "s3://$bucket" --recursive
}

terraform destroy -var="project_name=$ProjectName" -var="environment=$Environment" -auto-approve
Write-Host "Lab '$Environment' destroyed. Your twin is untouched." -ForegroundColor Green
```

Usage:

```powershell
cd D:\Training\AI_deploy\projects\iac-lab
.\scripts\deploy.ps1 -Environment dev
.\scripts\destroy.ps1 -Environment test
```

> If PowerShell blocks the script ("running scripts is disabled"), run once:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` — or invoke it as `powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1`.

---

## Part 7 (Optional): Static Website Extension (S3 + CloudFront)

Mirrors Day 4's frontend served from S3, minus Next.js. Terraform loads **all** `.tf` files in the folder, so we add a new file instead of editing `main.tf`.

### Step 1: Add `terraform/site.tf`

```hcl
# S3 bucket for the static practice page (account ID makes the name globally unique)
resource "aws_s3_bucket" "site" {
  bucket = "${local.name_prefix}-site-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.site.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.site]
}

output "site_bucket" {
  value = aws_s3_bucket.site.id
}

output "site_url" {
  value = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
```

> Notice: outputs don't have to live in `outputs.tf`. Any `.tf` file in the folder can define anything.

### Step 2: Create `site/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>iac-lab</title>
</head>
<body>
  <h1>iac-lab static site</h1>
  <p>Uploaded to S3 by Terraform.</p>
  <button onclick="greet()">Call the API</button>
  <pre id="out"></pre>

  <script>
    // Paste the output of: terraform output -raw api_url
    const API = "PASTE-YOUR-API-URL-HERE";

    async function greet() {
      const res = await fetch(`${API}/greet?name=Visitor`);
      document.getElementById("out").textContent = JSON.stringify(await res.json(), null, 2);
    }
  </script>
</body>
</html>
```

### Step 3: Apply and upload

```powershell
# In terraform/ (dev workspace)
terraform apply

$bucket = terraform output -raw site_bucket
aws s3 cp ..\site\index.html "s3://$bucket/index.html"
terraform output -raw site_url
```

Open the `site_url` in a browser. (Paste your real `api_url` into `index.html` first and re-run the `aws s3 cp` line if you want the button to work.)

### Step 4 (optional, slow): Add CloudFront in front

Only if you want the full Day 4 experience. Append to `site.tf`:

```hcl
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  tags                = local.common_tags

  origin {
    domain_name = aws_s3_bucket_website_configuration.site.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.site.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.site.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "site_cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}
```

```powershell
terraform apply                       # creating CloudFront takes 5-15 minutes
terraform output -raw site_cloudfront_url
```

⚠️ **Slow teardown warning:** `terraform destroy` on a CloudFront distribution also takes 5–15 minutes (it disables, waits, then deletes). That's normal. If you're short on time, skip this step — the S3 website alone already teaches the frontend bucket pattern.

---

## Part 8: Destroy the Lab (and Prove the Twin Is Untouched)

The final Day 4 skill: tearing down with one command. This is where the lab design pays off — destroy only ever sees `iac-lab-*` resources.

### Step 1: Destroy test

```powershell
cd D:\Training\AI_deploy\projects\iac-lab\terraform
terraform workspace select test
terraform destroy -var="environment=test"
```

(If you added the website in the test workspace: `aws s3 rm "s3://$(terraform output -raw site_bucket)" --recursive` first — S3 buckets must be empty before Terraform can delete them.)

### Step 2: Destroy dev

```powershell
terraform workspace select dev

# If you added the website extension:
if (terraform state list | Select-String "aws_s3_bucket.site") {
    aws s3 rm "s3://$(terraform output -raw site_bucket)" --recursive
}

terraform destroy
```

### Step 3: Remove the workspaces

```powershell
terraform workspace select default
terraform workspace delete test
terraform workspace delete dev
```

### Step 4: Final verification

```powershell
# Lab is gone:
aws lambda list-functions --region us-east-2 `
  --query "Functions[?starts_with(FunctionName, 'iac-lab')].FunctionName" --output table

# Twin is alive:
curl.exe -s https://geqmekl6zk.execute-api.us-east-2.amazonaws.com/health
curl.exe -s -o NUL -w "%{http_code}" https://d2x406ty7t8qp3.cloudfront.net
```

The first command returns an empty table. The second returns the twin's health JSON and `200`. **That is the whole point of this lab: you practiced full create/change/destroy cycles without ever putting your live project at risk.**

And because it's all code: `.\scripts\deploy.ps1 -Environment dev` rebuilds the whole lab anytime you want to practice again.

✅ **Checkpoint:** lab destroyed, twin untouched, skills acquired.

---

## Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| `terraform: command not found` after install | You opened the terminal before installing, or PATH isn't updated. Close **all** terminals, open a new one, retry. |
| Apply fails: `open ...lambda-deployment.zip: no such file` | Run `python build.py` in `lambda/` first. The zip is gitignored and must be built locally. |
| `BucketAlreadyExists` | Extremely unlikely (names include your account ID). If it happens, change `project_name` in `terraform.tfvars`. |
| Endpoint returns `{"message":"Internal Server Error"}` | Check logs: `aws logs tail /aws/lambda/iac-lab-dev-api --region us-east-2 --since 10m`. Usually a typo in `handler.py`; fix, rebuild zip, apply. |
| `404` / `{"message":"Not Found"}` on a path | HTTP API routes are exact `METHOD /path` pairs. A `POST` needs a `POST` route; `GET /greet?name=x` needs the `GET /greet` route. List routes: `aws apigatewayv2 get-routes --api-id $(terraform output -raw api_gateway_id) --region us-east-2 --query "Items[].RouteKey" --output table`. |
| Code changed but the API still responds with old behavior | Rebuild the zip (`python build.py`) **then** `terraform apply`. Terraform compares `source_code_hash` against the zip file. |
| `terraform workspace select test` then apply without `-var` created/planned wrong names | Always pass the same `-var="environment=..."` as the workspace. If resources were created under the wrong names, destroy with the matching var and retry. |
| In PowerShell, `curl` opens a weird response object | Use `curl.exe`. PowerShell aliases `curl` to `Invoke-WebRequest`. |
| Destroy seems stuck on CloudFront | 5–15 minutes is normal. Let it finish; don't Ctrl+C. |
| `Error: Invalid value for variable "environment"` | Must be exactly one of `dev`, `test`, `prod`. |

---

## What You Practiced (Day 4 Concept Map)

| `day4.md` topic | This lab equivalent |
|---|---|
| Part 1: Clean Slate (delete manual resources) | **Skipped on purpose.** Replaced by the 5 Safety Rules + isolated `iac-lab` project. |
| Part 2: Terraform concepts + install | Part 0 (install) + Part 1 (concept table). |
| Part 3: `.tf` files (provider/variables/main/outputs/tfvars) | Part 2 — same file layout, smaller config. |
| Part 4: deploy/destroy scripts | Part 6 (`scripts/deploy.ps1`, `scripts/destroy.ps1`). |
| Part 5: Deploy dev | Part 3. |
| Part 6: Deploy test (workspaces) | Part 5. |
| Part 7: Destroy | Part 8. |
| Part 8: Custom domain (optional) | Not needed for practice — read it when you do it for the twin. |
| S3 + CloudFront frontend | Part 7 extension. |
| API Gateway throttling in Terraform | Baked into `main.tf` (`default_route_settings`) — compare with the throttle settings you made by hand! |

## What About the Real Day 4 for Your Twin, Later?

When you eventually want the *actual* twin (not the lab) managed by Terraform, you have options — decide then, nothing is lost:

- **Option A — clean slate when the twin is dormant:** after you're done showcasing it, back up anything valuable (e.g. export notes), delete the manual resources following `day4.md` Part 1, and let Terraform rebuild the twin fully. The quota system's DynamoDB table is *not* in the Day 4 config, so if you want it managed by Terraform too, add an `aws_dynamodb_table` resource + env vars — something this lab's skills (variables, env blocks, apply) prepared you for.
- **Option B — parallel project name:** run the Day 4 config with `project_name = "twindev"` so both coexist. More advanced: bucket names, IAM roles, and CORS must all be reviewed, and the Terraform Lambda would need your OpenAI/proxy environment variables added, or it will deploy but fail at runtime.
- Either way, the lab gives you the muscle memory first.

## Cheat Sheet

```powershell
terraform init                  # once per project / after provider changes
terraform fmt                   # format files
terraform validate              # syntax check
terraform plan                  # preview changes (READ IT)
terraform apply                 # make it so (type: yes)
terraform output                # show outputs
terraform state list            # what does Terraform own?
terraform workspace new dev     # create + select workspace
terraform workspace list        # show all workspaces
terraform workspace select dev  # switch
terraform destroy               # remove everything in the current workspace
```

**Resources**

- [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Terraform best practices](https://www.terraform-best-practices.com/)
- `day4.md` — the twin version of this material (use its Part 2 for deeper concept explanations)

Congratulations — you learned Infrastructure as Code without risking the project you built by hand. 🚀
