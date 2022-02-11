# Copyright 2022 Cognite AS
import json

with open('./Files/Source/AAD_Groups.json') as json_file:
    aad_groups = json.load(json_file)

with open('Files/Source/APP_Registrations.json') as json_file:
    aad_apps = json.load(json_file)

with open('./Files/Source/AAD_Group_Memberships.json') as json_file:
    aad_memberships = json.load(json_file)

invalid_apps = []
invalid_groups = []

# validate each membership to see whether it is available in other source files
for membership in aad_memberships:
    app_name = membership.get("Service principal")
    groups = membership.get("Groups")

    # validate app registrations
    if app_name is not None:
        invalid = True
        for app in aad_apps:
            if app.get("App name") == app_name:
                invalid = False
                break
        if invalid:
            invalid_apps.append(app_name)

    # validate groups
    for group in groups:
        invalid = True
        for g in aad_groups:
            if g.get("Group") == group:
                invalid = False
                break
        if invalid:
            invalid_groups.append(group)

invalid_apps = list(set(invalid_apps))
invalid_groups = list(set(invalid_groups))

if len(invalid_apps) == 0 and len(invalid_groups) == 0:
    print("All groups and app registrations are valid in ./Files/Source/AAD_Group_Memberships.json")
else:
    if len(invalid_apps) != 0:
        print("Invalid app names found in file: ./Files/Source/AAD_Group_Memberships.json")
        print(invalid_apps)
    if len(invalid_groups) != 0:
        print("Invalid group names found in file: ./Files/Source/AAD_Group_Memberships.json")
        print(invalid_groups)

duplicate_groups = []
# validate group names for duplicates
for i in range(len(aad_groups)):
    group = aad_groups[i]
    for j in range(len(aad_groups)):
        if i == j:
            continue
        if group.get("Group").lower() == aad_groups[j].get("Group").lower():
            duplicate_groups.append(group.get("Group"))
            break

list(set(duplicate_groups))
if len(duplicate_groups) == 0:
    print("No duplicate groups found in ./Files/Source/AAD_Groups.json")
else:
    print("duplicate groups with different case found in ./Files/Source/AAD_Groups.json")
    print(duplicate_groups)
