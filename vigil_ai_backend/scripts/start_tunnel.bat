@echo off
title Vigil AI - Cloudflare Tunnel Auto-Manager
cd /d "%~dp0\.."
echo ============================================================
echo  Starting Vigil AI Cloudflare Tunnel Auto-Manager
echo ============================================================
python scripts\run_tunnel.py
pause
