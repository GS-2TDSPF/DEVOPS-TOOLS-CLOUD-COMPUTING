# Variáveis principais
# chmod +x gs-scripts.sh
# sed -i 's/\r$//' gs-scripts.sh
# ./gs-scripts.sh
GRUPO=orbitalert
LOCATION=eastus2
USER=azureuser
PASSWORD='OrbitAlert12@'

RG=rg-$GRUPO
VNET=vnet-$GRUPO
SUBNET=subnet-$GRUPO
NSG=nsg-$GRUPO
VM=vm-$GRUPO

# 1. Resource Group
az group create \
  --name $RG \
  --location $LOCATION \
  --tags owner=$GRUPO environment=dev cost-center=fiap

# 2. VNet e Subnet
az network vnet create \
  --resource-group $RG \
  --name $VNET \
  --address-prefix 10.10.0.0/16 \
  --subnet-name $SUBNET \
  --subnet-prefix 10.10.1.0/24 \
  --tags owner=$GRUPO environment=dev cost-center=fiap

# 3. NSG
az network nsg create \
  --resource-group $RG \
  --name $NSG \
  --tags owner=$GRUPO environment=dev cost-center=fiap

# 4. Regras do NSG
az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG \
  --name allow-ssh \
  --protocol Tcp \
  --priority 1000 \
  --destination-port-range 22 \
  --access Allow

az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG \
  --name allow-http \
  --protocol Tcp \
  --priority 1001 \
  --destination-port-range 80 \
  --access Allow

az network nsg rule create \
  --resource-group $RG \
  --nsg-name $NSG \
  --name allow-8080 \
  --protocol Tcp \
  --priority 1002 \
  --destination-port-range 8080 \
  --access Allow

# 5. Associar NSG à subnet
az network vnet subnet update \
  --resource-group $RG \
  --vnet-name $VNET \
  --name $SUBNET \
  --network-security-group $NSG

# 6. Criar VM Ubuntu com autenticação por password
az vm create \
  --resource-group $RG \
  --name $VM \
  --image Ubuntu2204 \
  --admin-username $USER \
  --admin-password $PASSWORD \
  --authentication-type password \
  --size Standard_D2s_v3 \
  --vnet-name $VNET \
  --subnet $SUBNET \
  --nsg $NSG \
  --tags owner=$GRUPO environment=dev cost-center=fiap

# 7. Instalar Docker, Git e Nano remotamente, sem SSH
az vm run-command invoke \
  --resource-group $RG \
  --name $VM \
  --command-id RunShellScript \
  --scripts '
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl git nano

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker azureuser
  '
