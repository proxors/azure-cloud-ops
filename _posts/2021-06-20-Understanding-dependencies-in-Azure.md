---
title: "Understanding dependencies in Azure"
categories:
  - Fundamentals
  - Azure
tags:
  - networking
  - compute
  - troubleshooting
---


# Dependency Fundamentals

When building Azure enviornments it's important to understand what components go into the solution. In this post we will talk about how a team lead who is writing Infrastructure As Code can bulid a skeleton model of their intended enviornment.

## Why build it via Code vs. Portal?

Generating new Azure resources through the portal is a great way to start to learn Azure. However once you start building out production enterprise enviornment's you'll find common naming conventions will help you determine what resources are associated to each other. See Boston University's Data Services 

## What goes into building a VM in Azure?

Azure virtual machine's depend on 3 different resources

1. Network Interface Card
2. Disk Storage (Unmanaged & Managed)
3. Compute Family SKU

### Network Interface Card (NIC)

When building a NIC out in Azure you'll have 2 questions you will need to answer

1. What subnet will this go to?
2. Will accelereated networking be enabled? 
   - More info on that [here](https://docs.microsoft.com/en-us/azure/virtual-network/create-vm-accelerated-networking-cli#benefits)

Once you answer that then you can start building your environment out rapidly without having to be billed for compute.

````terraform
resource "azurerm_virtual_network" "VNT-01" {
  name                = "VNT-1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.1.0/24"]
}
resource "azurerm_subnet" "SUBNET-01" {
  name                 = "SUBNET-01"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.VNT-01.name
  address_prefixes     = ["10.0.1.32/27"]
}
resource "azurerm_network_interface" "NIC-01" {
    name                        = "AZ-VM-NIC-01"
    location                    = azurerm_resource_group.example.location
    resource_group_name         = azurerm_resource_group.example.name

    ip_configuration {
        name                          = "ipcofnig"
        subnet_id                     = "${azurerm_subnet.SUBNET-01.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.0.1.40"
    }
}
````

That network interface block can be easily copy/pasted multiple times to setup multiple VM's in the same subnet. This allows you to rapidly build out a blueprint of how you want the environment to look like within Azure.

### Data Disk Storage

There are 4 tiers of managed disk storage inside of Azure today (Standard HDD,Standard SSD, Premium SSD's and Ultra Disk SSD's). Your cost scales with the IOPS requirements you have for the select VM. A Domain controller for a small organization may be best fit with a HDD while a SAP workload may be better off on a SSD. 

````terraform
resource "azurerm_managed_disk" "COPS-DISK-01" {
  name                 = "COPS-DISK-01"
  location             = "usgovvirginia"
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  tags = {
    environment = "staging"
  }
}
````


### VM Compute SKU

Azure is home to a family of SKU's that can be mapped to the workload you're moving to the Cloud. Whether it's Memory optimized, Burstable or High Performance Compute there's a SKU for you. Once you have decided on the SKU family you can go ahead and deploy your compute resources with the DISK and NETWORK portion completed above. 

````terraform
resource "azurerm_virtual_machine" "VM" {
  name                  = "VM-01"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.NIC-01.id]
  vm_size               = "Standard_DS1_v2"



  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "OS-DISK-01"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  
  os_profile {
    computer_name  = ""
    admin_username = ""
    admin_password = ""
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "DATA-DISK-01" {
  managed_disk_id    = azurerm_managed_disk.COPS-DISK-01.id
  virtual_machine_id = azurerm_virtual_machine.VM.id
  lun                = "10"
  caching            = "ReadWrite"
}
````


### Deployment

Leverag Azure CloudShell or your own AzCLI to authenticate and perform the deployement above but **ONLY** do the VM Deployment step after you've verified your network requirements and which subnet the VM in question will need to be located. By not deploying the compute resource you can easily move the NIC around and re-deploy the environment with little time in between!

Good luck to all those starting in Azure!