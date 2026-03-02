###############################################################################
# MODULE: APPLICATION GATEWAY + WAF
#
# Deploys Azure Application Gateway v2 with Web Application Firewall (WAF v2)
# as the public ingress layer for the GenAI application.
#
# Traffic flow:
#   Internet -> WAF (App Gateway) -> APIM (internal) -> Container Apps
#
# Key configuration:
#   - WAF v2 SKU with OWASP 3.2 ruleset in Prevention mode
#   - Public IP for internet-facing HTTPS ingress
#   - SSL/TLS termination at the gateway
#   - Backend pool pointing to APIM private IP
#   - Custom health probes for APIM gateway
#   - Diagnostic settings to Log Analytics
#   - UDR on this subnet routes return traffic via hub firewall
###############################################################################

# Public IP for Application Gateway ingress
resource "azurerm_public_ip" "app_gateway" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"   # Required for App Gateway v2
  zones               = ["1", "2", "3"]  # Zone-redundant for production

  tags = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  # WAF v2 SKU is required for WAF policies
  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = var.capacity   # 2 = minimum for production
  }

  # Autoscaling between min and max instances
  autoscale_configuration {
    min_capacity = var.autoscale_min
    max_capacity = var.autoscale_max
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id   # application-gateway subnet
  }

  # Frontend: public HTTPS ingress
  frontend_ip_configuration {
    name                 = "frontend-public"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }

  frontend_port {
    name = "https-443"
    port = 443
  }

  frontend_port {
    name = "http-80"
    port = 80
  }

  # Backend pool: APIM gateway private IP address
  backend_address_pool {
    name  = "apim-backend-pool"
    ip_addresses = var.apim_private_ip_addresses
  }

  # Backend HTTP settings for APIM (HTTPS)
  backend_http_settings {
    name                  = "apim-https-settings"
    cookie_based_affinity = "Disabled"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 180   # AI calls can be slow; 3-minute timeout
    pick_host_name_from_backend_address = true

    probe_name = "apim-health-probe"
  }

  # Health probe: APIM gateway status endpoint
  probe {
    name                = "apim-health-probe"
    protocol            = "Https"
    path                = "/status-0123456789abcdef"
    host                = var.apim_gateway_hostname
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    pick_host_name_from_backend_http_settings = false

    match {
      status_code = ["200-399"]
    }
  }

  # HTTPS listener
  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "frontend-public"
    frontend_port_name             = "https-443"
    protocol                       = "Https"
    ssl_certificate_name           = "gateway-ssl-cert"
    host_names                     = var.host_names
  }

  # HTTP -> HTTPS redirect
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-public"
    frontend_port_name             = "http-80"
    protocol                       = "Http"
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https-listener"
    include_path         = true
    include_query_string = true
  }

  # SSL certificate (PFX from Key Vault via KV reference)
  ssl_certificate {
    name                = "gateway-ssl-cert"
    key_vault_secret_id = var.ssl_certificate_key_vault_secret_id
  }

  # Request routing rule: HTTPS -> APIM backend
  request_routing_rule {
    name                       = "https-to-apim"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "apim-backend-pool"
    backend_http_settings_name = "apim-https-settings"
  }

  # HTTP redirect rule
  request_routing_rule {
    name                        = "http-redirect"
    rule_type                   = "Basic"
    priority                    = 200
    http_listener_name          = "http-listener"
    redirect_configuration_name = "http-to-https"
  }

  # WAF Policy association
  firewall_policy_id = azurerm_web_application_firewall_policy.this.id

  # System-assigned identity for Key Vault SSL certificate access
  identity {
    type         = "UserAssigned"
    identity_ids = [var.gateway_identity_id]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# WAF POLICY: OWASP 3.2 in Prevention mode
# Protects GenAI API endpoints from injection, XSS, and bot attacks.
# -----------------------------------------------------------------------------
resource "azurerm_web_application_firewall_policy" "this" {
  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  location            = var.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"   # Block malicious requests
    request_body_check          = true
    max_request_body_size_in_kb = 128
    file_upload_limit_in_mb     = 100
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "0.1"
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC SETTINGS: Application Gateway
# ApplicationGatewayAccessLog captures every request for security auditing.
# ApplicationGatewayFirewallLog captures WAF rule matches.
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_application_gateway.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "ApplicationGatewayAccessLog" }
  enabled_log { category = "ApplicationGatewayPerformanceLog" }
  enabled_log { category = "ApplicationGatewayFirewallLog" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
