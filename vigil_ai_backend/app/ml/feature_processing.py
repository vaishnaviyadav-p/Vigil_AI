import numpy as np

def calculate_magnitude(x, y, z):
    """
    Calculate Euclidean acceleration magnitude: sqrt(x^2 + y^2 + z^2)
    Earth gravity standard is ~9.8 m/s^2.
    """
    return np.sqrt(x**2 + y**2 + z**2)

def calculate_jerk(magnitudes, dt=0.05):
    """
    Calculate Jerk (rate of change of acceleration): d|a| / dt
    Sudden impacts or violent movements exhibit high jerk.
    """
    if len(magnitudes) < 2:
        return 0.0
    diffs = np.diff(magnitudes)
    return np.max(np.abs(diffs)) / max(dt, 0.001)

def extract_window_features(samples):
    """
    Extract statistical and kinematic features from a sensor window.
    samples: list of dicts with keys 'x', 'y', 'z' or list of magnitude values.
    Returns: 1D array of features [mean_mag, std_mag, max_mag, min_mag, energy, jerk]
    """
    if not samples:
        return np.array([9.8, 0.0, 9.8, 9.8, 96.04, 0.0])
    
    if isinstance(samples[0], dict):
        mags = np.array([calculate_magnitude(s.get('x', 0), s.get('y', 0), s.get('z', 9.8)) for s in samples])
    else:
        mags = np.array(samples)
    
    mean_mag = float(np.mean(mags))
    std_mag = float(np.std(mags))
    max_mag = float(np.max(mags))
    min_mag = float(np.min(mags))
    energy = float(np.sum(mags**2) / len(mags))
    jerk = float(calculate_jerk(mags))

    return np.array([mean_mag, std_mag, max_mag, min_mag, energy, jerk])
