# Copyright 2022 Cognite AS
param ([boolean]$dryRun = $true, [boolean]$batch = $false)

function Get-UTC-Date {
    $temp = Get-Date -UFormat "%A %B/%d/%Y %T %Z"
    $Time = Get-Date
    return $Time.ToUniversalTime().ToString("MMM_dd_yy_HH:mm:ss")
}

# create applications and service principals
function Add-AppRegistrations {
    param(
        $groups, $dryRun, $batch
    )

    $mode = ""
    if ($batch) {
        $mode += "batch"
    } else {
        $mode += "interactive"
    }

    $status = @()
    $createdApps = ""

    $groups | ForEach-Object {
        $i = [math]::Round(($status.count / $groups.count) * 100, 0)
        Write-Progress -Activity "Creating AzureAD App Registrations" -Status "$i% Complete:" -PercentComplete $i;
        #status object
        $entry = New-Object PSObject

        $appName = $_."App name"
        $AppIdName = $_."ID"
        $skipped = $false


        if ($null -eq $replyUrls) {
            $replyUrls = @()
        }

        Add-Member -InputObject $entry -MemberType NoteProperty -Name "Application" -Value $appName
        Add-Member -InputObject $entry -MemberType NoteProperty -Name "ID" -Value $AppIdName

        # check if azure app does not exist already
        if (!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue)) {
            # create app
            if (!$dryRun) {
                $confirmation = 'y'
                if (!$batch) {
                    $confirmation = Read-Host "Do you wish to create app '$($appName)' - (y/n)"
                }
                if ($confirmation -eq 'y') {
                    Write-Host "Creating Application $($appName)"
                    # appending file name to string
                    $date = Get-UTC-Date
                    $createdApps += "$($appName),created,$($mode),$($date)`n"
                    $myApp = New-AzureAdApplication -DisplayName $appName
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Created"
                } else {
                    $skipped = $true
                    Write-Host "[SKIP] Not Creating Application $($appName)"
                    # appending file name to string
                    $date = Get-UTC-Date
                    $createdApps += "$($appName),skipped,$($mode),$($date)`n"
                    Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Skipped"
                }
            }
            else {
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "To be created (Dryrun)"
            }
        }
        else {
            Write-Host "App '$($appName)' already exists in Azure"
            if (!$dryRun) {
                $date = Get-UTC-Date
                $createdApps += "$($appName),already-exists,$($mode),$($date)`n"
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "Verified (already exists)"
            }
            else {
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Status" -Value "DryRun (already exists)"
            }
        }
        if (!$dryrun -and !$skipped) {
            if (!(Get-AzureADServicePrincipal -Filter "AppId eq '$($myApp.AppId)'")) {
                $mySp = New-AzureADServicePrincipal -AccountEnabled $true -AppId $myApp.AppId -DisplayName $appName -Tags { WindowsAzureActiveDirectoryIntegratedApp }
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Service Principal" -Value "Created"
            }
            else {
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Service Principal" -Value "Verified (already exists)"
            }
        }
        else {
            if ($dryrun) {
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Service Principal" -Value "DryRun"
            } elseif ($skipped){
                Add-Member -InputObject $entry -MemberType NoteProperty -Name "Service Principal" -Value "Skipped"
            }
        }
        $status += $entry
    }
    return $status, $createdApps
}


Write-host "Preparing to create APP Registrations, dryRun: $dryRun"

$groups = Get-Content -Path "Files/Source/APP_Registrations.json" | ConvertFrom-Json

$status, $createdApps = Add-AppRegistrations -groups $groups -dryRun $dryRun -batch $batch

if (!$dryRun) {
    $date = Get-UTC-Date
    # writing created and skipped application names to files
    $outFileCreated = Join-Path (Get-Item -Path ".") "Files/Output/AppRegistration_Report_$($date).csv"
    # add file header
    $header = "app-name,status,mode,timestamp(UTC)"
    [IO.File]::WriteAllLines($outFileCreated, $header)

    Write-Host "Write App Registration Report to $($outFileCreated)"
    Add-Content $outFileCreated $createdApps
}

Write-Output $status | Format-Table -AutoSize
