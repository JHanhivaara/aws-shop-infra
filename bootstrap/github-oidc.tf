# GitHub Actions -> AWS without stored keys: GitHub signs a short-lived OIDC token,
# AWS checks it against this provider and the role trust policies below.
locals {
  repo = "JHanhivaara/aws-shop-infra"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Trust policy = WHO may assume the role. Permission policies = WHAT the role may do.
data "aws_iam_policy_document" "trust_any_ref" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:*"]
    }
  }
}

data "aws_iam_policy_document" "trust_main_only" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Exact match: PRs and other branches cannot get this role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:ref:refs/heads/main"]
    }
  }
}

# --- Plan role: read everything, write only the state lock file ---
resource "aws_iam_role" "gha_plan" {
  name               = "gha-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_any_ref.json
}

resource "aws_iam_role_policy_attachment" "gha_plan_readonly" {
  role       = aws_iam_role.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "state_lock" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "gha_plan_lock" {
  name   = "state-lock"
  role   = aws_iam_role.gha_plan.id
  policy = data.aws_iam_policy_document.state_lock.json
}

# --- Apply role: PowerUser (everything except IAM) + IAM limited to shop-* roles ---
resource "aws_iam_role" "gha_apply" {
  name               = "gha-apply"
  assume_role_policy = data.aws_iam_policy_document.trust_main_only.json
}

resource "aws_iam_role_policy_attachment" "gha_apply_poweruser" {
  role       = aws_iam_role.gha_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "shop_iam" {
  statement {
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.me.account_id}:role/shop-*"]
  }
}

resource "aws_iam_role_policy" "gha_apply_iam" {
  name   = "shop-roles-only"
  role   = aws_iam_role.gha_apply.id
  policy = data.aws_iam_policy_document.shop_iam.json
}

output "gha_plan_role_arn" { value = aws_iam_role.gha_plan.arn }
output "gha_apply_role_arn" { value = aws_iam_role.gha_apply.arn }
