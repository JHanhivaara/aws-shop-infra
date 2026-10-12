# aws-shop-infra

A small shop API (products and orders) on AWS, built with Terraform and deployed by GitHub
Actions. It's a learning project: the goal is a realistic, secure and cheap setup, not features.

```mermaid
flowchart LR
  dev([curl, SigV4-signed]) -->|AWS_IAM auth| url[Lambda function URL]
  url --> fn["Lambda shop-api<br/>FastAPI + Mangum, arm64"]
  subgraph vpc [VPC 10.0.0.0/16, private subnets only, no internet gateway]
    fn -->|IAM auth token, 5432| db[(RDS Postgres 18)]
    fn -->|443, migrate only| vpce[Secrets Manager endpoint]
  end
  gh[GitHub Actions] -->|OIDC, no stored keys| aws[gha-plan / gha-apply roles]
```

## What's in it

| Path | What |
|---|---|
| `bootstrap/` | S3 state bucket and the GitHub OIDC roles. Applied by hand, state in S3. |
| `infra/` | VPC, security groups, RDS, Lambda and function URL. Deployed by the pipeline. |
| `api/` | FastAPI app, SQL schema and grants, Lambda packaging. |
| `.github/workflows/terraform.yml` | Plan on every PR, apply on `main`. |

## Design decisions

- **No long-lived credentials.** CI assumes roles through GitHub OIDC. The trust policy matches
  GitHub's immutable `owner@id/repo@id` subject, so a recreated repo with the same name can't
  inherit it. PRs only get the read-only `gha-plan` role; `gha-apply` accepts `main` only.
- **No database passwords in code or state.** RDS keeps the master password in Secrets Manager
  (`manage_master_user_password`). The API logs in as `shop_api` with a 15-minute IAM token.
- **Least privilege everywhere.** `gha-apply` can only manage `shop-*` IAM roles. `shop_api` can
  read products and orders, update only `stock`, and insert orders. Security groups allow just
  Lambda → Postgres on 5432 and Lambda → the endpoint on 443.
- **Private network, no NAT gateway.** Nothing in the VPC is reachable from the internet, and the
  Lambda needs no internet: IAM auth tokens are signed locally, and the one service it calls
  (Secrets Manager, during setup) is reached through a VPC endpoint.
- **Correct orders under concurrency.** Stock is reserved with one conditional `UPDATE … WHERE
  stock >= qty` inside a transaction, so two buyers can't both get the last item, and a failed
  line rolls back the whole order.
- **Cheap to run.** The database and the endpoint sit behind a `create_db` switch and only exist
  during study sessions (about $0.03/hour). Everything else is free when idle.
- **The deploy is the plan.** CI builds a reproducible Lambda zip, plans, and ships the zip and
  `tfplan` together, so `apply` deploys exactly what was reviewed.

## Run locally

```bash
cd api
docker compose up -d --wait
psql postgresql://app:app@localhost:5432/shop -f src/shop/sql/schema.sql -f src/shop/sql/seed.sql
uv run fastapi dev src/shop/app.py   # http://localhost:8000/docs
```

## Use the deployed API

1. Set `default = true` for `create_db` in `infra/database.tf` and merge a PR.
2. Create the schema, seed data and `shop_api` user once:
   `aws lambda invoke --function-name shop-api --cli-binary-format raw-in-base64-out --payload '{"action":"migrate"}' /dev/stdout`
3. Call it: `api/call.sh products`, or
   `api/call.sh orders '{"items":[{"product_id":1,"quantity":2}]}'`
4. Set `create_db` back to `false` when done.
