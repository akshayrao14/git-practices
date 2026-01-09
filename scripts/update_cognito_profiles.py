import boto3
import json
import argparse

USER_POOL_ID = 'me-central-1_zABI3BmJ2'
GROUP_NAME = 'role:GenericRecruiter:recruiter'
REGION = 'me-central-1'

def update_profiles():
    parser = argparse.ArgumentParser(description='Update Cognito user profiles.')
    parser.add_argument('--update', action='store_true', help='Perform the actual update. Default is dry-run.')
    args = parser.parse_args()

    client = boto3.client('cognito-idp', region_name=REGION)
    
    total_users = 0
    eligible_users = 0
    updated_users = 0

    print(f"Starting script in {'UPDATE' if args.update else 'DRY-RUN'} mode...")

    try:
        # Pagination for listing users in group
        paginator = client.get_paginator('list_users_in_group')
        pages = paginator.paginate(
            UserPoolId=USER_POOL_ID,
            GroupName=GROUP_NAME
        )

        for page in pages:
            for user in page['Users']:
                total_users += 1
                username = user['Username']
                attributes = {attr['Name']: attr['Value'] for attr in user['Attributes']}
                
                if 'profile' not in attributes:
                    print(f"[{username}] - SKIPPED (No profile attribute)")
                    continue

                try:
                    profile_str = attributes['profile']
                    profile_data = json.loads(profile_str)
                    
                    zid = profile_data.get('zClId', '')
                    
                    if 'EHS_' in zid:
                        eligible_users += 1
                        new_zid = zid.replace('EHS_', 'EHSDEV_')
                        
                        if args.update:
                            profile_data['zid'] = new_zid
                            new_profile_str = json.dumps(profile_data)
                            
                            print(f"[{username}] - UPDATING: {zid} -> {new_zid}")
                            
                            client.admin_update_user_attributes(
                                UserPoolId=USER_POOL_ID,
                                Username=username,
                                UserAttributes=[
                                    {
                                        'Name': 'profile',
                                        'Value': new_profile_str
                                    }
                                ]
                            )
                            print(f"[{username}] - SUCCESS")
                            updated_users += 1
                        else:
                            print(f"[{username}] - DRY RUN: Would update {zid} -> {new_zid}")
                    else:
                        pass
                        print(f"[{username}] - NO CHANGE NEEDED ({zid})")
                        
                except json.JSONDecodeError:
                    print(f"[{username}] - ERROR (Invalid JSON in profile)")
                except Exception as e:
                    print(f"[{username}] - ERROR ({str(e)})")

        print("-" * 30)
        print(f"Total Users Scanned: {total_users}")
        print(f"Eligible Users: {eligible_users}")
        if args.update:
            print(f"Users Updated: {updated_users}")
        else:
            print(f"Users To Be Updated: {eligible_users} (Run with --update to apply)")
        print("-" * 30)

    except Exception as e:
        print(f"Global Error: {str(e)}")

if __name__ == '__main__':
    update_profiles()
