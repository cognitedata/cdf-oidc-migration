# Copyright 2022 Cognite AS
param ([boolean]$dryRun = $true, [boolean]$batch = $false)

function Get-UTC-Date {
    $temp = Get-Date -UFormat "%A %B/%d/%Y %T %Z"
    $Time = Get-Date
    return $Time.ToUniversalTime().ToString("MMM_dd_yy_HH:mm:ss")
}

function Add-PrincipalToAdGroup {
    param(
        $groups
    )

    $mode = ""
    if ($batch) {
        $mode += "batch"
    } else {
        $mode += "interactive"
    }

    $status = @()
    $createdGroups = ""

    $count = 0
    # Filter groups with Service Principal Memberships
    $groups | Where-Object { $null -ne $_."Service Principal" } | ForEach-Object {
        $count += 1
        $i = [math]::Round(($count / $groups.count) * 100, 0)        
        Write-Progress -Activity "Updating group memberships" -Status "$i% Complete:" -PercentComplete $i;

        $appName = $_."Service principal"
        $assignedGroups = $_."Groups"

        # App Registration check
        if ($myApp = Get-AzADApplication -DisplayName $appName -ErrorAction SilentlyContinue) {
            # Service Principal check
            if ($mySp = Get-AzADServicePrincipal -ApplicationId $myApp.AppId) {
                # iterate through grouos to assign membership
                $assignedGroups | ForEach-Object {
                    $groupName = $_
                    $entry = New-Object PSObject

                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Principal" -Value $appName
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Group" -Value $groupName

                    # Add Service principal to AAD group
                    $adgroup = Get-AzADGroup -DisplayName $groupName

                    if (!$adgroup) {
                        # if group does not exist in azure
                        Write-Host "Group '$($groupName)' not found for app '$($appName)' to assign membership"
                        Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Group not found in Azure"
                    }
                    else {
                        if (!(((Invoke-AzRestMethod -Uri "https://graph.microsoft.com/beta/groups/$($adgroup.Id)/members").Content | ConvertFrom-Json).value | Select-Object -Property DisplayName, Id, @{label='OdataType';expression={$_.'@odata.type'}} | Where-Object ( { $_.Id -eq $mySp.Id }))) {
                            if (!$dryRun) {
                                $confirmation = 'y'
                                if (!$batch) {
                                    $confirmation = Read-Host "Do you wish to add group '$($groupName)' to app '$($appName)'- (y/n)"
                                }
                                if ($confirmation -eq 'y') {
                                    Write-Host "Creating Membership for group '$($groupName)' to app '$($appName)'"
                                    # appending file name to string
                                    $date = Get-UTC-Date
                                    $createdGroups += "$($appName),$($groupName),created,$($mode),$($date)`n"
                                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Added Membership"
                                    Add-AzADGroupMember -TargetGroupObjectId $adgroup.Id -MemberObjectId $mySp.Id
                                } else {
                                    Write-Host "[SKIP] Not Creating Membership for group '$($groupName)' to app '$($appName)'"
                                    # appending file name to string
                                    $date = Get-UTC-Date
                                    $createdGroups += "$($appName),$($groupName),skipped,$($mode),$($date)`n"
                                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Skipped"
                                }
                            }
                            else {
                                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "DryRun (To be added)"
                            }
                        }
                        else {
                            $date = Get-UTC-Date
                            $createdGroups += "$($appName),$($groupName),already-exists,$($mode),$($date)`n"
                            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Membership already assigned"
                        }
                    }
                    $status += $entry
                }
            }
            else {
                # if service principal not found in azure
                Write-Host "Service Principal for app '$($appName)' not found in Azure"
                $entry = New-Object PSObject
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Principal" -Value $appName
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Service principal not found in Aure"
                $status += $entry
            }
        }
        else {
            # if app registration not found in azure
            Write-Host "App Registration '$($appName)' not found in Azure"
            $entry = New-Object PSObject
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Principal" -Value $appName
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "App registration not found in Azure"
            $status += $entry
        }
    }

    $count = 0
    # Filter groups with User Memberships
    $groups | Where-Object { $null -ne $_."User" } | ForEach-Object {
        $count += 1
        $i = [math]::Round(($count / $groups.count) * 100, 0)
        Write-Progress -Activity "Updating group memberships for end users " -Status "$i% Complete:" -PercentComplete $i;

        $useremail = $_."User"
        $assignedGroups = $_."Groups"

        # check is user exists in Azure
        if ($user = Get-AzADUser -Mail $useremail) {
            #status object
            $assignedGroups | ForEach-Object {
                $groupName = $_
                $entry = New-Object PSObject

                $user = Get-AzADUser -Mail $useremail
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Principal" -Value $user.DisplayName
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Group" -Value $groupName

                #Write-Host "Try to insert $($appName) into $($groupName)"
                # Add Service principal to AAD group
                $adgroup = Get-AzADGroup -DisplayName $groupName

                if (!$adgroup) {
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Group not found in Azure"
                }
                else {
                    # Service Principal
                    if (!(Get-AzADGroupMember -ObjectId $adgroup.Id | Where-Object ( { $_.Id -eq $user.Id }))) {
                        if (!$dryRun) {
                            $confirmation = 'y'
                            if (!$batch) {
                                $confirmation = Read-Host "Do you wish to add group '$($groupName)' to user '$($useremail)'- (y/n)"
                            }
                            if ($confirmation -eq 'y') {
                                Write-Host "Creating Membership for group '$($groupName)' to user '$($useremail)'"
                                # appending file name to string
                                $date = Get-UTC-Date
                                $createdGroups += "$($useremail),$($groupName),skipped,$($mode),$($date)`n"
                                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Added Membership"
                                Add-AzADGroupMember -TargetGroupObjectId $adgroup.Id -MemberObjectId $user.Id
                            } else {
                                Write-Host "[SKIP] Not Creating Membership for group '$($groupName)' to user '$($useremail)'"
                                # appending file name to string
                                $date = Get-UTC-Date
                                $createdGroups += "$($useremail),$($groupName),skipped,$($mode),$($date)`n"
                                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Skipped"
                            }
                        }
                        else {
                            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "DryRun (To be added)"
                        }
                    }
                    else {
                        $date = Get-UTC-Date
                        $createdGroups += "$($useremail),$($groupName),already-exists,$($mode),$($date)`n"
                        Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Membership already assigned"
                    }
                }
                $status += $entry
            }
        }
        else {
            Write-Host "User '$($useremail)' not found in Azure"
            $entry = New-Object PSObject
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Principal" -Value $useremail
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "User not found: $useremail"
            $status += $entry
        }
    }

    return $status, $createdGroups
}

Write-Host "Updating group memberships for App Registrations"
$groups = Get-Content -Path "Files/Source/AAD_Group_Memberships_Apps.json" | ConvertFrom-Json
$status, $createdGroupsForApps = Add-PrincipalToAdGroup ($groups)
Write-Output $status | Format-Table -AutoSize

Write-Host "Updating group memberships for Users in AAD"
$groups = Get-Content -Path "Files/Source/AAD_Group_Memberships_Users.json" | ConvertFrom-Json
$status, $createdGroupsForUsers = Add-PrincipalToAdGroup ($groups)
Write-Output $status | Format-Table -AutoSize

if (!$dryRun) {
    $date = Get-UTC-Date
    # writing created and skipped group names to files
    $outFileCreated = Join-Path (Get-Item -Path ".") "Files/Output/AAD_Group_Membership_Report_$($date).csv"

    # add file header
    $header = "app-name,group-name,status,mode,timestamp(UTC)"
    [IO.File]::WriteAllLines($outFileCreated, $header)

    Write-Host "Write Membership Assignment Report to $($outFileCreated)"
    Add-Content $outFileCreated $createdGroupsForApps
    Add-Content $outFileCreated $createdGroupsForUsers
}
