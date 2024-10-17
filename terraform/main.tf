## GENERAL
# initial terraform block to set the required provider, source and version
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.38.0"
    }
  }
  # S3 BACK END FOR REMOTE STATE STORAGE
  backend "s3" {
    bucket         = "ob-crc-remote-state"
    key            = "terraformstate/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-remote-state-dynamodb"
    encrypt        = true
    profile        = "crc"
  }
}

# set some config about the provider
provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = ["c:\\Users\\obutt\\.aws\\config"]
  shared_credentials_files = ["c:\\Users\\obutt\\.aws\\credentials"]
  profile                  = "crc"
}

## REMOTE STATE
# dynamo for lock table
resource "aws_dynamodb_table" "tf_lock" {
  name         = "tf-remote-state-dynamodb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

# s3 bucket to store state
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "ob-crc-remote-state"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "tf_state_bucket_version" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

## DYNAMODB
# create the dynamodb table
resource "aws_dynamodb_table" "tf_visitorcounttable" {
  name         = "tf_visitorcounttable"
  hash_key     = "record_id"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "record_id"
    type = "S"
  }
}

# create the one and only item this table needs
resource "aws_dynamodb_table_item" "tf_visitorcounttable_items" {
  table_name = aws_dynamodb_table.tf_visitorcounttable.name
  hash_key   = aws_dynamodb_table.tf_visitorcounttable.hash_key
  item       = <<EOF
        {
            "record_id":{"S": "lol"},
            "record_count":{"N": "818"}
        }
    EOF

  lifecycle {
    ignore_changes = [
      item
    ]
  }
}

## LAMBDA
# create role for lambda usage
resource "aws_iam_role" "tf_LambdaDynamoDBRole" {
  name               = "tf_LambdaDynamoDBRole"
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
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:BatchGetItem",
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:BatchWriteItem",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem"
          ],
          "Resource" : "arn:aws:dynamodb:us-east-1:995961725945:table/tf_visitorcounttable"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:us-east-1:995961725945:*"
        },
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : "*"
        }
      ]
  })
}

# create attachment of the role to the policy
resource "aws_iam_role_policy_attachment" "tf_LambdaDynamoDBPolicy_attachment" {
  role       = aws_iam_role.tf_LambdaDynamoDBRole.name
  policy_arn = aws_iam_policy.tf_LambdaDynamoDBPolicy.arn
}

# create lambda function
resource "aws_lambda_function" "tf_lambdafunctionnamegoeshere" {
  filename         = "lambda_function.zip"
  function_name    = "tf_LambdaFunctionNameGoesHere"
  role             = aws_iam_role.tf_LambdaDynamoDBRole.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda_function.zip")
}

# create lambda permissions for api gateway
resource "aws_lambda_permission" "tf_apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tf_lambdafunctionnamegoeshere.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:995961725945:${aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id}/*/${aws_api_gateway_method.tf_method.http_method}${aws_api_gateway_resource.tf_get.path}"

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
  parent_id   = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.root_resource_id
  path_part   = "GET"
  rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
}

# create api gateway method
resource "aws_api_gateway_method" "tf_method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.tf_get.id
  rest_api_id   = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
}

# create api gateway method integration to lambda
resource "aws_api_gateway_integration" "tf_integration" {
  rest_api_id             = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id             = aws_api_gateway_resource.tf_get.id
  http_method             = aws_api_gateway_method.tf_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
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
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

}

# create api gateway method integration response from lambda
resource "aws_api_gateway_integration_response" "tf_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id = aws_api_gateway_resource.tf_get.id
  http_method = aws_api_gateway_method.tf_method.http_method
  status_code = aws_api_gateway_method_response.tf_method_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
}

# create api gateway method options
resource "aws_api_gateway_method" "tf_method_options" {
  rest_api_id      = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id      = aws_api_gateway_resource.tf_get.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = false
}

# create api gateway method options response
resource "aws_api_gateway_method_response" "tf_options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id = aws_api_gateway_resource.tf_get.id
  http_method = aws_api_gateway_method.tf_method_options.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# create api gateway options integration
resource "aws_api_gateway_integration" "tf_options_integration" {
  rest_api_id          = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id          = aws_api_gateway_resource.tf_get.id
  http_method          = "OPTIONS"
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"
  request_templates = {
    "application/json" : "{\"statusCode\": 200}"
  }
}

#create api gateway options integration response
resource "aws_api_gateway_integration_response" "tf_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  resource_id = aws_api_gateway_resource.tf_get.id
  http_method = aws_api_gateway_integration.tf_options_integration.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# create api gateway deployment
resource "aws_api_gateway_deployment" "tf_apigw_deployment" {
  rest_api_id = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.tf_get,
      aws_api_gateway_method.tf_method,
      aws_api_gateway_method.tf_method_options,
      aws_api_gateway_integration.tf_integration
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# create api gateway stage
resource "aws_api_gateway_stage" "tf_stage" {
  deployment_id = aws_api_gateway_deployment.tf_apigw_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.tf_APIGatewayCreatedForLambdaFunction.id
  stage_name    = "prod"
}
