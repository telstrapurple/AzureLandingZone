# Azure Landing Zone

## Introduction

These ARM templates help deploy a simple but best-practice Azure Landing Zone, following the Microsoft Cloud Adoption Framework. This a first iteration of the repository and is all about simplicity in design and something that is so simplistic, that any new Azure organisation should be able to understand it without needing technical credit in software development.

It doesn't do bells and whistles stuff, like Azure Firewall or Azure Policy, but nor should it. The adoption of Azure should be cost-effective and scale with the maturity of the organisation and this repository when fully deployed costs as little as ~$300 AUD a month to run (VPN variant). It's a great entry-level to Azure for many organisations looking to host IaaS virtual machines and do some PaaS.

## Future works

As the introduction suggested, this is repository is first iteration. Second and third iterations would take the below manual steps and automate them in an Azure Pipeline or GitHub Action. If you want to do this yourself, please don't hesitate to contribute!

## Getting Started

To get started with ARM Templates, firstly have a read of the following [article](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/template-tutorial-create-first-template?tabs=azure-powershell). When you have read this article, you should have a basic understanding of how ARM Templates are constructed and why they're beneficial to help accelerate deployments in Azure.

To develop these ARM Templates, you should obtain the following tools of the trade:

1. [Get VS Code](https://code.visualstudio.com/download)
2. [Get the ARM Template extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools)
3. [Get Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-4.7.0)

### Build and Test

ARM templates are not necessarily built in the traditional software development sense, but they most certainly tested. To test an ARM Template, use the [Template Test Toolkit](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/test-toolkit).

### Deploy

There are multiple ways to deploy an ARM template. For example, you can:

- [Deploy via the Portal](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-portal)
- [Deploy via PowerShell](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-powershell)
- [Deploy via Azure CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-cli)

The way in which these templates were deployed originally was by using the PowerShell method. Note however that not every ARM template was run individually, as the Resource Group templates actually calls upon the many other templates in this repository. This is known as [Linked Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/linked-templates).

Use either the Resource Group ARM templates or the individual templates to complete whatever deployment you need. These templates as their name implies are templates, and can be changed based on your future needs.

```powershell
New-AzDeployment -Name "20211201-DeployResourceGroupSecurity" -Location "Australia East" -TemplateParameterFile .\parameters\resourceGroup.Security.Prod.parameters.json -TemplateFile .\resourceGroup.json
```

## Specific details

![Hub and Spoke Networking](doc/networkingHubandSpoke.jpg =500x)

The design of this Azure Landing Zone is based on the best-practice Hub and Spoke networking model. This is an intentional design choice to facilitate enterprise-scale configuration like deploying a Network Virtual Appliance (NVA) or Azure Firewall in the HUB virtual network. That way, Production and DevTest vNet traffic must traverse that. Again, as above, NVA's our and Azure Route Server don't exist in this solution, but they can.

### I'm starting from scratch, what do I need to do?

1. Create your Azure Subscription(s). Ideally you'd have two, one for Production, another for DevTest. Two is beneficial because of the cost savings you can get with DevTest pricing.
2. Update the ARM templates subscriptionID parameter to the subscription you want to deploy into. You would split this by doing find and replace:
   - `<<HubSubscriptionID>>` = Production subscription id
   - `<<ProdSubscriptionID>>` = Production subscription id
   - `<<DevSubscriptionID>>` = DevTest subscription id.
3. Update the parameter files as needed to apply the prescribe naming standard you want.
   - By default these ARM templates are assumed to be deploying into AustraliaEast hence the location code is SYD, but if you wanted to deploy into another region, there is nothing stopping you from changing this, again with a find and replace across everything. You could duplicate this entire repo to deploy into two places if you wanted to as well!
   - Update the IP CIDR's for the vNet's and Subnets based on your wanted address space for Azure.
   - Update the `networking.S2SConnectivity.Hub.parameters` template to deploy with VPN or ExpressRoute. For `vngSKU` see, https://docs.microsoft.com/en-us/azure/expressroute/expressroute-about-virtual-network-gateways or https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings
   - Update the `resourceGroup` parameters template to apply Role Based Access Controls of Owner, Contributor and Reader roles using Azure AD Groups if you want.
   - Update anything else outstanding. Including:
     - `<<customerCode>>`, a two to four letter Company Code. E.g. TP for Telstra Purple.
     - `<<customerCodeLowerCase>>`, a two to four letter Company Code in lower case. E.g. TP for Telstra Purple.
     - `<<keyVaultAzADGroupId>>`, an Azure AD Group ID that has permissions to the KeyVaults with a pre canned access policy.
     - `<<azureADGroupID>>`, and Azure AD Group ID, that has Contributor rights to Resource Groups is the `boolAzureADRBAC` parameter is set to `true`.
     - `<<email>>`, email address to get Azure Security Centre alerts.
     - `<<phone>>`, E164 phone number for Microsoft Support to call the customer on.
4. Create a single Resource Group in Azure using the naming standard agreed in step 3. Inside that create the storage account, again using the agreed naming standard with a blob container that has a read/list SAS token. TIP: Use [Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/) for creating the blob and SAS token after you created the resource group. Find-and-replace parameters:
   - `<<preCreatedStorageAccount>>`, the storage account name.
   - `<<preCreatedStorageContainer>>`, the blob container name.
   - `<<sasTokenfromPreCreatedStorageAccount>>`, the read/list SAS token.
5. Update the ARM templates, again using find-and-replace, the storage account blob URI for the files. You should see this in all the ARM templates.
6. Upload this entire repository into that blob, making sure the URI path to the templates matches those you edited in the ARM templates.
7. Locally, using PowerShell or Azure CLI deploy each of the `resourceGroup` ARM templates, and the nestedTemplates in the storage account will do all the rest for you.
8. Coffee!

Note: Some resources groups have dependencies on resources deployed in other resource groups. For example, Log Analytics and Storage diagnostics. Try deploying them in this order:

1. `administration` resource group.
2. `network` resource group.
3. `security` resource group.
4. `backup` resource group.
5. All other resource groups.

Alternatively, you deploy each resource individually, rather than using the resource group ARM templates.

### IaaS

Provided in this repository is an IaaS VM ARM template that does all the things, including configuring log analytics, backup and even [desired state configuration](https://docs.microsoft.com/en-us/powershell/scripting/dsc/overview/overview?view=powershell-7).

## Contribute

Anyone can contribute to this repo! License is MIT. All you need to do is learn about is Git version control in VS Code and you should be well under way!

- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Git version control in VS Code](https://code.visualstudio.com/docs/introvideos/versioncontrol)
