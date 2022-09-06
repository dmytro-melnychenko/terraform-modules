variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "cidr" {
  description = "The CIDR block for the VPC."
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(any)
  default     = []
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(any)
  default     = []
}

variable "db_subnets" {
  description = "List of public subnets"
  type        = list(any)
  default     = []
}

variable "db_subnets_with_internet" {
  description = "Enable internet in DB subnets"
}

variable "private_subnets_with_internet" {
  description = "Enable internet in private subnets"
}

variable "private_subnets_single_nat" {
  description = "Single NAT for all private subnets"
}

variable "one_nat_gateway_per_az" {
  description = "One NAT per AZ"
}

# variable "additional_tags" {
#   description = "Additional tags to add"
#   type        = list(string)
#   default     = []
# }

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(any)
  default     = []
}
