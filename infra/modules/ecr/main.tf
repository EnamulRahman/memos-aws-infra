# Accept default AES-256 encryption for this portfolio repository.
# Customer-managed KMS encryption is deferred pending repository migration.
# tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "this" {
  name         = var.repository_name
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "IMMUTABLE"

  tags = var.tags
}