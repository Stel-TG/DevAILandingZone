# Azure AI Landing Zone — Terraform

A modular, production-ready Terraform implementation for deploying a secure, governed Azure AI Landing Zone, based on the [Microsoft Azure AI Landing Zones](https://github.com/Azure/AI-Landing-Zones) reference architecture.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AI LANDING ZONE (Spoke Subscription)                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-ailz-prod-cc                                    │   │
│  │                                                                     │   │
│  │  ┌──────────────┐  ┌─────────────────────────────────────────────┐ │   │
│  │  │ GOVERNANCE   │  │  VNET: 10.226.214.192/26  (64 IPs)          │ │   │
│  │  │              │  │                                             │ │   │
│  │  │ • Policy     │  │  ┌──────────────────┐ ┌──────────────────┐ │ │   │
│  │  │ • RBAC       │  │  │ machine-learning  │ │ private-endpoints│ │ │   │
│  │  │ • Diagnostic │  │  │ .192/28          │ │ .208/28          │ │ │   │
│  │  │   Settings   │  │  │ .192 – .207      │ │ .208 – .223      │ │ │   │
│  │  └──────────────┘  │  │                  │ │                  │ │ │   │
│  │                    │  │ • AML Compute    │ │ • KV PE          │ │ │   │
│  │  ┌──────────────┐  │  │ • Training Jobs  │ │ • Storage PE     │ │ │   │
│  │  │ OBSERVABILITY│  │  └──────────────────┘ │ • ACR PE         │ │ │   │
│  │  │              │  │                        │ • AML PE         │ │ │   │
│  │  │ • Log        │  │  ┌──────────────────┐  │ • OpenAI PE      │ │ │   │
│  │  │   Analytics  │  │  │ databricks-pub   │  └──────────────────┘ │ │   │
│  │  │ • App        │  │  │ .224/28          │                       │ │   │
│  │  │   Insights   │  │  │ .224 – .239      │                       │ │   │
│  │  │ • Monitor    │  │  ├──────────────────┤                       │ │   │
│  │  └──────────────┘  │  │ databricks-priv  │                       │ │   │
│  │                    │  │ .240/28          │                       │ │   │
│  │                    │  │ .240 – .255      │                       │ │   │
│  │                    │  └──────────────────┘                       │ │   │
│  │                    └─────────────────────────────────────────────┘ │   │
│  │                                                                     │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │  AI/ML SERVICES (Private Endpoints Only)                     │  │   │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │  │   │
│  │  │  │  Azure   │ │  Azure   │ │  Azure   │ │ Cognitive Svcs│  │  │   │
│  │  │  │   ML     │ │  OpenAI  │ │  Storage │ │ / AI Services │  │  │   │
│  │  │  │ Workspace│ │ Service  │ │ (ADLS2)  │ │               │  │  │   │
│  │  │  └──────────┘ └──────────┘ └──────────┘ └───────────────┘  │  │   │
│  │  │  ┌──────────┐ ┌──────────┐                                  │  │   │
│  │  │  │ Key Vault│ │Container │                                   │  │   │
│  │  │  │ (RBAC)   │ │ Registry │                                   │  │   │
│  │  │  └──────────┘ └──────────┘                                   │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         │ VNET Peering — run scripts\setup-peering.ps1 after deployment
         ▼
┌─────────────────────────────────┐
│  HUB NETWORK (Separate Sub)     │
│  • Azure Firewall               │
│  • Private DNS Zones            │
│  • ExpressRoute / VPN Gateway   │
└─────────────────────────────────┘
```

### Subnet Reference

| Subnet | CIDR | IP Range | Purpose |
|--------|------|----------|---------|
| `machine-learning` | `10.226.214.192/28` | .192 – .207 (14 usable) | AML compute clusters, training jobs |
| `private-endpoints` | `10.226.214.208/28` | .208 – .223 (14 usable) | Private endpoint NICs for all services |
| `databricks-public` | `10.226.214.224/28` | .224 – .239 (14 usable) | Reserved — future Azure Databricks |
| `databricks-private` | `10.226.214.240/28` | .240 – .255 (14 usable) | Reserved — future Azure Databricks |

---

## Repository Structure

```
azure-ai-landing-zone/
├── main.tf                          # Root orchestration - module calls
├── variables.tf                     # All input variables with defaults
├── outputs.tf                       # Exported resource IDs and names
├── naming.tf                        # Centralized naming convention locals
├── terraform.tfvars.example         # Example variable values
├── backend.hcl.example              # Terraform backend configuration template
│
├── modules/
│   ├── resource_group/              # Resource group creation
│   ├── networking/                  # Spoke VNET + subnets (peering separate)
│   ├── nsg/                         # Network Security Groups per subnet
│   ├── policy/                      # Azure Policy assignments
│   ├── log_analytics/               # Log Analytics Workspace + solutions
│   ├── application_insights/        # Application Insights component
│   ├── key_vault/                   # Key Vault with private endpoint
│   ├── storage/                     # ADLS Gen2 storage with private endpoints
│   ├── container_registry/          # Azure Container Registry (Premium)
│   ├── machine_learning/            # AML Workspace + private endpoints + RBAC
│   ├── cognitive_services/          # Azure Cognitive Services
│   ├── openai/                      # Azure OpenAI Service + model deployments
│   ├── monitor/                     # Alert rules and action groups
│   └── rbac/                        # Role assignments for AAD groups
│
├── scripts/
│   ├── bootstrap.sh                 # Creates Terraform state storage (run first)
│   ├── deploy.sh                    # Full Terraform deployment script
│   ├── destroy.sh                   # Resource cleanup script
│   └── setup-peering.ps1            # Hub-spoke VNET peering (run after deploy)
│
└── docs/
    └── roles.md                     # RBAC role recommendations
```

Each module follows the standard structure:
```
modules/<name>/
├── main.tf        # Resource definitions
├── variables.tf   # Input parameters
└── outputs.tf     # Exported values
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5.0 |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | >= 2.55.0 |
| [Azure PowerShell (Az)](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps) | >= 11.0 (for peering script) |
| Azure Subscription | With Contributor access |

**Required permissions:**
- `Contributor` on the spoke subscription (resource deployment)
- `User Access Administrator` on the spoke subscription (RBAC assignments)
- `Network Contributor` on the hub VNET resource group (for peering — used by `setup-peering.ps1`)

---

## Quick Start

### Step 1: Bootstrap Terraform State

Run once per environment — creates the Azure Storage Account for Terraform remote state.

```bash
git clone <this-repo>
cd azure-ai-landing-zone

az login
export SUBSCRIPTION_ID="<your-subscription-id>"
export ENVIRONMENT="prod"
export LOCATION="canadacentral"

chmod +x scripts/*.sh
./scripts/bootstrap.sh
```

### Step 2: Configure Variables

```cmd
:: Windows Command Prompt
copy terraform.tfvars.example terraform.tfvars
```

```bash
# Linux / macOS
cp terraform.tfvars.example terraform.tfvars
```

Key values to update in `terraform.tfvars`:
- `spoke_subscription_id` — Spoke Azure subscription ID
- `hub_subscription_id` — Hub subscription ID (used by `setup-peering.ps1`)
- `tenant_id` — Azure AD tenant ID
- `hub_vnet_id`, `hub_vnet_name`, `hub_resource_group` — Existing hub VNET details
- `alert_email_addresses` — Team email addresses for monitoring alerts

> **VNET note:** The spoke VNET uses `10.226.214.192/26`. Subnet CIDRs are pre-set
> as defaults in `variables.tf`. Override only if your IP plan differs.

### Step 3: Select Modules

In `terraform.tfvars`, toggle modules on/off:

```hcl
deploy_machine_learning     = true   # Core AML workspace
deploy_openai               = false  # Enable when Azure OpenAI required
deploy_cognitive_services   = false  # Enable when AI Services required
deploy_networking           = true   # Spoke VNET (set false if using existing)
```

### Step 4: Deploy Landing Zone Resources

```bash
./scripts/deploy.sh
```

Or manually:

```bash
terraform init -backend-config="backend.hcl"
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Step 5: Establish Hub-Spoke VNET Peering

Peering is a **separate step** run after the spoke VNET is provisioned. It requires credentials for both the spoke and hub subscriptions.

```powershell
# Edit the $Config block at the top of the script with your subscription IDs,
# VNET names, and resource groups, then run:
.\scripts\setup-peering.ps1

# Non-interactive (CI/CD):
.\scripts\setup-peering.ps1 -Force

# To remove peering during teardown:
.\scripts\setup-peering.ps1 -Remove
```

### Step 6: Deploy Specific Module (Optional)

```bash
./scripts/deploy.sh --target module.machine_learning
# Or:
terraform apply -var-file="terraform.tfvars" -target=module.machine_learning
```

---

## Naming Convention

All resources follow the pattern: `<type-prefix>-<project>-<env>-<location-short>`

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `rg-{project}-{env}-{loc}` | `rg-ailz-prod-cc` |
| VNET | `vnet-{project}-{env}-{loc}` | `vnet-ailz-prod-cc` |
| Log Analytics | `law-{project}-{env}-{loc}` | `law-ailz-prod-cc` |
| Key Vault | `kv-{project}-{env}-{loc}` | `kv-ailz-prod-cc` |
| Storage Account | `st{project}{env}{loc}` | `stailzprodcc` |
| Container Registry | `acr{project}{env}{loc}` | `acrailzprodcc` |
| AML Workspace | `mlw-{project}-{env}-{loc}` | `mlw-ailz-prod-cc` |
| Azure OpenAI | `oai-{project}-{env}-{loc}` | `oai-ailz-prod-cc` |

Location short codes: `canadacentral=cc`, `canadaeast=ce`, `eastus=eu`, `eastus2=eu2`

---

## Security Defaults

| Control | Default |
|--------|---------|
| Public network access | **Disabled** on all resources |
| Private endpoints | **Enabled** for all services |
| Key Vault authorization | **RBAC** (not access policies) |
| Key Vault purge protection | **Enabled** (90-day retention) |
| Storage HTTPS only | **Enforced** via Policy |
| Storage public blob access | **Disabled** |
| TLS minimum version | **TLS 1.2** |
| AML workspace | **Private** mode only |
| NSG internet inbound | **Denied** |
| NSG internet outbound | **Denied** (route via hub firewall) |

---

## Destroying Resources

```bash
./scripts/destroy.sh
```

> **Warning:** Key Vault and Cognitive Services resources enter soft-delete state after destruction. Resources are fully removed after the configured retention period (90 days). To immediately purge: `az keyvault purge --name <vault-name>`

---

## CI/CD Integration

The deploy script supports non-interactive mode for pipelines:

```yaml
# Example GitHub Actions workflow step
- name: Deploy AI Landing Zone
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  run: |
    terraform init -backend-config="backend.hcl"
    terraform plan -var-file="terraform.tfvars" -out=tf.plan
    terraform apply tf.plan
```

---

## References

- [Azure AI Landing Zones Reference](https://github.com/Azure/AI-Landing-Zones)
- [Azure Cloud Adoption Framework - AI Scenarios](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/)
- [Azure Machine Learning Private Networking](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-secure-workspace-vnet)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure RBAC Built-in Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
