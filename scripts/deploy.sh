#!/usr/bin/env bash
###############################################################################
# scripts/deploy.sh
# PURPOSE: Full deployment script for the Azure AI Landing Zone.
#          Runs terraform init -> plan -> apply with safety checks.
#
# USAGE:
#   ./scripts/deploy.sh [--auto-approve] [--target MODULE]
#
# OPTIONS:
#   --auto-approve    Skip interactive plan confirmation (use in CI/CD)
#   --target MODULE   Deploy a specific module only (e.g., --target module.machine_learning)
#   --plan-only       Generate plan file only, do not apply
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PLAN_FILE="${ROOT_DIR}/tf.plan"
AUTO_APPROVE=false
TARGET_ARGS=""
PLAN_ONLY=false

# ─────────────────────────────────────────────────────────────────────────────
# ARGUMENT PARSING
# ─────────────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto-approve) AUTO_APPROVE=true; shift ;;
    --target)       TARGET_ARGS="-target=$2"; shift 2 ;;
    --plan-only)    PLAN_ONLY=true; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

echo "============================================================"
echo "Azure AI Landing Zone - Deployment"
echo "============================================================"
echo "Working directory: ${ROOT_DIR}"
echo "Auto-approve:      ${AUTO_APPROVE}"
echo "Plan only:         ${PLAN_ONLY}"
[ -n "$TARGET_ARGS" ] && echo "Target:            ${TARGET_ARGS}"
echo "============================================================"

cd "$ROOT_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# VALIDATE PREREQUISITES
# ─────────────────────────────────────────────────────────────────────────────
echo "[PRE-CHECK] Validating prerequisites..."

command -v terraform >/dev/null 2>&1 || { echo "ERROR: terraform is not installed"; exit 1; }
command -v az >/dev/null 2>&1 || { echo "ERROR: Azure CLI is not installed"; exit 1; }

# Check terraform version meets minimum
TF_VERSION=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])")
echo "  Terraform version: ${TF_VERSION}"

# Check Azure CLI is authenticated
AZ_ACCOUNT=$(az account show --query name -o tsv 2>/dev/null) || {
  echo "ERROR: Not logged in to Azure CLI. Run: az login"
  exit 1
}
echo "  Azure account: ${AZ_ACCOUNT}"

# Check terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
  echo "ERROR: terraform.tfvars not found."
  echo "  Copy terraform.tfvars.example -> terraform.tfvars and update values."
  exit 1
fi

# Check backend.hcl exists
if [ ! -f backend.hcl ]; then
  echo "ERROR: backend.hcl not found."
  echo "  Run scripts/bootstrap.sh first to create the Terraform state storage."
  exit 1
fi

echo "  Prerequisites OK"

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM INIT
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[1/3] Initializing Terraform with remote backend..."
terraform init \
  -backend-config="backend.hcl" \
  -upgrade \
  -reconfigure

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM VALIDATE
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[1.5] Validating Terraform configuration..."
terraform validate
echo "  Configuration is valid."

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM PLAN
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[2/3] Generating Terraform plan..."
terraform plan \
  -var-file="terraform.tfvars" \
  ${TARGET_ARGS} \
  -out="${PLAN_FILE}" \
  -detailed-exitcode || PLAN_EXIT_CODE=$?

# Exit codes: 0=no changes, 1=error, 2=changes present
PLAN_EXIT_CODE="${PLAN_EXIT_CODE:-0}"
case $PLAN_EXIT_CODE in
  0) echo "  No infrastructure changes detected. Already up-to-date." ;;
  1) echo "  ERROR: Terraform plan failed. Review errors above."; exit 1 ;;
  2) echo "  Changes detected. Review plan output above." ;;
esac

# If plan-only mode, exit after saving plan
if [ "$PLAN_ONLY" = true ]; then
  echo ""
  echo "Plan saved to: ${PLAN_FILE}"
  echo "To apply: terraform apply \"${PLAN_FILE}\""
  exit 0
fi

# If no changes and not in plan-only mode, exit cleanly
[ "$PLAN_EXIT_CODE" -eq 0 ] && exit 0

# ─────────────────────────────────────────────────────────────────────────────
# APPLY CONFIRMATION (unless --auto-approve)
# ─────────────────────────────────────────────────────────────────────────────
if [ "$AUTO_APPROVE" = false ]; then
  echo ""
  read -r -p "Apply the plan? [yes/no]: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "Deployment cancelled by user."
    exit 0
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# TERRAFORM APPLY
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Applying Terraform plan..."
terraform apply "${PLAN_FILE}"

echo ""
echo "============================================================"
echo "Deployment COMPLETE!"
echo "============================================================"
echo ""
echo "Outputs:"
terraform output
echo ""
echo "Next steps:"
echo "  - Review deployed resources in the Azure Portal"
echo "  - Assign AAD groups to RBAC roles (see docs/roles.md)"
echo "  - Configure private DNS zone links to your hub VNET"
echo "============================================================"
