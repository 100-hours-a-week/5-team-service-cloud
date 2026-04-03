#!/usr/bin/env bash
# =============================================================================
# SSM Parameter Store — DEV 환경 값 주입 스크립트
# 실행 전: AWS CLI 자격증명 확인 (aws sts get-caller-identity)
# 실행: bash scripts/ssm_inject_dev.sh
# 전제: 리포 루트에 ssm_params_export.txt 존재 (gitignored)
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
EXPORT_FILE="${REPO_ROOT}/ssm_params_export.txt"

ENV="dev"
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

echo "=== DEV SSM 주입 시작 ==="
echo ""

# =============================================================================
# 🔄 Terraform이 자동 write — 이 스크립트에서 스킵
# =============================================================================
# AWS_REGION, AWS_S3_*, ECR_REGISTRY  → terraform write (base/data 레이어)
# SPRING_REDIS_PORT, SPRING_RABBITMQ_PORT → terraform write (static)
# QDRANT_URL, QDRANT_API_KEY, QDRANT_LOCATION, QDRANT_COLLECTION_* → terraform write

# =============================================================================
# ✅ 구 인프라 값 + docker-compose 기반 값 주입
# =============================================================================
echo "--- AI / ML ---"
put_param "AI_API_KEY"     "SecureString" "7f3a9c2e4b6d8a1f0c5e9d3b7a2c8e4f1a6d9c0b5e8f2a4d7c3b9e1a5"
put_param "GEMINI_API_KEY" "SecureString" "AIzaSyD_Pq0u5UkceE1ILU-yzpZmVieSKOJX5lA"
put_param "GEMINI_MODEL"   "String"       "models/gemini-2.5-flash"

echo ""
echo "--- Database (Docker Compose — mysql 서비스) ---"
put_param "DB_USERNAME" "SecureString" "root"
put_param "DB_PASSWORD" "SecureString" "zsed1235"
put_param "DB_URL"      "String"       "jdbc:mysql://localhost:3306/doktoridb?serverTimezone=Asia/Seoul&useSSL=false"
put_param "AI_DB_URL"   "SecureString" "mysql+pymysql://root:zsed1235@localhost:3306/doktoridb?charset=utf8mb4"

echo ""
echo "--- Redis (Docker Compose — 서비스명: redis) ---"
put_param "SPRING_REDIS_HOST"     "String"       "redis"
put_param "SPRING_REDIS_PASSWORD" "SecureString" "zsed1235"

echo ""
echo "--- RabbitMQ (Docker Compose — 서비스명: rabbitmq) ---"
put_param "SPRING_RABBITMQ_HOST"     "String"       "rabbitmq"
put_param "SPRING_RABBITMQ_USERNAME" "SecureString" "admin"
put_param "SPRING_RABBITMQ_PASSWORD" "SecureString" "zsed1235"

echo ""
echo "--- MongoDB (Docker Compose — 서비스명: mongodb) ---"
# MONGO_URI: mongodb 서비스 기본 계정 doktori / zsed1235
put_param "MONGO_URI" "SecureString" "mongodb://doktori:zsed1235@mongodb:27017/doktoridb?authSource=admin"

echo ""
echo "--- Auth ---"
# JWT_SECRET: dev/prod 동일 — dev는 그대로, prod는 새로 생성 필요
put_param "JWT_SECRET"              "SecureString" "R4xZTbNTRBrfBULweNEesNNyz1st8RHvT07ct64iS02"
put_param "KAKAO_CLIENT_ID"         "SecureString" "d5a5d8a5ef66dcd5c1a8cbe3261b1d43"
put_param "KAKAO_CLIENT_SECRET"     "SecureString" "o70nW1utkgc5z0Pyw4XN0e3dMLdl6b4m"
put_param "KAKAO_FRONTEND_REDIRECT" "String"       "https://dev.doktori.kr/oauth/callback"
put_param "KAKAO_REDIRECT_URI"      "String"       "https://dev.doktori.kr/api/oauth/kakao/callback"
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
# private key 포함 → git에 직접 저장 금지. 로컬 export 파일에서 읽어서 주입
if [[ -f "${EXPORT_FILE}" ]]; then
  FIREBASE_JSON=$(python3 - "${EXPORT_FILE}" <<'PYEOF'
import sys, json

txt = open(sys.argv[1]).read()
section = txt.split("## [DEV]")[1].split("## [PROD]")[0]
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

[AI / ML]
  /doktori/dev/AI_BASE_URL   — AI 서비스 base URL

[RunPod]
  /doktori/dev/RUNPOD_API_KEY
  /doktori/dev/RUNPOD_ENDPOINT_ID
  /doktori/dev/RUNPOD_POLL_INTERVAL_SECONDS  (예: "5")
  /doktori/dev/RUNPOD_POLL_TIMEOUT_SECONDS   (예: "300")

[Scheduler / Cache]
  /doktori/dev/QUIZ_CACHE_TTL_SECONDS  (예: "86400")

TODO

echo "=== 완료 ==="
