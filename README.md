# Azure AI Landing Zone — Terraform

A modular, production-ready Terraform implementation of the **Azure AI Landing Zone** reference architecture, including AI Foundry, GenAI microservices, private networking, and enterprise governance.

Reference: [Microsoft Azure AI Landing Zones](https://github.com/Azure/AI-Landing-Zones)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│  AI Landing Zone Prod Subscription                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────────┐    │
│  │ AI App Resource Group                                                        │    │
│  │                                                                              │    │
│  │  ┌──── AI Foundry Agent Service standard setup ──────────────────────────┐  │    │
│  │  │  Dependencies: Storage · AI Search · Cosmos DB · Key Vault             │  │    │
│  │  │  Azure AI Foundry Service:                                              │  │    │
│  │  │    AI Foundry Project:                                                  │  │    │
│  │  │      AI Services endpoints · Foundry models · Connections               │  │    │
│  │  │      Foundry Agent Service (ai-foundry-agent subnet)                   │  │    │
│  │  └────────────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                              │    │
│  │  ┌──── AI Services VNET 10.226.214.0/24 ───────────────────────────────┐  │    │
│  │  │  Private Endpoints  .0/27   ── All service PE NICs (16 endpoints)   │  │    │
│  │  │  AI Foundry Agent   .32/28  ── Foundry Agent Service container       │  │    │
│  │  │  API Management     .48/29  ── APIM internal VNet (rate limit / JWT) │  │    │
│  │  │  Container App Env  .64/27  ── GenAI microservices (Dapr-enabled)   │  │    │
│  │  │  App Gateway        .96/28  ── WAF v2 / OWASP 3.2 (public ingress)  │  │    │
│  │  │  Build agent       .112/29  ── Self-hosted CI/CD VM                 │  │    │
│  │  │  Jumpbox           .120/29  ── Admin VM (no public IP, Entra login)  │  │    │
│  │  │  Databricks-public .128/28  ── Reserved                              │  │    │
│  │  │  Databricks-private .144/28 ── Reserved                              │  │    │
│  │  │  AML Compute       .160/28  ── Compute Instances (no public IP)      │  │    │
│  │  │  Growth space      .176–.255 ── 80 IPs unallocated for future use   │  │    │
│  │  └───────────────────────────────────────────────────────────────────────┘  │    │
│  │                                                                              │    │
│  │  ┌──── GenAI app dependencies ──┐  ┌──── GenAI app microservices ────────┐  │    │
│  │  │ Cosmos DB · Key Vault        │  │ Container App Environment           │  │    │
│  │  │ Storage · Container Registry │  │  Frontend · Orchestrator · SK       │  │    │
│  │  │ App Configuration            │  │  MCP · Ingestion  (Dapr enabled)    │  │    │
│  │  └──────────────────────────────┘  └─────────────────────────────────────┘  │    │
│  │                                                                              │    │
│  │  ┌──── Enterprise knowledge ──┐     ┌──── Security & governance ──────────┐  │    │
│  │  │  Grounding with Bing       │     │  Policy · Defender for Cloud        │  │    │
│  │  │  AI Search Service         │     │  Entra ID · Purview                 │  │    │
│  │  └────────────────────────────┘     └─────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────────┘
    │  VNET Peering — run .\scripts\setup-peering.ps1 after deployment
    ▼
┌─────────────────────────────────────┐
│  Hub Network (Separate Subscription) │
│  Azure Firewall · Private DNS Zones  │
│  Azure Bastion · ExpressRoute / VPN  │
└─────────────────────────────────────┘
```

---

## Subnet Reference

| Subnet | CIDR | IP Range | Usable | Purpose |
|--------|------|----------|--------|---------|
| `private-endpoints` | `10.226.214.0/27` | .0 – .31 | 27 | All service private endpoint NICs (16 at initial deploy) |
| `ai-foundry-agent` | `10.226.214.32/28` | .32 – .47 | 11 | AI Foundry Agent Service runtime |
| `api-management` | `10.226.214.48/29` | .48 – .55 | 3 | APIM internal VNet integration |
| `container-app-environment` | `10.226.214.64/27` | .64 – .95 | 27 | Container App Environment (workload profiles — /27 min required by Microsoft) |
| `application-gateway` | `10.226.214.96/28` | .96 – .111 | 11 | Application Gateway + WAF (dedicated) |
| `build-agent` | `10.226.214.112/29` | .112 – .119 | 3 | Self-hosted CI/CD build agent VM |
| `jumpbox` | `10.226.214.120/29` | .120 – .127 | 3 | Admin jump box VM |
| `databricks-public` | `10.226.214.128/28` | .128 – .143 | 11 | Reserved — future Azure Databricks |
| `databricks-private` | `10.226.214.144/28` | .144 – .159 | 11 | Reserved — future Azure Databricks |
| `aml-compute` | `10.226.214.160/28` | .160 – .175 | 11 | AML Compute Instances (no public IP) — chatbot dev against private endpoints |
| *(growth space)* | `10.226.214.176/27+` | .176 – .255 | ~80 | Unallocated — available for future subnets |

VNET address space: `10.226.214.0/24` (256 IPs: .0 – .255)
- **168 IPs allocated** across 10 subnets
- **88 IPs unallocated** (.176 – .255) for future growth

### Private Endpoint Coverage (16 NICs at initial deploy)

All services have `public_network_access_enabled = false`. Access is exclusively through private endpoints in the `private-endpoints` subnet.

| # | Service | DNS Zone |
|---|---------|----------|
| 1 | Key Vault | `privatelink.vaultcore.azure.net` |
| 2 | Storage (blob) | `privatelink.blob.core.windows.net` |
| 3 | Storage (DFS) | `privatelink.dfs.core.windows.net` |
| 4 | Container Registry | `privatelink.azurecr.io` |
| 5 | Machine Learning workspace | `privatelink.api.azureml.ms` |
| 6 | **Azure OpenAI** | `privatelink.openai.azure.com` |
| 7 | **Cognitive Services** | `privatelink.cognitiveservices.azure.com` |
| 8 | AI Foundry Hub | `privatelink.api.azureml.ms` |
| 9 | AI Search | `privatelink.search.windows.net` |
| 10 | Cosmos DB | `privatelink.documents.azure.com` |
| 11 | App Configuration | `privatelink.azconfig.io` |
| 12 | Log Analytics | `privatelink.ods.opinsights.azure.com` |
| 13 | API Management | `privatelink.azure-api.net` |
| 14 | Container App Environment | `privatelink.azurecontainerapps.io` |

> **Bold** = newly enabled for chatbot private endpoint migration (previously `deploy = false` in prod).

---

## Repository Structure

```
azure-ai-landing-zone/
├── main.tf                          # Root orchestration — all module calls
├── variables.tf                     # All input variables with defaults
├── outputs.tf                       # Exported resource IDs and names
├── naming.tf                        # Centralized naming conventions
├── terraform.tfvars.example         # Example variable values
├── backend.hcl.example              # Terraform backend configuration template
│
├── modules/
│   ├── resource_group/              # Resource group
│   ├── managed_identity/            # User-assigned MIs (foundry, apps, build)
│   ├── security_governance/         # Defender for Cloud, Purview, Network Watcher
│   ├── policy/                      # Azure Policy assignments
│   ├── log_analytics/               # Log Analytics Workspace
│   ├── monitor/                     # Azure Monitor alerts and action groups
│   ├── application_insights/        # Application Insights
│   ├── networking/                  # Spoke VNET + all subnets (peering separate)
│   ├── nsg/                         # Network Security Groups per subnet
│   ├── key_vault/                   # Key Vault (RBAC, purge protection)
│   ├── storage/                     # Storage Account ADLS Gen2
│   ├── container_registry/          # Azure Container Registry (Premium)
│   ├── cognitive_services/          # AI Services endpoints (Cognitive Services)
│   ├── openai/                      # Azure OpenAI — Foundry models
│   ├── ai_search/                   # Azure AI Search (RAG / vector index)
│   ├── cosmos_db/                   # Cosmos DB (agent memory + app state)
│   ├── ai_foundry/                  # AI Foundry Hub, Project, Connections, Agent
│   ├── machine_learning/            # Azure ML workspace (optional)
│   ├── app_configuration/           # Azure App Configuration
│   ├── container_app_environment/   # Container App Env + 5 microservices
│   ├── api_management/              # APIM internal VNet
│   ├── app_gateway/                 # Application Gateway + WAF v2
│   ├── jumpbox/                     # Admin jump box VM
│   ├── build_agent/                 # Self-hosted CI/CD build agent VM
│   ├── private_endpoints/           # Private endpoints for platform services
│   └── rbac/                        # Role assignments for AAD groups
│
├── scripts/
│   ├── bootstrap.sh                 # Creates Terraform state storage (run first)
│   ├── deploy.sh                    # Full Terraform deployment script
│   ├── destroy.sh                   # Resource cleanup script
│   └── setup-peering.ps1            # Hub-spoke VNET peering (run after deploy)
│
├── diagrams/
│   ├── architecture.svg             # Full architecture diagram
│   └── architecture.mermaid         # Mermaid source
│
└── docs/
    └── roles.md                     # RBAC role recommendations
```

---

## Prerequisites

| Tool | Minimum Version |
|------|----------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5.0 |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | >= 2.55.0 |
| [Azure PowerShell (Az)](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps) | >= 11.0 (peering script only) |

**Required permissions:**
- `Contributor` + `User Access Administrator` on the spoke subscription
- `Network Contributor` on the hub VNET resource group (for peering)

---

## Quick Start

### Step 1 — Bootstrap Terraform State

Run once per environment. Creates the Azure Storage Account for Terraform remote state.

```bash
az login
export SUBSCRIPTION_ID="<your-spoke-subscription-id>"
export ENVIRONMENT="prod"
export LOCATION="canadacentral"

chmod +x scripts/*.sh
./scripts/bootstrap.sh
```

### Step 2 — Configure Variables

```cmd
:: Windows Command Prompt
copy terraform.tfvars.example terraform.tfvars
```
```bash
# Linux / macOS
cp terraform.tfvars.example terraform.tfvars
```

Key values to update in `terraform.tfvars`:

- `spoke_subscription_id`, `hub_subscription_id`, `tenant_id`
- `hub_vnet_id`, `hub_vnet_name`, `hub_resource_group`
- `admin_ssh_public_key` — for jump box and build agent VMs
- `apim_publisher_email`, `alert_email_addresses`
- RBAC group object IDs (`data_scientist_group_id`, etc.)

> **VNET note:** The spoke VNET uses `10.226.214.0/24` (256 IPs). All subnet CIDRs are pre-configured as defaults in `variables.tf`. 88 IPs (.176 – .255) remain unallocated for future growth. Override the `subnets` map only if your IP plan differs.

### Step 3 — Select Modules

Toggle what to deploy in `terraform.tfvars`:

```hcl
# Core AI Foundry setup (all on by default)
deploy_ai_foundry        = true
deploy_ai_search         = true
deploy_cosmos_db         = true
deploy_cognitive_services = true
deploy_openai            = true   # Enable when Azure OpenAI quota approved

# GenAI app layer
deploy_container_app_env = true
deploy_api_management    = true
deploy_app_gateway       = true

# Optional
deploy_machine_learning  = false  # Classic AML workspace
deploy_bing_grounding    = false  # Grounding with Bing
```

### Step 4 — Deploy Landing Zone Resources

```bash
./scripts/deploy.sh
```

Or manually:

```bash
terraform init -backend-config="backend.hcl"
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Step 5 — Establish Hub-Spoke VNET Peering

Peering is a **separate step** run after the spoke VNET is provisioned. Requires credentials for both the spoke and hub subscriptions.

```powershell
# Edit $Config at the top of the script, then run:
.\scripts\setup-peering.ps1

# Non-interactive (CI/CD):
.\scripts\setup-peering.ps1 -Force

# To remove peering during teardown:
.\scripts\setup-peering.ps1 -Remove
```

### Step 6 — Deploy a Specific Module (Optional)

```bash
./scripts/deploy.sh --target module.ai_foundry
./scripts/deploy.sh --target module.container_app_environment
terraform apply -var-file="terraform.tfvars" -target=module.app_gateway
```

---

## Module Summary

| Module | On by Default | Description |
|--------|:---:|-------------|
| `resource_group` | Yes | Resource group for all landing zone resources |
| `managed_identity` | Yes | User-assigned MIs: foundry, apps, build |
| `security_governance` | Yes | Defender for Cloud, Purview, Network Watcher |
| `policy` | Yes | Allowed locations, deny public AI, HTTPS storage |
| `log_analytics` | Yes | Central log sink for all services |
| `monitor` | Yes | Alert rules and email action group |
| `application_insights` | Yes | APM linked to Log Analytics |
| `networking` | Yes | Spoke VNET + 9 subnets |
| `nsg` | Yes | Network Security Groups per subnet |
| `key_vault` | Yes | Shared secret store (RBAC, purge protection) |
| `storage` | Yes | ADLS Gen2 storage (foundry artifacts + app data) |
| `container_registry` | Yes | Container images for microservices and agents |
| `cognitive_services` | Yes | AI Services endpoints (AI Foundry Project) |
| `openai` | Yes | Azure OpenAI — Foundry models (GPT-4o, Embeddings) |
| `ai_search` | Yes | Vector RAG index (Foundry + microservices) |
| `cosmos_db` | Yes | Agent memory + app state (NoSQL) |
| `ai_foundry` | Yes | AI Foundry Hub, Project, Connections, Agent Service |
| `app_configuration` | Yes | Feature flags for GenAI microservices |
| `container_app_environment` | Yes | 5 microservices: Frontend, Orchestrator, SK, MCP, Ingestion |
| `api_management` | Yes | Internal APIM gateway (rate limit, JWT auth) |
| `app_gateway` | Yes | Application Gateway WAF v2, OWASP 3.2 Prevention |
| `jumpbox` | Yes | Admin jump box VM (no public IP, Entra login) |
| `build_agent` | Yes | Self-hosted CI/CD build agent VM |
| `private_endpoints` | Yes | All service private endpoint NICs |
| `rbac` | Yes | RBAC role assignments for AAD groups |
| `machine_learning` | **No** | Classic Azure ML workspace (separate from Foundry) |

---

## Naming Convention

Pattern: `<type-prefix>-<project>-<environment>-<location-short>`

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `rg-{p}-{e}-{l}` | `rg-ailz-prod-cc` |
| VNET | `vnet-{p}-{e}-{l}` | `vnet-ailz-prod-cc` |
| AI Foundry Hub | `aif-{p}-{e}-{l}` | `aif-ailz-prod-cc` |
| AI Foundry Project | `aifp-{p}-{e}-{l}` | `aifp-ailz-prod-cc` |
| AI Foundry Agent Svc | `aifas-{p}-{e}-{l}` | `aifas-ailz-prod-cc` |
| AI Search | `srch-{p}-{e}-{l}` | `srch-ailz-prod-cc` |
| Cosmos DB | `cosmos-{p}-{e}-{l}` | `cosmos-ailz-prod-cc` |
| Container App Env | `cae-{p}-{e}-{l}` | `cae-ailz-prod-cc` |
| Container App | `ca-{name}-{p}-{e}-{l}` | `ca-frontend-ailz-prod-cc` |
| APIM | `apim-{p}-{e}-{l}` | `apim-ailz-prod-cc` |
| App Gateway | `agw-{p}-{e}-{l}` | `agw-ailz-prod-cc` |
| App Configuration | `appcs-{p}-{e}-{l}` | `appcs-ailz-prod-cc` |
| Storage Account | `st{p}{e}{l}` | `stailzprodcc` |
| Container Registry | `cr{p}{e}{l}` | `crailzprodcc` |
| Jump box VM | `vm-jumpbox-{p}-{e}-{l}` | `vm-jumpbox-ailz-prod-cc` |
| Build Agent VM | `vm-build-{p}-{e}-{l}` | `vm-build-ailz-prod-cc` |
| Managed Identities | `id-{workload}-{p}-{e}-{l}` | `id-foundry-ailz-prod-cc` |

Location short codes: `canadacentral=cc`, `canadaeast=ce`, `eastus=eu`, `eastus2=eu2`

---

## Security Defaults

| Control | Default |
|--------|---------|
| Public network access | Disabled on all resources |
| Private endpoints | Enabled for all services |
| Key Vault authorization | RBAC (not access policies) |
| Key Vault purge protection | Enabled (90-day retention) |
| Storage HTTPS only | Enforced via Policy |
| TLS minimum version | TLS 1.2 |
| AI Foundry | Private workspace mode only |
| APIM | Internal VNet (no public management endpoint) |
| App Gateway | WAF v2, OWASP 3.2, Prevention mode |
| Container Apps | Internal CAE, no direct public ingress |
| NSG internet inbound | Denied |
| NSG internet outbound | Denied (route via hub firewall) |
| Managed identities | System + user-assigned (no service principal secrets) |
| Defender for Cloud | Enabled: AI, Containers, KeyVaults, Storage, ARM |

---

## Traffic Flow

```
Internet
  └─> Application Gateway (WAF v2)  [application-gateway subnet .96/28]
        └─> API Management (internal) [api-management subnet .48/29]
              └─> Container Apps      [container-app-env subnet .64/27]
                    ├─> Azure OpenAI   (via private endpoint .0/27)
                    ├─> AI Search      (via private endpoint .0/27)
                    └─> AI Foundry Agent Service  [ai-foundry-agent subnet .32/28]

Chatbot development (private endpoint migration validation):
  Hub Bastion / VPN ──> Jumpbox VM  [jumpbox subnet .120/29]
                          └─> AML Compute Instance  [aml-compute subnet .160/28]
                                ├─> Azure OpenAI      (via private endpoint .0/27)
                                ├─> AI Search         (via private endpoint .0/27)
                                ├─> Cosmos DB         (via private endpoint .0/27)
                                ├─> Storage           (via private endpoint .0/27)
                                └─> Key Vault         (via private endpoint .0/27)

AML compute clusters (batch training):
  AML managed VNet ──> OpenAI, AI Search, Cosmos DB
                        (via AML-managed outbound PE rules — separate from spoke PEs)

Admin access:
  Hub Bastion ──> Jump box VM  [jumpbox subnet .120/29]

CI/CD pipelines:
  Build agent VM  [build-agent subnet .112/29]
    └─> Container Registry  (via private endpoint)
    └─> Container App Environment  (deploy revisions)
```

---

## Destroying Resources

```bash
./scripts/destroy.sh
```

Then remove VNET peering:
```powershell
.\scripts\setup-peering.ps1 -Remove
```

> **Warning:** Key Vault and Cognitive Services enter soft-delete state (90-day retention). To immediately purge: `az keyvault purge --name kv-ailz-prod-cc`

---

## CI/CD Integration

```yaml
# Example GitHub Actions workflow
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
- [Azure AI Foundry Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/)
- [Azure Cloud Adoption Framework — AI Scenarios](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/scenarios/ai/)
- [Container Apps with Dapr](https://learn.microsoft.com/en-us/azure/container-apps/dapr-overview)
- [Azure API Management in internal VNet mode](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-internal-vnet)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
