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

##### - First Create a resource group to manage the AKS cluster resources.

```az group create --name pkar-aks-rg --location eastus```
