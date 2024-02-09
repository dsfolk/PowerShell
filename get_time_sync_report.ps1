# This script is to fetch time sync status from all DCs in the forest
# ################################################################################

# Importing module for AD
Import-Module ActiveDirectory

# This line is for custom credentials. If you want to use different UserID and Password to connect to the DCs for fetching timestamp, enable the below block:
# Also enable the Credential switch "-Credential $cred" in line no 47.
<#
$UserName = "Domain\User"
$Password = "Password1"
$cred = [System.Management.Automation.PSCredential]::new($UserName, $(ConvertTo-SecureString -String $Password -AsPlainText -Force))
#>

$result = @()
$local_machine_timezone = [System.TimeZoneInfo]::Local

# Running loop for each domain in forest
foreach ($domain in (Get-ADForest).Domains) {

    # Getting all DCs for current domain
    $dcs = Get-ADDomainController -Filter * -Server $domain
    
    # Running loop for each DCs
    foreach ($dc in $dcs) {

        # This codeblock will run on the DCs from local machine
        $script_block = {

            $sourceTime = Get-Date
            $sourceTimeZone = [System.TimeZoneInfo]::Local
            $targetTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("India Standard Time")

            if ($(cmd /c "w32tm /resync /force")[1] -eq "The command completed successfully.") { $ForceTimeSyncStatus = "Success" }
            else { $ForceTimeSyncStatus = "Failed" }
            
            [PSCustomObject]@{
                SystemTime          = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($sourceTime, $sourceTimeZone.Id, $targetTimeZone.Id)
                TimeSyncSource      = $(cmd /c "w32tm /query /source")
                ForceTimeSyncStatus = $ForceTimeSyncStatus
            }
        }

        try { 

            # This command will run the above codeblock in Domain Controllers. 
            $command_result = Invoke-Command -ComputerName $dc.HostName -ArgumentList $local_machine_timezone -ScriptBlock $script_block -ErrorAction Stop -ErrorVariable gettimeinfo_error #-Credential $cred  
            
            $result += [PSCustomObject]@{

                Hostname            = $command_result.PSComputerName
                ConnectionStatus    = $true
                SystemTime          = $command_result.SystemTime
                TimeSyncSource      = $command_result.TimeSyncSource
                ForceTimeSyncStatus = $command_result.ForceTimeSyncStatus
            }
        }
        
        catch { 
            
            $result += [PSCustomObject]@{

                Hostname            = $dc.HostName
                ConnectionStatus    = $false
                SystemTime          = $null
                TimeSyncSource      = $null
                ForceTimeSyncStatus = $null
            }
        }
    }
}

$result | Format-Table
