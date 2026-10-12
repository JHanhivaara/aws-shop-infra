
variable "create_db" {
  type        = bool
  default     = true
  description = "Create the RDS instance. Flip to true for a study session, back to false after."
}

resource "aws_db_subnet_group" "shop" {
  name       = "shop"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_db_instance" "shop" {
  count = var.create_db ? 1 : 0

  identifier     = "shop"
  engine         = "postgres"
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                             = "shop"
  username                            = "shop_admin"
  manage_master_user_password         = true
  iam_database_authentication_enabled = true

  db_subnet_group_name   = aws_db_subnet_group.shop.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}
