#!/usr/bin/env bash
###############################################################################
# scripts/destroy.sh
# PURPOSE: Safely destroys all resources in the AI Landing Zone.
#          Includes multiple confirmation prompts to prevent accidental deletion.
#
# WARNING: This script will PERMANENTLY DELETE all deployed resources.
#          Ensure backups are taken and destruction is intentional.
#
# USAGE:
#   ./scripts/destroy.sh [--force]
#
# OPTIONS:
#   --force    Skip confirmation prompts (use ONLY in automated cleanup pipelines)
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --force) FORCE=true; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

echo "============================================================"
echo "  ⚠️  AZURE AI LANDING ZONE - DESTROY ALL RESOURCES ⚠️"
echo "============================================================"
echo ""
echo "  This will PERMANENTLY DELETE all resources in the landing zone."
echo "  This action CANNOT be undone."
echo ""
echo "  Resources to be destroyed:"
echo "    - Azure Machine Learning Workspace"
echo "    - Storage Accounts (and all data)"
echo "    - Key Vault (with purge-delayed secret deletion)"
echo "    - Container Registry (and all images)"
echo "    - Virtual Network and Private Endpoints"
echo "    - Log Analytics Workspace (and all logs)"
echo "    - Application Insights"
echo "    - All Policy Assignments"
echo ""

cd "$ROOT_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# CONFIRMATION PROMPTS (unless --force)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$FORCE" = false ]; then
  read -r -p "Are you sure you want to DESTROY all resources? Type 'DESTROY' to confirm: " CONFIRM1
  if [[ "$CONFIRM1" != "DESTROY" ]]; then
    echo "Destruction cancelled."
    exit 0
  fi

  # Extract environment from tfvars for second confirmation
  ENVIRONMENT=$(grep -E "^environment\s*=" terraform.tfvars 2>/dev/null | awk -F'"' '{print $2}' || echo "unknown")
  read -r -p "Confirm environment to destroy ('${ENVIRONMENT}'): " CONFIRM2
  if [[ "$CONFIRM2" != "$ENVIRONMENT" ]]; then
    echo "Environment name mismatch. Destruction cancelled."
    exit 0
  fi
fi

echo ""
echo "[1/3] Initializing Terraform..."
terraform init -backend-config="backend.hcl" -reconfigure

echo ""
echo "[2/3] Generating destroy plan..."
terraform plan \
  -var-file="terraform.tfvars" \
  -destroy \
  -out="destroy.plan"

if [ "$FORCE" = false ]; then
  echo ""
  read -r -p "Final confirmation - Apply DESTROY plan? [yes/no]: " FINAL_CONFIRM
  if [[ "$FINAL_CONFIRM" != "yes" ]]; then
    echo "Destruction cancelled."
    rm -f destroy.plan
    exit 0
  fi
fi

echo ""
echo "[3/3] Destroying resources..."
terraform apply "destroy.plan"

rm -f destroy.plan

echo ""
echo "============================================================"
echo "Destruction COMPLETE."
echo ""
echo "Note: Key Vault and Cognitive Services resources may be in"
echo "soft-delete state for the configured retention period."
echo "To permanently purge: az keyvault purge --name <name>"
echo "============================================================"
