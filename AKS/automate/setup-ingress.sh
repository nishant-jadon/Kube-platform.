#!/bin/bash
while ! [[ "$env" =~ ^(sb|dv|ut|pd)$ ]] 
do
  echo "Ensure you have owner permissions on the subscription before you continue."
  echo "Please specifiy environment [sb, dv,ut,pd]?"
  read -r env
done 

case $env in

  dv)
    az account set --subscription 'RangerRom DEV'
    ;;

  sb)
    az account set --subscription 'RangerRom SANDBOX'
    ;;

  ut)
    az account set --subscription 'RangerRom TEST'
    ;;

  pd)
    az account set --subscription 'RangerRom PROD'
    ;;  
  *)
    echo "Invalid Environment"
    exit
    ;;
esac

env="rrau${env}"

ipAddressName="${env}-aks-application-gateway-ip"
resourcegroup="MC_${env}-aks-rg_${env}-aks-cluster_australiaeast"
gatewayname="${env}-aks-application-gateway"
location="australiaeast"
vnet="${env}-network"
subnet="${env}-aks-application-gateway-subnet"

az network public-ip create \
  --resource-group $resourcegroup \
  --name $ipAddressName \
  --allocation-method Static \
  --sku Standard

sleep 20

subnetid=$(az network vnet subnet show -g "${env}-network-rg" -n "${env}-aks-application-gateway-subnet" --vnet-name ${vnet} --query id)
cmd="az network application-gateway create --name $gatewayname \
                                      --resource-group $resourcegroup \
                                      --capacity 2  \
                                      --sku "WAF_v2" \
                                      --subnet $subnetid \
                                      --http-settings-cookie-based-affinity Disabled \
                                      --location $location \
                                      --frontend-port 80 \
                                      --public-ip-address $ipAddressName"
eval $cmd
az network application-gateway waf-config set -g $resourcegroup --gateway-name $gatewayname \
                            --enabled true --firewall-mode Detection --rule-set-version 3.0

#Setup AAD POD Identity to manage application gateway
az identity create -g $resourcegroup -n "${env}-aks-aad_pod_identity"
sleep 20

principalid=$(az identity show -g $resourcegroup -n "${env}-aks-aad_pod_identity" --query 'principalId')
appgatewayid=$(az network application-gateway show -g $resourcegroup -n $gatewayname --query 'id')

echo "Assign Role so AKS can manage the Application Gateway"

echo "Configuring Create Role for identity - $principalid - for gateway"
cmd="az role assignment create --role Contributor --assignee $principalid --scope $appgatewayid"
eval $cmd

resourceGroupid=$(az group show --name $resourcegroup --query 'id')

echo "Configuring Read Role for identity - $principalid - for gateway resourcegroup"
cmd="az role assignment create --role Reader --assignee $principalid --scope $resourceGroupid"
eval $cmd

az identity show -g $resourcegroup -n "${env}-aks-aad_pod_identity"
echo "Please use the azure identity details above to configure AKS via Help for the AG Ingress Controller"
echo "Careful with copy and paste. Hidden characters can affect the values!"


echo "Ingress Controller for Azure Application Gateway"
az aks get-credentials --resource-group "${env}-aks-rg" --name "${env}-aks-cluster"
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

subscriptionid=$(az account show --query id | sed  's/\"//g')
appGatewayResourceId=$(az network application-gateway show -g $resourcegroup -n $gatewayname --query resourceGroup  | sed  's/\"//g')
identityClientid=$(az identity show -g $resourcegroup -n "${env}-aks-aad_pod_identity" --query clientId  | sed  's/\"//g')
aksfqdn=$(az aks show --resource-group "${env}-aks-rg" --name "${env}-aks-cluster" --query fqdn  | sed  's/\"//g')

cmd="helm upgrade ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
     --install \
     --namespace default \
     --debug \
     --set appgw.name=$gatewayname \
     --set appgw.resourceGroup=$appGatewayResourceId \
     --set appgw.subscriptionId=$subscriptionid \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityResourceID=/subscriptions/$subscriptionid/resourcegroups/$appGatewayResourceId/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$env-aks-aad_pod_identity \
     --set armAuth.identityClientID=$identityClientid \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set aksClusterConfiguration.apiServerAddress=$aksfqdn"
eval $cmd
kubectl get pods

