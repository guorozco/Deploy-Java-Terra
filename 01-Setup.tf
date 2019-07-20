####################################################
# Owner: GU														#
# Platform: AWS												#
####################################################

##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}

variable "aws_region" {}

variable "aws_secret_key" {}
variable "private_key_path" {}

variable "github_url" {}

variable "key_name" {
  default = "etax"
}

variable "company" {
  default = "nttdata"
}

variable "app" {
  default = "JavaWeb"
}

variable "network_address_space" {
  default = "10.0.0.0/16"
}

variable "amis" {
  description = "Base AMI to launch the instances"
  default = {
  us-east-1 = "ami-0c6b1d09930fac512"
  }
}

variable "billing_code_tag" {}
variable "environment_tag" {}

variable "instance_count" {
  default = 2
}

variable "subnet_count" {
  default = 2
}

variable "git" {
  default = "https://github.com/guorozco/Deploy-Java-Terra"
}

variable "EC2_type" {
  default = "t2.micro"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

provider "github" {
  base_url = "https://github.com/"
  token = "NOT-READY-ADD-YOOR-TOKEN"
  organization = ""
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}
