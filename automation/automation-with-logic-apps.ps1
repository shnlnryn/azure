

$creds = Get-AutomationPSCredential -Name "secazautomation"

Connect-MsolService -Credential $creds

Connect-AzureAD -Credential $creds

$TodaysDate = Get-Date -Format dd-MM-yyyy
$ReportFileName = "ProPlus" + $TodaysDate + ".csv"
$ReportItem = New-Item -ItemType File -Name $ReportFileName


$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


$ProplusUsers = Get-MsolUser -MaxResults 1000000 | Where-Object {($_.licenses).AccountSkuId -match "O365_Tenant:OFFICESUBSCRIPTION"}


Foreach ($User in $ProplusUsers) {

        $UsageLocation = Get-AzureADUser -ObjectId $User.userprincipalname | Select-Object Country, City, Department, PhysicalDeliveryOffice, State, UsageLocation

        $Details=(Get-AzureADUser -ObjectId $user.userprincipalname).AssignedPlans|where {$_.ServicePlanId -eq "43de0ff5-c92c-492b-9116-175376d08c38"}|Select-Object Service, AssignedTimestamp

        
          $User.userprincipalname
          $Details.AssignedTimestamp


        $object = [pscustomobject]@{
        User = $User.UserPrincipalName
        Country = $UsageLocation.Country
        City = $UsageLocation.City
        UsageLocation = $UsageLocation.UsageLocation
        Department = $UsageLocation.Department
        State = $UsageLocation.State
        OfficeLocation = $UsageLocation.PhysicalDeliveryOffice
        Service = $Details.Service
        AssignedDate = $Details.AssignedTimestamp
        }


        $object | Export-CSV -Path $ReportFileName -NoTypeInformation -Append

        }



#Store file in Azure Storage

$storageKey = "YOUR_Azure_storage_key"
$storageContext = New-AzureStorageContext -StorageAccountName "YOURstorageAccountname" -StorageAccountKey $storageKey
Set-AzureStorageBlobContent -File $ReportFileName -Container "exportedfiles" -BlobType "Block" -Context $storageContext -Verbose



## Logic App [Email-O365Proplus-Report] copies the report from blob to Sharepoint document library



