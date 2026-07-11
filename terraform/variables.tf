variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "ap-south-1a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair (create this in AWS console first)"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32, used to restrict SSH access"
  type        = string
}

variable "app_port" {
  description = "Port the containerized app listens on inside the container"
  type        = number
  default     = 5000
}
