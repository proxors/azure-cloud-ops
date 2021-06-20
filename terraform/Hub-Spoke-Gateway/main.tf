variable "subscription_id" {
    type = string
}
variable "client_id" {
    type = string
}
variable "client_secret" {
    type = string
}
variable "tenant_id" {
    type = string
}
variable "azureRegion" {
    type = string
}

variable "sharedKey" {
    type = string
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  environment     = var.azureRegion
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "spoke1" {
  name     = "spoke1"
  location = "usgovvirginia"
}

resource "azurerm_resource_group" "spoke2" {
  name     = "spoke2"
  location = "usgovvirginia"
}

resource "azurerm_resource_group" "hub" {
  name     = "hub"
  location = "usgovvirginia"
}


#### VNETS #####

resource "azurerm_virtual_network" "hub-vnt-01" {
  name                = "hub-vnt-1"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_virtual_network" "spoke-vnt-01" {
  name                = "spoke-vnt-1"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  address_space       = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "spoke-vnt-02" {
  name                = "spoke-vnt-2"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name
  address_space       = ["10.0.2.0/24"]
}

#### SUBNETS #####

#### HUB GATEWAY SUBNET
resource "azurerm_subnet" "HUB-GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub-vnt-01.name
  address_prefixes     = ["10.0.0.0/27"]
}

#### SPOKE 2 GATEWAY SUBNET
resource "azurerm_subnet" "SPOKE-GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke-vnt-02.name
  address_prefixes     = ["10.0.2.0/27"]
}

#### SPOKE 1 SUBNET
resource "azurerm_subnet" "Spoke1-Subnet" {
  name                 = "Spoke-SUB1"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke-vnt-01.name
  address_prefixes     = ["10.0.1.32/27"]
}

resource "azurerm_subnet" "Spoke1-Bastion-Subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.spoke1.name
  virtual_network_name = azurerm_virtual_network.spoke-vnt-01.name
  address_prefixes     = ["10.0.1.64/27"]
}

#### SPOKE 2 SUBNET

resource "azurerm_subnet" "Spoke2-Subnet" {
  name                 = "Spoke-SUB2"
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke-vnt-02.name
  address_prefixes     = ["10.0.2.32/27"]
}

#### HUB SUBNET

resource "azurerm_subnet" "HUB-Subnet" {
  name                 = "Hub-SUB1"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub-vnt-01.name
  address_prefixes     = ["10.0.0.32/27"]
}

#### PUBLIC IP

resource "azurerm_public_ip" "pip" {
  name                = "PIP-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "pip2" {
  name                = "PIP-02"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name

  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "pip3" {
  name                = "PIP-03"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name
  allocation_method = "Static"
  sku = "Standard"
}



#### GATEWAY

resource "azurerm_virtual_network_gateway" "vnt-gwy" {
  name                = "VNT-GWY-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.HUB-GatewaySubnet.id
  }
}

resource "azurerm_virtual_network_gateway" "vnt-gwy2" {
  name                = "VNT-GWY-02"
  location            = azurerm_resource_group.spoke2.location
  resource_group_name = azurerm_resource_group.spoke2.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "Basic"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.pip2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.SPOKE-GatewaySubnet.id
  }
}

#### CONNECTION

resource "azurerm_virtual_network_gateway_connection" "hub_to_spoke" {
  name                = "HUB-TO-SPOKE"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.vnt-gwy.id
  peer_virtual_network_gateway_id = azurerm_virtual_network_gateway.vnt-gwy2.id

  shared_key = var.sharedKey
}

#### NIC

resource "azurerm_network_interface" "Spoke1-NIC" {
    name                        = "SPOKE1-NIC"
    location                    = azurerm_resource_group.spoke1.location
    resource_group_name         = azurerm_resource_group.spoke1.name

    ip_configuration {
        name                          = "ipcofnig"
        subnet_id                     = "${azurerm_subnet.Spoke1-Subnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.0.1.40"
    }
}

resource "azurerm_network_interface" "Spoke1-NIC-2" {
    name                        = "SPOKE1-NIC-2"
    location                    = azurerm_resource_group.spoke1.location
    resource_group_name         = azurerm_resource_group.spoke1.name

    ip_configuration {
        name                          = "ipcofnig"
        subnet_id                     = "${azurerm_subnet.Spoke1-Subnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.0.1.41"
    }
}

resource "azurerm_network_interface" "Spoke2-NIC" {
    name                        = "SPOKE2-NIC"
    location                    = azurerm_resource_group.spoke2.location
    resource_group_name         = azurerm_resource_group.spoke2.name

    ip_configuration {
        name                          = "ipconfig"
        subnet_id                     = "${azurerm_subnet.Spoke2-Subnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.0.2.40"
    }
}

resource "azurerm_network_interface" "HUB-NIC" {
    name                        = "HUB-NIC"
    location                    = azurerm_resource_group.hub.location
    resource_group_name         = azurerm_resource_group.hub.name

    ip_configuration {
        name                          = "ipconfig"
        subnet_id                     = "${azurerm_subnet.HUB-Subnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address            = "10.0.0.40"
    }
}

#### Virtual Machine's

resource "azurerm_linux_virtual_machine" "SPOKE2-VM-1" {
  name                = "SPOKE2-VM-1"
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location
  size                = "Standard_F2"
  admin_username      = "adamdost"
  network_interface_ids = [
    azurerm_network_interface.Spoke2-NIC.id,
  ]

  admin_ssh_key {
    username   = "adamdost"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}


resource "azurerm_linux_virtual_machine" "SPOKE1-VM-1" {
  name                = "SPOKE1-VM-1"
  resource_group_name = azurerm_resource_group.spoke1.name
  location            = azurerm_resource_group.spoke1.location
  size                = "Standard_F2"
  admin_username      = "adamdost"
  network_interface_ids = [
    azurerm_network_interface.Spoke1-NIC.id,
  ]

  admin_ssh_key {
    username   = "adamdost"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "HUB-VM-1" {
  name                = "HUB-VM-1"
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  size                = "Standard_F2"
  admin_username      = "adamdost"
  network_interface_ids = [
    azurerm_network_interface.HUB-NIC.id,
  ]

  admin_ssh_key {
    username   = "adamdost"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_bastion_host" "AZ-BST-01" {
  name                = "AZ-BST-01"
  location            = azurerm_resource_group.spoke1.location
  resource_group_name = azurerm_resource_group.spoke1.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.Spoke1-Bastion-Subnet.id
    public_ip_address_id = azurerm_public_ip.pip3.id
  }
}
