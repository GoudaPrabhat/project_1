resource "aws_lambda_function" "failover_lambda" {
  filename         = "lambda_function.py.zip"
  function_name    = "failoverLambda"
  role             = aws_iam_role.lambda_failover_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda_function.py.zip")
}

resource "aws_lambda_permission" "sns_trigger" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover_lambda.function_name
  principal     = "sns.amazonaws.com"
}