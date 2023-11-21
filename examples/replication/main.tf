terraform {
  required_version = ">= 1.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.24.0"
    }
  }
}

provider "aws" {}

data "aws_availability_zones" "selected" {
  state = "available"

  lifecycle {
    postcondition {
      condition     = length(self.names) > 0
      error_message = "Failed to get Avaialbe Zones"
    }
  }
}

# create vpc.

resource "aws_vpc" "example" {
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  cidr_block           = "10.0.0.0/16"
}

resource "aws_subnet" "example" {
  for_each = {
    for k, v in data.aws_availability_zones.selected.names : v => cidrsubnet(aws_vpc.example.cidr_block, 8, k)
  }

  vpc_id            = aws_vpc.example.id
  availability_zone = each.key
  cidr_block        = each.value
}

# create postgresql service.

module "this" {
  source = "../.."

  infrastructure = {
    vpc_id = aws_vpc.example.id
  }

  architecture                  = "replication"
  replication_readonly_replicas = 3
}

output "context" {
  value = module.this.context
}

output "refer" {
  value = nonsensitive(module.this.refer)
}

output "connection" {
  value = module.this.connection
}

output "connection_without_port" {
  value = module.this.connection_without_port
}

output "connection_readonly" {
  value = module.this.connection_readonly
}

output "connection_without_port_readonly" {
  value = module.this.connection_without_port_readonly
}

output "database" {
  value = module.this.database
}

output "username" {
  value = module.this.username
}

output "password" {
  value = nonsensitive(module.this.password)
}

output "endpoints" {
  value = module.this.endpoints
}

output "endpoints_readonly" {
  value = module.this.endpoints_readonly
}
