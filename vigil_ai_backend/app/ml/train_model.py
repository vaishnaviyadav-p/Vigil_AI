import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

def generate_sensor_dataset(n_samples=2500):
    """
    Generate synthetic sensor feature dataset simulating:
    - Normal activities: sitting/stationary (0), walking (1), jogging/running (2)
    - Anomalous events: sudden fall impact (3), violent shake/struggle (4)
    Features: [mean_mag, std_mag, max_mag, min_mag, energy, jerk]
    """
    np.random.seed(42)
    features = []
    labels = []  # 0: normal, 1: anomaly

    # 1. Stationary / Sitting (nominal 9.8 m/s^2)
    for _ in range(n_samples // 3):
        mean_m = np.random.normal(9.8, 0.2)
        std_m = np.random.uniform(0.05, 0.4)
        max_m = mean_m + np.random.uniform(0.1, 0.8)
        min_m = mean_m - np.random.uniform(0.1, 0.8)
        energy = mean_m**2 + std_m**2
        jerk = np.random.uniform(0.5, 4.0)
        features.append([mean_m, std_m, max_m, min_m, energy, jerk])
        labels.append(0)

    # 2. Walking / Gentle movement
    for _ in range(n_samples // 3):
        mean_m = np.random.normal(10.2, 0.8)
        std_m = np.random.uniform(1.0, 3.0)
        max_m = mean_m + np.random.uniform(2.0, 5.0)
        min_m = max(1.0, mean_m - np.random.uniform(2.0, 5.0))
        energy = mean_m**2 + std_m**2
        jerk = np.random.uniform(5.0, 18.0)
        features.append([mean_m, std_m, max_m, min_m, energy, jerk])
        labels.append(0)

    # 3. Running / Rapid movement
    for _ in range(n_samples // 4):
        mean_m = np.random.normal(11.5, 1.5)
        std_m = np.random.uniform(3.0, 6.0)
        max_m = mean_m + np.random.uniform(6.0, 12.0)
        min_m = max(0.5, mean_m - np.random.uniform(5.0, 9.0))
        energy = mean_m**2 + std_m**2
        jerk = np.random.uniform(15.0, 40.0)
        features.append([mean_m, std_m, max_m, min_m, energy, jerk])
        labels.append(0)

    # 4. Fall impact (sudden massive acceleration spike > 25 m/s^2, extreme jerk, then stillness)
    for _ in range(n_samples // 8):
        mean_m = np.random.normal(15.0, 4.0)
        std_m = np.random.uniform(8.0, 16.0)
        max_m = np.random.uniform(25.0, 55.0)
        min_m = np.random.uniform(0.1, 1.5)
        energy = mean_m**2 + std_m**2
        jerk = np.random.uniform(80.0, 250.0)
        features.append([mean_m, std_m, max_m, min_m, energy, jerk])
        labels.append(1)

    # 5. Violent shake / struggle
    for _ in range(n_samples // 8):
        mean_m = np.random.normal(14.0, 3.5)
        std_m = np.random.uniform(7.0, 14.0)
        max_m = np.random.uniform(22.0, 45.0)
        min_m = np.random.uniform(0.5, 3.0)
        energy = mean_m**2 + std_m**2
        jerk = np.random.uniform(60.0, 180.0)
        features.append([mean_m, std_m, max_m, min_m, energy, jerk])
        labels.append(1)

    X = np.array(features)
    y = np.array(labels)
    return X, y

def train_and_save_models(output_dir=None):
    if output_dir is None:
        base_dir = os.path.abspath(os.path.dirname(__file__))
        output_dir = os.path.join(base_dir, 'models')
    
    os.makedirs(output_dir, exist_ok=True)
    print(f"Generating synthetic sensor dataset for VIGIL AI...")
    X, y = generate_sensor_dataset()

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # 1. Isolation Forest for Unsupervised Anomaly Detection (trained on normal samples)
    print("Training Isolation Forest Anomaly Detection model...")
    X_normal = X_scaled[y == 0]
    iso_forest = IsolationForest(
        n_estimators=100,
        contamination=0.08,
        random_state=42
    )
    iso_forest.fit(X_normal)

    # 2. Supervised Random Forest Classifier for movement classification
    print("Training Random Forest Movement/Anomaly Classifier...")
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)
    rf_clf = RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42)
    rf_clf.fit(X_train, y_train)

    y_pred = rf_clf.predict(X_test)
    print("Random Forest Evaluation:")
    print(classification_report(y_test, y_pred, target_names=['Normal', 'Anomaly']))

    # Save artifacts
    scaler_path = os.path.join(output_dir, 'scaler.joblib')
    iso_path = os.path.join(output_dir, 'isolation_forest.joblib')
    rf_path = os.path.join(output_dir, 'risk_rf_model.joblib')

    joblib.dump(scaler, scaler_path)
    joblib.dump(iso_forest, iso_path)
    joblib.dump(rf_clf, rf_path)

    print(f"Models successfully trained and saved to: {output_dir}")
    return scaler_path, iso_path, rf_path

if __name__ == '__main__':
    train_and_save_models()
