# imports
import boto3
import json

# get the service resource
dynamodb = boto3.resource('dynamodb')

# define table to be working on; set to variable "table"
table = dynamodb.Table('tf_visitorcounttable')

def lambda_handler(event, context):
    response = table.get_item(
        Key={
            'record_id': 'lol' # this record ID has already been set within DynamoDB
            }
    )

    count = response['Item']['record_count'] # pull out the actual count number from DynamoDB
    
    # increment count by 1 on DynamoDB table
    table.update_item(
        Key={
            'record_id': 'lol',
        },
        UpdateExpression='SET record_count = record_count + :val1',
        ExpressionAttributeValues={
            ':val1': 1 
        }
    )
    
    # get count again after it's been incremented...
    response = table.get_item(
        Key={
            'record_id': 'lol'
            }
    )
    
    # ...so that you can set the count and return it
    count = response['Item']['record_count']
        
    return {
        'count': count
    }