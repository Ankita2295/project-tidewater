variable "name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string } # e.g. oidc.eks.<region>.amazonaws.com/id/XXXX
variable "namespace" {
  type    = string
  default = "settle"
}
variable "service_account" {
  type    = string
  default = "settle-api"
}
variable "secret_arns" {
  type        = list(string)
  description = "Secrets Manager ARNs this workload is allowed to read"
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "workload" {
  name               = "${var.name}-${var.service_account}-irsa"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# Least privilege: read-only on exactly the secrets this workload needs,
# nothing else. No wildcard resource ARNs.
data "aws_iam_policy_document" "secrets_read" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    effect    = "Allow"
    resources = var.secret_arns
  }
}

resource "aws_iam_policy" "secrets_read" {
  name   = "${var.name}-${var.service_account}-secrets-read"
  policy = data.aws_iam_policy_document.secrets_read.json
}

resource "aws_iam_role_policy_attachment" "secrets_read" {
  role       = aws_iam_role.workload.name
  policy_arn = aws_iam_policy.secrets_read.arn
}

output "role_arn" { value = aws_iam_role.workload.arn }
