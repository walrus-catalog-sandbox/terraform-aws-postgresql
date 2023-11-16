#
# Contextual Fields
#

variable "context" {
  description = <<-EOF
Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.

Examples:
```
context:
  project:
    name: string
    id: string
  environment:
    name: string
    id: string
  resource:
    name: string
    id: string
```
EOF
  type        = map(any)
  default     = {}
}

#
# Infrastructure Fields
#

variable "infrastructure" {
  description = <<-EOF
Specify the infrastructure information for deploying.

Examples:
```
infrastructure:
  vpc_id: string                  # the ID of the VPC where the PostgreSQL service applies
  kms_key_id: sting,optional      # the ID of the KMS key which to encrypt the PostgreSQL data
  domain_suffix: string           # a private DNS namespace of the CloudMap where to register the applied PostgreSQL service
```
EOF
  type = object({
    vpc_id        = string
    kms_key_id    = optional(string)
    domain_suffix = string
  })
}

#
# Deployment Fields
#

variable "architecture" {
  description = <<-EOF
Specify the deployment architecture, select from standalone or replication.
EOF
  type        = string
  default     = "standalone"
  validation {
    condition     = var.architecture == null || contains(["standalone", "replication"], var.architecture)
    error_message = "Invalid architecture"
  }
}

variable "replication_readonly_replicas" {
  description = <<-EOF
Specify the number of read-only replicas under the replication deployment.
EOF
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 3, 5], var.replication_readonly_replicas)
    error_message = "Invalid number of read-only replicas"
  }
}

variable "engine_version" {
  description = <<-EOF
Specify the deployment engine version, select from https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-release-calendar.html#Release.Calendar.
EOF
  type        = string
  default     = "13"
  validation {
    condition     = contains(["13", "14", "15"], var.engine_version)
    error_message = "Invalid version"
  }
}

variable "engine_parameters" {
  description = <<-EOF
Specify the deployment engine parameters, select for https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html.
EOF
  type = list(object({
    name  = string
    value = string
  }))
  default = null
}

variable "database" {
  description = <<-EOF
Specify the database name.
EOF
  type        = string
  default     = "mydb"
  validation {
    condition     = var.database == null || can(regex("^[a-z][-a-z0-9_]{0,61}[a-z0-9]$", var.database))
    error_message = format("Invalid database: %s", var.database)
  }
}

variable "username" {
  description = <<-EOF
Specify the account username.
EOF
  type        = string
  default     = "rdsuser"
  validation {
    condition     = can(regex("^[A-Za-z_]{0,15}[a-z0-9]$", var.username))
    error_message = format("Invalid username: %s", var.username)
  }
}

variable "password" {
  description = <<-EOF
Specify the account password, ref to https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.Constraints.
EOF
  type        = string
  default     = null
  sensitive   = true
  validation {
    condition     = var.password == null || can(regex("^[A-Za-z0-9\\!#\\$%\\^&\\*\\(\\)_\\+\\-=]{8,32}", var.password))
    error_message = "Invalid password"
  }
}

variable "resources" {
  description = <<-EOF
Specify the computing resources.

Examples:
```
resources:
  class: string, optional         # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html#Concepts.DBInstanceClass.Summary
```
EOF
  type = object({
    class = optional(string, "db.t3.medium")
  })
  default = {
    class = "db.t3.medium"
  }
}

variable "storage" {
  description = <<-EOF
Specify the storage resources.

Examples:
```
storage:
  class: string, optional        # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html
  size: number, optional         # in megabyte
```
EOF
  type = object({
    class = optional(string, "gp2")
    size  = optional(number, 20 * 1024)
  })
  default = {
    class = "gp2"
    size  = 20 * 1024
  }
  validation {
    condition     = var.storage == null || try(var.storage.size >= 20480, true)
    error_message = "Storage size must be larger than 20480Mi"
  }
}
