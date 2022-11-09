## GENERAL
# initial terraform block to set the required provider, source and version
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.38.0"
        }
    }
}

# set some config about the provider
provider "aws" {
    region = "us-east-1"
}

## DYNAMODB
# create the dynamodb table
resource "aws_dynamodb_table" "tf_visitorcounttable" {
    name = "tf_visitorcounttable"
    hash_key = "record_id"
    billing_mode = "PAY_PER_REQUEST"
    attribute {
      name = "record_id"
      type = "S"
    }
}

# create the one and only item this table needs
resource "aws_dynamodb_table_item" "tf_visitorcounttable_items" {
    table_name = aws_dynamodb_table.tf_visitorcounttable.name
    hash_key = aws_dynamodb_table.tf_visitorcounttable.hash_key
    item = <<EOF
        {
            "record_id":{"S": "lol"},
            "record_count":{"N": "1"}
        }
    EOF
}

## LAMBDA
# create role for lambda usage
resource "aws_iam_role" "tf_LambdaDynamoDBRole" {
    name = "tf_LambdaDynamoDBRole"
    assume_role_policy = <<EOF
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }   
            ]
        }
EOF
}

# create policy for above role (to set permissions for the role)
resource "aws_iam_policy" "tf_LambdaDynamoDBPolicy" {
    name = "tf_LambdaDynamoDBPolicy"
    policy = jsonencode(
        {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGetItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWriteItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:995961725945:table/tf_visitorcounttable"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:us-east-1:995961725945:*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
        }
    ]
})
}

# create attachment of the role to the policy
resource "aws_iam_role_policy_attachment" "tf_LambdaDynamoDBPolicy_attachment" {
    role = aws_iam_role.tf_LambdaDynamoDBRole.name
    policy_arn = aws_iam_policy.tf_LambdaDynamoDBPolicy.arn
}

# create lambda function
resource "aws_lambda_function" "tf_lambdafunctionnamegoeshere" {
    filename = "lambda_function.zip"
    function_name = "tf_LambdaFunctionNameGoesHere"
    role = aws_iam_role.tf_LambdaDynamoDBRole.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.9"
}

# create lambda permissions for api gateway
resource "aws_lambda_permission" "tf_apigw_lambda" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.tf_lambdafunctionnamegoeshere.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:us-east-1:995961725945:${aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id}/*/${aws_api_gateway_method.tf_method.http_method}${aws_api_gateway_resource.tf_get.path}"

    depends_on = [
      aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction
    ]
}


## API GATEWAY
# create api gateway (rest api)
resource "aws_api_gateway_rest_api" "tf_APIGatewayCreatedForLambdaFunction" {
    name = "tf_APIGatewayCreatedForLambdaFunction"
    endpoint_configuration {
      types = ["REGIONAL"]
    }
}

# create api gateway resource
resource "aws_api_gateway_resource" "tf_get" {
    parent_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.root_resource_id
    path_part = "GET"
    rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id 
}

# create api gateway method
resource "aws_api_gateway_method" "tf_method" {
    authorization = "NONE"
    http_method = "GET"
    resource_id = aws_api_gateway_resource.tf_get.id
    rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
}

# create api gateway method integration to lambda
resource "aws_api_gateway_integration" "tf_integration" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_get.id
    http_method = aws_api_gateway_method.tf_method.http_method
    integration_http_method = "POST"
    type = "AWS"
    # uri = aws_lambda_function.tf_lambdafunctionnamegoeshere.invoke_arn
    uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:995961725945:function:tf_LambdaFunctionNameGoesHere/invocations"
}

# create api gateway method response
resource "aws_api_gateway_method_response" "tf_method_response_200" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_get.id
    http_method = aws_api_gateway_method.tf_method.http_method
    status_code = "200"
    response_models = {
        "application/json" = "Empty"
    }
}

# create api gateway method integration response from lambda
resource "aws_api_gateway_integration_response" "tf_integration_response" {
    rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
    resource_id = aws_api_gateway_resource.tf_get.id
    http_method = aws_api_gateway_method.tf_method.http_method
    status_code = aws_api_gateway_method_response.tf_method_response_200.status_code
}

