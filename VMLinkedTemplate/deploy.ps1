$now = Get-Date
$expiry = (Get-Date).AddHours(2)
$templateFolder = ".\VirtualMachines"
$templates = Get-ChildItem $templateFolder
$containerName = "templates"
$accessPolicyName = "templateDeploymentPolicy"
$deploymentResourceGroup = "vm-prod-rg"
$location = "australiaeast"

function createStorageAccount ($resourceGroup) {
	Do {
		$saPrefix = -join ((97..122) | Get-Random -Count 19 | % {[char]$_})
		$saRandName = $saPrefix + "slrs1"
		$sa = Get-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
	} While ($sa)

	New-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -SkuName Standard_LRS -Location australiaeast -Kind Storage
}

# Check if there's currently a logged in Azure Session
Try {
  Get-AzureRmContext
} Catch {
  if ($_ -like "*Login-AzureRmAccount to login*") {
    Login-AzureRmAccount
  }
}

$exists = Get-AzureRmResourceGroup -Name $deploymentResourceGroup -ErrorAction SilentlyContinue
If (!$exists) {
	New-AzureRmResourceGroup -Name $deploymentResourceGroup -Location $location
}

$storageAccountName = (createStorageAccount($deploymentResourceGroup)).StorageAccountName
Set-AzureRmCurrentStorageAccount -Name $storageAccountName -ResourceGroupName $deploymentResourceGroup

New-AzureStorageContainer -Name templates -Permission Off
New-AzureStorageContainerStoredAccessPolicy -Policy $accessPolicyName -Container $containerName -Permission rl -StartTime $now -ExpiryTime $expiry
$sasToken = New-AzureStorageContainerSASToken -Name $containerName -Policy $accessPolicyName

foreach ($template in $templates) {
	$templateToUpload = "$templateFolder\$template"
	Set-AzureStorageBlobContent -File $templateToUpload -Container $containerName -Blob $template -Force
}

New-AzureRmResourceGroupDeployment -Name "NewVM" -ResourceGroupName $deploymentResourceGroup -TemplateFile ".\deploy.json" -TemplateParameterFile ".\deploy.parameters.json" -containerSasToken $sasToken  -storageAccountName $storageAccountName

Remove-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $deploymentResourceGroup -Force

