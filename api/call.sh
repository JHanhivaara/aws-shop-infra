#!/usr/bin/env bash
# Call the deployed API, signed with your aws-learning identity (the function URL uses AWS_IAM).
# Usage: api/call.sh products
#        api/call.sh orders '{"items":[{"product_id":1,"quantity":1}]}'
set -euo pipefail
cd "$(dirname "$0")/../infra"

url=$(AWS_PROFILE=aws-learning terraform output -raw api_url)
eval "$(aws configure export-credentials --profile aws-learning --format env)"
args=(--aws-sigv4 "aws:amz:eu-north-1:lambda" --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY"
  -H "x-amz-security-token: $AWS_SESSION_TOKEN" -s -w ' [%{http_code}]\n')
if [[ $# -ge 2 ]]; then
  args+=(-X POST -H 'content-type: application/json' -d "$2")
fi
curl "${args[@]}" "${url}$1"
