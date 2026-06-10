# FastAPI Async Patterns

Concentrated patterns for async FastAPI services. Pair with the `python-developer` agent.

## Path Operations and Pydantic v2

```python
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field

router = APIRouter(prefix="/users", tags=["users"])


class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=100)


class UserOut(BaseModel):
    id: int
    email: EmailStr
    name: str


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    repo: "UserRepo" = Depends(get_user_repo),
) -> UserOut:
    if await repo.exists_by_email(payload.email):
        raise HTTPException(status.HTTP_409_CONFLICT, "Email already used")
    user = await repo.create(payload)
    return UserOut.model_validate(user)
```

## Yield-Dependencies for Resource Cleanup

```python
from collections.abc import AsyncIterator
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        else:
            await session.commit()
```

## Settings via pydantic-settings

```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="APP_")
    database_url: str
    jwt_secret: str
    log_level: str = "INFO"

settings = Settings()  # values come from env
```

## Testing FastAPI with httpx AsyncClient

```python
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_create_user():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        r = await client.post("/users", json={"email": "a@b.io", "name": "A"})
    assert r.status_code == 201
```

## FastAPI Don'ts

- Don't put blocking I/O (sync DB calls, `requests`, `time.sleep`) in `async def` handlers — use `asyncio.to_thread` or switch to an async client.
- Don't validate manually after Pydantic — let the model do it; raise `HTTPException` only for domain conflicts.
- Don't return ORM objects directly — map to `*Out` Pydantic models via `model_validate`.
- Don't store secrets in code — `pydantic-settings` + env vars.
