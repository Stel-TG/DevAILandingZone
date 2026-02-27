###############################################################################
# scripts\setup-peering.ps1
#
# PURPOSE
# -------
# Establishes VNET peering between the AI Landing Zone spoke VNET and the
# existing hub VNET in a separate subscription.
#
# Peering is separated from the core Terraform deployment because:
#   - Hub credentials (hub_subscription_id) are distinct from spoke credentials
#   - Peering lifecycle should not block or rollback core resource deployment
#   - Network team may own the hub-side peering independently
#   - Avoids requiring dual-subscription Terraform provider aliases in CI/CD
#
# PREREQUISITES
# -------------
#   - Azure PowerShell (Az module) installed:
#       Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
#   - Contributor on spoke subscription
#   - Network Contributor on hub VNET resource group (for hub->spoke peering)
#
# USAGE
# -----
#   # Interactive (prompts for confirmation)
#   .\scripts\setup-peering.ps1
#
#   # Non-interactive (CI/CD pipelines)
#   .\scripts\setup-peering.ps1 -Force
#
#   # Remove peering (teardown)
#   .\scripts\setup-peering.ps1 -Remove
###############################################################################

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force,    # Skip confirmation prompts
    [switch]$Remove    # Remove peering instead of creating it
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# CONFIGURATION — Update these values to match your environment
# =============================================================================

$Config = @{
    # ── Spoke (AI Landing Zone) ──────────────────────────────────────────────
    SpokeSubscriptionId  = "00000000-0000-0000-0000-000000000000"   # REPLACE
    SpokeResourceGroup   = "rg-ailz-prod-cc"
    SpokeVnetName        = "vnet-ailz-prod-cc"
    # Spoke address space (for confirmation display only)
    SpokeAddressSpace    = "10.226.214.192/26"

    # ── Hub (existing, separate subscription) ────────────────────────────────
    HubSubscriptionId    = "11111111-1111-1111-1111-111111111111"   # REPLACE
    HubResourceGroup     = "rg-hub-network"
    HubVnetName          = "vnet-hub-prod"

    # ── Peering settings ─────────────────────────────────────────────────────
    SpokePeeringName     = "peer-spoke-to-hub"
    HubPeeringName       = "peer-hub-to-ailz-prod-cc"

    # Set true if the hub has a VPN or ExpressRoute gateway that spokes use
    UseRemoteGateways    = $false
    AllowGatewayTransit  = $false
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Step, [string]$Message)
    Write-Host ""
    Write-Host "[$Step] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "  OK  $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ..  $Message" -ForegroundColor Gray
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-Header "Azure AI Landing Zone — VNET Peering Setup"

Write-Host ""
Write-Host "  Spoke VNET : $($Config.SpokeVnetName)  [$($Config.SpokeAddressSpace)]"
Write-Host "              $($Config.SpokeResourceGroup) / sub: $($Config.SpokeSubscriptionId)"
Write-Host "  Hub VNET   : $($Config.HubVnetName)"
Write-Host "              $($Config.HubResourceGroup) / sub: $($Config.HubSubscriptionId)"
Write-Host "  Operation  : $(if ($Remove) { 'REMOVE peering' } else { 'CREATE peering' })"

