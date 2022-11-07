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


# create lambda function
resource "aws_lambda_function" "tf_lambdafunctionnamegoeshere" {
    filename = lambda_function.zip
    function_name = "tf_lambdafunctionnamegoeshere"
    role = aws_iam_role.tf_LambdaDynamoDBRole.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.9"
}