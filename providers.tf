terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "472bc165-99ec-4603-8733-cc7762a1ea6a"
}