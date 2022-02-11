# Copyright 2022 Cognite AS
import argparse
import json
import os
import re

from cognite.client import CogniteClient


def write_to_file(file_name, content):
    f = open(file_name, "w")
    f.write(json.dumps(content, indent=4))
    f.close()


# default values for arguments
CDF_CLUSTER = "api"  # api, westeurope-1 etc
COGNITE_PROJECT = os.getenv("COGNITE_PROJECT")
COGNITE_APIKEY = os.getenv("COGNITE_API_KEY")

parser = argparse.ArgumentParser()

parser.add_argument(
    "--cdf-cluster", type=str, default=CDF_CLUSTER, help="api, westeurope-1 etc"
)
parser.add_argument(
    "--cognite-project", type=str, default=COGNITE_PROJECT, help="Cognite project"
)
parser.add_argument(
    "--cognite-apikey", type=str, default=COGNITE_APIKEY, help="Cognite apikey"
)

p = parser.parse_args()

# setting up the Cognite client
c = CogniteClient(client_name="oidc-iam-reader-client",
                  base_url=f"https://{p.cdf_cluster}.cognitedata.com",
                  api_key=p.cognite_apikey,
                  project=p.cognite_project
                  )

print("\nSuccessfully logged into Cognite.\n\n")

groups = c.iam.groups.list(all=True)
service_accounts = c.iam.service_accounts.list()

# separate types of service accounts
sa_with_groups = []
sa_without_groups = []
sa_with_emails = []
sa_without_emails = []

for sa in service_accounts:
    if re.match(r".*@.*\..*$", sa.name):
        sa_with_emails.append({"name": sa.name, "id": sa.id})
    else:
        sa_without_emails.append({"name": sa.name, "id": sa.id})

    if len(sa.groups) != 0:
        sa_with_groups.append({"name": sa.name, "id": sa.id, "groups": sa.groups})
    else:
        sa_without_groups.append({"name": sa.name, "id": sa.id})

groups_with_source_ids = []
groups_without_capabilities = []
groups_with_capabilities = []

# separate types of groups
for group in groups:
    if len(group.capabilities) == 0:
        groups_without_capabilities.append(
            {"name": group.name, "capabilities": group.capabilities, "source_id": group.source_id, "id": group.id})
    else:
        groups_with_capabilities.append(
            {"name": group.name, "capabilities": group.capabilities, "source_id": group.source_id, "id": group.id})
    if group.source_id is not None:
        groups_with_source_ids.append(
            {"name": group.name, "capabilities": group.capabilities, "source_id": group.source_id, "id": group.id})

# check if groups have duplicate capabilities
groups_with_duplicate_capabilities = []

for group in groups:
    for group2 in groups:
        if group.id == group2.id:
            continue
        if len(group.capabilities) == len(group2.capabilities):
            cCount = len(group.capabilities)
            for c1 in group.capabilities:
                for c2 in group2.capabilities:
                    if c1 == c2:
                        cCount = cCount - 1
            if cCount == 0:
                invertedGrouping = {"group2": {"id": group.id, "name": group.name},
                                    "group1": {"id": group2.id, "name": group2.name}}
                if invertedGrouping not in groups_with_duplicate_capabilities:
                    groups_with_duplicate_capabilities.append({"group1": {"id": group.id, "name": group.name},
                                                               "group2": {"id": group2.id, "name": group2.name}})

groups_without_service_accounts_linked = []
groups_with_service_accounts_linked = []

for group in groups:
    is_linked = False
    for sa in service_accounts:
        if group.id in sa.groups:
            is_linked = True
            break
    if not is_linked:
        groups_without_service_accounts_linked.append({"id": group.id, "name": group.name})
    else:
        groups_with_service_accounts_linked.append(
            {"id": group.id, "name": group.name, "capabilities": group.capabilities})

groups_to_be_merged = []

