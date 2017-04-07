$now = Get-Date
$expiry = (Get-Date).AddHours(2)
$templateFolder = "C:\Users\Lee Hardy\Documents\git-repos\VMLinkedTemplate\VMLinkedTemplate\VirtualMachines"
$templates = Get-ChildItem $templateFolder
$containerName = "templates"
$policyName = "templateDeploymentPolicy"
$deploymentResourceGroup = "vm-prod-rg"
$deploymentResourceGroupLocation = "australiaeast"

# Generates a random name for the storage account, checks if it exists and if so generate a new name, else create the Storage Account
function createStorageAccount ($resourceGroup) {
	Do {
		$saPrefix = -join ((97..122) | Get-Random -Count 19 | % {[char]$_})
		$saRandName = $saPrefix + "slrs1"
		$sa = Get-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
	} While ($sa)

	New-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -SkuName Standard_LRS -Location $deploymentResourceGroupLocation -Kind Storage
}

# Check if there's currently a logged in Azure Session
Try {
  Get-AzureRmContext
} Catch {
  if ($_ -like "*Login-AzureRmAccount to login*") {
    Login-AzureRmAccount
  }
}

# Check if the resource group exists, if not create it
$resourceGroupExists = Get-AzureRmResourceGroup -Name $deploymentResourceGroup -ErrorAction SilentlyContinue
if (!$resourceGroupExists) {
	New-AzureRmResourceGroup -Name $deploymentResourceGroup -Location $deploymentResourceGroupLocation
}

# Create Storage Account and get SAS token for deployment
$storageAccountName = (createStorageAccount($deploymentResourceGroup)).StorageAccountName
Set-AzureRmCurrentStorageAccount -Name $storageAccountName -ResourceGroupName $deploymentResourceGroup

New-AzureStorageContainer -Name templates
New-AzureStorageContainerStoredAccessPolicy -Policy $policyName -Container $containerName -Permission rl -StartTime $now -ExpiryTime $expiry
$sasToken = New-AzureStorageContainerSASToken -Name $containerName -Policy $policyName

# Upload templates to Storage Account
foreach ($template in $templates) {
	$templateToUpload = "$templateFolder\$template"
	Set-AzureStorageBlobContent -File $templateToUpload -Container $containerName -Blob $template -Force
}

# Perform ARM deployment
New-AzureRmResourceGroupDeployment -Name "NewVM" -ResourceGroupName $deploymentResourceGroup -TemplateFile ".\deploy.json" -TemplateParameterFile ".\deploy.parameters.json" -containerSasToken $sasToken  -storageAccountName $storageAccountName

# Cleanup
Remove-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $deploymentResourceGroup -Confirm:$false

