# ECR lives in bootstrap so it exists before the first image build
# and survives `terraform destroy` of the infra stack.
# Accept default AES-256 encryption for this portfolio repository.
# tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "memos" {
  name         = "memos"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "IMMUTABLE"
}
