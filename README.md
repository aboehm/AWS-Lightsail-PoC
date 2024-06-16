# AWS Lightsail PoC

A simple AWS Lightsail webservice deployment with Terragrunt.

## Use case

* A webservice should respond with a defined text (`display-text`). The value is sensitive and should be suppressed in terraform logs and provided via an environment variable `ECHO_TEXT`
* There should be development and production stage. Both can be configured independently.
* The platform is AWS with focus on Lightsail
* The domain management should be managed by Route53 too
* Terraform and Terragrunt should be used

## Solution sketches

There are two solutions to solve the use case.

### Use containers (modules/webservice-container)

Lightsail provides an integrated domain, certificate and load balancing management.

The current AWS provider doesn't provide the load balancer domain but the URL of the load balancer.
The URL must be formated to be used for an alias for Route53.
Also a predefined zone ID [must be used for the corresponding AWS region](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-route-53-alias-record-for-container-service.html).

### Use instances (modules/webservice-instance)

Lightsail can use managed EC2 instance with a load balancer.
The load balancer can be equipped with certificates and custom domain names, that can be aliased with Route53.
On the EC2 instance a regular docker daemon can be installed and ports for services can be published.

## Deploy

For the development stage do

```sh
cd stage/dev
terragrunt apply -auto-approve
```

For the production stage do

```sh
cd stage/prod
terragrunt apply -auto-approve
```

## Configuration

| **Parameter**           | **Meaning**                                       |
| ----------------------- | ------------------------------------------------- |
| `display-text`          | Text to be returned by webservice                 |
| `domain`                | Domain of the service                             |
| `ec2-enable-access-ssh` | Enable public SSH access (only for instance)      |
| `enforce-https`         | Enforce redirection to HTTPS (only for instance)  |
| `service-instances`     | Number of running contains (only for containers)  |
| `service-power`         | Lightsail instance type to use                    |

Set the corresponding parameters for 

* Development stage in `stages/dev/terragrunt.hcl`
* Production stage in `stages/prod/terragrunt.hcl`

## Trouble shooting

### Missing field for DNS validation records

`aws_lightsail_certificate` used `domain_validation_options` and `aws_lightsail_lb_certificate` used `domain_validation_records` instead.

### Can't deploy due dependent data that's available only after creation of resources

Certificate status isn't evaluated in a nice way for `aws_lightsail_certificate` and `aws_lightsail_lb_certificate`. Use the target parameter to deploy certain resources first e.g.

```sh
# For EC2 solution
terragrunt apply -auto-approve -target=aws_lightsail_lb_certificate.frontend
# For container solution
terragrunt apply -auto-approve -target=aws_lightsail_certificate.webservice
```
