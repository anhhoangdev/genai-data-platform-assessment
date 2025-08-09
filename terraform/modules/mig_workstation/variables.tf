variable "name" {
  description = "MIG name"
  type        = string
}

variable "region" {
  description = "Region for the regional MIG"
  type        = string
}

variable "zones" {
  description = "List of zones for distribution policy"
  type        = list(string)
}

variable "instance_template_self_link" {
  description = "Instance template self link"
  type        = string
}

variable "target_size" {
  description = "Target size"
  type        = number
}

variable "min_replicas" {
  description = "Min replicas"
  type        = number
}

variable "max_replicas" {
  description = "Max replicas"
  type        = number
}

variable "cpu_target_utilization" {
  description = "CPU target utilization for autoscaler"
  type        = number
  default     = 0.6
}


