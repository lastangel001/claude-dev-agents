---
name: python-patterns
description: Idiomatic Python 3.11+ patterns — PEP 8, modern type hints, async/TaskGroup, comprehensions, dataclasses, FastAPI essentials, tooling (ruff/mypy/pytest). Activate when writing, reviewing, or refactoring Python code, or working with pyproject.toml / FastAPI / Django / Flask projects.
---

# Python Development Patterns (3.11+)

Idiomatic Python patterns and best practices for building robust, efficient, and maintainable applications. Target: **Python 3.11+** exclusively.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing new Python code or modules
- Reviewing Python code / diffs
- Refactoring existing Python code
- Designing Python packages, APIs, libraries
- Building FastAPI / async services
- Trigger phrases: "Python", "Pythonic way", "type hints", "FastAPI", "async", "ревью Python", "идиоматичный Python"

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Annotating signatures, generics, `Protocol`, `Self`, type aliases | [references/typing.md](references/typing.md) |
| Comprehensions, generators, dataclasses, decorators, context managers, EAFP | [references/idioms.md](references/idioms.md) |
| Exception handling, chaining, custom hierarchies | [references/errors.md](references/errors.md) |
| Threads vs processes vs asyncio, `TaskGroup`, blocking-in-async pitfalls | [references/concurrency.md](references/concurrency.md) |
| FastAPI endpoints, Pydantic v2, yield-deps, settings, httpx tests | [references/fastapi.md](references/fastapi.md) |
| Project layout, imports, `__slots__`/memory, ruff/mypy/pytest, pyproject.toml | [references/tooling.md](references/tooling.md) |

## Core Principles

1. **Readability counts.** Code should be obvious: full names, clear flow, no clever one-liners that need decoding.
2. **Explicit is better than implicit.** No hidden side effects, no magic setup calls; configuration visible at the call site.
3. **EAFP over LBYL.** Try the operation and handle the failure (`try/except FileNotFoundError`) instead of racy pre-checks (`os.path.exists`). For dict defaults use `dict.get(key, default)` — neither pattern needed.

## Quick Reference: Python Idioms

| Idiom | Description |
|-------|-------------|
| EAFP | Easier to Ask Forgiveness than Permission |
| Context managers | Use `with` for resource management |
| List comprehensions | For simple transformations |
| Generators | For lazy evaluation and large datasets |
| Type hints | Annotate function signatures — `list[X]`, `X \| None`, never `typing.List/Optional` |
| Dataclasses | For data containers with auto-generated methods |
| `__slots__` | For memory optimization |
| f-strings | For string formatting |
| `pathlib.Path` | For path operations |
| `enumerate` | For index-element pairs in loops |
| `asyncio.TaskGroup` | Structured concurrency (3.11+), prefer over `gather` |

## Anti-Patterns to Avoid

```python
# Bad: Mutable default arguments
def append_to(item, items=[]):
    items.append(item)
    return items

# Good: Use None and create new list
def append_to(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

# Bad: Checking type with type()
if type(obj) == list:
    process(obj)

# Good: Use isinstance
if isinstance(obj, list):
    process(obj)

# Bad: Comparing to None with ==
if value == None:
    process()

# Good: Use is
if value is None:
    process()

# Bad: from module import *
from os.path import *

# Good: Explicit imports
from os.path import join, exists

# Bad: Bare except
try:
    risky_operation()
except:
    pass

# Good: Specific exception
try:
    risky_operation()
except SpecificError as e:
    logger.error(f"Operation failed: {e}")
```

__Remember__: Python code should be readable, explicit, and follow the principle of least surprise. When in doubt, prioritize clarity over cleverness.
