output "api_url" {
  description = "Base URL of the lab API"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "health_url" {
  description = "Health check URL"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/health"
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "api_gateway_id" {
  description = "API Gateway ID (handy for debugging and cleanup)"
  value       = aws_apigatewayv2_api.main.id
}
