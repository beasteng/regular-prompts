# ── Trust policy ──────────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "start_ec2_lambda" {
  name               = "start-ec2-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

# ── Permissions ───────────────────────────────────────────────────
data "aws_iam_policy_document" "start_ec2_perms" {
  # EC2: describe + start this specific instance only
  statement {
    effect  = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
    # Scope StartInstances to instance tag for extra safety
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ManagedBy"
      values   = ["terraform"]
    }
  }

  # CloudWatch Logs
  statement {
    effect  = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "start_ec2_inline" {
  name   = "start-ec2-inline-policy"
  role   = aws_iam_role.start_ec2_lambda.id
  policy = data.aws_iam_policy_document.start_ec2_perms.json
}
