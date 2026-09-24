# Build setup

How to build `KenshiCoop.dll` (and the game-less test tools) from a clean
machine. Everything below was verified end-to-end on Windows 10/11 x64; no
environment variables or admin `Setup.bat` are needed - the build scripts pass
`UseEnv=true` with explicit paths.

## 1. Toolchain

The plugin must compile with the **VC++ 2010 (v100) x64** compiler, because
KenshiLib's import libraries and headers target that ABI.

Install, in this order:

1. **Visual C++ 2010 Express** (or any VS2010 edition) + **VS2010 SP1**.
2. **Windows SDK 7.1** (x64 components).
3. **KB2519277** - "Visual C++ 2010 SP1 Compiler Update for the Windows
   SDK 7.1" (restores the x64 compilers the SDK 7.1 installer removes).

Sanity check - both must exist:

```
C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\bin\amd64\cl.exe
C:\Program Files\Microsoft SDKs\Windows\v7.1
```

You also need:

- **MSBuild** from any recent Visual Studio (2019 or newer; the "Build Tools"
  edition is enough - no IDE required). `scripts\build_plugin.cmd` locates it
  via `vswhere`; if that fails, set `MSBUILD` to the full `MSBuild.exe` path.
- **git** and **git-lfs** (the KenshiLib dependencies ship binaries over LFS).
- **PowerShell 7 (`pwsh`)** for the game-less test suite (`scripts\verify.ps1`
  uses `Import-PowerShellDataFile`, which Windows PowerShell 5.1 lacks).

## 2. Dependencies (pinned)

### KenshiLib + Boost (`third_party/KenshiLib_deps`)

Only tag **`v0.1`** has the header layout this tree compiles against (newer
tags moved `kenshi/CombatClass.h` and break the build).

```cmd
git clone https://github.com/BFrizzleFoShizzle/KenshiLib_Examples_deps.git third_party\KenshiLib_deps
git -C third_party\KenshiLib_deps checkout v0.1
git -C third_party\KenshiLib_deps lfs pull
```

Then extract `third_party\KenshiLib_deps\boost_1_60_0\boost.zip` in place, so
the headers sit at `third_party\KenshiLib_deps\boost_1_60_0\boost\`.

Finally apply the vendored header fixes (see `third_party\kenshilib\README.md`
for what they are and why):

```cmd
git -C third_party\KenshiLib_deps apply ..\kenshilib\kenshilib_headers_v0.1.patch
```

The dependency clone is git-ignored on purpose: the patch lives in its working
tree only.

### ENet (`third_party/enet/enet`)

Version **`v1.3.18`**, plus the two vendored patches (C89 `for` loops for the
v100 compiler, and the socket hooks the Steam P2P tunnel needs). From the repo
root:

```cmd
git clone --depth 1 --branch v1.3.18 https://github.com/lsalzman/enet.git third_party\enet\enet
git apply third_party\enet\patches\0001-enet-c89-for-loops.patch
git apply third_party\enet\patches\0002-enet-socket-hooks.patch
```

## 3. Build

```cmd
scripts\build_plugin.cmd Harness    :: test DLL with the scenario runner (dev)
scripts\build_plugin.cmd Release    :: the DLL shipped to players
scripts\build_prototest.cmd         :: dist\prototest.exe  (unit layer)
scripts\build_netsim.cmd            :: dist\netsim.exe     (WAN relay proxy)
scripts\build_tunneltest.cmd        :: dist\tunneltest.exe (ENet-over-tunnel proof)
```

Expected outputs: `src\plugin\x64\Harness\KenshiCoop.dll` (~1.4 MB) and
`src\plugin\x64\Release\KenshiCoop.dll` (~1.0 MB), both with 0 errors.

## 4. Game-less tests

```cmd
dist\prototest.exe                  :: 522/522 checks passed
pwsh -NoProfile -File scripts\verify.ps1
```

`verify.ps1` runs the prototest layer, the contract fixtures (32/32) and the
oracle fixtures on synthetic logs - no Kenshi install needed.

**Locale note:** the plugin's logs always format numbers with `.` (C++
`printf`), and the oracle library (`scripts\CoopOracles.psm1`) pins the thread
to the invariant culture at import, so `verify.ps1` passes identically under
comma-decimal locales (es-ES, de-DE, ...) and en-US.

The full scenario suite (`scripts\run_test.ps1`, `scripts\dev_cycle.ps1`,
`scripts\deploy.cmd`) needs a local Kenshi 1.0.65 install and is out of scope
for a build check.