for sa in service_accounts:
    for sa2 in service_accounts:
        if sa.id == sa2.id:
            continue
        if len(sa.groups) > 1 and len(sa2.groups) > 1:
            common_items = set(sa.groups).intersection(set(sa2.groups))
            if len(common_items) > 1:
                pass
                # iterate through all other service accounts to see whether these are in use
                for s in service_accounts:
                    if s.id == sa.id or s.id == sa2.id:
                        continue
                    if list(common_items) in s.groups:
                        groups_to_be_merged.append(list(common_items))

print("============ Summary of Service Accounts - Total: ", len(service_accounts), " ============\n")
print("Service accounts with groups: ", len(sa_with_groups), "\n", sa_with_groups)
print("\nService accounts without groups: ", len(sa_without_groups), "\n", sa_without_groups)
print("\nService accounts with emails: ", len(sa_with_emails), "\n", sa_with_emails)
print("\nService accounts without emails: ", len(sa_without_emails), "\n", sa_without_emails)

print("\n============ Summary of Groups - Total: ", len(groups), " ============\n")

print("Groups with source ids: ", len(groups_with_source_ids), "\n", groups_with_source_ids)
print("\nGroups without capabilities: ", len(groups_without_capabilities), "\n", groups_without_capabilities)
print("\nGroups with capabilities: ", len(groups_with_capabilities), "\n", groups_with_capabilities)
print("\nGroups with service accounts linked: ", len(groups_with_service_accounts_linked), "\n",
      groups_with_service_accounts_linked)
print("\nGroups without service accounts linked: ", len(groups_without_service_accounts_linked), "\n",
      groups_without_service_accounts_linked)
print("\nGroups that can be merged: ", len(groups_to_be_merged), "\n", groups_to_be_merged)

print("Preparing IAM information files")
write_to_file("./Files/CDF_IAM/sa_with_groups.json", sa_with_groups)
write_to_file("./Files/CDF_IAM/sa_without_groups.json", sa_without_groups)
write_to_file("./Files/CDF_IAM/sa_with_emails.json", sa_with_emails)
write_to_file("./Files/CDF_IAM/sa_without_emails.json", sa_without_emails)

write_to_file("./Files/CDF_IAM/groups_with_source_ids.json", groups_with_source_ids)
write_to_file("./Files/CDF_IAM/groups_without_capabilities.json", groups_without_capabilities)
write_to_file("./Files/CDF_IAM/groups_with_capabilities.json", groups_with_capabilities)
write_to_file("./Files/CDF_IAM/groups_with_sa.json", groups_with_service_accounts_linked)
write_to_file("./Files/CDF_IAM/groups_without_sa.json", groups_without_service_accounts_linked)
write_to_file("./Files/CDF_IAM/groups_can_be_merged.json", groups_to_be_merged)

# prepare jsons for AAD scripts
print("preparing AAD source files")

# preparing app registrations source file
aad_app_registrations = [{"App name": item["name"]} for item in sa_without_emails]
write_to_file("Files/Source/APP_Registrations.json", aad_app_registrations)

# preparing aad groups source file
aad_groups = [{"Group": item["name"], "CDFAlias": item["name"], "Capabilities": item["capabilities"]} for item in
              groups_with_service_accounts_linked]
write_to_file("./Files/Source/AAD_Groups.json", aad_groups)

# preparing aad groups and memberships with emails and app registrations source file
aad_memberships_apps = []
aad_memberships_users = []
for sa in sa_with_groups:
    groups = []
    for group in sa["groups"]:
        for x in groups_with_service_accounts_linked:
            if x["id"] == group:
                groups.append(x["name"])
    if re.match(r".*@.*\..*$", sa["name"]):
        aad_memberships_users.append({"User": sa["name"], "Groups": groups})
    else:
        aad_memberships_apps.append({"Service principal": sa["name"], "Groups": groups})

write_to_file("./Files/Source/AAD_Group_Memberships_Apps.json", aad_memberships_apps)
write_to_file("./Files/Source/AAD_Group_Memberships_Users.json", aad_memberships_users)
