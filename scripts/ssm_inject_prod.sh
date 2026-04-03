#!/usr/bin/env bash
# =============================================================================
# SSM Parameter Store — PROD 환경 값 주입 스크립트
# 실행 전: AWS CLI 자격증명 확인 (aws sts get-caller-identity)
# 실행: bash scripts/ssm_inject_prod.sh
# =============================================================================
set -euo pipefail

ENV="prod"
PROJECT="doktori"
PATH_PREFIX="/${PROJECT}/${ENV}"
REGION="ap-northeast-2"

put_param() {
  local name="$1" type="$2" value="$3"
  aws ssm put-parameter \
    --region "${REGION}" \
    --name "${PATH_PREFIX}/${name}" \
    --type "${type}" \
    --value "${value}" \
    --overwrite \
    --no-cli-pager
  echo "  ✅ ${name}"
}

echo "=== PROD SSM 주입 시작 ==="
echo ""

# =============================================================================
# 🔄 Terraform이 자동 write — 이 스크립트에서 스킵
# =============================================================================
# AWS_REGION              → terraform write (var.aws_region)
# AWS_S3_BUCKET_NAME      → terraform write (module.storage output: "doktori-v2-prod")
# AWS_S3_DB_BACKUP        → terraform write (module.storage output)
# AWS_S3_ENABLED          → terraform write ("true")
# AWS_S3_ENDPOINT         → terraform write ("https://s3.ap-northeast-2.amazonaws.com")
# ECR_REGISTRY            → terraform write (account_id + region)
# SPRING_REDIS_PORT       → terraform write ("6379")
# SPRING_RABBITMQ_PORT    → terraform write ("5672")
# DB_PASSWORD             → terraform write (random_password → database module)
# DB_URL                  → terraform write (RDS Proxy endpoint + db_name 조립)
# AI_DB_URL               → terraform write (ephemeral + value_wo)

# =============================================================================
# ✅ 구 인프라에서 그대로 사용 가능한 값
# =============================================================================
echo "--- AI / ML ---"
# ⚠️  AI_API_KEY: 구 인프라 값이 hex 32자리로 placeholder처럼 보임. 실제 키 확인 필요.
#     확인 후 아래 주석 해제
# put_param "AI_API_KEY" "SecureString" "7f3a9c2e4b6d8a1f0c5e9d3b7a2c8e4f1a6d9c0b5e8f2a4d7c3b9e1a5"
put_param "GEMINI_API_KEY" "SecureString" "AIzaSyD_Pq0u5UkceE1ILU-yzpZmVieSKOJX5lA"
put_param "GEMINI_MODEL"   "String"       "models/gemini-2.5-flash"

echo ""
echo "--- Database ---"
# DB_USERNAME: Terraform이 RDS를 var.db_username("admin")으로 생성 — 구 값("doktori_prod") 사용 금지
put_param "DB_USERNAME" "SecureString" "admin"
# DB_PASSWORD, DB_URL, AI_DB_URL → Terraform이 write (위 스킵 목록 참조)

echo ""
echo "--- Auth ---"
# ⚠️  JWT_SECRET: 구 인프라에서 dev/prod 동일 값 사용 중 — 보안 위험. 새 값 생성 권장
#     임시로 구 값 주입 후 교체 예정이면 아래 주석 해제
# put_param "JWT_SECRET" "SecureString" "R4xZTbNTRBrfBULweNEesNNyz1st8RHvT07ct64iS02"
put_param "KAKAO_CLIENT_ID"         "SecureString" "fe4b9611ac8b7f1d7ac33eb5bf7363af"
put_param "KAKAO_CLIENT_SECRET"     "SecureString" "nRFzrE0NUW8eU7207EyWnsfopMvD7QoP"
put_param "KAKAO_FRONTEND_REDIRECT" "String"       "https://doktori.kr/oauth/callback"
put_param "KAKAO_REDIRECT_URI"      "String"       "https://doktori.kr/api/oauth/kakao/callback"
put_param "KAKAO_REST_API_KEY"      "SecureString" "5b1e3e510366c29eeca660fc0557fcc1"

