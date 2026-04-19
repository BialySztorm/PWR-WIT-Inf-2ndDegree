resource "aws_cognito_user_pool" "chat_user_pool" {
  name                     = "chatapp-user-pool"
  auto_verified_attributes = ["email"]
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "chat_user_pool_client" {
  name         = "chatapp-react-client"
  user_pool_id = aws_cognito_user_pool.chat_user_pool.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

