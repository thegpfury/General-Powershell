$disklist = get-physicaldisk
$poollist = get-storagepool

$htmlHead = @"
<title> Storage Report - $($env:COMPUTERNAME)</title>
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 2px; border-style: solid; border-color: black; background-color: #00ff00;}
TD {border-width: 1px; padding: 2px; border-style: solid; border-color: black;}
</style>
"@


$fulldisk = @() 
$fullpool = @() 

# Function to pull basic disk health
function DiskDetails($disk)
{
    # Gathers the details
    $reliability = $disk | Get-StorageReliabilityCounter
    $diskdetails = New-Object psobject
    
    $days = [math]::round(($reliability.PowerOnHours / 24), 1)
    $gigs = [math]::round($disk.size / 1GB, 2)
    # Since not all drives collect that data, let's clean it up  
    if ($reliability.ReadErrorsUncorrected -eq $null)
    {
        $readerrors = "N/A"   
    }
    else 
    {
        $readerrors = $reliability.ReadErrorsUncorrected
    
    }

    if ($reliability.WriteErrorsUncorrected -eq $null)
    {
        $writeerrors = "N/A"   
    }
    else 
    {
    
        $writeerrors = $reliability.ReadErrorsUncorrected
    
    }

    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Model" -Value $disk.Model
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Serial" -Value $disk.SerialNumber
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Size" -Value "$gigs GB"
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Health" -Value $disk.HealthStatus
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Type" -Value $disk.MediaType
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Slot" -Value $disk.PhysicalLocation
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Runtime" -Value "$days days"
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Read Errors" -Value $readerrors
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "Write Errors" -Value $writeerrors
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "CanPool" -Value $disk.CanPool
    Add-Member -InputObject $diskdetails -MemberType NoteProperty -Name "PoolID" -Value $disk.StoragePoolUniqueId
    
    return $diskdetails
}
# This function gets the pool data
function PoolDetails($Pool)
{
    $pooldetails = New-Object psobject
    $poolgigs = [math]::round($pool.size / 1TB, 2)

    $pooldisks = (get-storagepool $pool.FriendlyName | get-physicaldisk)
    
    Add-Member -InputObject $pooldetails -MemberType NoteProperty -Name "Name" -Value $pool.FriendlyName
    Add-Member -InputObject $pooldetails -MemberType NoteProperty -Name "Health" -Value $pool.HealthStatus
    Add-Member -InputObject $pooldetails -MemberType NoteProperty -Name "Status" -Value $pool.OperationalStatus
    Add-Member -InputObject $pooldetails -MemberType NoteProperty -Name "Size" -Value "$poolgigs TB"
    
    Add-Member -InputObject $pooldetails -MemberType NoteProperty -Name "# of Disks" -Value $pooldisks.count

    return $pooldetails
}

# Pulls disk details
foreach ($disk in $disklist)
{
    $parsedDisk = diskdetails($disk)
    $fulldisk += $parseddisk
   
}
# Get's pool data
foreach ($pool in $poollist)
{
    # Skip Primordial Pool
    $parsedpool = pooldetails($pool)
    if ($parsedpool.name -eq "Primordial")
    {

    }
    # Gets rest of data
    else
    {
        $fullpool += $parsedpool
    }
}

# Time to Display data
# Default Disk Data
$fulldisk | select-object model, Serial, size, health, type, runtime, "read errors", "write errors" | format-table

# Pool Data
$fullpool | format-table

# Disks with Read Errors
$fulldisk | select-object model, Serial, size, health, slot, "read errors", "write errors" | Where-Object { $_."read errors" -ge 1 -and $_."read errors" -notlike "N/A" } | format-table

# Disks with SLot Details
$fulldisk | select-object model, Serial, size, slot | sort-object slot | format-table 

$PlainDiskData = $fulldisk | select-object model, Serial, size, health, type, runtime, "read errors", "write errors" | convertto-html -Fragment
$PoolData = $fullpool | convertto-html -Fragment
$ErrorDiskData = $fulldisk | select-object model, Serial, size, health, slot, "read errors", "write errors" | Where-Object { $_."read errors" -ge 1 -and $_."read errors" -notlike "N/A" } | convertto-html -Fragment
$DiskSlotDetails = $fulldisk | select-object model, Serial, size, slot | sort-object slot | convertto-html -Fragment

$htmlhead, $plaindiskdata, $pooldata, $errordiskdata, $diskslotdetails  | out-file -filepath diskdata.html
