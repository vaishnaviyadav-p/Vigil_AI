import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import urllib.request
import json
from app import create_app
from app.models import User
from flask_jwt_extended import create_access_token

app = create_app()
with app.app_context():
    u = User.query.filter_by(email='vaishu.yadav2410@gmail.com').first()
    token = create_access_token(identity=str(u.id))

sos_data = json.dumps({
    'latitude': 12.9716,
    'longitude': 77.5946,
    'alert_type': 'SOS_MANUAL',
    'description': 'Live Mobile Data Tracking Verification'
}).encode()

req = urllib.request.Request(
    'http://127.0.0.1:5000/api/emergency/sos',
    data=sos_data,
    headers={'Content-Type': 'application/json', 'Authorization': f'Bearer {token}'}
)

with urllib.request.urlopen(req) as resp:
    res = json.loads(resp.read().decode())
    tracking_url = res['data']['tracking_url']
    tracking_token = res['data']['tracking_token']
    print('1. SOS Generated Tracking URL:', tracking_url)
    print('2. Public Tunnel Active?:', res['data']['sms_dispatch']['public_tunnel_active'])
    print('3. Tunnel Diagnostic:', res['data']['sms_dispatch']['tunnel_diagnostic'])

req_track = urllib.request.Request(tracking_url)
with urllib.request.urlopen(req_track, timeout=8) as resp_track:
    html = resp_track.read().decode('utf-8', errors='ignore')
    print('4. Public Live Tracking Page HTTP Status:', resp_track.getcode())
    print('   HTML Length:', len(html))
    print('   Contains Map:', 'id="map"' in html)
    print('   Contains Tracking Token:', tracking_token in html)
    print('   Contains Coordinates:', '12.9716' in html and '77.5946' in html)
