####################################################
# Owner: GU														#
# Platform: AWS												#
####################################################

##################################################################################
# CI/CD Implementation
##################################################################################
##Creation of the S3 Bucket for Artifact store
resource "aws_s3_bucket" "b" {
  bucket = "${var.company}-art-s3"
  acl    = "private"

  tags = {
    Name        = "${var.environment_tag}-S3"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_iam_role" "CodeBuildRole" {
  name = "CodeBuildRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "CodeBuildRole" {
  role = "${aws_iam_role.CodeBuildRole.name}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.b.arn}",
        "${aws_s3_bucket.b.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_codebuild_project" "CodeBuild" {
  name          = "${var.company}-${var.app}"
  description   = "${var.company}-${var.app}"
  build_timeout = "5"
  service_role  = "${aws_iam_role.CodeBuildRole.arn}"

  artifacts {
    type = "S3"
    location = "${aws_s3_bucket.b.id}"
    name = "${var.company}-${var.app}"
    packaging = "ZIP"
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:2.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "Name"
      value = "${var.company}-${var.app}-CB"
    }

    environment_variable {
      name  = "BillingCode"
      value = "${var.billing_code_tag}"
    }
  }

  source {
    type            = "GITHUB"
    location        = "${var.git}"
    git_clone_depth = 1
  }

  tags = {
    Name        = "${var.environment_tag}-CBP"
    BillingCode = "${var.billing_code_tag}"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_iam_role" "CodeDeployRole" {
  name = "CodeDeploy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = "${aws_iam_role.CodeDeployRole.name}"
}

resource "aws_codedeploy_app" "CodeDeploy" {
  compute_platform = "Server"
  name             = "${var.company}-${var.app}"
}

resource "aws_codedeploy_deployment_config" "CodeDeploy-Conf" {
  deployment_config_name = "Healthy"

  minimum_healthy_hosts {
    type  = "HOST_COUNT"
    value = 1
  }
}

resource "aws_codedeploy_deployment_group" "CodeDeploy-GP" {
  app_name              = "${aws_codedeploy_app.CodeDeploy.name}"
  deployment_group_name = "${var.company}-${var.app}-dgn"
  service_role_arn      = "${aws_iam_role.CodeDeployRole.arn}"

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "${var.app}-${var.environment_tag}"
    }

  }


  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}

resource "aws_iam_role" "CodePipeline" {
  name = "CodePipeline"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = "${aws_iam_role.CodePipeline.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action":"s3:*",
      "Resource": [
        "${aws_s3_bucket.b.arn}",
        "${aws_s3_bucket.b.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "codedeploy:*",
      "Resource": "*"
    }
  ]
}
EOF
}


resource "aws_codepipeline" "codepipeline" {
  name     = "${var.company}-${var.app}-pl"
  role_arn = "${aws_iam_role.CodePipeline.arn}"

  artifact_store {
    location = "${aws_s3_bucket.b.bucket}"
    type     = "S3"

#    encryption_key {
#      id   = "${data.aws_kms_alias.s3kmskey.arn}"
#      type = "KMS"
#    }
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner  = "guorozco"
        Repo   = "application"
        Branch = "master"
        OAuthToken = "XX-TOKEN-GIT"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "${aws_codebuild_project.CodeBuild.name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ApplicationName = "${aws_codedeploy_app.CodeDeploy.name}"
        DeploymentGroupName = "${aws_codedeploy_deployment_group.CodeDeploy-GP.deployment_group_name}"
      }
    }
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "elb_dns_name" {
  value = "${aws_elb.ELB.dns_name}"
}
