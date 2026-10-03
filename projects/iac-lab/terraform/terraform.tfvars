project_name   = "iac-lab"
environment    = "dev"
aws_region     = "us-east-2"
lambda_timeout = 30 # AI calls can take a few seconds

# Bedrock model (Nova Lite runs in-region in us-east-2)
bedrock_model_id = "amazon.nova-lite-v1:0"
max_tokens       = 200
system_prompt    = "You are a concise assistant. Answer in at most three sentences."

api_throttle_burst_limit = 10
api_throttle_rate_limit  = 5
