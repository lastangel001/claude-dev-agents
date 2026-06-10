# Type Hints (Python 3.11+)

## Basic Type Annotations

```python
from typing import Any

def process_user(
    user_id: str,
    data: dict[str, Any],
    active: bool = True,
) -> User | None:
    """Process a user and return the updated User or None."""
    if not active:
        return None
    return User(user_id, data)
```

Always use built-in generics (`list`, `dict`, `tuple`, `set`) and `X | Y` union syntax. Never `typing.List/Dict/Tuple/Optional/Union` in new code.

## Type Aliases and Generics (PEP 695, 3.12+ where available; 3.11 fallback shown)

```python
from typing import TypeVar

# Type alias for complex types
type JSON = dict[str, "JSON"] | list["JSON"] | str | int | float | bool | None  # 3.12+
# 3.11 fallback:
# JSON = dict[str, Any] | list[Any] | str | int | float | bool | None

def parse_json(data: str) -> JSON:
    return json.loads(data)

# Generic helper
T = TypeVar("T")

def first(items: list[T]) -> T | None:
    """Return the first item or None if list is empty."""
    return items[0] if items else None
```

## `Self` for Fluent Returns (3.11+)

```python
from typing import Self

class QueryBuilder:
    def where(self, cond: str) -> Self:
        self._conds.append(cond)
        return self
```

## Protocol-Based Duck Typing

```python
from typing import Protocol

class Renderable(Protocol):
    def render(self) -> str:
        """Render the object to a string."""

def render_all(items: list[Renderable]) -> str:
    """Render all items that implement the Renderable protocol."""
    return "\n".join(item.render() for item in items)
```
