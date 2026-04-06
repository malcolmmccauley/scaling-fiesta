resource "aws_iam_user" "test" {
  name = "test"

  tags = {
    ManagedBy = "terraform"
  }
}
