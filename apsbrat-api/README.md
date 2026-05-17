# APSBrat API

Professional Spring Boot setup (Maven, Java 17, Flyway, PostgreSQL) with feature-based structure.

## Implemented modules
- `user`: entity, repository, service, controller (read from DB)
- `school`: entity, repository, service, controller (read from DB)

## Placeholder modules (no business logic)
- `auth`, `post`, `feed`, `follow`, `community`, `chat`, `notification`, `search`

## Run
1. Configure database credentials in environment variables (or defaults in `application.yml`):
   - `DB_USER`, `DB_PASSWORD`
2. Start app:
   - `mvn spring-boot:run`

## Endpoints
- `GET /api/users?page=0&size=20`
- `GET /api/schools?page=0&size=20`

Both return `ApiResponse<T>` wrapper.