echo ""
echo "--- Zoom ---"
put_param "ZOOM_ACCOUNT_ID"    "SecureString" "ViLuVXHFRGGnm14ypomBCw"
put_param "ZOOM_CLIENT_ID"     "SecureString" "094AAqVAQPuTGkb_fc6m5w"
put_param "ZOOM_CLIENT_SECRET" "SecureString" "s6eSI9wfrP7P1lXcdry8xk3FcyMheu1n"

echo ""
echo "--- Recommendation Scheduler ---"
put_param "ENABLE_RECO_SCHEDULER"   "String" "true"
put_param "RECO_SCHEDULER_CRON"     "String" "0 3 * * 0"
put_param "RECO_SCHEDULER_SEARCH_K" "String" "20"
put_param "RECO_SCHEDULER_TOP_K"    "String" "4"
put_param "RECO_SCHEDULER_TZ"       "String" "Asia/Seoul"

echo ""
echo "--- Firebase ---"
# FIREBASE_SERVICE_ACCOUNT: private key 포함 — git에 직접 저장 금지
# ssm_params_export.txt의 FIREBASE_SERVICE_ACCOUNT 값을 복사해서 아래 실행
# aws ssm put-parameter \
#   --region ap-northeast-2 \
#   --name "/doktori/prod/FIREBASE_SERVICE_ACCOUNT" \
#   --type SecureString \
#   --value "$(cat /path/to/firebase-service-account.json | tr -d '\n')" \
#   --overwrite

# =============================================================================
# ❓ 새로 입력 필요 — 아래 TODO 항목은 값 확인 후 직접 입력
# =============================================================================
echo ""
echo "=============================================="
echo "❓ 아래 파라미터는 값을 직접 입력해야 합니다."
echo "=============================================="
cat <<'TODO'

[AI / ML] — 확인/생성 필요
  /doktori/prod/AI_API_KEY    — 구 값이 placeholder로 의심됨. 실제 API Key 확인 후 입력
  /doktori/prod/AI_BASE_URL   — 구 인프라에 없던 항목. AI 서비스 base URL 입력 필요

[Auth] — 반드시 새로 생성
  /doktori/prod/JWT_SECRET    — 구 인프라에서 dev/prod 동일 값 사용 중 (보안 위험!)
                                새 JWT Secret 생성: openssl rand -base64 48

[RunPod]
  /doktori/prod/RUNPOD_API_KEY               — 구 인프라에 없던 항목
  /doktori/prod/RUNPOD_ENDPOINT_ID           — 구 인프라에 없던 항목
  /doktori/prod/RUNPOD_POLL_INTERVAL_SECONDS — 구 인프라에 없던 항목 (예: "5")
  /doktori/prod/RUNPOD_POLL_TIMEOUT_SECONDS  — 구 인프라에 없던 항목 (예: "300")

[Redis — ElastiCache or EC2]
  /doktori/prod/SPRING_REDIS_HOST     — ElastiCache endpoint 또는 내부 DNS
  /doktori/prod/SPRING_REDIS_PASSWORD — Redis AUTH 패스워드

[RabbitMQ — EC2]
  /doktori/prod/SPRING_RABBITMQ_HOST     — 내부 DNS (예: rabbitmq.prod.doktori.internal)
  /doktori/prod/SPRING_RABBITMQ_USERNAME — RabbitMQ 관리자 계정명
  /doktori/prod/SPRING_RABBITMQ_PASSWORD — RabbitMQ 패스워드

[Scheduler / Cache]
  /doktori/prod/QUIZ_CACHE_TTL_SECONDS — 캐시 TTL 값 입력 필요 (예: "86400")

TODO

echo "=== 완료 ==="
