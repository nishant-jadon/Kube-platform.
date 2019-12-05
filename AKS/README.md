## Azure Kubernetes Service (AKS)
Managed Kubernetes simplifies deployment, management and operations of Kubernetes, and allows developers to take advantage of Kubernetes without worrying about the underlying plumbing to get it up running and freeing up developer time to focus on the applications. Different Cloud Providers are offering this service – for example Google Kubernetes Engine (GKE), Amazon has Elastic Container Service for Kubernetes (EKS), Microsoft has Azure Kubernetes Service (AKS).
Here we are going to setup AKS.

### Setup Azure Kubernetes Service (AKS)
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
az login 
az account set --subscription "Microsoft Azure XXXX"
az account show --output table
```
##### - First Create a resource group to manage the AKS cluster resources.

```az group create --name pkar-aks-rg --location eastus```

##### -  Create the Virtual Network (vnet) and the subnet 

```
az network vnet create --resource-group pkar-aks-rg --name pkar-aks-vnet --address-prefixes 10.20.0.0/16 --subnet-name pkar-aks-prod-subnet --subnet-prefix 10.20.1.0/24
az network vnet subnet create --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --address-prefixes 10.20.2.0/24 -n pkar-aks-uat-subnet
az network vnet subnet create --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --address-prefixes 10.20.3.0/24 -n pkar-aks-sit-subnet
az network vnet create --resource-group pkar-aks-rg --name pkar-mgm-vnet --address-prefixes 10.30.0.0/16 --subnet-name pkar-mgm-bastion-subnet --subnet-prefix 10.30.1.0/24
```

##### -  Create a service principal and assign permissions
AKS uses service principal to access other azure services like ACR & others. Default role is contributor so use “–skip-assignment”. Other available roles are as follow:

- Owner (pull, push, and assign roles to other users)
- Contributor (pull and push)
- Reader (pull only access)

The following example output shows the application ID and password for your service principal. These values are used in additional steps to assign a role to the service principal and then create the AKS cluster: Copy output of following command

```az ad sp create-for-rbac -n "pkar-app-sp" --skip-assignment```

To assign the correct delegations in the remaining steps, use the az network vnet show and az network vnet subnet show commands to get the required resource IDs. These resource IDs are stored as variables and referenced in the remaining steps:

```
VNET_ID=$(az network vnet show --resource-group pkar-aks-rg --name pkar-aks-vnet --query id -o tsv)
APPS_ID=$(az ad sp list --display-name pkar-app-sp --query [].appId --output tsv)
PROD_SUBNET_ID=$(az network vnet subnet show --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --name pkar-aks-prod-subnet --query id -o tsv)
UAT_SUBNET_ID=$(az network vnet subnet show --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --name pkar-aks-uat-subnet --query id -o tsv)
SIT_SUBNET_ID=$(az network vnet subnet show --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --name pkar-aks-sit-subnet --query id -o tsv)
```

Now assign the service principal for your AKS cluster Contributor permissions on the virtual network using the az role assignment create command. Provide your own <appId> as shown in the output from the previous command to create the service principal:
  
```
az role assignment create --assignee $APPS_ID --scope $PROD_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $UAT_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $SIT_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $VNET_ID --role Contributor
```

##### -  Get the latest available Kubernetes version in your preferred region into a bash variable. 

```version=$(az aks get-versions -l eastus --query 'orchestrators[-1].orchestratorVersion' -o tsv)```

##### -  Create an AKS PROD cluster in the PROD Subnet

```
az aks create \
    --resource-group pkar-aks-rg \
    --name pkar-aks-cluster \
    --node-count 1 \
    --network-plugin kubenet \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --pod-cidr 10.244.0.0/16 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $PROD_SUBNET_ID \
    --generate-ssh-keys \
    --node-vm-size Standard_DS1_v2 \
    --nodepool-name paksappsnp
    --kubernetes-version $version \
    --service-principal $APPS_ID \
    --client-secret <password>
```

##### -  Add another nodepoll for infra in AKS PROD cluster.

```
az aks nodepool add \
    --resource-group pkar-aks-rg \
    --cluster-name pkar-aks-cluster \
    --name paksinfranp \
    --node-count 1 \
    --node-vm-size Standard_DS1_v2 \
    --kubernetes-version $version
```

### Scale node pool

```
az aks nodepool scale \
    --resource-group pkar-aks-rg \
    --cluster-name pkar-aks-cluster \
    --name <NODEPOOL-NAME> \
    --node-count 1 \
    --no-wait
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

##### -  Setup Bastion VM in Managment VNET

```
az vm create \
    --resource-group pkar-aks-rg \
    --name pkar-mgm-bastion-vm \
    --vnet-name pkar-mgm-vnet \
    --subnet pkar-mgm-bastion-subnet \
    --image OpenLogic:CentOS:7.5:latest \
    --size Standard_DS1_v2 \
    --admin-username azureuser 
    --ssh-key-value ~/.ssh/id_rsa.pub
    
openssl rsa -in ~/.ssh/id_rsa -outform pem > id_rsa.pem

yum install putty curl git zip wget -y
puttygen id_rsa.pem -o azure.ppk -O private    
```

### Setup Azure Container Registry (ACR)
Azure Container Registry (ACR) is a managed Docker registry service based on the open-source Docker Registry.  It is a secure private registry managed by Azure, and also a managed service so Azure handles the security, backend infrastructure and storage so the developers can focus on their applications. ACR allows you to store images for all types of container deployments. Below step-by-step process of ACR creation and integration with Azure Kubernetes Service (AKS) using Azure Service Principal.

##### - Login to Azure using Azure CLI & set the Subscription

```
az login -u <username> -p <password>
az account set --subscription "Microsoft Azure XXXX"
az account show --output table
az account show
```

##### -  Create Azure Container Registry (ACR)

``` 
az acr create --name pkar-aks-acr --resource-group pkar-aks-rg --sku standard --location eastus
az acr list
```

##### - Login to ACR 
Before login please verify if docker is installed.

```
az acr login -n pkar-aks-acr
az acr list -o table
```

##### - Push docker image to ACR 
Before login please verify if docker is installed. First download image from docker, tag the image then push to ACR.

```
docker pull nginxdemos/hello
docker tag nginxdemos/hello:latest pkar-aks-acr.azurecr.io/pkarnginx:v1
docker push pkar-aks-acr.azurecr.io/pkarnginx:v1
az acr repository list -n pkar-aks-acr -o table
```

##### - Use ACR with AKS

- Get the id of the service principal configured for AKS

```
CLIENT_ID=$(az aks show --resource-group pkar-aks-rg --name pkar-aks-rg --query "servicePrincipalProfile.clientId" --output tsv)
APPS_ID=$(az ad sp list --display-name nn-aks-cluster --query [].appId --output tsv)
```

- Get the resource ID of ACR

```ACR_ID=$(az acr show --name pkar-aks-acr --resource-group pkar-aks-rg --query "id" --output tsv)```

- Assign reader role to ACR Resource  

``` az role assignment create --assignee $CLIENT_ID --role Reader --scope $ACR_ID```

##### - ACR commands

```
az acr list --resource-group pkar-aks-rg --query [].loginServer
az acr list --resource-group pkar-aks-rg --query [].loginServer --output table
az acr list --resource-group pkar-aks-rg --query [].{nnlogin:loginServer} --output table
az acr list --resource-group pkar-aks-rg --query [].{ACRloginServer:loginServer} --output table
az acr repository list -n pkar-aks-acr -o table
az acr repository show-tags --name pkar-aks-acr --repository pkarnginx --output table
```
