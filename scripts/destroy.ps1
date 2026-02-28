###############################################################################
# scripts\destroy.ps1
# PURPOSE: Safely destroys all resources in the AI Landing Zone.
#          Includes multiple confirmation prompts to prevent accidental deletion.
#
# WARNING: This script will PERMANENTLY DELETE all deployed resources.
#          Ensure backups are taken and destruction is intentional.
#
# USAGE:
#   .\scripts\destroy.ps1 [-Force]
#
# OPTIONS:
#   -Force    Skip confirmation prompts (use ONLY in automated cleanup pipelines)
###############################################################################

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir   = Split-Path -Parent $ScriptDir

Write-Host "============================================================" -ForegroundColor Red
Write-Host "  WARNING: AZURE AI LANDING ZONE - DESTROY ALL RESOURCES"    -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  This will PERMANENTLY DELETE all resources in the landing zone."
Write-Host "  This action CANNOT be undone."
Write-Host ""
Write-Host "  Resources to be destroyed:"
Write-Host "    - Azure Machine Learning Workspace"
Write-Host "    - Storage Accounts (and all data)"
Write-Host "    - Key Vault (with purge-delayed secret deletion)"
Write-Host "    - Container Registry (and all images)"
Write-Host "    - Virtual Network and Private Endpoints"
Write-Host "    - Log Analytics Workspace (and all logs)"
Write-Host "    - Application Insights"
Write-Host "    - All Policy Assignments"
Write-Host ""

Set-Location $RootDir

# ─────────────────────────────────────────────────────────────────────────────
# CONFIRMATION PROMPTS (unless -Force)
# ─────────────────────────────────────────────────────────────────────────────
if (-not $Force) {
    $confirm1 = Read-Host "Are you sure you want to DESTROY all resources? Type 'DESTROY' to confirm"
    if ($confirm1 -ne "DESTROY") {
        Write-Host "Destruction cancelled." -ForegroundColor Yellow
        exit 0
    }

    # Extract environment from tfvars for second confirmation
    $Environment = "unknown"
    if (Test-Path "terraform.tfvars") {
        $match = Select-String -Path "terraform.tfvars" -Pattern '^\s*environment\s*=\s*"(.+)"'
        if ($match) {
            $Environment = $match.Matches[0].Groups[1].Value
        }
    }

    $confirm2 = Read-Host "Confirm environment to destroy ('$Environment')"
    if ($confirm2 -ne $Environment) {
        Write-Host "Environment name mismatch. Destruction cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM INIT
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[1/3] Initializing Terraform..." -ForegroundColor Yellow

terraform init -backend-config="backend.hcl" -reconfigure
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM DESTROY PLAN
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/3] Generating destroy plan..." -ForegroundColor Yellow

terraform plan `
    -var-file="terraform.tfvars" `
    -destroy `
    -out="destroy.plan"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $Force) {
    Write-Host ""
    $finalConfirm = Read-Host "Final confirmation - Apply DESTROY plan? [yes/no]"
    if ($finalConfirm -ne "yes") {
        Write-Host "Destruction cancelled." -ForegroundColor Yellow
        Remove-Item -Path "destroy.plan" -ErrorAction SilentlyContinue
        exit 0
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM APPLY (DESTROY)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/3] Destroying resources..." -ForegroundColor Yellow

terraform apply "destroy.plan"
$ApplyExitCode = $LASTEXITCODE

Remove-Item -Path "destroy.plan" -ErrorAction SilentlyContinue

if ($ApplyExitCode -ne 0) { exit $ApplyExitCode }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Destruction COMPLETE."                                         -ForegroundColor Green
Write-Host ""
Write-Host "Note: Key Vault and Cognitive Services resources may be in"
Write-Host "soft-delete state for the configured retention period."
Write-Host "To permanently purge: az keyvault purge --name <name>"
Write-Host ""
Write-Host "To remove VNET peering:"
Write-Host "  .\scripts\setup-peering.ps1 -Remove"
Write-Host "============================================================" -ForegroundColor Green
