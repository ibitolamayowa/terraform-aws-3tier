# Create a DB subnet group
resource "aws_db_subnet_group" "mysql-subnet" {
  name       = "mysql-subnet-group"
  subnet_ids = [aws_subnet.private[2].id, aws_subnet.private[3].id]
}

# Create a MySQL RDS instance
resource "aws_db_instance" "mysql" {
  identifier             = "mysql-instance"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "mydatabase"
  username               = "myuser"
  password               = "mypassword"
  db_subnet_group_name   = aws_db_subnet_group.mysql-subnet.name
  vpc_security_group_ids = [aws_security_group.mysql-sg.id]
  skip_final_snapshot = true
}

# Create a security group for the MySQL instance
resource "aws_security_group" "mysql-sg" {
  name_prefix = "mysql-"
  vpc_id      = aws_vpc.aws_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
