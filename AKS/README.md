## Azure Kubernetes Service (AKS)
Managed Kubernetes simplifies deployment, management and operations of Kubernetes, and allows developers to take advantage of Kubernetes without worrying about the underlying plumbing to get it up running and freeing up developer time to focus on the applications. Different Cloud Providers are offering this service – for example Google Kubernetes Engine (GKE), Amazon has Elastic Container Service for Kubernetes (EKS), Microsoft has Azure Kubernetes Service (AKS).
Here we are going to setup AKS.

#### Install Azure CLI and login to Azure
Azure Kubernetes Service management can be done from a development VM as well as using Azure Cloud Shell.  
In my setup, I’m using an CentOS VM and I’ve install Azure CLI locally. 

##### - Install Azure CLI

```
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'

sudo yum install azure-cli -y 
```
##### - Login to Azure using Azure CLI & set the Subscription

```
az login -u <username> -p <password>
az account set --subscription "Microsoft Azure XXXX"
az account show --output table
```
##### - First Create a resource group to manage the AKS cluster resources.

```az group create --name pkar-aks-rg --location eastus```

##### -  Create the Virtual Network (vnet) and the subnet 

```az network vnet create --resource-group pkar-aks-rg --name pkar-aks-vnet --address-prefixes 192.168.0.0/16 --subnet-name pkar-aks-subnet --subnet-prefix 192.168.1.0/24```

##### -  Create a service principal and assign permissions
The following example output shows the application ID and password for your service principal. These values are used in additional steps to assign a role to the service principal and then create the AKS cluster: Copy output of following command

```az ad sp create-for-rbac --skip-assignment```

To assign the correct delegations in the remaining steps, use the az network vnet show and az network vnet subnet show commands to get the required resource IDs. These resource IDs are stored as variables and referenced in the remaining steps:

```
VNET_ID=$(az network vnet show --resource-group pkar-aks-rg --name pkar-aks-vnet --query id -o tsv)
SUBNET_ID=$(az network vnet subnet show --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --name pkar-aks-subnet --query id -o tsv)
```

Now assign the service principal for your AKS cluster Contributor permissions on the virtual network using the az role assignment create command. Provide your own <appId> as shown in the output from the previous command to create the service principal:
  
```az role assignment create --assignee <appId> --scope $VNET_ID --role Contributor```

##### -  Create an AKS cluster in the virtual network

```
az aks create \
    --resource-group pkar-aks-rg \
    --name pkar-aks-cluster \
    --node-count 2 \
    --network-plugin kubenet \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --pod-cidr 10.244.0.0/16 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $SUBNET_ID \
    --generate-ssh-keys \
    --node-vm-size Standard_DS1_v2 \
    --service-principal <appId> \
    --client-secret <password>
```

##### -  Install kubectl 

```sudo az aks install-cli```

##### -  Connect to AKS Cluster (Get Credencials & setup environment)

``` 
az aks get-credentials --resource-group pkar-aks-rg --name pkar-aks-cluster
kubectl config get-clusters
kubectl config current-context
kubectl get nodes
```


