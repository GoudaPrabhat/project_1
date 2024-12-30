
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.0"
#     }
#   }
# }

provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "primary_rds" {
  identifier           = "source-instance-identifier"
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_name              = "primarydb"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql8.0"
  multi_az             = true
  publicly_accessible  = true
  skip_final_snapshot  = true
  backup_retention_period = 7
  iam_database_authentication_enabled = true

}

resource "aws_iam_role" "rds_replication_role" {
  name = "rds-cross-region-replication-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "rds_replication_policy" {
  role = aws_iam_role.rds_replication_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "lambda_failover_role" {
  name = "lambda-failover-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_failover_policy" {
  name = "lambda-failover-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:PromoteReadReplica",
        "route53:ChangeResourceRecordSets",
        "cloudwatch:PutMetricData",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}


provider "aws" {
  alias  = "secondary"
  region = "us-west-2"
}

# resource "aws_db_instance" "read_replica" {
#   provider                  = aws.secondary
#   identifier                = "read-replica-instance"
#   replicate_source_db       = aws_db_instance.primary_rds.identifier
#   instance_class            = "db.t3.micro"
#   publicly_accessible       = true
#   skip_final_snapshot       = true
#   replica_source_region     = "us-east-2"

#   lifecycle {
#     ignore_changes = [replicate_source_db]
#   }

#   depends_on = [aws_db_instance.primary_rds]
# }

# resource "null_resource" "create_cross_region_replica" {
#   depends_on = [aws_db_instance.primary_rds]

#   provisioner "local-exec" {
#     command = <<EOT
# aws rds create-db-instance-read-replica \
# --region us-west-2 \
# --db-instance-identifier secondary-db-instance \
# --source-db-instance-identifier ${aws_db_instance.primary_rds.arn} \
# --db-instance-class db.t3.micro \
# --publicly-accessible
# EOT
#   }
# }


# # Promote Read Replica to Standalone
# resource "null_resource" "promote_replica" {
#   depends_on = [aws_db_instance.read_replica]

#   provisioner "local-exec" {
#     command = <<EOT
# aws rds promote-read-replica \
# --region us-west-2 \
# --db-instance-identifier ${aws_db_instance.read_replica.id}
# EOT
#   }
# }

resource "null_resource" "create_and_promote_replica" {
  depends_on = [aws_db_instance.primary_rds]

  provisioner "local-exec" {
    command = <<EOT
# Step 1: Create the Read Replica
aws rds create-db-instance-read-replica \
--region us-west-2 \
--db-instance-identifier secondary-db-instance \
--source-db-instance-identifier ${aws_db_instance.primary_rds.arn} \
--db-instance-class db.t3.micro \
--publicly-accessible

# # Step 2: Wait for the Read Replica to be available
# while true; do
#   status=$(aws rds describe-db-instances \
#     --region us-west-2 \
#     --db-instance-identifier secondary-db-instance \
#     --query "DBInstances[0].DBInstanceStatus" \
#     --output text)
#   echo "Replica Status: $status"
#   if [ "$status" == "available" ]; then
#     break
#   fi
#   sleep 10
# done

# # Step 3: Promote the Read Replica to Standalone
# aws rds promote-read-replica \
# --region us-west-2 \
# --db-instance-identifier secondary-db-instance
EOT
  }
}

  

# CREATE TABLE employees (
#     id INT AUTO_INCREMENT PRIMARY KEY,
#     name VARCHAR(50) NOT NULL,
#     position VARCHAR(50),
#     salary DECIMAL(10, 2)
# );

# INSERT INTO employees (name, position, salary)
# VALUES 
#     ('Alice Johnson', 'Manager', 75000.00),
#     ('Bob Smith', 'Engineer', 65000.00),
#     ('Charlie Brown', 'Analyst', 55000.00);
