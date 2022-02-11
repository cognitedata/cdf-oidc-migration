# CDF-OIDC-Migration

Sample Scripts that can be used to migrate Cognite Data Fusion [(CDF)](https://docs.cognite.com/dev/) tenants from Legacy authentication to Native Tokens authentication with Azure. The scripts are available as-is and serve as starting points for you to customize/contribute to your needs:

## Step 1 - Install required dependencies

Run  `pip install -r requirements.txt`

- Make sure powershell version in 7 or higher. Use the following command to see the version

`Get-Host | Select-Object Version`

- run the following to Connect to AAD from local machine

`Connect-AzAccount -TenantId <tenant-id>`

`Connect-AzureAD -TenantId <tenant-id>`

- run the following to Connect to AAD from Azure Portal

Run `Connect-AzureAD`

## Step 2 - Fetch CDF IAM information

The API key given in this requires the following capabilities (permissions):
- ["groupsAcl:LIST"]
- ["usersAcl:LIST"]

Fetch CDF IAM information and generate CDF source files. Please replace the following in the command
- `<cdf-cluster>` --> api, omv etc
- `<cognite-project>` --> name of the project in cdf
- `<cdf-apikey>` --> api key with read/list permissions to Groups, Service Accounts

Run `python read_iam_info_cdf.py --cdf-cluster <cdf-cluster> --cognite-project <cognite-project> --cognite-apikey <cdf-apikey>`

Update following files as required
- ./Files/Source/APP_Registrations.json
- ./Files/Source/AAD_Groups.json
- ./Files/Source/AAD_Group_Memberships.json

## Step 3 - Validate Group Memberships

- Run `python validate_memberships.py` 

## Step 4 - Generate App Registrations in Azure

- Run `./Create_APP_Registrations.ps1 -dryrun $False -batch $False`

(Use flag `-batch` if you wish to create all at once. If this is `$False` (default), then you will be prompted for a confirmation for each app.)

(Use flag `-dryrun` with `$True` to see a report without creating any resources. Default is `$False`)

Output reports will be stored in `/Files/Output` folder

## Step 5 - Generate Groups in Azure

- Run `./Create_AAD_Groups.ps1 -dryrun $False -batch $False`

(Use flag `-batch` if you wish to create all at once. If this is `$False` (default), then you will be prompted for a confirmation for each app.)

(Use flag `-dryrun` with `$True` to see a report without creating any resources. Default is `$False`)

Output reports will be stored in `/Files/Output` folder

## Step 5 - Generate Group memberships in Azure

- Run `./Assign_Group_Membership.ps1 -dryrun $False -batch $False`

(Use flag `-batch` if you wish to create all at once. If this is `$False` (default), then you will be prompted for a confirmation for each app.)

(Use flag `-dryrun` with `$True` to see a report without creating any resources. Default is `$False`)

Output reports will be stored in `/Files/Output` folder

## Step 5 - Create CDF groups with source IDs

The API key given in this requires the following capabilities (permissions):
- ["groupsAcl:LIST"]
- ["groupsAcl:CREATE"]
- ["groupsAcl:DELETE"]
- ["datasetsAcl:READ"]

Please replace the following in the command
- `<cdf-cluster>` --> api, omv etc
- `<cognite-project>` --> name of the project in cdf
- `<cdf-apikey>` --> api key with read/list permissions to Groups, Service Accounts
- `<batch>` --> True or False. True if you want to create all at once. False (default) if it should be created interactively

Note: equality of existing groups and new groups will happen only with the group name. If the group name is similar and other properties are different, this will not create that specific group.

Run `python create_groups_in_cdf.py --cdf-cluster <cdf-cluster> --cognite-project <cognite-project> --cognite-apikey <cdf-apikey> --batch <batch>`

Output reports will be stored in `/Files/Output` folder

## License

[Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0)
