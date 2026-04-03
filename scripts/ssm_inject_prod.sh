#!/usr/bin/env bash
# =============================================================================
# SSM Parameter Store — PROD 환경 값 주입 스크립트
# 실행 전: AWS CLI 자격증명 확인 (aws sts get-caller-identity)
# 실행: bash scripts/ssm_inject_prod.sh
# 전제: 리포 루트에 ssm_params_export.txt 존재 (gitignored)
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
EXPORT_FILE="${REPO_ROOT}/ssm_params_export.txt"

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
# AWS_REGION, AWS_S3_*, ECR_REGISTRY     → terraform write (base 레이어)
# SPRING_REDIS_PORT, SPRING_RABBITMQ_PORT → terraform write (static)
# DB_PASSWORD                             → terraform write (random_password → database module)
# DB_URL                                  → terraform write (RDS Proxy endpoint 조립)
# AI_DB_URL                               → terraform write (ephemeral + value_wo)

# =============================================================================
# ✅ 구 인프라 값 주입
# =============================================================================
echo "--- AI / ML ---"
put_param "AI_API_KEY"     "SecureString" "7f3a9c2e4b6d8a1f0c5e9d3b7a2c8e4f1a6d9c0b5e8f2a4d7c3b9e1a5"
put_param "GEMINI_API_KEY" "SecureString" "AIzaSyD_Pq0u5UkceE1ILU-yzpZmVieSKOJX5lA"
put_param "GEMINI_MODEL"   "String"       "models/gemini-2.5-flash"

echo ""
echo "--- Database ---"
# DB_USERNAME: Terraform이 RDS를 var.db_username("admin")으로 생성 → 일치시켜야 함
put_param "DB_USERNAME" "SecureString" "admin"
# DB_PASSWORD, DB_URL, AI_DB_URL → Terraform이 write (스킵 목록 참조)

echo ""
echo "--- Auth ---"
# ⚠️  JWT_SECRET: 구 인프라에서 dev/prod 동일 값 — 새로 생성 강력 권장
#     openssl rand -base64 48 으로 생성 후 아래 주석 해제
# put_param "JWT_SECRET" "SecureString" "<NEW_PROD_SECRET>"
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
echo "--- Firebase (ssm_params_export.txt에서 추출) ---"
if [[ -f "${EXPORT_FILE}" ]]; then
  FIREBASE_JSON=$(python3 - "${EXPORT_FILE}" <<'PYEOF'
import sys, json

txt = open(sys.argv[1]).read()
section = txt.split("## [PROD]")[1]
key = "FIREBASE_SERVICE_ACCOUNT (SecureString) = "
idx = section.index(key)
val_str = section[idx + len(key):]
obj, _ = json.JSONDecoder().raw_decode(val_str)
print(json.dumps(obj))
PYEOF
)
  put_param "FIREBASE_SERVICE_ACCOUNT" "SecureString" "${FIREBASE_JSON}"
else
  echo "  ⚠️  ssm_params_export.txt 없음 — FIREBASE_SERVICE_ACCOUNT 수동 주입 필요"
fi

# =============================================================================
# ❓ 새로 입력 필요
# =============================================================================
echo ""
echo "=============================================="
echo "❓ 아래 파라미터는 값을 직접 입력해야 합니다."
echo "=============================================="
cat <<'TODO'

[Auth] — 반드시 새로 생성
  /doktori/prod/JWT_SECRET  — dev/prod 동일 값은 보안 위험
                              생성: openssl rand -base64 48

[AI / ML]
  /doktori/prod/AI_BASE_URL   — AI 서비스 base URL

[RunPod]
  /doktori/prod/RUNPOD_API_KEY
  /doktori/prod/RUNPOD_ENDPOINT_ID
  /doktori/prod/RUNPOD_POLL_INTERVAL_SECONDS  (예: "5")
  /doktori/prod/RUNPOD_POLL_TIMEOUT_SECONDS   (예: "300")

[Redis — prod 인프라 구성 후 입력]
  /doktori/prod/SPRING_REDIS_HOST     — ElastiCache endpoint 또는 내부 DNS
  /doktori/prod/SPRING_REDIS_PASSWORD — Redis AUTH 패스워드

[RabbitMQ — prod 인프라 구성 후 입력]
  /doktori/prod/SPRING_RABBITMQ_HOST
  /doktori/prod/SPRING_RABBITMQ_USERNAME
  /doktori/prod/SPRING_RABBITMQ_PASSWORD

[Scheduler / Cache]
  /doktori/prod/QUIZ_CACHE_TTL_SECONDS  (예: "86400")

TODO

echo "=== 완료 ==="
