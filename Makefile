.PHONY: up down logs rebuild psql
up:       ; docker compose up --build -d
down:     ; docker compose down
logs:     ; docker compose logs -f api
rebuild:  ; docker compose build --no-cache api && docker compose up -d
psql:     ; docker compose exec db psql -U $${DB_USER:-aps_user} -d apsbrat_db
