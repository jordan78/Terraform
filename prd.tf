provider "azurerm" {
  subscription_id = "${var.azurerm_subscription_id}"
}

resource "azurerm_resource_group "prdRG" {
  name = "Prd_Resource_Group"
  location = "East US 2"
}

## IP Space for all instances ###
resource "azurerm_virtual_network" "prdvlan" {
  name = "prdvlan-virtual-network"
  address_space = ["10.0.0.0/16"]
  location = "East US 2"
  resource_group_name = "${azurerm_resource_group.prdRG.name}"
}

## Subnet lives in the virtual network ##

resource "azurerm_subnet" "vtvsubnet" {
   name = "vtv-subnet"
   resource_group_name = "${azurerm_resource_group.prdRG.name}"
   virtual_network_name = "${azurerm_virtual_network.prdvlan.name}"
   address_prefix = "10.0.1.0/24"
}

resource "azurerm_network_interface" "gpdynamics_eth"  {
    name = "gpdynamics_ethernet"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
    ip_configuration {
        subnet_id = "${azurerm_subnet.vtv-subnet.id}"
        private_ip_address_allocation = "dynamic"
    }    
}

resource "azurerm_network_interface" "gpweb_eth"  {
    name = "gpweb_ethernet"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
    ip_configuration {
        subnet_id = "${azurerm_subnet.vtv-subnet.id}"
        private_ip_address_allocation = "dynamic"
    }    
}

resource "azurerm_network_interface" "vtvad2_eth"  {
    name = "vtvad2_ethernet"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
    ip_configuration {
        subnet_id = "${azurerm_subnet.vtv-subnet.id}"
        private_ip_address_allocation = "dynamic"
    }    
}

resource "azurerm_availability_set" "VMsAV" { 
    name = "VMsAV-availability-set"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
}

resource "random_id" "stg_acc" { 
    prefix = "stg"
    byte_length = "4"
}
## storage account must be unique for the entire scope of azure.
resource "azurerm_storage_account" "vtvvmstgaccount" { 

    name = "${lower(random_id.storage_account.hex)}"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
    location = "East US 2"
    account_type = "Standard_LRS"
}


## Creating VMs 

resource "azurerm_virtual_machine" "GPDynamics"  { 
    name = "gpdynamics"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.prdRG.name}"
    network_interface_ids = "${azurerm_network_interface.gpdynamics_eth.id}"
    vm_size = "Standard_A0"
    availability_set_id = "${azurerm_availability_set.VMsAV.id}"

    storage_image_reference { 
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "14.04.2-LTS"
        version = "latest"
    }
    
    storage_os_disk {
        name = "gpdynamics_cdrive"
        vhd_uri = "${azurerm_storage_account.appstgaccount.primary_blob_endpoint}${element(azure_storage_containter.kon.*.name, count.index)}/mydisk.vhd"
        caching = "ReadWrite"
        ####create_option = "FromImage"
    }

    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true
    
    os_profile { 
        computer_name = "app-instance-${count.index}"
        admin_username = "mmyasin"
        admin_password = "${var.azurerm_vm_admin_password}"
    }

    
}
