terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-skyline-tfstate-eus2"
    storage_account_name = "stskylinetfro2esw" # <-- from bootstrap output
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate" # one state file per environment
    use_azuread_auth     = true                    # use your Entra login, not storage keys
  }
}