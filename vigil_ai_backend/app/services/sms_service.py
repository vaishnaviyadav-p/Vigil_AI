import os
import base64
import urllib.request
import urllib.parse
import urllib.error
import json
import socket
from datetime import datetime
from dotenv import load_dotenv

class SMSService:
    @classmethod
    def verify_url_reachable(cls, url, timeout=2.0):
        """
        Actively checks if a given public URL is alive and reaches our Flask backend.
        Catches:
        - Cloudflare Error 1033 (Unable to resolve requested host)
        - DNS lookup failures (getaddrinfo failed)
        - Timeouts and connection refused
        Returns (is_reachable: bool, status_code: int, message: str)
        """
        if not url or not url.startswith('http'):
            return False, 0, "Invalid URL scheme"

        test_url = url.rstrip('/') + '/'
        try:
            req = urllib.request.Request(
                test_url,
                headers={'User-Agent': 'VigilAI-HealthCheck/2.0'}
            )
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                code = resp.status
                body = resp.read(512).decode('utf-8', errors='ignore')
                if '1033' in body or 'error code: 1033' in body.lower():
                    return False, 1033, "Cloudflare Error 1033: Tunnel host is unresolvable"
                if code in (200, 301, 302, 404):
                    return True, code, "Reachable"
                return False, code, f"Unexpected HTTP status {code}"
        except urllib.error.HTTPError as e:
            body = e.read(512).decode('utf-8', errors='ignore')
            if e.code == 1033 or '1033' in body:
                return False, 1033, "Cloudflare Error 1033: Tunnel host is unresolvable"
            if e.code in (404, 200):
                return True, e.code, "Reachable"
            return False, e.code, f"HTTP Error {e.code}"
        except Exception as e:
            return False, 0, str(e)

    @classmethod
    def get_public_base_url(cls, request=None, verify=True):
        """
        Determines the most accessible base URL for live tracking links.
        Priority:
        1. Request forwarded headers (if incoming request arrives through trycloudflare.com / ngrok)
        2. PUBLIC_TRACKING_BASE_URL environment variable from .env (verified reachable)
        3. Active local tunnel file (tunnel_url.txt from Cloudflare tunnel or ngrok, verified reachable)
        4. Real local LAN IP (e.g. http://192.168.x.x:5000) for same-network access
        5. Request host URL fallback
        """
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        env_file = os.path.join(base_dir, '.env')
        if os.path.exists(env_file):
            load_dotenv(env_file, override=True)

        # 1. Check if request arrived through a reverse proxy / tunnel
        if request:
            f_host = request.headers.get('X-Forwarded-Host', request.host)
            f_proto = request.headers.get('X-Forwarded-Proto', request.scheme)
            if 'trycloudflare.com' in f_host or 'ngrok' in f_host:
                return f"{f_proto}://{f_host}".rstrip('/')

        # 2. Check PUBLIC_TRACKING_BASE_URL in .env
        env_url = os.environ.get('PUBLIC_TRACKING_BASE_URL', '').strip()
        if env_url and env_url.startswith('http'):
            clean_env = env_url.rstrip('/')
            if not verify:
                return clean_env
            is_ok, code, msg = cls.verify_url_reachable(clean_env)
            if is_ok:
                return clean_env
            print(f"[VIGIL AI] Note: Configured PUBLIC_TRACKING_BASE_URL ({clean_env}) reachability check: {msg}")

        # 3. Check tunnel_url.txt for a newly written tunnel
        tunnel_file = os.path.join(base_dir, 'tunnel_url.txt')
        if os.path.exists(tunnel_file):
            try:
                with open(tunnel_file, 'r', encoding='utf-8') as f:
                    t_url = f.read().strip()
                if t_url and t_url.startswith('http'):
                    clean_t = t_url.rstrip('/')
                    if not verify:
                        return clean_t
                    is_ok, code, msg = cls.verify_url_reachable(clean_t)
                    if is_ok:
                        return clean_t
            except Exception:
                pass

        # 4. Fallback to real local Wi-Fi / LAN IP
        lan_ip = None
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(('8.8.8.8', 80))
            lan_ip = s.getsockname()[0]
            s.close()
        except Exception:
            pass

        port = os.environ.get('PORT', '5000')

        if lan_ip and lan_ip != '127.0.0.1':
            return f"http://{lan_ip}:{port}"

        # 5. Request host fallback
        if request and request.host_url:
            return request.host_url.rstrip('/')

        return f"http://127.0.0.1:{port}"

    @classmethod
    def get_tunnel_diagnostic(cls, request=None):
        """
        Returns full diagnostic information regarding Cloudflare tunnel connectivity.
        """
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        env_file = os.path.join(base_dir, '.env')
        if os.path.exists(env_file):
            load_dotenv(env_file, override=True)

        env_url = os.environ.get('PUBLIC_TRACKING_BASE_URL', '').strip()
        tunnel_file = os.path.join(base_dir, 'tunnel_url.txt')
        t_file_url = ""
        if os.path.exists(tunnel_file):
            try:
                with open(tunnel_file, 'r', encoding='utf-8') as f:
                    t_file_url = f.read().strip()
            except Exception:
                pass

        active_url = cls.get_public_base_url(request, verify=False)
        is_https = active_url.startswith('https://')
        is_reachable, code, msg = cls.verify_url_reachable(active_url)

        return {
            'active_base_url': active_url,
            'configured_env_url': env_url,
            'tunnel_file_url': t_file_url,
            'is_public_https': is_https,
            'is_verified_reachable': is_reachable,
            'status_code': code,
            'diagnostic_message': (
                "Verified active! Tracking links are globally accessible over cellular mobile data."
                if (is_https and is_reachable)
                else (
                    f"Cloudflare Tunnel Error: {msg}. Run 'python scripts/run_tunnel.py' to launch an active public tunnel."
                    if is_https
                    else "Tunnel is currently offline. Tracking links are using local Wi-Fi IP."
                )
            ),
            'recommended_action': (
                "None needed. System is operating normally."
                if (is_https and is_reachable)
                else "On the laptop running Flask, execute: 'python scripts/run_tunnel.py' or 'scripts/start_tunnel.bat'"
            )
        }

    @staticmethod
    def normalize_phone_number(phone):
        """
        Normalizes any phone number into E.164 standard format required by Twilio and cellular carriers.
        Example: '8618085394' -> '+918618085394'
        """
        if not phone:
            return ""
        digits = ''.join(c for c in str(phone) if c.isdigit() or c == '+')
        if digits.startswith('+'):
            return digits
        # 10-digit Indian mobile number starting with 6, 7, 8, or 9
        if len(digits) == 10 and digits[0] in '6789':
            return f"+91{digits}"
        # 12-digit Indian number starting with 91
        if len(digits) == 12 and digits.startswith('91'):
            return f"+{digits}"
        # Prepend + if missing
        if not digits.startswith('+'):
            return f"+{digits}"
        return digits

    @classmethod
    def format_sos_alert_message(cls, user_name, latitude, longitude, tracking_url, timestamp=None):
        """
        Formats SOS alert containing:
        - "Vigil AI SOS Alert!"
        - User's name
        - Current GPS coordinates
        - Timestamp
        - Live tracking link
        """
        if timestamp is None:
            timestamp = datetime.utcnow()
        time_str = timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')

        return (
            f"Vigil AI SOS Alert!\n"
            f"User: {user_name} has triggered an EMERGENCY SOS.\n"
            f"Current Location: ({latitude:.5f}, {longitude:.5f})\n"
            f"Timestamp: {time_str}\n"
            f"Live Tracking Link: {tracking_url}\n"
            f"Please check on them immediately!"
        )

    @classmethod
    def dispatch_sos_alert(cls, user, emergency, contacts, tracking_url):
        """
        Dispatches or prepares the emergency alert for registered contacts.
        - Uses Twilio cellular SMS gateway if credentials are configured in .env.
        - Normalizes recipient phone numbers to E.164 standard (+91...).
        - Prepares native device SMS and WhatsApp intent payloads for instant delivery.
        - Checks live tunnel reachability and attaches diagnostic status.
        - Never fakes delivery; returns explicit delivery or configuration status.
        """
        base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
        env_file = os.path.join(base_dir, '.env')
        if os.path.exists(env_file):
            load_dotenv(env_file, override=True)

        account_sid = os.environ.get('TWILIO_ACCOUNT_SID', '').strip()
        auth_token = os.environ.get('TWILIO_AUTH_TOKEN', '').strip()
        from_phone = os.environ.get('TWILIO_PHONE_NUMBER', '').strip()

        # Check for empty or template placeholder values
        is_placeholder = (
            not account_sid or not auth_token or not from_phone or
            any(v.startswith('your_') or 'here' in v for v in (account_sid, auth_token, from_phone))
        )

        message_body = cls.format_sos_alert_message(
            user_name=user.full_name,
            latitude=emergency.latitude,
            longitude=emergency.longitude,
            tracking_url=tracking_url,
            timestamp=emergency.created_at
        )

        encoded_body = urllib.parse.quote(message_body)

        contacts_info = []
        for c in contacts:
            norm_phone = cls.normalize_phone_number(c.phone)
            clean_digits = ''.join(ch for ch in norm_phone if ch.isdigit())
            contacts_info.append({
                'id': c.id,
                'name': c.name,
                'phone': c.phone,
                'normalized_phone': norm_phone,
                'relationship': c.relationship,
                'sms_intent_uri': f"sms:{norm_phone}?body={encoded_body}",
                'whatsapp_uri': f"https://wa.me/{clean_digits}?text={encoded_body}"
            })

        # Check public tunnel status
        is_public_https = tracking_url.startswith('https://')
        is_verified, code, msg = cls.verify_url_reachable(tracking_url.split('/track/')[0]) if is_public_https else (False, 0, "Local Wi-Fi IP")

        tunnel_meta = {
            'is_public_https': is_public_https,
            'public_tunnel_active': is_public_https and is_verified,
            'diagnostic_message': (
                "Verified active! Tracking link is accessible over mobile data."
                if (is_public_https and is_verified)
                else (
                    f"Warning: Tracking link is using a local or unverified URL ({msg}). Emergency contact should be on same Wi-Fi or run 'python scripts/run_tunnel.py'."
                )
            )
        }

        if not contacts:
            return {
                'configured': not is_placeholder,
                'status': 'NO_CONTACTS',
                'gateway': 'Twilio Cellular SMS Gateway' if not is_placeholder else 'None',
                'message': 'No registered emergency contacts found in user account. Please add contacts.',
                'alert_text': message_body,
                'tracking_url': tracking_url,
                'public_tunnel_active': tunnel_meta['public_tunnel_active'],
                'tunnel_diagnostic': tunnel_meta['diagnostic_message'],
                'contacts_attempted': []
            }

        # If real SMS gateway credentials are provided, perform cellular dispatch via Twilio API
        if not is_placeholder:
            dispatch_results = []
            twilio_url = f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json"
            credentials = f"{account_sid}:{auth_token}"
            base64_auth = base64.b64encode(credentials.encode()).decode()

            for contact in contacts:
                target_phone = cls.normalize_phone_number(contact.phone)
                post_data = urllib.parse.urlencode({
                    'To': target_phone,
                    'From': from_phone,
                    'Body': message_body
                }).encode('utf-8')

                req = urllib.request.Request(
                    twilio_url,
                    data=post_data,
                    headers={
                        'Authorization': f'Basic {base64_auth}',
                        'Content-Type': 'application/x-www-form-urlencoded'
                    }
                )

                try:
                    with urllib.request.urlopen(req, timeout=10) as response:
                        res_data = json.loads(response.read().decode())
                        dispatch_results.append({
                            'id': contact.id,
                            'name': contact.name,
                            'phone': contact.phone,
                            'normalized_phone': target_phone,
                            'status': 'DELIVERED',
                            'message_sid': res_data.get('sid'),
                            'carrier_status': res_data.get('status')
                        })
                except urllib.error.HTTPError as he:
                    error_body = he.read().decode('utf-8', errors='ignore')
                    err_msg = f"HTTP {he.code}"
                    try:
                        err_json = json.loads(error_body)
                        err_msg = f"Twilio Error {err_json.get('code')}: {err_json.get('message')}"
                    except Exception:
                        pass
                    dispatch_results.append({
                        'id': contact.id,
                        'name': contact.name,
                        'phone': contact.phone,
                        'normalized_phone': target_phone,
                        'status': 'FAILED',
                        'error': err_msg
                    })
                except Exception as ex:
                    dispatch_results.append({
                        'id': contact.id,
                        'name': contact.name,
                        'phone': contact.phone,
                        'normalized_phone': target_phone,
                        'status': 'FAILED',
                        'error': str(ex)
                    })

            has_success = any(r['status'] == 'DELIVERED' for r in dispatch_results)
            return {
                'configured': True,
                'status': 'DELIVERED' if has_success else 'FAILED',
                'gateway': 'Twilio Cellular SMS Gateway',
                'message': 'Cellular SMS successfully dispatched via Twilio.' if has_success else 'Twilio SMS dispatch failed. Check Twilio error details.',
                'alert_text': message_body,
                'tracking_url': tracking_url,
                'public_tunnel_active': tunnel_meta['public_tunnel_active'],
                'tunnel_diagnostic': tunnel_meta['diagnostic_message'],
                'contacts_attempted': dispatch_results
            }

        # SMS Gateway NOT configured in environment
        return {
            'configured': False,
            'status': 'NOT_CONFIGURED',
            'gateway': 'None (Twilio credentials not set in backend environment)',
            'message': (
                'Twilio SMS credentials not set in backend .env. '
                'Device native SIM SMS dispatch intent prepared automatically.'
            ),
            'alert_text': message_body,
            'tracking_url': tracking_url,
            'public_tunnel_active': tunnel_meta['public_tunnel_active'],
            'tunnel_diagnostic': tunnel_meta['diagnostic_message'],
            'contacts_attempted': contacts_info
        }
