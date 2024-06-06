
variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type for the workers. If an arm64-based AMI is used, this must be an arm64-based instance type."
  default     = "t3.micro"
}

variable "min_size" {
  type        = number
  description = "Minimum numbers of workers to spin up"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of workers to spin up"
  default     = 10
}

variable "poweroff_delay" {
  type        = number
  description = "Number of seconds to wait before powering the EC2 instance off after the Spacelift launcher stopped"
  default     = 15
}

variable "worker_pool_id" {
  type        = string
  description = "ID (ULID) of the the worker pool."
  validation {
    condition     = can(regex("^[0-9A-HJKMNP-TV-Z]+$", var.worker_pool_id))
    error_message = "The worker pool ID must be a valid ULID (eg 01HCC6QZ932J7WDF4FTVM9QMEP)."
  }
}

variable "worker_pool_config" {
  type        = string
  description = "config of the worker pool."
}

variable "worker_pool_private_key" {
  type        = string
  description = "worker pool private key"
}

variable "enable_autoscaling" {
  default     = true
  description = "Determines whether to create the Lambda Autoscaler function and dependent resources or not"
  type        = bool
}

variable "spacelift_api_key_id" {
  type        = string
  description = "ID of the Spacelift API key to use"
  default     = null
}

variable "spacelift_api_key_secret" {
  type        = string
  sensitive   = true
  description = "Secret corresponding to the Spacelift API key to use"
}

variable "spacelift_api_key_endpoint" {
  type        = string
  description = "Full URL of the Spacelift API endpoint to use, eg. https://demo.app.spacelift.io"
  default     = null
}

variable "autoscaling_max_create" {
  description = "The maximum number of instances the utility is allowed to create in a single run"
  type        = number
  default     = 1
}

variable "autoscaling_max_terminate" {
  description = "The maximum number of instances the utility is allowed to terminate in a single run"
  type        = number
  default     = 1
}

