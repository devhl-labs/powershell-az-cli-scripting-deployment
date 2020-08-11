# TODO: set variables
$studentName = "shawn"
$rgName = "$studentName-rg-autodeploy"
$vmName = "$studentName-vm-autodeploy"
$vmSize = "Standard_B2s" # az vm list-sizes --query "[? contains(name, 'B2')] | [1].name"
$vmImage = "Canonical:UbuntuServer:18.04-LTS:latest" # az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn"
$vmAdminUsername = "student"
$kvName = "$studentName-lc0820-ps-kv"
$kvSecretName = "ConnectionStrings--Default"
$kvSecretValue = "server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode"

az configure --default group="$rgName"
az configure --default vm="$vmName"

# TODO: provision RG
az group create -n "$rgName" 

# TODO: provision VM
$vm = (az vm create --name "$vmName" --resource-group "$rgName" --size "$vmSize" --image "$vmImage" --admin-username "$vmAdminUserName" --assign-identity --generate-ssh-keys)
$vmObj = $vm | ConvertFrom-Json

# TODO: capture the VM systemAssignedIdentity
#$VmObjectId="$(az vm show -g "$rgName" --n "$vmName" --query "identity.principalId")"  #available with $vmObj.identity.systemAssignedIdentity

# TODO: open vm port 443
az vm open-port -g "$rgName" -n "$vmName" --port 443

# provision KV
az keyvault create -n $kvName --resource-group "$rgName" --enable-soft-delete false --enabled-for-deployment true #enable-soft-delete has been deprecated

# TODO: create KV secret (database connection string)
az keyvault secret set --vault-name $kvName -n $kvSecretName --value $kvSecretValue

# TODO: set KV access-policy (using the vm ``systemAssignedIdentity``)
az keyvault set-policy -n "$kvName" --object-id $vmObj.identity.systemAssignedIdentity --secret-permissions get list

# configure the VM
$startingDirectory = Get-Location
Set-Location $PSScriptRoot
az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/1configure-vm.sh
az vm run-command invoke --command-id RunShellScript --scripts @vm-configuration-scripts/2configure-ssl.sh
az vm run-command invoke --command-id RunShellScript --scripts @deliver-deploy.sh
Set-Location $startingDirectory

# TODO: print VM public IP address to STDOUT or save it as a file
Write-Output "VM available at $($vmObj.publicIpAddress)"
