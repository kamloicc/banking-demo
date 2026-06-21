# Phase 4: Application v2 (Phone login + Account number + UI)

The goal of v2 is to upgrade the **application layer** while keeping **v1** intact for comparison.

## New Features (v2)

- **Generate random account number** for users on registration (`account_number`, unique).
- **Register/login using phone number** (`phone`, unique).
- **Transfer money by account number** and **auto-display recipient name** (UI calls lookup).
- **Improved UI** (keeping React + Tailwind, enhanced forms/UX).

## API Changes (v2)

- `POST /api/auth/register`: body `{ phone, username, password }` → returns `account_number`
- `POST /api/auth/login`: body `{ phone, password }`
- `GET /api/account/lookup?account_number=...` → `{ account_number, username }`
- `POST /api/transfer/transfer`: body `{ to_account_number, amount }`

## Database Notes

v2 still uses `Base.metadata.create_all()` for quick demo. When running on a DB with existing v1 schema, you should use a new DB or migration (Alembic) to add `phone`, `account_number` columns.
