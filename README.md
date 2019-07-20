**Prerequisites**

* Terraform greater than: 0.11.7+

**Installation Steps**

* Configure your `AWS_ACCESS_KEY_ID` and your `AWS_SECRET_ACCESS_KEY`
```

Change the variables on the file "varFile.tfvars": 

aws_access_key = "XXXXXX"

aws_secret_key = "XOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXOXO"


```
* Change the variables on the file: "varFile.tfvars" before you run terraform apply
```
private_key_path = "PATH-TO-KEY"

environment_tag = "dev"

billing_code_tag = "ACCT8675309"

aws_region = "us-east-1"

key_name = "Demo-Test"
```

```
** NOT REQUIRE ** 
*Create your Key Pair on the region where is going to be deployed the solution
* Configure your Key file on the `03-server.tf`
```
variable "key_pair" {
  default = "new-key-pair"
}

  key_name = "Demo-Test"
  
}
```

```
Then:
* cd to the folder where you git clone the repo
* Execute `terraform apply -var-file=varFile.tfvars`
