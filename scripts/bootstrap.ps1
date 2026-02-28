###############################################################################
# scripts\bootstrap.ps1
# PURPOSE: Pre-deployment bootstrap script.
#          Creates the Terraform state storage account and container BEFORE
#          running terraform init. This must run once per environment.
#
# PREREQUISITES:
#   - Azure CLI installed and authenticated (az login)
#   - Contributor access to the target subscription
#   - Environment variables set (or passed as parameters)
#
# USAGE:
#   $env:SUBSCRIPTION_ID = "<your-subscription-id>"
#   $env:ENVIRONMENT     = "prod"
#   $env:LOCATION        = "canadacentral"
#   .\scripts\bootstrap.ps1
#
#   Or pass parameters directly:
#   .\scripts\bootstrap.ps1 -SubscriptionId "<id>" -Environment "prod" -Location "canadacentral"
###############################################################################

[CmdletBinding()]
param(
    [string]$SubscriptionId = $env:SUBSCRIPTION_ID,
    [string]$Environment    = $(if ($env:ENVIRONMENT) { $env:ENVIRONMENT } else { "prod" }),
    [string]$Location       = $(if ($env:LOCATION)    { $env:LOCATION }    else { "canadacentral" })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────────
# VALIDATE REQUIRED PARAMETERS
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SubscriptionId) {
    Write-Error "SUBSCRIPTION_ID is required. Set the environment variable or pass -SubscriptionId."
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
$LocationShort = switch ($Location) {
    "canadacentral" { "cc"  }
    "canadaeast"    { "ce"  }
    "eastus"        { "eu"  }
    "eastus2"       { "eu2" }
    default         { $Location.Substring(0, [Math]::Min(4, $Location.Length)) }
}

$TfStateRg        = "rg-tfstate-${Environment}-${LocationShort}"
$TfStateSa        = "sttfstate${Environment}${LocationShort}"
$TfStateContainer = "tfstate"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Azure AI Landing Zone - Terraform State Bootstrap"           -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Subscription:    $SubscriptionId"
Write-Host "Environment:     $Environment"
Write-Host "Location:        $Location"
Write-Host "Resource Group:  $TfStateRg"
Write-Host "Storage Account: $TfStateSa"
Write-Host "============================================================" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# SET SUBSCRIPTION CONTEXT
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[1/5] Setting Azure subscription context..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$accountName = az account show --query name -o tsv
Write-Host "      Active subscription: $accountName" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# CREATE RESOURCE GROUP FOR TERRAFORM STATE
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] Creating Terraform state resource group: $TfStateRg" -ForegroundColor Yellow
az group create `
    --name $TfStateRg `
    --location $Location `
    --tags "ManagedBy=Bootstrap" "Environment=$Environment" "Purpose=TerraformState" `
    --output table
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# CREATE STORAGE ACCOUNT FOR TERRAFORM STATE
# GRS replication for geo-redundancy; minimum TLS 1.2; HTTPS only
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Creating Terraform state storage account: $TfStateSa" -ForegroundColor Yellow
az storage account create `
    --name $TfStateSa `
    --resource-group $TfStateRg `
    --location $Location `
    --sku "Standard_GRS" `
    --kind "StorageV2" `
    --access-tier "Hot" `
    --https-only true `
    --min-tls-version "TLS1_2" `
    --allow-blob-public-access false `
    --tags "ManagedBy=Bootstrap" "Environment=$Environment" "Purpose=TerraformState" `
    --output table
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# ENABLE BLOB VERSIONING (protect state file history)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Enabling blob versioning on state storage account..." -ForegroundColor Yellow
az storage account blob-service-properties update `
    --account-name $TfStateSa `
    --resource-group $TfStateRg `
    --enable-versioning true `
    --enable-delete-retention true `
    --delete-retention-days 30
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# CREATE TERRAFORM STATE CONTAINER
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Creating Terraform state container: $TfStateContainer" -ForegroundColor Yellow
az storage container create `
    --name $TfStateContainer `
    --account-name $TfStateSa `
    --auth-mode login `
    --output table
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# GENERATE BACKEND.HCL
# ─────────────────────────────────────────────────────────────────────────────
$backendContent = @"
# Generated by scripts\bootstrap.ps1 - DO NOT COMMIT THIS FILE
resource_group_name  = "$TfStateRg"
storage_account_name = "$TfStateSa"
container_name       = "$TfStateContainer"
key                  = "ai-landing-zone.tfstate"
"@

Set-Content -Path "backend.hcl" -Value $backendContent -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Bootstrap COMPLETE!"                                           -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "backend.hcl has been generated. Next steps:"
Write-Host ""
Write-Host "  1. Copy the example variable file to terraform.tfvars:"
Write-Host "       copy terraform.tfvars.example terraform.tfvars"
Write-Host "     Then update with your subscription ID, tenant ID, and settings."
Write-Host ""
Write-Host "  2. Initialize Terraform with remote state:"
Write-Host "       terraform init -backend-config=`"backend.hcl`""
Write-Host ""
Write-Host "  3. Review the deployment plan:"
Write-Host "       terraform plan -var-file=`"terraform.tfvars`""
Write-Host ""
Write-Host "  4. Deploy:"
Write-Host "       terraform apply -var-file=`"terraform.tfvars`""
Write-Host ""
Write-Host "  See README.md for full deployment documentation."
Write-Host "============================================================" -ForegroundColor Green
