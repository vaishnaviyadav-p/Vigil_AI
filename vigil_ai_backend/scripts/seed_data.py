import os
import sys

# Ensure root directory in python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.models import db, User, Profile, TrustedContact, SafetyZone, Incident, Geofence

app = create_app()

def seed():
    with app.app_context():
        print("[VIGIL AI Seed] Initializing database...")
        db.create_all()

        # 1. Admin User
        admin = User.query.filter_by(email='admin@vigilai.com').first()
        if not admin:
            admin = User(
                full_name='Security Admin',
                email='admin@vigilai.com',
                phone='+919876543200',
                role='ADMIN'
            )
            admin.set_password('admin123')
            db.session.add(admin)
            db.session.flush()
            admin_prof = Profile(user_id=admin.id)
            db.session.add(admin_prof)
            print("  -> Created Admin user: admin@vigilai.com / admin123")

        # 2. Regular User (Primary demo user)
        user = User.query.filter_by(email='user@vigilai.com').first()
        if not user:
            user = User(
                full_name='Ananya Sharma',
                email='user@vigilai.com',
                phone='+919876543210',
                role='USER'
            )
            user.set_password('user123')
            db.session.add(user)
            db.session.flush()

            user_prof = Profile(
                user_id=user.id,
                blood_group='O+',
                medical_notes='Asthma inhaler in purse',
                emergency_countdown=5,
                shake_to_sos=True,
                voice_distress_detection=True,
                fall_detection=True,
                demo_mode=False
            )
            db.session.add(user_prof)
            print("  -> Created Demo User: user@vigilai.com / user123")

            # 3. Trusted Contacts for Demo User
            contacts = [
                TrustedContact(
                    user_id=user.id,
                    name='Sunita Sharma (Mother)',
                    phone='+919876543220',
                    email='sunita@example.com',
                    relationship='Parent',
                    priority=1,
                    notification_preference='ALL'
                ),
                TrustedContact(
                    user_id=user.id,
                    name='Rajesh Sharma (Father)',
                    phone='+919876543221',
                    email='rajesh@example.com',
                    relationship='Parent',
                    priority=1,
                    notification_preference='ALL'
                ),
                TrustedContact(
                    user_id=user.id,
                    name='Pooja Verma (Best Friend)',
                    phone='+919876543222',
                    email='pooja@example.com',
                    relationship='Friend',
                    priority=2,
                    notification_preference='SMS'
                )
            ]
            db.session.add_all(contacts)
            print(f"  -> Added {len(contacts)} trusted contacts.")

            # 4. Geofence around Campus / Home
            geofence = Geofence(
                user_id=user.id,
                name='College Campus Safe Zone',
                latitude=12.9716,
                longitude=77.5946,
                radius_meters=350.0,
                notify_on_exit=True,
                is_active=True
            )
            db.session.add(geofence)
            print("  -> Added campus geofence boundary.")

        # 5. Configured Safety Zones
        if SafetyZone.query.count() == 0:
            zones = [
                SafetyZone(
                    name='Campus Main Security Hub',
                    description='24/7 security booth, well-lit perimeter, emergency blue-light phones.',
                    zone_type='SAFE',
                    latitude=12.9716,
                    longitude=77.5946,
                    radius_meters=300.0,
                    risk_weight=-20.0
                ),
                SafetyZone(
                    name='Metro Station Crossing',
                    description='Moderate foot traffic; caution recommended during off-peak night hours.',
                    zone_type='CAUTION',
                    latitude=12.9750,
                    longitude=77.5990,
                    radius_meters=250.0,
                    risk_weight=15.0
                ),
                SafetyZone(
                    name='Railway Underpass (Isolated)',
                    description='Poor lighting, zero CCTV coverage, high frequency of reported harassment.',
                    zone_type='HIGH_RISK',
                    latitude=12.9810,
                    longitude=77.6040,
                    radius_meters=350.0,
                    risk_weight=30.0
                ),
                SafetyZone(
                    name='East Boundary Forest Trail',
                    description='Unpatrolled after 7 PM. Entering triggers caution alerts.',
                    zone_type='HIGH_RISK',
                    latitude=12.9660,
                    longitude=77.5880,
                    radius_meters=400.0,
                    risk_weight=25.0
                )
            ]
            db.session.add_all(zones)
            print(f"  -> Seeded {len(zones)} Safety Zones (SAFE, CAUTION, HIGH_RISK).")

        # 6. Sample Community Incidents
        if Incident.query.count() == 0:
            incidents = [
                Incident(
                    user_id=admin.id if admin else 1,
                    category='Harassment',
                    description='Individual making inappropriate comments near bus shelter.',
                    latitude=12.9790,
                    longitude=77.6015,
                    address='North Bus Stop, Sector 4',
                    severity='HIGH',
                    status='VERIFIED'
                ),
                Incident(
                    user_id=admin.id if admin else 1,
                    category='Suspicious Activity',
                    description='Vehicle parked with headlights off for prolonged period near student hostel.',
                    latitude=12.9730,
                    longitude=77.5910,
                    address='West Campus Gate',
                    severity='MEDIUM',
                    status='REPORTED'
                ),
                Incident(
                    user_id=admin.id if admin else 1,
                    category='Physical Threat',
                    description='Attempted bag snatching near poorly lit alleyway.',
                    latitude=12.9815,
                    longitude=77.6035,
                    address='Old Railway Underpass Road',
                    severity='CRITICAL',
                    status='INVESTIGATING'
                )
            ]
            db.session.add_all(incidents)
            print(f"  -> Seeded {len(incidents)} Community Safety Incidents.")

        db.session.commit()
        print("[VIGIL AI Seed] Completed successfully.")

if __name__ == '__main__':
    seed()
