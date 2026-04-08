
resource "azurerm_resource_group" "azurerm" {
  name     = "${var.application_name}-${var.environment_name}-RG"
  location = var.location
}

resource "random_string" "suffix" {
  length  = 7
  special = false
  upper   = false
}


resource "azurerm_storage_account" "azurerm" {
  name                     = "sa${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.azurerm.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "container" {
 name                  = "backupfile"
 storage_account_id    = azurerm_storage_account.azurerm.id
 container_access_type = "private"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                        = "kv-${var.application_name}-${var.environment_name}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.azurerm.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  rbac_authorization_enabled = true

}

resource "azurerm_role_assignment" "user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "prod-law-workspace"
  location            = var.location
  resource_group_name = azurerm_resource_group.azurerm.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "Alerts" {
  name                       = "diag-setting"
  target_resource_id         = azurerm_storage_account.azurerm.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_metric { 
    category = "AllMetrics"
  }
}


resource "azurerm_virtual_network" "main" {
  name                = "${var.application_name}-${var.environment_name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.azurerm.name
  address_space       = [var.base_address_space]
}

locals {
  range_address_space= cidrsubnet(var.base_address_space,10,0)
  web_address_space  = cidrsubnet(var.base_address_space,10,1)
  app_address_space  = cidrsubnet(var.base_address_space,10,2)
}

resource "azurerm_subnet" "range" {
  name                 = "sn-range"
  resource_group_name  = azurerm_resource_group.azurerm.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.range_address_space]
}

resource "azurerm_subnet" "web" {
  name                 = "sn-web"
  resource_group_name  = azurerm_resource_group.azurerm.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.web_address_space]
}

resource "azurerm_subnet" "app" {
  name                 = "sn-app"
  resource_group_name  = azurerm_resource_group.azurerm.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.app_address_space]
}

resource "azurerm_network_security_group" "access" {
  name                = "Nsg-${var.application_name}-${var.environment_name}-access"
  location            = azurerm_resource_group.azurerm.location
  resource_group_name = azurerm_resource_group.azurerm.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${chomp(data.http.myip.response_body)}/32"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "acces_range" {
  subnet_id                 = azurerm_subnet.range.id
  network_security_group_id = azurerm_network_security_group.access.id
}

data "http" "myip" {
  url = "https://api.ipify.org"
}