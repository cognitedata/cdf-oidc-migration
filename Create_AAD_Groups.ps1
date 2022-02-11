# Copyright 2022 Cognite AS
param ([boolean]$dryRun = $true, [boolean]$batch = $false)

function Get-UTC-Date {
    $temp = Get-Date -UFormat "%A %B/%d/%Y %T %Z"
    $Time = Get-Date
    return $Time.ToUniversalTime().ToString("MMM_dd_yy_HH:mm:ss")
}

function Add-ADGroups {
    param (
        $groups, $batch
    )

    $mode = ""
    if ($batch) {
        $mode += "batch"
    } else {
        $mode += "interactive"
    }

    $groupSource = @{}
    $status = @()
    $createdGroups = ""

    $groups | ForEach-Object {
        $i = [math]::Round(($status.count / $groups.count) * 100, 0)
        Write-Progress -Activity "Creating AzureAD groups" -Status "$i% Complete:" -PercentComplete $i;
        
        $entry = New-Object PSObject
        $groupName = $_."Group"
        $capabilityList = $_."Capabilities"
        $cdfAlias = $_."CDFAlias"

        #status object
        Add-Member -InputObject $entry -MemberType NoteProperty -Name "Group" -Value $groupName

        $group = Get-AzureADGroup -All $true | Where-Object { ($_.DisplayName -eq $groupName) }
        # if group does no already exist in Azure
        if ( $null -eq $group ) {
            if (!$dryRun) {
                $confirmation = 'y'
                if (!$batch) {
                    $confirmation = Read-Host "Do you wish to create group '$($groupName)' - (y/n)"
                }

                if ($confirmation -eq 'y') {
                    Write-Host "Creating Group $($groupName)"

                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Created"
                    $group = New-AzureADGroup -DisplayName $groupName -Description $groupName -SecurityEnabled $true -MailEnabled $false -MailNickName "NotSet"
                    Start-Sleep -Seconds 10
                    $group = Get-AzureADGroup -All $true | Where-Object { ($_.DisplayName -eq $groupName) }
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "ObjectID" -Value $group.ObjectId

                    # appending file name to string
                    $date = Get-UTC-Date
                    $createdGroups += "$($groupName),created,$($mode),$($group.ObjectId),$($date)`n"

                    if ($null -ne $cdfAlias)
                    {
                        $groupDetail = @{ }
                        $groupDetail.Add("ID", $group.ObjectId)
                        $groupDetail.Add("Capabilities", $capabilityList)
                        $groupSource.Add($cdfAlias, $groupDetail)
                    }
                    else
                    {
                        $groupDetail = @{ }
                        $groupDetail.Add("ID", $group.ObjectId)
                        $groupDetail.Add("Capabilities", $capabilityList)
                        $groupSource.Add($groupName, $groupDetail)
                    }
                } else {
                    Write-Host "[SKIP] Not Creating Group $($groupName)"
                    # appending file name to string
                    $date = Get-UTC-Date
                    $createdGroups += "$($groupName),skipped,$($mode),-,$($date)`n"
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Skipped"
                }
            }
            else {
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "DryRun (To be created)"
            }
        }
        else {
            # group already exists in Azure
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Verified (already exists)"
            Add-Member -InputObject $entry -MemberType NoteProperty -Name "ObjectID" -Value $group.ObjectId

            Write-Host "Group '$($groupName)' already exists in Azure"
            $date = Get-UTC-Date
            $createdGroups += "$($groupName),already-exists,$($mode),$($group.ObjectId),$($date)`n"

            # CDF alias has been configured in the source files
            if ($null -ne $cdfAlias) {
                $groupDetail = @{}
                $groupDetail.Add("ID", $group.ObjectId)
                $groupDetail.Add("Capabilities", $capabilityList)
                $groupSource.Add($cdfAlias, $groupDetail)
            } else {
                $groupDetail = @{}
                $groupDetail.Add("ID", $group.ObjectId)
                $groupDetail.Add("Capabilities", $capabilityList)
                $groupSource.Add($group.DisplayName, $groupDetail)
            }

        }
        $status += $entry     
    }
    $groupReturn = @{"AADGroups" = $groupSource }
    return $groupReturn, $status, $createdGroups
}

$groups = Get-Content -Path "Files/Source/AAD_Groups.json" | ConvertFrom-Json
$groupReturn, $status, $createdGroups = Add-ADGroups -groups $groups  -batch $batch

Write-Output $status | Format-Table -AutoSize

if (!$dryRun) {
    $outFile = Join-Path (Get-Item -Path ".") "Files/Output/Output_AADGroups_With_IDs.json"
    Write-Host "Write Group SourceIds to $($outfile)"
    New-Item "./Files/Output" -ItemType Directory -ErrorAction SilentlyContinue
    $content = $groupReturn | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllLines($outfile, $content)

    $date = Get-UTC-Date
    # writing created and skipped group names to files
    $outFileCreated = Join-Path (Get-Item -Path ".") "Files/Output/AADGroups_Report_$($date).csv"

    # add file header
    $header = "group-name,status,mode,id,timestamp(UTC)"
    [IO.File]::WriteAllLines($outFileCreated, $header)

    Write-Host "Write Group Report to $($outFileCreated)"
    Add-Content $outFileCreated $createdGroups
}
