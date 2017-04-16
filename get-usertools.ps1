# Get-UserTools
# Powershell tool to pull user information from AD, whether by single searches, or by searching through a text file of data. 
# Written by: Will McVicker
# Email will.mcvicker@outlook.com
# 
###### Instructions ######
#
# Basic usage
#
# get-usertools [username/displayname/SID]
#  
# Returns the information for the user that it finds. It iterates through SID, displayname, and then username to find it. 
#
# get-usertools -filename c:\users.txt -grid 1 -csv C:\user-export.csv
#
# This will pull the list of users from C:\users.txt, export datagrid with the details, as well as saving a CSV of the details found.
# You can mix and match displaynames, SIDs, and usernames in this text file, it will iterate through and see what it can find. 
#
param(
[string]$fullname = "",
[string]$filename = "",
[BOOLEAN]$grid = $false,
[string]$csv = ""
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
function Write-info($details,$found)
    {
        $fundetails = New-Object psobject
        
        if($found -eq 1)
        {
        $firstname = $details.givenname
        $lastname = $details.surname
        $concateName = "$firstname $lastname"
        $groups = $details.memberof -replace "CN=",""
        $groups = $groups -replace ",.*,DC=local", ""
        $groupstring = $groups | out-string
        $groupstring = $groupstring -replace "`n|`r", ", "
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "UserName" -Value $details.Name
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "FullName" -Value $concateName
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "SID" -Value $details.SID
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "LastLogon" -Value $details.LastLogonDate
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Email" -Value $details.EmailAddress
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Modified" -Value $details.Modified
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Groups" -Value $groupstring
        }
    else
        {
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "UserName" -Value $details
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "FullName" -Value "Not Found"
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "SID" -Value "Not Found"
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "LastLogon" -Value "Not Found"
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Email" -Value "Not Found"
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Modified" -Value "Not Found"
        Add-Member -InputObject $fundetails -MemberType NoteProperty -Name "Groups" -Value "Not Found"
        }
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
                    $fundetails1 = write-info $matchuser 1
                    $userlist += $fundetails1
                }
            }
            else
            {
                $fundetails2 = write-info $user 0
                $userlist += $fundetails2
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
        if($grid) 
        {
            # If the DG option is true, it will output the full user list as a datagrid.
            $userlist1 | Out-GridView
        }
        if($csv) 
        {
            # If the CSV option has a path, it will export a CSV with the user details
                
                try
                {
                    $csv = $userlist1  | export-csv -path $csv
                }
                catch 
                {
                    $Error1 = $_.Exception.Message
                    $Failed1 = $_.Exception.ItemName
                    Write-host "Error: $error1" 
                    Write-host "Failed Item: $failed1"
                }
        }
    }
}