# ─────────────────────────────────────────────────────────────────────────────
# CONFIRMATION
# ─────────────────────────────────────────────────────────────────────────────
if (-not $Force) {
    $action = if ($Remove) { "REMOVE" } else { "CREATE" }
    Write-Host ""
    $confirm = Read-Host "Proceed to $action VNET peering? [yes/no]"
    if ($confirm -ne "yes") {
        Write-Host "Operation cancelled by user." -ForegroundColor Yellow
        exit 0
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# AUTHENTICATION CHECK
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "1/5" "Checking Azure authentication..."
try {
    $context = Get-AzContext
    if (-not $context) {
        throw "Not authenticated"
    }
    Write-Success "Authenticated as: $($context.Account.Id)"
} catch {
    Write-Host "  ERROR: Not signed in to Azure. Run: Connect-AzAccount" -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# GET SPOKE VNET
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "2/5" "Retrieving spoke VNET..."
Set-AzContext -SubscriptionId $Config.SpokeSubscriptionId | Out-Null

$spokeVnet = Get-AzVirtualNetwork `
    -Name $Config.SpokeVnetName `
    -ResourceGroupName $Config.SpokeResourceGroup

if (-not $spokeVnet) {
    Write-Host "  ERROR: Spoke VNET '$($Config.SpokeVnetName)' not found." -ForegroundColor Red
    Write-Host "         Run deploy.sh first to provision the spoke VNET." -ForegroundColor Red
    exit 1
}
Write-Success "Spoke VNET found: $($spokeVnet.Id)"

# ─────────────────────────────────────────────────────────────────────────────
# GET HUB VNET
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "3/5" "Retrieving hub VNET..."
Set-AzContext -SubscriptionId $Config.HubSubscriptionId | Out-Null

$hubVnet = Get-AzVirtualNetwork `
    -Name $Config.HubVnetName `
    -ResourceGroupName $Config.HubResourceGroup

if (-not $hubVnet) {
    Write-Host "  ERROR: Hub VNET '$($Config.HubVnetName)' not found." -ForegroundColor Red
    exit 1
}
Write-Success "Hub VNET found: $($hubVnet.Id)"

# ─────────────────────────────────────────────────────────────────────────────
# REMOVE MODE
# ─────────────────────────────────────────────────────────────────────────────
if ($Remove) {
    Write-Step "4/5" "Removing hub -> spoke peering..."
    Set-AzContext -SubscriptionId $Config.HubSubscriptionId | Out-Null
    $hubPeering = Get-AzVirtualNetworkPeering `
        -VirtualNetworkName $Config.HubVnetName `
        -ResourceGroupName $Config.HubResourceGroup `
        -Name $Config.HubPeeringName -ErrorAction SilentlyContinue
    if ($hubPeering) {
        Remove-AzVirtualNetworkPeering `
            -VirtualNetworkName $Config.HubVnetName `
            -ResourceGroupName $Config.HubResourceGroup `
            -Name $Config.HubPeeringName -Force
        Write-Success "Hub -> spoke peering removed."
    } else {
        Write-Info "Hub -> spoke peering not found (already removed or never created)."
    }

    Write-Step "5/5" "Removing spoke -> hub peering..."
    Set-AzContext -SubscriptionId $Config.SpokeSubscriptionId | Out-Null
    $spokePeering = Get-AzVirtualNetworkPeering `
        -VirtualNetworkName $Config.SpokeVnetName `
        -ResourceGroupName $Config.SpokeResourceGroup `
        -Name $Config.SpokePeeringName -ErrorAction SilentlyContinue
    if ($spokePeering) {
        Remove-AzVirtualNetworkPeering `
            -VirtualNetworkName $Config.SpokeVnetName `
            -ResourceGroupName $Config.SpokeResourceGroup `
            -Name $Config.SpokePeeringName -Force
        Write-Success "Spoke -> hub peering removed."
    } else {
        Write-Info "Spoke -> hub peering not found (already removed or never created)."
    }

    Write-Host ""
    Write-Host "Peering removal complete." -ForegroundColor Green
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# CREATE MODE: Peering in both directions
# Both peerings must exist for bidirectional connectivity.
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "4/5" "Creating hub -> spoke peering (hub subscription)..."
Set-AzContext -SubscriptionId $Config.HubSubscriptionId | Out-Null

$existingHubPeer = Get-AzVirtualNetworkPeering `
    -VirtualNetworkName $Config.HubVnetName `
    -ResourceGroupName $Config.HubResourceGroup `
    -Name $Config.HubPeeringName -ErrorAction SilentlyContinue

if ($existingHubPeer) {
    Write-Info "Hub -> spoke peering already exists. State: $($existingHubPeer.PeeringState)"
} else {
    Add-AzVirtualNetworkPeering `
        -Name $Config.HubPeeringName `
        -VirtualNetwork $hubVnet `
        -RemoteVirtualNetworkId $spokeVnet.Id `
        -AllowVirtualNetworkAccess `
        -AllowForwardedTraffic `
        -AllowGatewayTransit:$Config.AllowGatewayTransit | Out-Null

    Write-Success "Hub -> spoke peering created: $($Config.HubPeeringName)"
}

Write-Step "5/5" "Creating spoke -> hub peering (spoke subscription)..."
Set-AzContext -SubscriptionId $Config.SpokeSubscriptionId | Out-Null

$existingSpokePeer = Get-AzVirtualNetworkPeering `
    -VirtualNetworkName $Config.SpokeVnetName `
    -ResourceGroupName $Config.SpokeResourceGroup `
    -Name $Config.SpokePeeringName -ErrorAction SilentlyContinue

if ($existingSpokePeer) {
    Write-Info "Spoke -> hub peering already exists. State: $($existingSpokePeer.PeeringState)"
} else {
    Add-AzVirtualNetworkPeering `
        -Name $Config.SpokePeeringName `
        -VirtualNetwork $spokeVnet `
        -RemoteVirtualNetworkId $hubVnet.Id `
        -AllowVirtualNetworkAccess `
        -AllowForwardedTraffic `
        -UseRemoteGateways:$Config.UseRemoteGateways | Out-Null

    Write-Success "Spoke -> hub peering created: $($Config.SpokePeeringName)"
}

# ─────────────────────────────────────────────────────────────────────────────
# VERIFY PEERING STATE
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Verifying peering state..." -ForegroundColor Gray

Start-Sleep -Seconds 5  # Allow Azure to propagate peering state

Set-AzContext -SubscriptionId $Config.SpokeSubscriptionId | Out-Null
$spokePeerStatus = Get-AzVirtualNetworkPeering `
    -VirtualNetworkName $Config.SpokeVnetName `
    -ResourceGroupName $Config.SpokeResourceGroup `
    -Name $Config.SpokePeeringName

Set-AzContext -SubscriptionId $Config.HubSubscriptionId | Out-Null
$hubPeerStatus = Get-AzVirtualNetworkPeering `
    -VirtualNetworkName $Config.HubVnetName `
    -ResourceGroupName $Config.HubResourceGroup `
    -Name $Config.HubPeeringName

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  Peering Summary" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "  spoke -> hub  [$($Config.SpokePeeringName)]"
$spokeColor = if ($spokePeerStatus.PeeringState -eq "Connected") { "Green" } else { "Red" }
Write-Host "    State: $($spokePeerStatus.PeeringState)" -ForegroundColor $spokeColor
Write-Host ""
Write-Host "  hub -> spoke  [$($Config.HubPeeringName)]"
$hubColor = if ($hubPeerStatus.PeeringState -eq "Connected") { "Green" } else { "Red" }
Write-Host "    State: $($hubPeerStatus.PeeringState)" -ForegroundColor $hubColor
Write-Host ""

if ($spokePeerStatus.PeeringState -eq "Connected" -and $hubPeerStatus.PeeringState -eq "Connected") {
    Write-Host "  Peering CONNECTED successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Next steps:"
    Write-Host "    1. Verify DNS resolution from spoke reaches hub DNS resolver"
    Write-Host "    2. Link hub Private DNS Zones to the spoke VNET"
    Write-Host "       (see docs\roles.md for DNS zone list)"
    Write-Host "    3. Confirm spoke traffic routes via hub firewall"
    Write-Host "       (check hub route table effective routes)"
} else {
    Write-Host "  WARNING: Peering state is not yet Connected." -ForegroundColor Yellow
    Write-Host "  Wait a few minutes and re-check in the Azure Portal." -ForegroundColor Yellow
}

Write-Host ""
