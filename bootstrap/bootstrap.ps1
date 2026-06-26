# bootstrap/bootstrap.ps1  — run ONCE to create the Terraform state backend
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$location      = "eastus2"
$rgName        = "rg-skyline-tfstate-eus2"
# Storage account names: 3-24 chars, lowercase letters+numbers, GLOBALLY unique.
$rand          = -join ((48..57) + (97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
$storageName   = "stskylinetf$rand"
$containerName = "tfstate"

# Resource group for state
az group create --name $rgName --location $location --tags managed_by=bootstrap purpose=tfstate | Out-Null

# Storage account: Standard LRS is fine; enable versioning + soft delete to protect state
az storage account create `
  --name $storageName `
  --resource-group $rgName `
  --location $location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false | Out-Null

az storage account blob-service-properties update `
  --account-name $storageName `
  --resource-group $rgName `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 14 | Out-Null

# Container (uses your Entra login, not account keys)
az storage container create `
  --name $containerName `
  --account-name $storageName `
  --auth-mode login | Out-Null

Write-Host "`n✅ Backend ready. Put these in environments/dev/backend.tf:" -ForegroundColor Green
Write-Host "  resource_group_name  = `"$rgName`""
Write-Host "  storage_account_name = `"$storageName`""
Write-Host "  container_name       = `"$containerName`""