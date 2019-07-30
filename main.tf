provider "azurerm" {
  subscription_id = "${var.azurerm_subscription_id}"
}

resource "azurerm_resource_group "TerraformRG" {
  name = "Terraform_Resource_Group"
  location = "East US 2"
}

## IP Space for all instances ###
resource "azurerm_virtual_network" "appnetwork" {
  name = "app-virtual-network"
  address_space = ["10.0.0.0/16"]
  location = "East US 2"
  resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
}

## Subnet lives in the virtual network ##

resource "azurerm_subnet" "appsubnet" {
   name = "app-subnet"
   resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
   virtual_network_name = "${azurerm_virtual_network.appnetwork.name}"
   address_prefix = "10.0.1.0/24"
}

resource "azurerm_public_ip" "pip" {
    name = "app-public-ip"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    public_ip_address_allocation = "static"
}

resource "azurerm_network_inferface" "NIC1"  {
    count = "${var.azurerm_instances}"
    name = "app-interface-${count.index}"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"

    ip_configuration {
        name = "demo-ip-${count.index}"
        subnet_id = "${azurerm_subnet.appsubnet.id}"
        private_ip_address_allocation = "dynamic"
        load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.demo.id}"
    }    
}

resource "azurerm_lb" "lb" { 
    name = "app-lb"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    
    frontend_ip_configuration { 
      name = "default"
      public_ip_address_id = "${azurerm_public_ip.pip.id}"
      private_ip_address_allocation = "dynamic"
    }
}

resource "azurerm_lb_rule" "lbrule" { 
    name = "app-lb-rule-80-80"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    loadbalancer_id = "${azurerm_lb.lb.id}"
    backend_address_pool_id = "${azurerm_lb_backend_address_pool.demo.id}"
    probe_id = "${azurerm_lb_probe.demo.id}"
    
    protocol  = "tcp"
    frontend_port = 80
    backend_port  = 80
    frontend_ip_configuration_name = "default"
}

## health probe to make sure there is 200 level respone back
resource "azurerm_lb_probe" "demo" { 
    name = "app-lb-probe-80-up"
    loadbalancer_id = "${azurerm_lb_lb.id}"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    protocol = "Http"
    request_path = "/"
    port = 80

}

resource "azurerm_lb_backend_address_pool" "demo" { 
    name = "demo-lb-pool"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    
}

resource "azurerm_availability_set" "appAV" { 
    name = "app-availability-set"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
}

resource "random_id" "stg_acc" { 
    prefix = "stg"
    byte_length = "4"
}
## storage account must be unique for the entire scope of azure.
resource "azurerm_storage_account" "appstgaccount" { 

    name = "${lower(random_id.storage_account.hex)}"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    location = "East US 2"
    account_type = "Standard_LRS"
}

## creating virtual container where the VMs will live.

resource "azurerm_storage_container" "kon" { 
    count = "${var.azurerm_instances}"
    name  = "app-storage-container-${count.index}"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    storage_account_name = "${azurerm_storage_account.appstgaccount.name}"
    container_access_type = "private"
    
}

## Creating VMs 

resource "azurerm_virtual_machine" "appvm"  { 
    count = "${var.azurerm_instances}"
    name = "app-instance-${count.index}"
    location = "East US 2"
    resource_group_name = "${azurerm_resource_group.TerraformRG.name}"
    network_interface_ids = ["${element(azurerm_network_interface.NIC1.*.id, count.index)}"
    vm_size = "Standard_A0"
    availability_set_id = "${azurerm_availability_set.appAV.id}"

    storage_image_reference { 
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "14.04.2-LTS"
        version = "latest"
    }
    
    storage_os_disk {
        name = "app-disk-${count.index}"
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
        #custom_data  = "${base64encode(file("${path.moduel}/templates/install.sh"))}"
    }

    os_profile_linux_config { 
        disable_password_authentication = false
    }

    
}




