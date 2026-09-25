import os
from datetime import datetime

class RiskEngine:
    """
    AI-Assisted Multi-Factor Risk Assessment Engine.
    Combines sensory anomalies, geospatial risk zones, voice distress flags,
    geofence boundaries, contextual time hazards, and user feedback.
    
    Adheres to safety ethics: Signals are treated as statistical risk indicators,
    not definitive or infallible proof of danger.
    """

    LEVEL_SAFE = 'SAFE'          # 0 - 30
    LEVEL_LOW = 'LOW'            # 31 - 50
    LEVEL_MEDIUM = 'MEDIUM'      # 51 - 70
    LEVEL_HIGH = 'HIGH'          # 71 - 85
    LEVEL_CRITICAL = 'CRITICAL'  # 86 - 100

    DISCLAIMER = (
        "AI-assisted risk score. Sensory, location, and audio indicators are "
        "probabilistic signals designed to assist safety monitoring and cannot "
        "definitively determine individual danger or medical condition."
    )

    @staticmethod
    def get_risk_level(score):
        score = max(0.0, min(100.0, float(score)))
        if score <= 30.0:
            return RiskEngine.LEVEL_SAFE
        elif score <= 50.0:
            return RiskEngine.LEVEL_LOW
        elif score <= 70.0:
            return RiskEngine.LEVEL_MEDIUM
        elif score <= 85.0:
            return RiskEngine.LEVEL_HIGH
        else:
            return RiskEngine.LEVEL_CRITICAL

    @classmethod
    def evaluate(cls, 
                 is_sos=False,
                 is_fall=False,
                 is_anomaly=False,
                 anomaly_score=0.0,
                 is_distress_voice=False,
                 voice_keyword=None,
                 zone_type=None,
                 is_geofence_breach=False,
                 hour=None,
                 nearby_incidents_count=0,
                 user_activity='STATIONARY'):
        """
        Calculates cumulative risk score (0-100) and returns itemized contributing factors.
        """
        if hour is None:
            hour = datetime.utcnow().hour

        base_score = 5.0  # nominal baseline
        factors = []

        # 1. SOS Trigger: immediate critical weighting
        if is_sos:
            impact = 70.0
            base_score += impact
            factors.append({
                'factor': 'Manual / Confirmed SOS Triggered',
                'impact': f"+{impact:.0f}",
                'severity': 'CRITICAL'
            })

        # 2. Fall Detection Signal
        if is_fall:
            impact = 35.0
            base_score += impact
            factors.append({
                'factor': 'Possible Fall / High Impact Event',
                'impact': f"+{impact:.0f}",
                'severity': 'HIGH'
            })

        # 3. Movement Anomaly (from Isolation Forest or Accelerometer Jerk)
        if is_anomaly:
            impact = min(30.0, 20.0 + (abs(anomaly_score) * 10.0))
            base_score += impact
            factors.append({
                'factor': 'Abnormal Kinematic Movement (ML Anomaly)',
                'impact': f"+{impact:.0f}",
                'severity': 'MEDIUM'
            })

        # 4. Voice Distress Keyword
        if is_distress_voice:
            impact = 30.0
            base_score += impact
            keyword_str = f" ('{voice_keyword}')" if voice_keyword else ""
            factors.append({
                'factor': f"Distress Keyword Recognized{keyword_str}",
                'impact': f"+{impact:.0f}",
                'severity': 'HIGH'
            })

        # 5. Safety Zone Proximity
        if zone_type == 'HIGH_RISK':
            impact = 20.0
            base_score += impact
            factors.append({
                'factor': 'Inside Configured High-Risk Zone',
                'impact': f"+{impact:.0f}",
                'severity': 'HIGH'
            })
        elif zone_type == 'CAUTION':
            impact = 10.0
            base_score += impact
            factors.append({
                'factor': 'Inside Caution Zone',
                'impact': f"+{impact:.0f}",
                'severity': 'MEDIUM'
            })

        # 6. Geofence Boundary Breach
        if is_geofence_breach:
            impact = 15.0
            base_score += impact
            factors.append({
                'factor': 'Personal Geofence Boundary Exited',
                'impact': f"+{impact:.0f}",
                'severity': 'MEDIUM'
            })

        # 7. Time-of-Day Contextual Risk (Late night hours: 10 PM - 5 AM)
        if hour >= 22 or hour <= 5:
            impact = 7.0
            base_score += impact
            factors.append({
                'factor': 'Contextual Late-Night Time Hazard',
                'impact': f"+{impact:.0f}",
                'severity': 'LOW'
            })

        # 8. Historical Incident Density nearby
        if nearby_incidents_count > 0:
            impact = min(15.0, nearby_incidents_count * 3.0)
            base_score += impact
            factors.append({
                'factor': f"High Local Incident Density ({nearby_incidents_count} reports)",
                'impact': f"+{impact:.0f}",
                'severity': 'LOW' if impact < 10 else 'MEDIUM'
            })

        # Clamp between 0 and 100
        final_score = max(0.0, min(100.0, base_score))
        level = cls.get_risk_level(final_score)

        return {
            'risk_score': round(final_score, 1),
            'safety_score': round(100.0 - final_score, 1),
            'risk_level': level,
            'factors': factors,
            'disclaimer': cls.DISCLAIMER,
            'timestamp': datetime.utcnow().isoformat()
        }
