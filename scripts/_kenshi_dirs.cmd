@echo off
REM Shared install-dir defaults for the harness .cmd scripts. SINGLE resolution
REM point (the batch twin of CoopHarness.psm1's Get-CoopKenshiDir /
REM Get-CoopKenshiJoinDir): override either dir by setting the env var BEFORE
REM calling a script, e.g.:
REM   set KENSHICOOP_KENSHI_DIR=D:\Games\Kenshi
REM   set KENSHICOOP_KENSHI_JOIN_DIR=D:\Kenshi-Join
REM Unset = exactly the historical defaults below, so an unconfigured machine
REM behaves as before. Meant to be CALLed, not run directly.
if "%KENSHICOOP_KENSHI_DIR%"=="" set "KENSHICOOP_KENSHI_DIR=C:\Program Files (x86)\Steam\steamapps\common\Kenshi"
if "%KENSHICOOP_KENSHI_JOIN_DIR%"=="" set "KENSHICOOP_KENSHI_JOIN_DIR=%USERPROFILE%\Kenshi-Join"
