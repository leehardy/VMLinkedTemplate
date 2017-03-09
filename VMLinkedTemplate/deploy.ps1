$now = Get-Date
$expiry = (Get-Date).AddHours(2)
$templateFolder = "C:\Users\Lee Hardy\Documents\git-repos\VMLinkedTemplate\VMLinkedTemplate\VirtualMachines"
$templates = Get-ChildItem $templateFolder
$storageAccountResourceGroup = "storage-prod-rg"
$containerName = "templates"
$policyName = "templateDeploymentPolicy"
$deploymentResourceGroup = "vm-prod-rg"


function createStorageAccount ($resourceGroup) {
	Do {
		$saPrefix = -join ((97..122) | Get-Random -Count 10 | % {[char]$_})
		$saRandName = $saPrefix + "slrs1"
		$sa = Get-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
	} While ($sa)

	New-AzureRmStorageAccount -Name $saRandName -ResourceGroupName $resourceGroup -SkuName Standard_LRS -Location australiaeast -Kind Storage
}

Login-AzureRmAccount

$storageAccountName = (createStorageAccount($storageAccountResourceGroup)).StorageAccountName
Set-AzureRmCurrentStorageAccount -Name $storageAccountName -ResourceGroupName $storageAccountResourceGroup

New-AzureStorageContainer -Name templates
New-AzureStorageContainerStoredAccessPolicy -Policy $policyName -Container $containerName -Permission rl -StartTime $now -ExpiryTime $expiry
$sasToken = New-AzureStorageContainerSASToken -Name $containerName -Policy $policyName

foreach ($template in $templates) {
	$templateToUpload = "$templateFolder\$template"
	Set-AzureStorageBlobContent -File $templateToUpload -Container $containerName -Blob $template -Force
}

New-AzureRmResourceGroupDeployment -Name "NewVM" -ResourceGroupName $deploymentResourceGroup -TemplateFile ".\deploy.json" -TemplateParameterFile ".\deploy.parameters.json" -containerSasToken $sasToken  -storageAccountName $storageAccountName

Remove-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $storageAccountResourceGroup -Confirm

