# imports
import boto3

# get the service resource
dynamodb = boto3.resource('dynamodb')

# define table to be working on set to variable "table"
table = dynamodb.Table('visitorcounttable')


response = table.get_item(
    Key={
        'record_id': 'lol' 
        }
)

print("Response is: ", response)
item = response['Item']
print("\n")
print("Item is:", item)
print("\n")
count = item['record_count']
print("Count is currently: ", count)
print("\n")

##

print("Count BEFORE update is", count)

# increment count by 1
table.update_item(
    Key={
        'record_id': 'lol',
    },
    UpdateExpression='SET record_count = record_count + :val1',
    ExpressionAttributeValues={
        ':val1': 1 
    }
)

#### get count again
response = table.get_item(
    Key={
        'record_id': 'lol'
        }
)
#### set count again
item = response['Item']
count = item['record_count']

print("Count AFTER update is", count)


# visitor count on web page would get current count + 1 and show you that as you will be +1 visitor
# TODO: turn this whole thing into some kind of function
print("\n")
print("You are visitor number: ", count)


#############################---- lambda function working below ----#############################

# imports
import boto3
import json

# get the service resource
dynamodb = boto3.resource('dynamodb')

# define table to be working on; set to variable "table"
table = dynamodb.Table('visitorcounttable')

def lambda_handler(event, context):
    response = table.get_item(
        Key={
            'record_id': 'lol' 
            }
    )

    count = response['Item']['record_count']
    
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
    
    # get count again
    response = table.get_item(
        Key={
            'record_id': 'lol'
            }
    )
    
    # set count again
    count = response['Item']['record_count']
        
    return {
        'count': count
    }