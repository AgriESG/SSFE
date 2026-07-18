"""
Request metrics for AgriESG API.

Counts requests per endpoint and per day in Upstash Redis (durable,
survives Render restarts). Exposes a token-protected /metrics-internal
endpoint to read the totals.

Author: Esther Oluwasolayimika Olusola

Design notes:
- Health checks, docs and root are EXCLUDED so uptime monitors and
  Render's own probes never inflate usage numbers. Only real product
  endpoints are counted.
- Counting is fire-and-forget in a background task: if Upstash is slow
  or down, API responses are never delayed and never fail because of
  metrics.
- Keys:
    m:total                          -> all counted requests ever
    m:endpoint:<slug>                -> per-endpoint total
    m:daily:<YYYY-MM-DD>             -> all counted requests that day
    m:endpoint:<slug>:daily:<date>   -> per-endpoint per day
"""

import asyncio
import datetime
import os

import httpx
from fastapi import APIRouter, Header, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

UPSTASH_URL = os.getenv("UPSTASH_REDIS_REST_URL", "").rstrip("/")
UPSTASH_TOKEN = os.getenv("UPSTASH_REDIS_REST_TOKEN", "")
METRICS_TOKEN = os.getenv("METRICS_TOKEN", "")

# Paths that must NOT count as product usage.
EXCLUDED_PATHS = {
    "/",
    "/health",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/favicon.ico",
    "/metrics-internal",
}

_HEADERS = {"Authorization": f"Bearer {UPSTASH_TOKEN}"}


async def _pipeline(commands):
    """Send a batch of Redis commands to Upstash. Never raises."""
    if not UPSTASH_URL or not UPSTASH_TOKEN:
        return None
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.post(
                f"{UPSTASH_URL}/pipeline", headers=_HEADERS, json=commands
            )
            return r.json()
    except Exception:
        return None


class RequestCounterMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        path = request.url.path
        if path not in EXCLUDED_PATHS and response.status_code < 500:
            today = datetime.date.today().isoformat()
            slug = path.strip("/").replace("/", "_") or "root"
            keys = [
                "m:total",
                f"m:endpoint:{slug}",
                f"m:daily:{today}",
                f"m:endpoint:{slug}:daily:{today}",
            ]
            # Fire and forget: never delays or breaks the response.
            asyncio.create_task(_pipeline([["INCR", k] for k in keys]))
        return response


router = APIRouter()


@router.get("/metrics-internal", include_in_schema=False)
async def metrics_internal(x_metrics_token: str = Header(default="")):
    """Private totals reader. Returns 404 (not 401) without the token
    so the endpoint is invisible to anyone probing the API."""
    if not METRICS_TOKEN or x_metrics_token != METRICS_TOKEN:
        raise HTTPException(status_code=404)

    result = await _pipeline([["KEYS", "m:*"]])
    if not result:
        return {"error": "metrics store unavailable"}
    keys = result[0].get("result") or []
    if not keys:
        return {"metrics": {}, "note": "no data yet"}

    values = await _pipeline([["MGET", *keys]])
    if not values:
        return {"error": "metrics store unavailable"}
    counts = {
        k: int(v)
        for k, v in zip(keys, values[0].get("result") or [])
        if v is not None
    }
    return {
        "generated_at": datetime.datetime.utcnow().isoformat() + "Z",
        "totals": {
            k: v for k, v in sorted(counts.items()) if ":daily:" not in k
        },
        "daily": {
            k: v for k, v in sorted(counts.items()) if ":daily:" in k
        },
    }
