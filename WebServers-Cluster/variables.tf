# variable "server_port" {
#   description = "The port the server will use for HTTP requests"
#   type        = number
#   default     = 8080 // Default port is set to 8080, but can be overridden when applying the configuration/export TF_VAR_server_port=8089 followed by terraform plan./terraform plan -var "server_port=8080"
# }

variable "Cluster_Name" {
  description = "The name to use for all the clusters"
  type = string
}

variable "instance_type" {
  description = "Type of the Instance"
  type = string
}

variable "min_size" {
  description = "minimum number of Ec2 Instances in ASG"
  type = number
}

variable "max_size" {
  description = "maximum number of Ec2 Instances in ASG"
  type = number
}