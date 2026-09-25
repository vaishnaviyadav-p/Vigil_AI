import os
import joblib
import numpy as np
from app.ml.feature_processing import extract_window_features, calculate_magnitude
from app.ml.risk_model import RiskEngine

class MLService:
    _instance = None

    def __init__(self, models_dir=None):
        if models_dir is None:
            base_dir = os.path.abspath(os.path.dirname(__file__))
            models_dir = os.path.join(base_dir, 'models')

        self.models_dir = models_dir
        self.scaler = None
        self.iso_forest = None
        self.rf_model = None
        self.load_models()

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = MLService()
        return cls._instance

    def load_models(self):
        scaler_path = os.path.join(self.models_dir, 'scaler.joblib')
        iso_path = os.path.join(self.models_dir, 'isolation_forest.joblib')
        rf_path = os.path.join(self.models_dir, 'risk_rf_model.joblib')

        if os.path.exists(scaler_path) and os.path.exists(iso_path) and os.path.exists(rf_path):
            try:
                self.scaler = joblib.load(scaler_path)
                self.iso_forest = joblib.load(iso_path)
                self.rf_model = joblib.load(rf_path)
                print("[VIGIL AI ML] ML Models loaded successfully.")
            except Exception as e:
                print(f"[VIGIL AI ML] Error loading models: {e}")
        else:
            print("[VIGIL AI ML] Models not found yet. Training pipeline should be executed.")

    def predict_anomaly(self, sensor_samples):
        """
        Takes raw accelerometer sensor window or precomputed features.
        Returns:
        {
           'is_anomaly': bool,
           'anomaly_score': float,
           'confidence': float,
           'activity_state': str
        }
        """
        # Feature extraction
        features = extract_window_features(sensor_samples)
        mean_mag, std_mag, max_mag, min_mag, energy, jerk = features

        # Basic kinematic state classification
        if max_mag > 28.0 or jerk > 80.0:
            activity_state = 'FALL_IMPACT'
        elif std_mag > 6.0 and jerk > 45.0:
            activity_state = 'SHAKING'
        elif mean_mag > 12.0 or std_mag > 3.0:
            activity_state = 'RUNNING'
        elif std_mag > 0.8:
            activity_state = 'WALKING'
        else:
            activity_state = 'STATIONARY'

        # If models loaded, use ML inference
        if self.scaler is not None and self.iso_forest is not None:
            try:
                features_scaled = self.scaler.transform([features])
                # Isolation Forest: -1 for anomaly, 1 for inlier
                iso_pred = self.iso_forest.predict(features_scaled)[0]
                # Decision function: lower values mean more anomalous
                score = float(self.iso_forest.decision_function(features_scaled)[0])
                is_anomaly = bool(iso_pred == -1 or activity_state in ('FALL_IMPACT', 'SHAKING'))
                
                rf_prob = 0.5
                if self.rf_model is not None:
                    rf_prob = float(self.rf_model.predict_proba(features_scaled)[0][1])

                return {
                    'is_anomaly': is_anomaly,
                    'anomaly_score': round(abs(score), 3),
                    'confidence': round(rf_prob, 3),
                    'activity_state': activity_state,
                    'features': {
                        'mean_magnitude': round(mean_mag, 2),
                        'std_magnitude': round(std_mag, 2),
                        'max_magnitude': round(max_mag, 2),
                        'jerk': round(jerk, 2)
                    }
                }
            except Exception as e:
                print(f"[VIGIL AI ML] Inference error: {e}")

        # Heuristic fallback if models not yet loaded
        is_anomaly = activity_state in ('FALL_IMPACT', 'SHAKING')
        return {
            'is_anomaly': is_anomaly,
            'anomaly_score': 0.85 if is_anomaly else 0.1,
            'confidence': 0.9 if is_anomaly else 0.5,
            'activity_state': activity_state,
            'features': {
                'mean_magnitude': round(mean_mag, 2),
                'std_magnitude': round(std_mag, 2),
                'max_magnitude': round(max_mag, 2),
                'jerk': round(jerk, 2)
            }
        }

    def evaluate_risk(self, **kwargs):
        """
        Wrapper around RiskEngine.evaluate.
        """
        return RiskEngine.evaluate(**kwargs)
