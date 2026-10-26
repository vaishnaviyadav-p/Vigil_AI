import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.models import db

class VigilAITestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = create_app()
        cls.client = cls.app.test_client()
        cls.token = None

    def test_01_health_check(self):
        res = self.client.get('/')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data['status'], 'OPERATIONAL')

    def test_02_login(self):
        res = self.client.post('/api/auth/login', json={
            'email': 'user@vigilai.com',
            'password': 'user123'
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.__class__.token = data['data']['access_token']
        self.assertIsNotNone(self.__class__.token)

    def test_03_profile_and_contacts(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        res = self.client.get('/api/users/profile', headers=headers)
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data['data']['email'], 'user@vigilai.com')

        res_c = self.client.get('/api/contacts', headers=headers)
        self.assertEqual(res_c.status_code, 200)
        c_data = res_c.get_json()
        self.assertGreaterEqual(len(c_data['data']), 1)

    def test_04_zones_and_geofence(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        res_z = self.client.get('/api/zones', headers=headers)
        self.assertEqual(res_z.status_code, 200)
        self.assertGreaterEqual(len(res_z.get_json()['data']), 1)

        # Check proximity to High-Risk Underpass (12.9810, 77.6040)
        res_check = self.client.post('/api/zones/check', headers=headers, json={
            'latitude': 12.9810,
            'longitude': 77.6040
        })
        self.assertEqual(res_check.status_code, 200)
        self.assertTrue(res_check.get_json()['data']['is_inside'])

    def test_05_sensor_ml_anomaly_detection(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        # Simulate violent jerky sensor samples
        samples = [
            {'x': 18.5, 'y': 22.0, 'z': 35.0},
            {'x': 0.1, 'y': 0.2, 'z': 0.8},
            {'x': 2.0, 'y': 1.5, 'z': 1.0}
        ]
        res = self.client.post('/api/sensors/stream', headers=headers, json={'samples': samples})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertIn('analysis', data['data'])

    def test_06_ai_risk_evaluation(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        res = self.client.post('/api/risk/evaluate', headers=headers, json={
            'latitude': 12.9810,
            'longitude': 77.6040,
            'is_anomaly': True,
            'is_distress_voice': True,
            'voice_keyword': 'HELP'
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()['data']
        self.assertGreater(data['risk_score'], 60.0)
        self.assertIn(data['risk_level'], ('HIGH', 'CRITICAL'))
        self.assertGreaterEqual(len(data['factors']), 2)
        self.assertIn('disclaimer', data)

    def test_07_sos_lifecycle(self):
        headers = {'Authorization': f'Bearer {self.token}'}
        # Trigger SOS with real coordinates
        res_sos = self.client.post('/api/emergency/sos', headers=headers, json={
            'latitude': 12.9716,
            'longitude': 77.5946,
            'accuracy': 8.5,
            'alert_type': 'SOS_MANUAL'
        })
        self.assertEqual(res_sos.status_code, 201)
        sos_data = res_sos.get_json()['data']
        sos_id = sos_data['emergency']['id']
        tracking_token = sos_data['tracking_token']
        tracking_url = sos_data['tracking_url']

        self.assertIsNotNone(tracking_token)
        self.assertIn('/track/', tracking_url)
        self.assertIn('sms_dispatch', sos_data)

        # 1. Test public tracking endpoint (NO authentication header required!)
        res_track = self.client.get(f'/api/emergency/track/{tracking_token}')
        self.assertEqual(res_track.status_code, 200)
        track_data = res_track.get_json()['data']
        self.assertEqual(track_data['status'], 'ACTIVE')
        self.assertTrue(track_data['is_live_sharing'])
        self.assertEqual(track_data['user_name'], 'Ananya Sharma')
        self.assertNotIn('password_hash', track_data)
        self.assertNotIn('email', track_data)

        # 2. Test live GPS location update stream
        res_update = self.client.post(f'/api/emergency/{sos_id}/location', headers=headers, json={
            'latitude': 12.9730,
            'longitude': 77.5960,
            'accuracy': 6.0,
            'speed': 1.4
        })
        self.assertEqual(res_update.status_code, 200)
        self.assertEqual(res_update.get_json()['data']['emergency']['latitude'], 12.9730)

        # 3. Test HTML web tracking page
        res_page = self.client.get(f'/track/{tracking_token}')
        self.assertEqual(res_page.status_code, 200)
        self.assertIn(b'VIGIL AI', res_page.data)
        self.assertIn(b'Leaflet', res_page.data)

        # 4. Verify active status via API
        res_act = self.client.get('/api/emergency/active', headers=headers)
        self.assertTrue(res_act.get_json()['data']['has_active'])

        # 5. Resolve SOS
        res_res = self.client.post(f'/api/emergency/{sos_id}/resolve', headers=headers)
        self.assertEqual(res_res.status_code, 200)
        resolved_data = res_res.get_json()['data']
        self.assertEqual(resolved_data['status'], 'RESOLVED')
        self.assertFalse(resolved_data['is_live_sharing'])

        # 6. Verify public tracking endpoint reflects RESOLVED status
        res_track_after = self.client.get(f'/api/emergency/track/{tracking_token}')
        self.assertEqual(res_track_after.status_code, 200)
        self.assertEqual(res_track_after.get_json()['data']['status'], 'RESOLVED')

    def test_08_safe_route_recommendation(self):
        res = self.client.post('/api/analytics/routes', json={
            'start_lat': 12.9716,
            'start_lon': 77.5946,
            'dest_lat': 12.9850,
            'dest_lon': 77.6100
        })
        self.assertEqual(res.status_code, 200)
        data = res.get_json()['data']
        self.assertIn('recommended_safe_route', data)
        self.assertIn('alternative_route', data)

    def test_09_admin_dashboard(self):
        res = self.client.get('/api/admin/dashboard')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()['data']
        self.assertIn('metrics', data)

if __name__ == '__main__':
    unittest.main()
