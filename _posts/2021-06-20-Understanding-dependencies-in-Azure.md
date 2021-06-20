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

### OS Disk Storage

There are 4 tiers of managed disk storage inside of Azure today (Standard HDD,Standard SSD, Premium SSD's and Ultra Disk SSD's). Your cost scales with the IOPS requirements you have for the select VM. A Domain controller for a small organization may be best fit with a HDD while a SAP workload may be better off on a SSD. 

````terraform
resource "azurerm_managed_disk" "example" {
  name                 = "cloudops-disk-01"
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