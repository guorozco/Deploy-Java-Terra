####################################################
# Owner: GU														#
# Platform: AWS												#
####################################################

## Roles for Bastion

resource "aws_iam_instance_profile" "EC2-Profile" {
  name = "EC2"
  role = "${aws_iam_role.role.name}"
}

resource "aws_iam_role" "role" {
  name = "EC2_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

### Creating EC2 instance (Bastion)
resource "aws_instance" "bastion" {
  ami               = "${lookup(var.amis,var.aws_region)}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${aws_security_group.nginx-sg.id}"]
  source_dest_check = false
  instance_type = "${var.EC2_type}"
  subnet_id = "${element(aws_subnet.PublicSubnet.*.id,0)}"
  iam_instance_profile = "EC2"

  tags = {
    Name        = "${var.environment_tag}-Bastion"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

# Create a new load balancer
resource "aws_elb" "ELB" {
  name               = "${var.company}-elb"
  #availability_zones = "${data.aws_availability_zones.available.names}"
  subnets            = ["${aws_subnet.PublicSubnet.*.id}"]
  security_groups    = ["${aws_security_group.elb-sg.id}"]
  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }


  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "tcp:8080"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name        = "${var.environment_tag}-elb"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}


## Creating Launch Configuration
resource "aws_launch_configuration" "lc" {
  image_id               = "${lookup(var.amis,var.aws_region)}"
  instance_type          = "${var.EC2_type}"
  security_groups        = ["${aws_security_group.nginx-sg.id}"]
  key_name               = "${var.key_name}"
  iam_instance_profile   = "EC2"
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install ruby -y
              sudo yum install wget -y
              cd /home/ec2-user
              wget "https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install"
              chmod +x ./install
              sudo ./install auto
              EOF
  lifecycle {
    create_before_destroy = true
  }
}

## Creating AutoScaling Group
resource "aws_autoscaling_group" "ASC" {
  launch_configuration = "${aws_launch_configuration.lc.id}"
  vpc_zone_identifier  = ["${aws_subnet.PrivateSubnet.*.id}"]
  name                 = "${var.company}-ASG"
  min_size = 2
  max_size = 6
  load_balancers = ["${aws_elb.ELB.name}"]
  health_check_type = "ELB"
  tag {
    key                 = "Name"
    value               = "${var.app}-${var.environment_tag}"
    propagate_at_launch = true
  }
}