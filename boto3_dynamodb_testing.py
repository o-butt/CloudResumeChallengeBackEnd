# import boto3

# # Get the service resource.
# dynamodb = boto3.resource('dynamodb', region_name='us-east-1')

# # Print list of all tables
# # tables = list(dynamodb.tables.all())
# # print(tables)


# # Instantiate a table resource object without actually
# # creating a DynamoDB table. Note that the attributes of this table
# # are lazy-loaded: a request is not made nor are the attribute
# # values populated until the attributes
# # on the table resource are accessed or its load() method is called.
# table = dynamodb.Table('visitorcounttable')

# # Print out some data about the table.
# # This will cause a request to be made to DynamoDB and its attribute
# # values will be set based on the response.
# print(table)

# # Get item from table
# response = table.get_item(
#     Key={
#         'visitorcount':
#     }
# )
# item = response['Item']
# print(item)
print("\n--------------------------------------------------------------------------------------------------------------------------------------\n")

import boto3
import time

# Get the service resource.
dynamodb = boto3.resource('dynamodb')

# # Create the DynamoDB table.
# table = dynamodb.create_table(
#     TableName='users',
#     KeySchema=[
#         {
#             'AttributeName': 'username',
#             'KeyType': 'HASH'
#         },
#         {
#             'AttributeName': 'last_name',
#             'KeyType': 'RANGE'
#         }
#     ],
#     AttributeDefinitions=[
#         {
#             'AttributeName': 'username',
#             'AttributeType': 'S'
#         },
#         {
#             'AttributeName': 'last_name',
#             'AttributeType': 'S'
#         },
#     ],
#     ProvisionedThroughput={
#         'ReadCapacityUnits': 5,
#         'WriteCapacityUnits': 5
#     }
# )

# # Wait until the table exists.
# print("Creating table.....")
# table.wait_until_exists()

# # Print out some data about the table.
# print(table.item_count)

table = dynamodb.Table('users')


# print(table.creation_date_time)

# table.put_item(
#    Item={
#         'username': 'joebloggs',
#         'first_name': 'Joe',
#         'last_name': 'Bloggs',
#         'age': 28,
#         'account_type': 'standard_user',
#     }
# )

response = table.get_item(
    Key={
        'username': 'janedoe', # have to request key username and last_name as the last_name is the sort key 
        'last_name': 'Doe' # making the username AND last_key a composite key (together they are the primary key)
    }
)
print("Response is: ", response)
item = response['Item']
age = item['age']
print("\n")
print("Item is", item)

print("\n")

print("Age BEFORE update is", age)
# time.sleep(5)

# increment age by 1
table.update_item(
    Key={
        'username': 'janedoe',
        'last_name': 'Doe'
    },
    UpdateExpression='SET age = age + :val1',
    ExpressionAttributeValues={
        ':val1': 1 
    }
)

#### get age again
response = table.get_item(
    Key={
        'username': 'janedoe', # have to request key username and last_name as the last_name is the sort key 
        'last_name': 'Doe' # making the username AND last_key a composite key (together they are the primary key)
    }
)
#### set age again
item = response['Item']
age = item['age']

print("Age AFTER update is", age)