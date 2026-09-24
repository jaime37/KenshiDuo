# Protocol history

The wire protocol version lives in `src/netproto/Wire.h` (`PROTOCOL_VERSION`).
It is checked at handshake; a mismatch is rejected (no back-compat). Every bump
gets a one-line entry here, newest at the bottom. Planned numbers are reserved
so parallel integration lines do not collide.

| Version | Change |
|---|---|
| 55 | Base fork point: upstream KenshiCoop v0.51 (`5a761e19`). |
| 56 | PR #70 (jayceslesar): save-native ground pickup notice (`PKT_NATIVE_TAKEN`), fixes upstream #44. |

## Planned (reserved, not yet merged)

| Version | Change |
|---|---|
| 57–61 | BorjaAres PRs #75, #76, #78, #79, #80 (one bump each, in that order). |
| 62–65 | July PRs #18, #28, #35, #36 (one bump each, in that order). |
