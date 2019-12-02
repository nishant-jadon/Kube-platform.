#!/bin/bash
aksversion='1.13.7'
while ! [[ "$env" =~ ^(sb|dv|ut|pd)$ ]] 
do
  echo "Please specifiy environment [sb, dv,ut,pd]?"
  read -r env
done 
 
case $env in
 
  dv)
    servicecidr="10.66.64.0/18"
    dnsserver="10.66.64.10"
    az account set --subscription 'RangerRom DEV'
    subscriptionid=$(az account show --subscription 'RangerRom DEV' --query id | sed  's/\"//g')
    ;;
 
  sb)
    servicecidr="10.69.64.0/18"
    dnsserver="10.69.64.10"
    az account set --subscription 'RangerRom SANDBOX'
    subscriptionid=$(az account show --subscription 'RangerRom SANDBOX' --query id | sed  's/\"//g')
    ;;
 
  ut)
    servicecidr="10.70.64.0/18"
    dnsserver="10.70.64.10"
    az account set --subscription 'RangerRom TEST'
    subscriptionid=$(az account show --subscription 'RangerRom TEST' --query id | sed  's/\"//g')
    ;;
 
  pd)
    servicecidr="10.68.64.0/18"
    dnsserver="10.68.64.10"
    az account set --subscription 'RangerRom PROD'
    subscriptionid=$(az account show --subscription 'RangerRom PROD' --query id | sed  's/\"//g')
    ;;  
  *)
    echo "environment not found"
    exit
    ;;
esac
 
env="rrau${env}"
location="australiaeast"
 
az group create --location $location --name "${env}-aks-rg"
sleep 5
 
az feature register -n VMSSPreview --namespace Microsoft.ContainerService
az provider register -n Microsoft.ContainerService
 
az aks create \
    --resource-group "${env}-aks-rg" \
    --name "${env}-aks-cluster" \
    --enable-vmss \
    --node-count 2 \
    --kubernetes-version $aksversion \
    --generate-ssh-keys \
    --network-plugin azure \
    --service-cidr $servicecidr \
    --dns-service-ip $dnsserver \
    --vnet-subnet-id "/subscriptions/${subscriptionid}/resourceGroups/${env}-network-rg/providers/Microsoft.Network/virtualNetworks/${env}-network/subnets/${env}-aks-cluster-subnet"
 
 
 
clusterprincipalid=$(az ad sp list --display-name ${env}-aks-cluster --query [0].objectId)
resourceGroupid=$(az group show --name ${env}-network-rg --query 'id')
echo "Configuring cluster to owner ${resourceGroupid}"
cmd="az role assignment create --role Contributor --assignee $clusterprincipalid --scope $resourceGroupid"
eval $cmd
 
 
echo "Configuring AKS Cluster with Tiller"
az aks get-credentials --resource-group "${env}-aks-rg" --name "${env}-aks-cluster" --overwrite-existing
kubectl apply -f ./config/tiller-rbac.yml
helm init --service-account tiller
 
while ! [[ ${#privatekey} -gt 2000 ]]
do
  echo "Please provide TLS Private Key - BASE64 Encoded PEM?"
  read -r privatekey
done
 
kubectl create namespace scpi-${env}
cat ./config/rangerrom-tls.yml  | sed "s/THEPRIVATEKEY/$privatekey/" > temptls.yml
kubectl apply -f temptls.yml -n default
#The Flag --export is going to be deprecated - Below is workaround.
kubectl get secret rangerrom-tls --namespace=default -o yaml | \
   sed '/^.*creationTimestamp:/d' |\
   sed '/^.*namespace:/d' |\
   sed '/^.*resourceVersion:/d' |\
   sed '/^.*selfLink:/d' |\
   sed '/^.*uid:/d' |\
   kubectl apply --namespace=scpi-${env} -f -
 
rm -f ./temptls.yml
privatekey=""
 
echo "Setup container registry permissions"
az acr create -n "${env}containerregistry" -g "${env}-common-rg" --sku Premium
containerid=$(az acr show -n ${env}containerregistry --query id)
principalidaks=$(az ad sp list --all --query "([?contains(to_string(displayName),'"${env}-aks-cluster"')].objectId)[0]")
cmd1="az role assignment create --role acrpull --assignee $principalidaks --scope $containerid"
eval $cmd1
 
echo "Setup container registry permissions - Centralised"
containerid=$(az acr show --subscription 'RangerRom PROD' -n rraupdcontainerregistry --query id)
cmd2="az role assignment create --role acrpull --assignee $principalidaks --scope $containerid"
eval $cmd2
