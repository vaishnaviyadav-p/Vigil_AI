import sys
import os
import json

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.models import SafetyZone, Incident
from app.services.route_service import calculate_safe_route_recommendation

app = create_app()
with app.app_context():
    zones = SafetyZone.query.filter_by(is_active=True).all()
    incidents = Incident.query.all()
    
    start_lat, start_lon = 12.9716, 77.5946
    dest_lat, dest_lon = 12.9850, 77.6100
    
    print('--- Testing foot mode ---')
    res_foot = calculate_safe_route_recommendation(start_lat, start_lon, dest_lat, dest_lon, zones, incidents, mode='foot')
    safe_f = res_foot['recommended_safe_route']
    short_f = res_foot['shortest_route']
    print(f"Safe (Foot): dist={safe_f['distance_km']}km, walk={safe_f['walking_time_text']}, drive={safe_f['driving_time_text']}, score={safe_f['safety_score']}")
    print(f"Short (Foot): dist={short_f['distance_km']}km, walk={short_f['walking_time_text']}, drive={short_f['driving_time_text']}, score={short_f['safety_score']}")
    
    print('\n--- Testing driving mode ---')
    res_car = calculate_safe_route_recommendation(start_lat, start_lon, dest_lat, dest_lon, zones, incidents, mode='driving')
    safe_c = res_car['recommended_safe_route']
    short_c = res_car['shortest_route']
    print(f"Safe (Car): dist={safe_c['distance_km']}km, walk={safe_c['walking_time_text']}, drive={safe_c['driving_time_text']}, score={safe_c['safety_score']}")
    print(f"Short (Car): dist={short_c['distance_km']}km, walk={short_c['walking_time_text']}, drive={short_c['driving_time_text']}, score={short_c['safety_score']}")
