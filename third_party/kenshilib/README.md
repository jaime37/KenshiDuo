# KenshiLib header fixes (vendored patch)

`kenshilib_headers_v0.1.patch` is a small patch against
[KenshiLib_Examples_deps](https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps)
**tag `v0.1`** that makes its published headers compile this plugin under the
v100 toolchain. The upstream author clearly builds against locally tweaked
headers that were never published; with the stock `v0.1` headers the build
stops inside KenshiLib itself:

- `enum BuildingDesignation` is defined identically in both `Platoon.h` and
  `Building/Building.h`, and some include orders pull both -> C2011
  redefinition. The patch wraps each definition in `#ifndef KC_BD_DEFINED`.
- `Building/CraftingBuilding.h` only forward-declares `class CraftingItem;`
  but the header instantiates a `std::deque<CraftingItem>`, which needs a
  complete type -> C2027. The patch turns it into an empty stub class. This is
  safe for this plugin: KenshiCoop only takes pointers to `CraftingBuilding`
  member functions and never iterates that deque or reads `CraftingItem`
  fields.

## How to apply

After cloning the dependencies (see `docs/BUILD_SETUP.md`):

```cmd
git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps.git third_party\KenshiLib_deps
git -C third_party\KenshiLib_deps checkout v0.1
git -C third_party\KenshiLib_deps lfs pull
git -C third_party\KenshiLib_deps apply ..\kenshilib\kenshilib_headers_v0.1.patch
```

The dependency clone stays an untracked, git-ignored nested repo: the patch
lives in its working tree only, never in its history.
