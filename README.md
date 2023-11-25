# AWS RDS for PostgreSQL Service

Terraform module which deploys [PostgreSQL](https://aws.amazon.com/rds/postgresql) service on AWS.

- [x] Support standalone(one read-write instance) and replication(one read-write instance and multiple read-only instances, for read write splitting).

## Usage

```hcl
module "postgresql" {
  source = "..."

  infrastructure = {
    vpc_id        = "..."
    kms_key_id    = "..."
    domain_suffix = "..."
  }

  architecture    = "replication"
  engine_version  = "13.0"          # https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-release-calendar.html#Release.Calendar
}
```

## Examples

- [Replication](./examples/replication)
- [Standalone](./examples/standalone)

## Contributing

Please read our [contributing guide](./docs/CONTRIBUTING.md) if you're interested in contributing to Walrus template.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.24.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.24.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.5.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_instance.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_security_group.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_service_discovery_instance.primay](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_instance) | resource |
| [aws_service_discovery_instance.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_instance) | resource |
| [aws_service_discovery_service.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_service_discovery_service.secondary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [random_password.password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_kms_key.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_service_discovery_dns_namespace.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/service_discovery_dns_namespace) | data source |
| [aws_subnets.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_context"></a> [context](#input\_context) | Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.<br><br>Examples:<pre>context:<br>  project:<br>    name: string<br>    id: string<br>  environment:<br>    name: string<br>    id: string<br>  resource:<br>    name: string<br>    id: string</pre> | `map(any)` | `{}` | no |
| <a name="input_infrastructure"></a> [infrastructure](#input\_infrastructure) | Specify the infrastructure information for deploying.<br><br>Examples:<pre>infrastructure:<br>  vpc_id: string                   # the ID of the VPC where the PostgreSQL service applies<br>  kms_key_id: string, optional     # the ID of the KMS key which to encrypt the PostgreSQL data<br>  domain_suffix: string, optional  # a private DNS namespace of the CloudMap where to register the applied PostgreSQL service<br>  publicly_accessible: bool       # whether the PostgreSQL service is publicly accessible</pre> | <pre>object({<br>    vpc_id        = string<br>    kms_key_id    = optional(string)<br>    domain_suffix = optional(string)<br>    publicly_accessible = optional(bool, false)<br>  })</pre> | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Specify the deployment architecture, select from standalone or replication. | `string` | `"standalone"` | no |
| <a name="input_replication_readonly_replicas"></a> [replication\_readonly\_replicas](#input\_replication\_readonly\_replicas) | Specify the number of read-only replicas under the replication deployment. | `number` | `1` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Specify the deployment engine version, select from https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-release-calendar.html#Release.Calendar. | `string` | `"15.0"` | no |
| <a name="input_engine_parameters"></a> [engine\_parameters](#input\_engine\_parameters) | Specify the deployment engine parameters, select for https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Appendix.PostgreSQL.CommonDBATasks.Parameters.html. | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_database"></a> [database](#input\_database) | Specify the database name. The database name must be 2-64 characters long and start with any lower letter, combined with number, or symbols: - \_.<br>The database name cannot be PostgreSQL forbidden keyword. | `string` | `"mydb"` | no |
| <a name="input_username"></a> [username](#input\_username) | Specify the account username. The username must be 2-16 characters long and start with lower letter, combined with number, or symbol: \_.<br>The username cannot be PostgreSQL forbidden keyword. | `string` | `"rdsuser"` | no |
| <a name="input_password"></a> [password](#input\_password) | Specify the account password. The password must be 8-32 characters long and start with any letter, number, or symbols: ! # $ % ^ & * ( ) \_ + - =.<br>If not specified, it will generate a random password.<br>See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html#RDS_Limits.Constraints. | `string` | `null` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Specify the computing resources.<br><br>Examples:<pre>resources:<br>  class: string, optional         # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html#Concepts.DBInstanceClass.Summary</pre> | <pre>object({<br>    class = optional(string, "db.t3.medium")<br>  })</pre> | <pre>{<br>  "class": "db.t3.medium"<br>}</pre> | no |
| <a name="input_storage"></a> [storage](#input\_storage) | Specify the storage resources.<br><br>Examples:<pre>storage:<br>  class: string, optional        # https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html<br>  size: number, optional         # in megabyte</pre> | <pre>object({<br>    class = optional(string, "gp2")<br>    size  = optional(number, 20 * 1024)<br>  })</pre> | <pre>{<br>  "class": "gp2",<br>  "size": 20480<br>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_context"></a> [context](#output\_context) | The input context, a map, which is used for orchestration. |
| <a name="output_refer"></a> [refer](#output\_refer) | The refer, a map, including hosts, ports and account, which is used for dependencies or collaborations. |
| <a name="output_connection"></a> [connection](#output\_connection) | The connection, a string combined host and port, might be a comma separated string or a single string. |
| <a name="output_connection_readonly"></a> [connection\_readonly](#output\_connection\_readonly) | The readonly connection, a string combined host and port, might be a comma separated string or a single string. |
| <a name="output_address"></a> [address](#output\_address) | The address, a string only has host, might be a comma separated string or a single string. |
| <a name="output_address_readonly"></a> [address\_readonly](#output\_address\_readonly) | The readonly address, a string only has host, might be a comma separated string or a single string. |
| <a name="output_port"></a> [port](#output\_port) | The port of the service. |
| <a name="output_database"></a> [database](#output\_database) | The name of PostgreSQL database to access. |
| <a name="output_username"></a> [username](#output\_username) | The username of the account to access the database. |
| <a name="output_password"></a> [password](#output\_password) | The password of the account to access the database. |
| <a name="output_endpoints"></a> [endpoints](#output\_endpoints) | The endpoints, a list of string combined host and port. |
| <a name="output_endpoints_readonly"></a> [endpoints\_readonly](#output\_endpoints\_readonly) | The readonly endpoints, a list of string combined host and port. |
<!-- END_TF_DOCS -->

## License

Copyright (c) 2023 [Seal, Inc.](https://seal.io)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [LICENSE](./LICENSE) file for details.

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
