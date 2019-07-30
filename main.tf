provider "azurerm" {
  subscription_id = "${var.azurerm_subscription_id}"
}

resource "azurerm_resource_group "TerraformRG" {
  name = "Terraform_Resource_Group"
  location = "East US 2"
}

resource "azurerm_virtual_network" "appnetwork" {
  name = "app-virtual-network"
  address_space = ["10.0.0.0/16"]
  location = "East US 2"
  resource_group_name = "${azurerm_resource_group.TerraformG.name}"
}

resource "azurerm_subnet" "appsubnet" {
   name = "app-subnet"
   resource_group_name = "${azurerm_resource_group.TerraformG.name}"
   virtual_network_name = "${azurerm_virtual_network.appnetwork.name}"
   address_prefix = "10.0.1.0/24"
}

