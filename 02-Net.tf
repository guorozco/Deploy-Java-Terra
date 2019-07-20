####################################################
# Owner: GU														#
# Platform: AWS												#
####################################################

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block = "${var.network_address_space}"

  tags = {
    Name        = "${var.environment_tag}-vpc"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name        = "${var.environment_tag}-igw"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_subnet" "PublicSubnet" {
  count                   = "${var.subnet_count}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 1)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name        = "Public-subnet-${count.index + 1}"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_subnet" "PrivateSubnet" {
  count                   = "${var.subnet_count}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 3)}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = "false"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name        = "Private-subnet-${count.index + 1}"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# Elastic IP for the NAT #
resource "aws_eip" "nat" {
  tags = {
    Name        = "EIP"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# NAT Gateway #
resource "aws_nat_gateway" "NATgw" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${element(aws_subnet.PublicSubnet.*.id,0)}"

  tags = {
    Name        = "NAT-GW"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# ROUTING #
resource "aws_route_table" "Pubrtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags = {
    Name        = "${var.environment_tag}-Pubrtb"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_route_table" "Prvrtb" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.NATgw.id}"
  }

  tags = {
    Name        = "${var.environment_tag}-Prvrtb"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_route_table_association" "Pubrta-subnet" {
  count          = "${var.subnet_count}"
  subnet_id      = "${element(aws_subnet.PublicSubnet.*.id,count.index)}"
  route_table_id = "${aws_route_table.Pubrtb.id}"
}

resource "aws_route_table_association" "Privrta-subnet" {
  count          = "${var.subnet_count}"
  subnet_id      = "${element(aws_subnet.PrivateSubnet.*.id,count.index)}"
  route_table_id = "${aws_route_table.Prvrtb.id}"
}

# SECURITY GROUPS #
resource "aws_security_group" "elb-sg" {
  name   = "nginx_elb_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment_tag}-elb-sg"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# Nginx security group 
resource "aws_security_group" "nginx-sg" {
  name   = "nginx_sg"
  vpc_id = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }
# HTTP access from the VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.network_address_space}"]
  }
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment_tag}-nginx-sg"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}
