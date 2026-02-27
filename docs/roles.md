# Azure RBAC Role Assignments — AI Landing Zone

Recommended Azure Active Directory group structure and role assignments for the AI Landing Zone. Groups should be created in Azure Active Directory and object IDs passed to the `rbac_assignments` variable in `terraform.tfvars`.

---

## Recommended Group Structure

| AAD Group Name | Members | Purpose |
|---------------|---------|---------|
| `grp-ailz-platform-engineers` | Platform/DevOps team | Full resource management |
| `grp-ailz-data-scientists` | ML practitioners | AML workspace, compute, experiments |
| `grp-ailz-data-engineers` | Data pipeline developers | Storage, compute, read AML |
| `grp-ailz-security-team` | Security/compliance | Read-only + security operations |
| `grp-ailz-business-analysts` | BI / reporting consumers | Read AML results, Power BI |
| `grp-ailz-cost-owners` | Finance / management | Cost Management Reader |

---

## Role Assignments

### Resource Group Level

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **Contributor** | Full resource management within landing zone |
| `grp-ailz-security-team` | **Reader** | Read-only visibility for compliance reviews |
| `grp-ailz-cost-owners` | **Cost Management Reader** | Budget visibility without resource access |

### Azure Machine Learning Workspace

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-data-scientists` | **AzureML Data Scientist** | Create experiments, manage compute, deploy models |
| `grp-ailz-data-engineers` | **AzureML Compute Operator** | Manage compute clusters, not model artifacts |
| `grp-ailz-platform-engineers` | **AzureML Workspace Connection Secrets Reader** | Manage workspace connections |

### Key Vault

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **Key Vault Administrator** | Manage secrets lifecycle |
| `grp-ailz-data-scientists` | **Key Vault Secrets User** | Read secrets for pipeline authentication |
| `grp-ailz-data-engineers` | **Key Vault Secrets User** | Read secrets for pipeline authentication |

### Storage Account (ADLS Gen2)

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **Storage Blob Data Owner** | Full data management |
| `grp-ailz-data-scientists` | **Storage Blob Data Contributor** | Read/write ML datasets and model artifacts |
| `grp-ailz-data-engineers` | **Storage Blob Data Contributor** | Read/write pipeline data |
| `grp-ailz-business-analysts` | **Storage Blob Data Reader** | Read model outputs for reporting |

### Container Registry

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **AcrPush** | Push base and platform images |
| `grp-ailz-data-scientists` | **AcrPush** | Push custom ML environment images |
| `grp-ailz-data-engineers` | **AcrPull** | Pull images for pipeline execution |

### Azure OpenAI

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **Cognitive Services Contributor** | Manage service and deployments |
| `grp-ailz-data-scientists` | **Cognitive Services OpenAI User** | Inference API access |
| `grp-ailz-data-engineers` | **Cognitive Services OpenAI User** | Embedding API access for pipelines |

### Log Analytics Workspace

| Group | Azure Built-in Role | Justification |
|-------|-------------------|---------------|
| `grp-ailz-platform-engineers` | **Log Analytics Contributor** | Manage workspace and query |
| `grp-ailz-security-team` | **Log Analytics Reader** | Query logs for security investigations |

---

## Terraform Variable Configuration

Copy the group object IDs from Azure AD and add to `terraform.tfvars`:

```hcl
rbac_assignments = [
  # Platform Engineers - Resource Group Contributor
  {
    principal_id         = "AAD_GROUP_OID_PLATFORM_ENGINEERS"
    role_definition_name = "Contributor"
    scope                = "resource_group"
  },
  # Data Scientists - AML Data Scientist
  {
    principal_id         = "AAD_GROUP_OID_DATA_SCIENTISTS"
    role_definition_name = "AzureML Data Scientist"
    scope                = "/subscriptions/.../resourceGroups/.../providers/Microsoft.MachineLearningServices/workspaces/mlw-ailz-prod-cc"
  },
  # Data Scientists - Storage Blob Data Contributor
  {
    principal_id         = "AAD_GROUP_OID_DATA_SCIENTISTS"
    role_definition_name = "Storage Blob Data Contributor"
    scope                = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/stailzprodcc"
  },
  # Security Team - Reader
  {
    principal_id         = "AAD_GROUP_OID_SECURITY_TEAM"
    role_definition_name = "Reader"
    scope                = "resource_group"
  }
]
```

---

## Service Principal / Managed Identity Roles

The following managed identity role assignments are handled automatically by Terraform modules:

| Identity | Resource | Role | Module |
|----------|---------|------|--------|
| AML Workspace System Identity | Linked Storage Account | Storage Blob Data Contributor | `machine_learning` |
| AML Workspace System Identity | Linked Container Registry | AcrPull | `machine_learning` |
| AML Workspace System Identity | Linked Key Vault | Key Vault Secrets User | `machine_learning` |

---

## Conditional Access Recommendations

For enhanced security, apply Conditional Access policies to AAD groups accessing AI Landing Zone resources:

1. **MFA Required** — All groups accessing Key Vault and AML workspace
2. **Compliant Device Required** — `grp-ailz-platform-engineers` for Contributor access
3. **Named Location Restriction** — Restrict access to corporate network/VPN IP ranges
4. **Sign-in Risk Policy** — Block high-risk sign-ins for all groups

---

## Privileged Identity Management (PIM)

Recommend enabling PIM for high-privilege roles:

| Role | PIM Configuration |
|------|------------------|
| Key Vault Administrator | Eligible (require activation + justification) |
| Contributor | Eligible (max 8 hour activation) |
| Storage Blob Data Owner | Eligible (require justification) |

This ensures just-in-time access and audit trail for privileged operations.
