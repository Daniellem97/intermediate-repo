
data "spacelift_current_stack" "this" {}

resource "spacelift_space" "intermediate-repo" {
  name = "intermediate-repo"

  # Every account has a root space that serves as the root for the space tree.
  # Except for the root space, all the other spaces must define their parents.
  parent_space_id = "root"


  # An optional description of a space.
  description = "All the resources for this intermediate repo will be created here."
}

resource "spacelift_stack" "managed" {
  name        = "Stack to create stack with drift detection"
  administrative = true
  repository   = "intermediate-repo"
  branch       = "main"
  project_root = "Drift-Detection-Stack"
  space_id    = spacelift_space.intermediate-repo.id
  depends_on  = [data.spacelift_current_stack.this]
}

resource "spacelift_stack_destructor" "ddstack" {
  stack_id = spacelift_stack.managed.id
  depends_on = [
    spacelift_environment_variable.worker_pool_id2
  ]
}

resource "spacelift_stack" "Stack-Dependencies" {
  name        = "Dependencies stack"
  administrative = true
  description = "Your first stack managed by Terraform"
  repository   = "intermediate-repo"
  branch       = "main"
  project_root = "Stack-Dependencies"
  space_id    = spacelift_space.intermediate-repo.id
  depends_on = [spacelift_space.intermediate-repo]
}

resource "spacelift_stack_destructor" "Stack-Dependencies" {
  stack_id = spacelift_stack.Stack-Dependencies.id
}

resource "spacelift_stack" "private_worker" {
  name        = "Private_worker"
  description = "A stack to create your private_worker"
  space_id = spacelift_space.intermediate-repo.id
  administrative    = true
  repository   = "intermediate-repo"
  branch       = "main"
  project_root = "Private-worker"
  depends_on = [spacelift_space.intermediate-repo]
}

resource "spacelift_stack_destructor" "private_worker" {
  stack_id = spacelift_stack.private_worker.id
  depends_on = [
    spacelift_environment_variable.worker_pool_private_key,
    spacelift_environment_variable.worker_pool_id,
    spacelift_environment_variable.worker_pool_config,
    spacelift_aws_integration_attachment.this
  ]
}

resource "spacelift_aws_integration_attachment" "this" {
  integration_id = spacelift_aws_integration.this.id
  stack_id       = spacelift_stack.private_worker.id
  read           = true
  write          = true

  # The integration needs to exist before we attach it.
  depends_on = [
    spacelift_aws_integration.this
  ]
}

# Apart from setting environment variables on your Stacks, you can mount files
# directly in Spacelift's workspace. Let's retrieve the list of Spacelift's
# outgoing addresses and store it as a JSON file.
data "spacelift_ips" "ips" {}

# This mounted file contains a JSON-encoded list of Spacelift's outgoing IPs.
# Note how we explicitly set the "write_only" bit for this file to "false".
# Thanks to that, you can download the file from the Spacelift GUI.
#
# You can read more about mounted files here: 
#
# https://docs.spacelift.io/concepts/configuration/environment.html#mounted-files
resource "spacelift_mounted_file" "stack-plaintext-file" {
  stack_id      = spacelift_stack.private_worker.id
  relative_path = "stack-plaintext-ips.json"
  content       = base64encode(jsonencode(data.spacelift_ips.ips.ips))
  write_only    = false
}

# Generate a private key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create a certificate signing request (CSR) using the private key
resource "tls_cert_request" "main" {
  private_key_pem = tls_private_key.main.private_key_pem

  subject {
    organization = "Spacelift Examples"
  }
}

# Create a worker pool in Spacelift using the base64-encoded CSR
resource "spacelift_worker_pool" "aws" {
  csr      = base64encode(tls_cert_request.main.cert_request_pem)
  name     = "AWS EC2 Worker Pool Example"
  space_id    = spacelift_space.intermediate-repo.id
}

# Output the worker pool ID
output "worker_pool_id" {
  value = spacelift_worker_pool.aws.id
}

# Output the worker pool config (credentials to connect workers)
output "worker_pool_config" {
  value     = spacelift_worker_pool.aws.config
  sensitive = true
}

# Output the base64-encoded private key
output "worker_pool_private_key" {
  value     = base64encode(tls_private_key.main.private_key_pem)
  sensitive = true
}

resource "spacelift_environment_variable" "worker_pool_private_key" {
  stack_id   = spacelift_stack.private_worker.id
  name       = "TF_VAR_worker_pool_private_key"
  value      = base64encode(tls_private_key.main.private_key_pem)
}

resource "spacelift_environment_variable" "worker_pool_id" {
  stack_id   = spacelift_stack.private_worker.id
  name       = "TF_VAR_worker_pool_id"
  value      = spacelift_worker_pool.aws.id
  write_only = false
}

resource "spacelift_environment_variable" "worker_pool_id2" {
  stack_id   = spacelift_stack.managed.id
  name       = "TF_VAR_worker_pool_id"
  value      = spacelift_worker_pool.aws.id
  write_only = false
}

resource "spacelift_environment_variable" "worker_pool_config" {
  stack_id   = spacelift_stack.private_worker.id
  name       = "TF_VAR_worker_pool_config"
  value      = spacelift_worker_pool.aws.config
}
