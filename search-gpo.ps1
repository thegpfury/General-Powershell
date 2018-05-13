# Search-GPO
# Will McVicker
# www.furytech.net
# This script will search through ALL GPO's in your AD for settings that you select. 

param (
[bool]$getgpo = 0, # This saves all the GPO's in your AD to the specified path. If you already saved it, make this a 0 to save time.
[string]$xmlPath = "c:\pstemp\all.xml", # Where to save XML, as well as where to read XML
# Policy list is a list of strings for Policy settings that you want to check if enabled or not
[array]$policylist = @("Password Protect the Screen saver","Disable the Connections page","Prohibit access to the Control Panel","Add/Delete items","Prevent access to the command prompt","Remove Task Manager","Prevent changing proxy settings","Prohibit adding items","prohibit closing items"),
# Reglist is a list of registry settings that you want to pull. Please note that this script will disregard any entries flagged with "D"
# This will prevent showing entries that are configured to delete existing registry entries
[array]$reglist = @("ProxyOverride","AutoConfigURL","ProxyServer"),
# This uses colon separated values to store a GPO policy that has an affiliated setting
# Yes, this is ugly. But, it works. 
[array]$policyedlist = @("Force specific screen saver:edittext:value","Screen saver Timeout:numeric:value","Hide These Specified Drives in My Computer:Dropdownlist:Value")
)

function CheckSettings($registry)
{
    if($registry)
    {
        if($registry.action -eq "D")
        {
        return ""
        }
        elseif($registry.action -ne "D")
        {
        return $registry.value
        }
    }
    else
    {
    return ""
    }
}
function CheckPolicy($Pol)
{
    if($Pol)
    {
    return $Pol.State
    }
    else
    {
    return ""
    }
}
function DirectGrab($Grab)
{
    if($Grab)
    {
    return $Grab
    }
    else
    {
    return ""
    }
}
function GrabFavorites($faves)
{
    if($faves)
    {
        foreach($fave in $faves)
        {
        $favelist += $fave.url
        }
       return $favelist
    }
    else
    {
    return ""
    }
}
# This initiates the array that holds the PSOBJECTS
$totalarray = @()

# Grab all GPOs from AD, if option selected
if($getgpo = 1)
{
    get-gporeport -all -reporttype xml -Path $xmlpath
}
# Loads all xml from the path
[xml]$all = get-content -Path $xmlpath

# Starts going through each GPO
foreach($gpo in $all.report.gpo)
{
    # PSObject for each GPO
    $array = New-Object PSObject
    Add-Member -inputObject $array -memberType NoteProperty -name “GPO” -value $gpo.name

    # Check for the registry settings
    foreach($reg in $reglist)
    {
    $registryset = checksettings($gpo.user.ExtensionData.extension.registrysettings.collection.collection.collection.collection.collection.collection.collection.registry.properties | where {$_.name -eq $reg})
    if ($registryset)
        {
        Add-Member -inputObject $array -memberType NoteProperty -name $reg -value $registryset
        }
    else
        {
        Add-Member -inputObject $array -memberType NoteProperty -name $reg  -value "N/A"
        }
    }   
    
    # Check for policys
    foreach($policy in $policylist)
    {
        $currentpolicy = checkpolicy($gpo.user.extensiondata.extension.policy | where {$_.name -eq "$policy"})
        if($currentpolicy)
        {
            Add-Member -inputObject $array -memberType NoteProperty -name $policy -value $currentpolicy
        }
        else
        {
            Add-Member -inputObject $array -memberType NoteProperty -name "$policy" -value "N/A"
        }
    }   
    # Check for PAC file -> IE Setting
    $pacIE = directgrab($gpo.user.extensiondata.extension.automaticconfiguration.proxyurl)
    if ($pacIE)
    {
        Add-Member -inputObject $array -memberType NoteProperty -name “PacIE” -value $pacIE
    }
    else
    {
        Add-Member -inputObject $array -memberType NoteProperty -name “PacIE” -value "N/A"
    }

    # Check for Enforced SCR
    foreach($policyed1 in $policyedlist)
    {
        $edpolname, $edvalue, $edpolicy = ($policyed1 -split(':'))
        $edname = "$edpolname $edvalue $edpolicy"
        $currentpolicyed = $gpo.user.extensiondata.extension.policy | where {$_.name -eq $edpolname}
        if ($currentpolicyed)
        {
                  
            Add-Member -inputObject $array -memberType NoteProperty -name $edpolname -value $currentpolicyed.State
            # Ugly Hack to deal with the 4th point in dropdown list. Gonna see if this breaks more
            if($edvalue -like "DropDownList")
            {
            Add-Member -inputObject $array -memberType NoteProperty -name $edname -value $currentpolicyed.$edvalue.$edpolicy.name
            }    
            else 
            {
                Add-Member -inputObject $array -memberType NoteProperty -name $edname -value $currentpolicyed.$edvalue.$edpolicy
            }
        }
        else
        {
            Add-Member -inputObject $array -memberType NoteProperty -name $edpolname -value "N/A"
            Add-Member -inputObject $array -memberType NoteProperty -name $edname  -value "N/A"
        }
    }
    # Check for Faves
    $favearray1 = grabfavorites($gpo.user.extensiondata.extension.favoriteurl)
    if ($favearray1)
    {
        Add-Member -inputObject $array -memberType NoteProperty -name “FaveList” -value $favearray1
    }
    else
    {
        Add-Member -inputObject $array -memberType NoteProperty -name “FaveList” -value "N/A"   
    }   
$totalArray += $array 
}

$totalArray | out-gridview
