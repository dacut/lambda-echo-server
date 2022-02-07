variable "domain_name" {
    description = "The domain name to use for service discovery."
    type = string
}

variable "ipv4_cidr_block" {
    type = string
    description = "IPv4 CIDR block to allocate for the VPC."
    default = "10.55.0.0/16"
}

variable "region" {
    type = string
    description = "AWS region to operate in."
    default = "us-west-2"
}

variable "service_name" {
    type = string
    description = "The name to use for service discovery."
    default = "echo"
}
