terraform {
  required_version = ">= 0.12"
  backend "s3" {
    bucket = "aws-global-transit-gateway"
    region = "eu-west-1"
  }
}
