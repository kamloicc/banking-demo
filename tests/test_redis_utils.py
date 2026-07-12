import asyncio

import pytest
from fastapi import HTTPException

from common.redis_utils import (
    create_session,
    get_user_id_from_session,
    publish_notify,
    set_presence,
)


class FakeRedis:
    """Small in-memory substitute for the Redis methods used by the app."""

    def __init__(self):
        self.values = {}
        self.ttls = {}
        self.published_messages = []

    async def setex(self, key, ttl, value):
        self.values[key] = value
        self.ttls[key] = ttl

    async def get(self, key):
        return self.values.get(key)

    async def delete(self, key):
        self.values.pop(key, None)
        self.ttls.pop(key, None)

    async def publish(self, channel, message):
        self.published_messages.append((channel, message))


def test_create_and_read_session():
    redis = FakeRedis()

    async def scenario():
        session_id = await create_session(redis, user_id=42)

        assert len(session_id) == 32
        assert redis.values[f"session:{session_id}"] == "42"
        assert await get_user_id_from_session(redis, session_id) == 42

    asyncio.run(scenario())


def test_missing_session_is_rejected():
    redis = FakeRedis()

    async def scenario():
        with pytest.raises(HTTPException) as exception:
            await get_user_id_from_session(redis, None)

        assert exception.value.status_code == 401
        assert exception.value.detail == "Missing session"

    asyncio.run(scenario())


def test_invalid_session_is_rejected():
    redis = FakeRedis()

    async def scenario():
        with pytest.raises(HTTPException) as exception:
            await get_user_id_from_session(redis, "invalid-session")

        assert exception.value.status_code == 401
        assert exception.value.detail == "Invalid/expired session"

    asyncio.run(scenario())


def test_presence_and_notification_operations():
    redis = FakeRedis()

    async def scenario():
        await set_presence(redis, user_id=7, online=True)

        assert redis.values["presence:7"] == "online"
        assert redis.ttls["presence:7"] == 60

        await publish_notify(redis, user_id=7, message="Transfer received")

        assert redis.published_messages == [
            ("notify:7", "Transfer received")
        ]

        await set_presence(redis, user_id=7, online=False)

        assert "presence:7" not in redis.values

    asyncio.run(scenario())
