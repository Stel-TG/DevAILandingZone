###############################################################################
# scripts\deploy.ps1
# PURPOSE: Full deployment script for the Azure AI Landing Zone.
#          Runs terraform init -> plan -> apply with safety checks.
#
# USAGE:
#   .\scripts\deploy.ps1 [-AutoApprove] [-Target <module>] [-PlanOnly]
#
# OPTIONS:
#   -AutoApprove    Skip interactive plan confirmation (use in CI/CD)
#   -Target         Deploy a specific module only
#                   (e.g., -Target "module.machine_learning")
#   -PlanOnly       Generate plan file only, do not apply
###############################################################################

[CmdletBinding()]
param(
    [switch]$AutoApprove,
    [string]$Target   = "",
    [switch]$PlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir
$PlanFile   = Join-Path $RootDir "tf.plan"
$TargetArgs = if ($Target) { "-target=$Target" } else { "" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Azure AI Landing Zone - Deployment"                           -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Working directory: $RootDir"
Write-Host "Auto-approve:      $($AutoApprove.IsPresent)"
Write-Host "Plan only:         $($PlanOnly.IsPresent)"
if ($Target) { Write-Host "Target:            $Target" }
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $RootDir

# ─────────────────────────────────────────────────────────────────────────────
# VALIDATE PREREQUISITES
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[PRE-CHECK] Validating prerequisites..." -ForegroundColor Yellow

# Check terraform is installed
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: terraform is not installed or not in PATH."
    exit 1
}

# Check Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "ERROR: Azure CLI is not installed or not in PATH."
    exit 1
}

# Check Terraform version
$TfVersionJson = terraform version -json | ConvertFrom-Json
$TfVersion     = $TfVersionJson.terraform_version
Write-Host "  Terraform version: $TfVersion" -ForegroundColor Gray

# Check Azure CLI is authenticated
try {
    $AzAccount = az account show --query name -o tsv 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $AzAccount) { throw }
    Write-Host "  Azure account:     $AzAccount" -ForegroundColor Gray
} catch {
    Write-Error "ERROR: Not logged in to Azure CLI. Run: az login"
    exit 1
}

# Check terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Error "ERROR: terraform.tfvars not found.`n  Copy terraform.tfvars.example -> terraform.tfvars and update values."
    exit 1
}

# Check backend.hcl exists
if (-not (Test-Path "backend.hcl")) {
    Write-Error "ERROR: backend.hcl not found.`n  Run .\scripts\bootstrap.ps1 first to create the Terraform state storage."
    exit 1
}

Write-Host "  Prerequisites OK" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM INIT
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[1/3] Initializing Terraform with remote backend..." -ForegroundColor Yellow

terraform init `
    -backend-config="backend.hcl" `
    -upgrade `
    -reconfigure

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM VALIDATE
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[1.5] Validating Terraform configuration..." -ForegroundColor Yellow

terraform validate
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "  Configuration is valid." -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM PLAN
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/3] Generating Terraform plan..." -ForegroundColor Yellow

$planArgs = @(
    "plan"
    "-var-file=terraform.tfvars"
    "-out=$PlanFile"
    "-detailed-exitcode"
)
if ($TargetArgs) { $planArgs += $TargetArgs }

terraform @planArgs
$PlanExitCode = $LASTEXITCODE

switch ($PlanExitCode) {
    0 { Write-Host "  No infrastructure changes detected. Already up-to-date." -ForegroundColor Green }
    1 { Write-Error "  ERROR: Terraform plan failed. Review errors above."; exit 1 }
    2 { Write-Host "  Changes detected. Review plan output above." -ForegroundColor Yellow }
}

# If plan-only mode, exit after saving plan
if ($PlanOnly) {
    Write-Host ""
    Write-Host "Plan saved to: $PlanFile"
    Write-Host "To apply:      terraform apply `"$PlanFile`""
    exit 0
}

# If no changes, exit cleanly
if ($PlanExitCode -eq 0) { exit 0 }

# ─────────────────────────────────────────────────────────────────────────────
# APPLY CONFIRMATION (unless -AutoApprove)
# ─────────────────────────────────────────────────────────────────────────────
if (-not $AutoApprove) {
    Write-Host ""
    $confirm = Read-Host "Apply the plan? [yes/no]"
    if ($confirm -ne "yes") {
        Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM APPLY
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/3] Applying Terraform plan..." -ForegroundColor Yellow

terraform apply $PlanFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Deployment COMPLETE!"                                          -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Outputs:"
terraform output
Write-Host ""
Write-Host "Next steps:"
Write-Host "  - Review deployed resources in the Azure Portal"
Write-Host "  - Assign AAD groups to RBAC roles (see docs\roles.md)"
Write-Host "  - Configure private DNS zone links to your hub VNET"
Write-Host "  - Run .\scripts\setup-peering.ps1 to establish hub-spoke VNET peering"
Write-Host "============================================================" -ForegroundColor Green
