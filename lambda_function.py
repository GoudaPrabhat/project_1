import boto3
import logging
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rds_client = boto3.client('rds', region_name='us-west-2')
route53_client = boto3.client('route53')

REPLICA_INSTANCE_ID = "read-replica-instance"
HOSTED_ZONE_ID = "YOUR_HOSTED_ZONE_ID"
DNS_RECORD_NAME = "db.devopstrng.xyz"


def promote_read_replica():
    try:
        logger.info(f"Promoting read replica {REPLICA_INSTANCE_ID}.")
        rds_client.promote_read_replica(DBInstanceIdentifier=REPLICA_INSTANCE_ID)
        while True:
            response = rds_client.describe_db_instances(DBInstanceIdentifier=REPLICA_INSTANCE_ID)
            status = response['DBInstances'][0]['DBInstanceStatus']
            logger.info(f"Replica status: {status}")
            if status == "available":
                break
            time.sleep(30)
    except Exception as e:
        logger.error(f"Failed to promote read replica: {e}")
        raise


def update_dns():
    try:
        response = route53_client.change_resource_record_sets(
            HostedZoneId=HOSTED_ZONE_ID,
            ChangeBatch={
                'Changes': [
                    {
                        'Action': 'UPSERT',
                        'ResourceRecordSet': {
                            'Name': DNS_RECORD_NAME,
                            'Type': 'CNAME',
                            'TTL': 300,
                            'ResourceRecords': [{
                                'Value': f"{REPLICA_INSTANCE_ID}.rds.us-west-2.amazonaws.com"
                            }]
                        }
                    }
                ]
            }
        )
        logger.info(f"DNS updated: {response}")
    except Exception as e:
        logger.error(f"Failed to update DNS: {e}")
        raise


def lambda_handler(event, context):
    promote_read_replica()
    update_dns()
    return {"statusCode": 200, "body": "Failover executed."}
