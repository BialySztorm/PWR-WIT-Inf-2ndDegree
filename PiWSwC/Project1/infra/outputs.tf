output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.chat_user_pool.id
}
output "cognito_client_id" {
  value = aws_cognito_user_pool_client.chat_user_pool_client.id
}
output "frontend_url" {
  value = aws_elastic_beanstalk_environment.frontend_env.endpoint_url
}
output "backend_url" {
  value = aws_elastic_beanstalk_environment.backend_env.endpoint_url
}
output "db_endpoint" {
  value = aws_db_instance.postgres_db.address
}

