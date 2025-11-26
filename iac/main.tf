terraform {
  required_version = ">= 0.14.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.20"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

locals {
  rg_name            = "${var.prefix}-rg"
  aks_name           = "${var.prefix}-aks"
  acr_name           = replace("${var.prefix}registry", "-", "")
  storage_account    = replace("${var.prefix}storage", "-", "")
  key_vault_name     = replace("${var.prefix}-kv", "-", "")
  pii_container_name = "leaked-data"
}

resource "azurerm_resource_group" "fakebank" {
  name     = local.rg_name
  location = var.location
  tags = {
    Environment = var.environment
    Owner       = "FakeBankingDemo"
    Purpose     = "CNAPP-vulnerability-demo"
  }
}

resource "azurerm_storage_account" "pii" {
  name                            = local.storage_account
  resource_group_name             = azurerm_resource_group.fakebank.name
  location                        = azurerm_resource_group.fakebank.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  public_network_access_enabled   = true
  https_traffic_only_enabled      = false
  min_tls_version                 = "TLS1_0"
  shared_access_key_enabled       = true

  blob_properties {
    versioning_enabled = false
  }

  tags = {
    Classification = "Confidential"
  }
}

resource "azurerm_storage_container" "pii" {
  name                  = local.pii_container_name
  storage_account_name  = azurerm_storage_account.pii.name
  container_access_type = "container"
}

resource "azurerm_storage_blob" "pii_dataset" {
  name                   = "personal-info.json"
  storage_account_name   = azurerm_storage_account.pii.name
  storage_container_name = azurerm_storage_container.pii.name
  type                   = "Block"
  source                 = "${path.module}/data/customer-data.json"
  content_type           = "application/json"
}

resource "azurerm_container_registry" "acr" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.fakebank.name
  location            = azurerm_resource_group.fakebank.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_key_vault" "kv" {
  name                          = local.key_vault_name
  location                      = azurerm_resource_group.fakebank.location
  resource_group_name           = azurerm_resource_group.fakebank.name
  tenant_id                     = var.tenant_id
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  enable_rbac_authorization     = true
  sku_name                      = "standard"
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "azurerm_kubernetes_cluster" "fakebank" {
  name                = local.aks_name
  location            = azurerm_resource_group.fakebank.location
  resource_group_name = azurerm_resource_group.fakebank.name
  dns_prefix          = "${var.prefix}-dns"

  sku_tier = "Free"

  default_node_pool {
    name                       = "default"
    vm_size                    = "Standard_D2_v2"
    node_count                 = 1
    enable_host_encryption     = false
    os_disk_size_gb            = 30
    max_pods                   = 250
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  api_server_access_profile {
    authorized_ip_ranges = ["0.0.0.0/0"]
  }

  role_based_access_control_enabled = false
  local_account_disabled            = false
  http_application_routing_enabled  = false

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    dns_service_ip    = "10.0.0.10"
    service_cidr      = "10.0.0.0/16"
  }

  tags = {
    Environment = var.environment
    Workload    = "FakeBanking"
  }
}

# Note: Kubernetes resources (namespace, deployments, services) are deployed
# via kubectl in the deploy-microservices.sh script to avoid provider dependency issues
