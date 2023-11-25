locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  namespace = join("-", [local.project_name, local.environment_name])

  tags = {
    "Name" = join("-", [local.namespace, local.resource_name])

    "walrus.seal.io/catalog-name"     = "terraform-aws-rds-postgresql"
    "walrus.seal.io/project-id"       = local.project_id
    "walrus.seal.io/environment-id"   = local.environment_id
    "walrus.seal.io/resource-id"      = local.resource_id
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }

  architecture = coalesce(var.architecture, "standalone")
}

#
# Ensure
#

data "aws_vpc" "selected" {
  id = var.infrastructure.vpc_id

  state = "available"

  lifecycle {
    postcondition {
      condition     = var.infrastructure.domain_suffix == null || (self.enable_dns_support && self.enable_dns_hostnames)
      error_message = "VPC needs to enable DNS support and DNS hostnames resolution"
    }
  }
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  lifecycle {
    postcondition {
      condition     = local.architecture == "replication" ? length(self.ids) > 1 : length(self.ids) > 0
      error_message = "Replication mode needs multiple subnets"
    }
  }
}

data "aws_kms_key" "selected" {
  count = var.infrastructure.kms_key_id != null ? 1 : 0

  key_id = var.infrastructure.kms_key_id

  lifecycle {
    postcondition {
      condition     = self.enabled
      error_message = "KMS key needs to be enabled"
    }
  }
}

data "aws_service_discovery_dns_namespace" "selected" {
  count = var.infrastructure.domain_suffix != null ? 1 : 0

  name = var.infrastructure.domain_suffix
  type = "DNS_PRIVATE"
}

#
# Random
#

# create a random password for blank password input.

resource "random_password" "password" {
  length      = 10
  special     = false
  lower       = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
}

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name        = join("-", [local.resource_name, random_string.name_suffix.result])
  fullname    = join("-", [local.namespace, local.name])
  description = "Created by Walrus catalog, and provisioned by Terraform."
  database    = coalesce(var.database, "mydb")
  username    = coalesce(var.username, "rdsuser")
  password    = coalesce(var.password, random_password.password.result)

  replication_readonly_replicas = var.replication_readonly_replicas == 0 ? 1 : var.replication_readonly_replicas
}

#
# Deployment
#

# create parameters group.

locals {
  version = coalesce(try(split(".", var.engine_version)[0], null), "15")
  parameters = merge(
    {
      synchronous_commit = "off"
    },
    {
      for c in(var.engine_parameters != null ? var.engine_parameters : []) : c.name => c.value
      if try(c.value != "", false)
    }
  )
  publicly_accessible = try(var.infrastructure.publicly_accessible, false)
}

resource "aws_db_parameter_group" "target" {
  name        = local.fullname
  description = local.description
  tags        = local.tags

  family = format("postgres%s", split(".", local.version)[0])

  dynamic "parameter" {
    for_each = local.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }
}

# create subnet group.

resource "aws_db_subnet_group" "target" {
  name        = local.fullname
  description = local.description
  tags        = local.tags

  subnet_ids = data.aws_subnets.selected.ids
}

# create security group.

resource "aws_security_group" "target" {
  name        = local.fullname
  description = local.description
  tags        = local.tags

  vpc_id = data.aws_vpc.selected.id
}

resource "aws_security_group_rule" "target" {
  description = local.description

  security_group_id = aws_security_group.target.id
  type              = "ingress"
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  from_port         = 5432
  to_port           = 5432
}

# create primary instance.

resource "aws_db_instance" "primary" {
  identifier = local.architecture == "replication" ? join("-", [local.fullname, "primary"]) : local.fullname
  tags       = local.tags

  publicly_accessible    = local.publicly_accessible
  multi_az               = local.architecture == "replication"
  db_subnet_group_name   = aws_db_subnet_group.target.id
  vpc_security_group_ids = [aws_security_group.target.id]

  engine               = "postgres"
  engine_version       = local.version
  parameter_group_name = aws_db_parameter_group.target.name
  db_name              = coalesce(var.database, "mydb")
  username             = coalesce(var.username, "user")
  password             = local.password

  instance_class    = try(var.resources.class, "db.t3.medium")
  storage_type      = try(var.storage.class, "gp2")
  allocated_storage = try(var.storage.size / 1024, 20)
  storage_encrypted = try(data.aws_kms_key.selected[0].arn != null, false) #tfsec:ignore:aws-rds-encrypt-instance-storage-data
  kms_key_id        = try(data.aws_kms_key.selected[0].arn, null)

  apply_immediately       = true
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  lifecycle {
    ignore_changes = [
      db_name,
      username,
      password
    ]
  }
}

# create secondary instance.

resource "aws_db_instance" "secondary" {
  count = local.architecture == "replication" ? local.replication_readonly_replicas : 0

  identifier = join("-", [local.fullname, "secondary", tostring(count.index)])
  tags       = local.tags

  replicate_source_db    = aws_db_instance.primary.arn
  publicly_accessible    = aws_db_instance.primary.publicly_accessible
  multi_az               = true
  db_subnet_group_name   = aws_db_instance.primary.db_subnet_group_name
  vpc_security_group_ids = aws_db_instance.primary.vpc_security_group_ids

  engine               = aws_db_instance.primary.engine
  engine_version       = aws_db_instance.primary.engine_version
  parameter_group_name = aws_db_instance.primary.parameter_group_name

  instance_class    = aws_db_instance.primary.instance_class
  storage_type      = aws_db_instance.primary.storage_type
  storage_encrypted = aws_db_instance.primary.storage_encrypted
  kms_key_id        = aws_db_instance.primary.kms_key_id

  apply_immediately       = true
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
}

#
# Exposing
#

resource "aws_service_discovery_service" "primary" {
  count = var.infrastructure.domain_suffix != null ? 1 : 0

  name        = format("%s.%s", (local.architecture == "replication" ? join("-", [local.name, "primary"]) : local.name), local.namespace)
  description = local.description
  tags        = local.tags

  dns_config {
    namespace_id   = data.aws_service_discovery_dns_namespace.selected[0].id
    routing_policy = "WEIGHTED"
    dns_records {
      ttl  = 30
      type = "CNAME"
    }
  }

  force_destroy = true
}

resource "aws_service_discovery_instance" "primay" {
  count = var.infrastructure.domain_suffix != null ? 1 : 0

  instance_id = aws_db_instance.primary.identifier
  service_id  = aws_service_discovery_service.primary[0].id

  attributes = {
    AWS_INSTANCE_CNAME = aws_db_instance.primary.address
  }
}

resource "aws_service_discovery_service" "secondary" {
  count = var.infrastructure.domain_suffix != null && local.architecture == "replication" ? 1 : 0

  name        = format("%s.%s", join("-", [local.name, "secondary"]), local.namespace)
  description = local.description
  tags        = local.tags

  dns_config {
    namespace_id   = data.aws_service_discovery_dns_namespace.selected[0].id
    routing_policy = "WEIGHTED"
    dns_records {
      ttl  = 30
      type = "CNAME"
    }
  }

  force_destroy = true
}

resource "aws_service_discovery_instance" "secondary" {
  count = var.infrastructure.domain_suffix != null && local.architecture == "replication" ? local.replication_readonly_replicas : 0

  instance_id = aws_db_instance.secondary[count.index].identifier
  service_id  = aws_service_discovery_service.secondary[0].id

  attributes = {
    AWS_INSTANCE_CNAME = aws_db_instance.secondary[count.index].address
  }
}
