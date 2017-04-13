param(
[string]$fullname = "",
[string]$filename = "C:\pstemp\users.txt",
[string]$export = "DG"
)
$userlist1 = @() 

# Grab-Info function will iterate through searching for SID, Displayname and Username for the username, settling on whatever is found first. 
function Grab-Info($search)
    {
    $nametest = get-aduser -LDAPFilter "(objectsid=$search)" -properties *
    if(!($nametest))
        {
        $nametest = get-aduser -LDAPFilter "(displayname=$search)" -properties *
        }
    if(!($nametest))
        {
        $nametest = get-aduser -LDAPFilter "(name=$search)" -properties *
        }
    return $nametest
}

# Write-Info function will create a psobject, and store the data that is grabbed. Future versions will allow a user to select more properties to grab.
function Write-info($details)
    {
        $fundetails = New-Object psobject
        $firstname = $details.givenname
        $lastname = $details.surname
        $concateName = "$firstname $lastname"
        $groups = $details.memberof -replace "CN=",""
        $groups = $groups -replace ",.*,DC=local", ""
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "UserName" -Value $details.Name
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "FullName" -Value $concateName
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "SID" -Value $details.SID
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "LastLogon" -Value $details.LastLogonDate
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Email" -Value $details.EmailAddress
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Modified" -Value $details.Modified
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Groups" -Value $groups
        return $fundetails
    }

# Parse-Info function will iterate through the file or username details and find details.
function Parse-info($parser)
    {
    $userlist = @()
    foreach($user in $parser)
        {
            $userDetails1 = Grab-Info $user
            if($userdetails1)
            {
                foreach($matchuser in $userdetails1)
                {
                    $fundetails1 = write-info($matchuser)
                    $userlist += $fundetails1
                }
            }
            else
            {
                write "$user not found"
            }
        }
        return $userlist
    }

# A check to ensure that active directory module is loaded
if(!(get-module activedirectory))
{
import-module activedirectory
}
# Simple search if there is not a filename.
if(!($filename))
{
            $userlist1 =parse-info($fullname)            
            $userlist1 | format-table
}
# A more fancy search is there is a filename.
elseif($filename)
{
    try
    {
        $filelist = get-content $filename -erroraction stop
    }
    catch
    {
        $Error1 = $_.Exception.Message
        $Failed1 = $_.Exception.ItemName
        Write-host "Error: $error1" 
        Write-host "Failed Item: $failed1"
    }
if($filelist)
{
    $userlist1 = parse-info $filelist
    $userlist1 | format-table
    if($export) 
    {
        if($export -eq "DG")
        {
            # If the DG option is selected, it will output the full user list as a datagrid. Currently not working. Need to fix. 
            $userlist1  | Out-GridView
        }

    }
}
}