# Deploy on Liara (Next.js)

## 1) Create app & PostgreSQL on Liara
- App Platform: Node.js (or Next.js)
- Database: PostgreSQL (14+)

## 2) Variables
Set in Liara Dashboard > Variables:
- `DATABASE_URL`: PostgreSQL connection string provided by Liara DB.
- `LIARA_AI_API_KEY`: (Optional) Liara AI access token.

## 3) Database Setup
- Option A (Auto-migration): On first API request (`/api/create-order` or `/api/unlock-report`), the application automatically creates its core schema (`migration_groups`, `countries`, `migration_modules`) and seeds official facts.
- Option B (SQL dump import): You can import `family_immigration_db.sql` directly into your Liara PostgreSQL instance via pgAdmin, DBeaver, or psql.

## 4) Build/Start
This repository uses:
- `build`: `next build`
- `start`: `next start -p $PORT`
