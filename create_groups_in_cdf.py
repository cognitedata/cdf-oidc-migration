# Copyright 2022 Cognite AS
import argparse
import json
import os.path
import datetime

from cognite.client import CogniteClient
from cognite.client.data_classes import Group, DataSet

# to avoid relative path issues
dir_path = os.path.dirname(os.path.realpath(__file__))


def get_formatted_date():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%b_%d_%y_%H:%M:%S")


def write_to_file(file_name, content):
    f = open(file_name, "w")
    f.write(content)
    f.close()


def dict_compare_keys(d1, d2):
    d1_keys = set(d1.keys())
    d2_keys = set(d2.keys())
    if len(d1_keys - d2_keys) > 0 or len(d2_keys - d1_keys) > 0:
        return False
    return True


# this will only compare the capabilities of both groups
def compare_group(group, new_group):
    if len(group.capabilities) != len(new_group.capabilities):
        return False
    if len(group.capabilities) == 0:
        return True
    for g1 in group.capabilities:
        g1_acl = next(iter(g1))
        match_found = False
        for g2 in new_group.capabilities:
            # check if g2 contains the acl of g1
            g2_acl = next(iter(g2))
            if g1_acl == g2_acl:
                match_found = True
                # compare actions
                g1_actions = g1.get(g1_acl).get("actions")
                g2_actions = g2.get(g2_acl).get("actions")
                if sorted(g1_actions) == sorted(g2_actions):
                    # compare scope
                    g1_scope = g1.get(g1_acl).get("scope")
                    g2_scope = g2.get(g2_acl).get("scope")
                    # compare the keys in scope (all, datasetScope, currentScope)
                    scope_key_equal = dict_compare_keys(g1_scope, g2_scope)
                    if scope_key_equal:
                        # if it is dataset scope, compare the dataset IDs as well
                        g1_scope_type = next(iter(g1_scope))
                        g2_scope_type = next(iter(g2_scope))
                        if g1_scope_type in ["datasetScope", "assetRootIdScope", "idscope"]:
                            if sorted(list(map(int, g1_scope.get(g1_scope_type).get("ids")))) == sorted(g2_scope.get(g2_scope_type).get("ids")):
                                return True
                            else:
                                return False
                        else:
                            return True
                    else:
                        return False
                else:
                    return False
        if not match_found:
            return False
    return False


def bootstrap(client, file, batch):
    """
    Load AzureAD script generated JSON for AADGroups.
    """
    create_status = ""
    mode = "batch" if batch else "interactive"

    with open(file, "r") as f:
        groups = json.load(f)
    f.close()
    
    existing_groups = {group.name: group for group in client.iam.groups.list(all=True)}
    for maingrp, grpdict in groups.items():
        for grpname, properties in grpdict.items():
            # this will be set to True in case missing resources are found in CDF
            abort = False
            try:
                capabilities = properties["Capabilities"]
                if capabilities == "None":
                    capabilityList = []
                else:
                    capabilityList = capabilities

                for cap in capabilityList:
                    for type in cap:
                        if "datasetScope" in cap[type]["scope"].keys():
                            ids = []
                            # iterate all dataset ids in scope and create missing ones
                            for id in cap[type]["scope"]["datasetScope"]["ids"]:

                                data_set = client.data_sets.retrieve(id=int(id))
                                if not data_set:
                                    print(f"Dataset {id}, does not exist for Group: {grpname}. Skipped. Please verify and rerun")
                                    abort = True
                                    create_status += f"{grpname},-,skipped - Dataset:{id} does not exist,{mode}," \
                                                     f"{properties['ID']},{get_formatted_date()}\n"
                                ids.append(data_set.id)
                            cap[type]["scope"]["datasetScope"]["ids"] = ids

                if abort:
                    continue

                group_obj = Group(name=grpname, capabilities=capabilityList)
                group_obj.source_id = properties["ID"]
                group_obj.source = grpname

                if grpname in existing_groups:
                    existing_group = existing_groups[grpname]
                    # compare properties in the group
                    # compare capabilities
                    if not compare_group(existing_group, group_obj):
                        print(f"Existing group {grpname} with different capabilities. Skipped. Please verify and rerun")
                        create_status += f"{grpname},{str(existing_group.id)},skipped - group already-exists with different capabilities,{mode}," \
                                         f"{existing_group.source_id},{get_formatted_date()}\n"
                        continue
                    # if source id is not specified, the group will be recreated with the new source id
                    if existing_group.source_id is None or existing_group.source_id == "":
                        choice = "y"
                        if not batch:
                            choice = input(f"\nUpdating source id of group: {grpname} in CDF. Proceed? (y/n):").lower()
                        if choice == "n":
                            create_status += f"{grpname},-,skipped - group exists but source id not updated,{mode},-,{get_formatted_date()}\n"
                            continue
                        elif choice == "y":
                            print(f"Group {grpname} exists with missing source ID, re-creating the group")
                            group = client.iam.groups.create(group_obj)
                            client.iam.groups.delete(existing_groups[grpname].id)
                            create_status += f"{grpname},{str(group.id)},re-created - added source id,{mode}," \
                                             f"{group.source_id},{get_formatted_date()}\n"
                            continue
                    # compare source IDs
                    if existing_group.source_id != group_obj.source_id:
                        print(f"Group {grpname} exists with another source id. Skipped. Please verify and rerun")
                        create_status += f"{grpname},{str(existing_group.id)},skipped - group already-exists with different source id,{mode}," \
                                         f"{existing_group.source_id},{get_formatted_date()}\n"
                        continue
                    if existing_group.source_id == group_obj.source_id:
                        print(f"Group {grpname} exists with same source id. Verified.")
                        create_status += f"{grpname},{str(existing_group.id)},already-exists,{mode}," \
                                         f"{existing_group.source_id},{get_formatted_date()}\n"
                        continue
                else:
                    choice = "y"
                    if not batch:
                        choice = input(f"\nCreating group: {grpname} in CDF. Proceed? (y/n):").lower()
                    if choice == "n":
                        create_status += f"{grpname},-,skipped - group not created,{mode},-,{get_formatted_date()}\n"
                        continue
                    elif choice == "y":
                        group = client.iam.groups.create(group_obj)
                        create_status += f"{grpname},{str(group.id)},group created,{mode}," \
                                         f"{group.source_id},{get_formatted_date()}\n"
                        print(f"Group: {grpname}, created successfully")
            except Exception as e:
                print(f":Failed to create group due to error: {e}")
                raise e
    return create_status


CDF_CLUSTER = "api"  # api, westeurope-1 etc
COGNITE_PROJECT = os.getenv("COGNITE_PROJECT")
COGNITE_APIKEY = os.getenv("COGNITE_API_KEY")


def str2bool(v):
    if isinstance(v, bool):
        return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')


if __name__ == "__main__":
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
    parser.add_argument(
        "--batch", type=str2bool, default=False, help="create all at once as a batch"
    )

    p = parser.parse_args()

    client = CogniteClient(
        api_key=p.cognite_apikey,
        project=p.cognite_project,
        base_url=f"https://{p.cdf_cluster}.cognitedata.com",
        client_name="cognite-python-dev",
    )

    status = bootstrap(client, "Files/Output/Output_AADGroups_With_IDs.json", p.batch)

    date = get_formatted_date()
    path = os.path.join(dir_path, f'Files/Output/CDF_Group_Report_{date}.csv')
    headers = "group-name,group_id,status,mode,source-id,timestamp(UTC)\n"
    write_to_file(path, headers + status)
