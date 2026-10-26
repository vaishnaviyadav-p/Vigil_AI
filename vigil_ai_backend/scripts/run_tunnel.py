"""
VIGIL AI – Cloudflare Tunnel Auto-Manager & Watchdog
Automatically launches cloudflared with HTTP/2 over TCP port 443,
detects the live trycloudflare.com URL, verifies public reachability,
updates .env and tunnel_url.txt, and auto-restarts if the tunnel drops.
"""

import os
import sys
import time
import re
import subprocess
import urllib.request
import urllib.error

# Paths
SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.abspath(os.path.join(SCRIPTS_DIR, '..'))
PROJECT_ROOT = os.path.abspath(os.path.join(BACKEND_DIR, '..'))

CLOUDFLARED_EXE = os.path.join(PROJECT_ROOT, 'cloudflared.exe')
TUNNEL_URL_FILE = os.path.join(BACKEND_DIR, 'tunnel_url.txt')
ENV_FILE = os.path.join(BACKEND_DIR, '.env')

def update_env_url(public_url):
    """Updates PUBLIC_TRACKING_BASE_URL in .env without overwriting other keys."""
    env_lines = []
    updated = False
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE, 'r', encoding='utf-8') as f:
            env_lines = f.readlines()

    new_lines = []
    for line in env_lines:
        if line.startswith('PUBLIC_TRACKING_BASE_URL='):
            new_lines.append(f"PUBLIC_TRACKING_BASE_URL={public_url}\n")
            updated = True
        else:
            new_lines.append(line)

    if not updated:
        new_lines.insert(0, f"PUBLIC_TRACKING_BASE_URL={public_url}\n")

    with open(ENV_FILE, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

    # Also update tunnel_url.txt
    with open(TUNNEL_URL_FILE, 'w', encoding='utf-8') as f:
        f.write(public_url.strip() + '\n')

    print(f"[TUNNEL MANAGER] Saved public URL to .env and tunnel_url.txt: {public_url}")


def verify_tunnel_reachable(public_url, max_retries=15):
    """Verifies that the Cloudflare edge DNS has propagated and returns HTTP 200 from Flask."""
    print(f"[TUNNEL MANAGER] Verifying public reachability for: {public_url} ...")
    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(
                public_url,
                headers={'User-Agent': 'VigilAI-Tunnel-Verifier/2.0'}
            )
            with urllib.request.urlopen(req, timeout=4) as resp:
                if resp.status == 200:
                    print(f"[TUNNEL MANAGER] SUCCESS: Tunnel verified reachable (HTTP {resp.status})!")
                    return True
        except urllib.error.HTTPError as e:
            if e.code == 1033:
                print(f"[TUNNEL MANAGER] Attempt {attempt}: Cloudflare Error 1033 (DNS propagating)...")
            else:
                print(f"[TUNNEL MANAGER] Attempt {attempt}: Received HTTP {e.code}...")
        except Exception as e:
            print(f"[TUNNEL MANAGER] Attempt {attempt}: Waiting for tunnel ({e})...")

        time.sleep(1.5)

    print("[TUNNEL MANAGER] WARNING: Tunnel did not verify within timeout.")
    return False


def run_tunnel():
    if not os.path.exists(CLOUDFLARED_EXE):
        print(f"[ERROR] cloudflared.exe not found at: {CLOUDFLARED_EXE}")
        sys.exit(1)

    print("=" * 65)
    print(" VIGIL AI – Cloudflare Tunnel Auto-Manager Starting")
    print(" Protocol: HTTP/2 over TCP 443 (resilient to socket timeouts)")
    print(" Forwarding to: http://127.0.0.1:5000")
    print("=" * 65)

    cmd = [
        CLOUDFLARED_EXE,
        "tunnel",
        "--protocol", "http2",
        "--url", "http://127.0.0.1:5000"
    ]

    while True:
        print("\n[TUNNEL MANAGER] Launching cloudflared tunnel process...")
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        tunnel_url = None
        dead_reasons = [
            "Unauthorized: Tunnel not found",
            "wsasendto",
            "connection refused",
            "unreachable network"
        ]

        try:
            for line in iter(proc.stdout.readline, ''):
                sys.stdout.write(line)
                sys.stdout.flush()

                # Search for tunnel URL pattern: https://*.trycloudflare.com
                if not tunnel_url:
                    match = re.search(r'(https://[a-zA-Z0-9-]+\.trycloudflare\.com)', line)
                    if match:
                        tunnel_url = match.group(1).strip()
                        print(f"\n[TUNNEL MANAGER] Detected Public URL: {tunnel_url}")
                        is_ok = verify_tunnel_reachable(tunnel_url)
                        if is_ok:
                            update_env_url(tunnel_url)
                            print("[TUNNEL MANAGER] Tunnel is active and ready for live tracking!\n")

                # Detect if tunnel died on Cloudflare side
                if any(err in line for err in dead_reasons):
                    print(f"\n[TUNNEL MANAGER] Cloudflare session invalidated: {line.strip()}")
                    print("[TUNNEL MANAGER] Terminating stale process and requesting fresh tunnel...")
                    break

            proc.terminate()
            proc.wait(timeout=5)
        except KeyboardInterrupt:
            print("\n[TUNNEL MANAGER] Stopping tunnel...")
            proc.terminate()
            break
        except Exception as e:
            print(f"[TUNNEL MANAGER] Process exception: {e}")
            try:
                proc.kill()
            except Exception:
                pass

        print("[TUNNEL MANAGER] Restarting tunnel in 2 seconds...")
        time.sleep(2)


if __name__ == '__main__':
    run_tunnel()
