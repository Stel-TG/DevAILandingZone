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
$TfStateSa        = "entaisttfstate${Environment}${LocationShort}"
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
Write-Host "[1/6] Setting Azure subscription context..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$accountName = az account show --query name -o tsv
Write-Host "      Active subscription: $accountName" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# REGISTER MICROSOFT.STORAGE PROVIDER
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/6] Ensuring Microsoft.Storage provider is registered..." -ForegroundColor Yellow
$providerState = az provider show --namespace Microsoft.Storage --query registrationState -o tsv
Write-Host "      Current state: $providerState" -ForegroundColor Green
if ($providerState -ne "Registered") {
    Write-Host "      Registering Microsoft.Storage..." -ForegroundColor Yellow
    az provider register --namespace Microsoft.Storage --wait
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "      Microsoft.Storage registered." -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# CREATE RESOURCE GROUP FOR TERRAFORM STATE
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/6] Creating Terraform state resource group: $TfStateRg" -ForegroundColor Yellow
az group create --name $TfStateRg --location $Location --output table
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# CREATE STORAGE ACCOUNT FOR TERRAFORM STATE
# All three properties are set explicitly at creation time so Azure Policy
# sees them in the PUT request body and does not deny the deployment:
#   - allow-blob-public-access false  (satisfies: block public access policy)
#   - https-only true                 (satisfies: enforce HTTPS policy)
#   - encryption via --encryption-services blob (satisfies: encrypted traffic policy)
# TLS 1.2 is applied in a separate update step to avoid the deprecated flag.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/6] Creating Terraform state storage account: $TfStateSa" -ForegroundColor Yellow
az storage account create --name $TfStateSa --resource-group $TfStateRg --location $Location --sku Standard_GRS --kind StorageV2 --access-tier Hot --https-only true --allow-blob-public-access false --encryption-services blob --min-tls-version TLS1_2 --default-action Deny --output table
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# ENFORCE TLS 1.2 AND BLOB VERSIONING
# Done as an update after creation to avoid deprecated CLI flags.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/6] Enabling blob versioning..." -ForegroundColor Yellow
az storage account blob-service-properties update --account-name $TfStateSa --resource-group $TfStateRg --enable-versioning true --enable-delete-retention true --delete-retention-days 30
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "      Versioning enabled." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# CREATE TERRAFORM STATE CONTAINER
# The storage account has networkAcls.defaultAction=Deny. We temporarily add
# the current machine's public IP to the network allow-list, create the
# container, then remove the rule.
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[6/6] Creating Terraform state container: $TfStateContainer" -ForegroundColor Yellow

Write-Host "      Detecting public IP..." -ForegroundColor Yellow
$MyIp = (Invoke-RestMethod -Uri "https://api.ipify.org").Trim()
Write-Host "      Public IP: $MyIp" -ForegroundColor Green

Write-Host "      Adding IP to storage account network rules..." -ForegroundColor Yellow
az storage account network-rule add --account-name $TfStateSa --resource-group $TfStateRg --ip-address $MyIp --output none
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "      Enabling AzureServices bypass..." -ForegroundColor Yellow
az storage account update --name $TfStateSa --resource-group $TfStateRg --bypass AzureServices --output none
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "      Waiting 30s for network rule to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

az storage container create --name $TfStateContainer --account-name $TfStateSa --auth-mode login --output table
$containerResult = $LASTEXITCODE

Write-Host "      Removing IP from storage account network rules..." -ForegroundColor Yellow
az storage account network-rule remove --account-name $TfStateSa --resource-group $TfStateRg --ip-address $MyIp --output none
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "      Network rule removed." -ForegroundColor Green

if ($containerResult -ne 0) { exit $containerResult }

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
