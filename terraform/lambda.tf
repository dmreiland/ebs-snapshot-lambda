resource "null_resource" "ebs_snapshot_lambda" {
  triggers = {
    package_json = "${base64sha256(file("${path.root}/../lambda/package.json"))}"
  }

  provisioner "local-exec" {
    command = "bash ${path.root}/scripts/setup.sh"
  }
}

data "archive_file" "ebs_snapshot_lambda" {
  type = "zip"
  source_dir = "../lambda/package"
  output_path = "../dist/ebs_snapshot_lambda.zip"

  depends_on = ["null_resource.ebs_snapshot_lambda"]
}

resource "aws_iam_role" "ebs_snapshot_lambda" {
  name = "ebs_snapshot_lambda_role"
  assume_role_policy = "${file("${path.module}/templates/role.json")}"
}

resource "aws_iam_role_policy" "ebs_snapshot_lambda" {
  name = "ebs_snapshot_lambda_role_policy"
  role = "${aws_iam_role.ebs_snapshot_lambda.id}"
  policy = "${file("${path.module}/templates/policy.json")}"
}

resource "aws_lambda_function" "ebs_snapshot_lambda" {
  filename = "${data.archive_file.ebs_snapshot_lambda.output_path}"
  source_code_hash = "${data.archive_file.ebs_snapshot_lambda.output_base64sha256}"
  function_name = "ebs_snapshot_lambda"
  description = "Lambda function to snapshot EBS volumes and purge them"
  role = "${aws_iam_role.ebs_snapshot_lambda.arn}"
  handler = "ebs_snapshot_lambda.handler"
  runtime = "nodejs4.3"
  timeout = 10
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name = "lambda_schedule"
  description = "Lambda Schedule"
  schedule_expression = "rate(${var.lamba_schedue})"
}

resource "aws_cloudwatch_event_target" "ebs_snapshot_lambda_schedule" {
  rule = "${aws_cloudwatch_event_rule.lambda_schedule.name}"
  target_id = "ebs_snapshot_lambda"
  arn = "${aws_lambda_function.ebs_snapshot_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_ebs_snapshot_lambda" {
  statement_id = "allow_cloudwatch_to_call_ebs_snapshot_lambda"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ebs_snapshot_lambda.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.lambda_schedule.arn}"
}
