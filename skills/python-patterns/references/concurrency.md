# Concurrency Patterns

Pick the model by workload: **async** for concurrent I/O, **threads** for blocking libraries you can't replace, **processes** for CPU-bound work.

## Threading for I/O-Bound Tasks

```python
import concurrent.futures
import threading

def fetch_url(url: str) -> str:
    """Fetch a URL (I/O-bound operation)."""
    import urllib.request
    with urllib.request.urlopen(url) as response:
        return response.read().decode()

def fetch_all_urls(urls: list[str]) -> dict[str, str]:
    """Fetch multiple URLs concurrently using threads."""
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        future_to_url = {executor.submit(fetch_url, url): url for url in urls}
        results = {}
        for future in concurrent.futures.as_completed(future_to_url):
            url = future_to_url[future]
            try:
                results[url] = future.result()
            except Exception as e:
                results[url] = f"Error: {e}"
    return results
```

## Multiprocessing for CPU-Bound Tasks

```python
def process_data(data: list[int]) -> int:
    """CPU-intensive computation."""
    return sum(x ** 2 for x in data)

def process_all(datasets: list[list[int]]) -> list[int]:
    """Process multiple datasets using multiple processes."""
    with concurrent.futures.ProcessPoolExecutor() as executor:
        results = list(executor.map(process_data, datasets))
    return results
```

## Async/Await for Concurrent I/O (3.11+ TaskGroup)

```python
import asyncio
import httpx

async def fetch_async(client: httpx.AsyncClient, url: str) -> str:
    response = await client.get(url)
    response.raise_for_status()
    return response.text

async def fetch_all(urls: list[str]) -> dict[str, str]:
    """Fetch multiple URLs concurrently with structured concurrency."""
    results: dict[str, str] = {}
    async with httpx.AsyncClient() as client, asyncio.TaskGroup() as tg:
        tasks = {url: tg.create_task(fetch_async(client, url)) for url in urls}
    # TaskGroup re-raises as ExceptionGroup if any task fails
    for url, task in tasks.items():
        results[url] = task.result()
    return results
```

Prefer `asyncio.TaskGroup` over `asyncio.gather` — it cancels siblings on failure and yields a clean `ExceptionGroup`. Use `except* SomeError:` to handle specific failures from the group.

## Rules of Thumb

- Never call blocking I/O (`requests`, sync DB drivers, `time.sleep`) inside `async def` — use an async client or `asyncio.to_thread`.
- Shared mutable state across threads needs a `threading.Lock`.
- Don't drop `asyncio.create_task` results — unobserved task exceptions vanish.
