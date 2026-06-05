resource "aws_dynamodb_table" "basic-dynamo-table" {
  name = "wanderlust-dynamodb-table-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

attribute {
  name = "LockID"
  type = "S"
}

tags = {
 Name =  "wanderlust-shubham-${terraform.workspace}"
 }
}
