provider "aws" {
    region = var.region
}

data "aws_availability_zones" "available" {
    state = "available"
    filter {
        name = "opt-in-status"
        values = ["opt-in-not-required"]
    }
}

locals {
    azs = slice(sort(data.aws_availability_zones.available.names), 0, 2)
}

terraform {
    required_providers {
        aws = {
            version = "~> 3.70"
        }
    }

    backend "s3" { }
}
