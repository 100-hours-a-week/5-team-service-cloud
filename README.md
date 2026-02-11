# Doktori 로컬 개발 환경

Docker Compose로 전체 스택을 로컬에서 실행하는 환경입니다.

## 사전 준비

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) 설치 후 실행
- Git, Make (Mac 기본 내장 / Windows: `choco install make`)

## 최초 세팅

```bash
git clone -b local-dev https://github.com/100-hours-a-week/5-team-service-cloud.git doktori
cd doktori
make setup
```

`make setup` 실행 후 **.env 파일 3개**를 수정해야 합니다:

| 파일 | 내용 |
|------|------|
| `.env` | DB 비밀번호 (`DB_PASSWORD`), DB 유저 (`DB_USERNAME`) |
| `Backend/.env` | JWT, Kakao OAuth, Zoom, S3 등 |
| `AI/.env` | Gemini API key 등 |

> 값은 팀 노션 참고

## 실행

```bash
make up       # 전체 빌드 + 시작 (첫 실행 시 5~10분 소요)
make down     # 중지 (데이터 유지)
make clean    # 중지 + 데이터 삭제 (주의!)
```

## 접속

| 서비스 | URL |
|--------|-----|
| Frontend | http://localhost |
| Backend API | http://localhost/api |
| Chat (WebSocket) | http://localhost/api/chat |
| AI | http://localhost/ai |
| MySQL | localhost:3307 (Workbench 등) |
| Redis | localhost:6379 |

## 일상 작업

```bash
# develop 최신 반영 (전체 pull → 재빌드)
make pull

# IDE 개발 (DB + Redis만 Docker, 나머지는 IDE에서 직접 실행)
make deps
```

## 로그 & 디버깅

```bash
make logs          # 전체
make logs-be       # Backend (API)
make logs-chat     # Backend (Chat)
make logs-fe       # Frontend
make logs-ai       # AI
make ps            # 서비스 상태
make redis-cli     # Redis CLI
make mysql-cli     # MySQL CLI
```

## 주의사항

- `make down` → 데이터 유지 / `make clean` → **데이터 삭제**
- Frontend 소스 변경 후 재빌드: `make clean && make up`
- 80 포트 충돌 시: `lsof -i :80`으로 확인 후 종료
- 전체 명령어 목록: `make help`
