import os
from datetime import timedelta
from dotenv import load_dotenv

BASE_DIR = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
load_dotenv(os.path.join(BASE_DIR, '.env'))

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'vigil-ai-super-secret-key-college-demo-2026')
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'vigil-jwt-security-key-production-grade')
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    # Database configuration:
    # MySQL default connection string
    MYSQL_HOST = os.environ.get('MYSQL_HOST', 'localhost')
    MYSQL_PORT = int(os.environ.get('MYSQL_PORT', 3306))
    MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', 'password')
    MYSQL_DB = os.environ.get('MYSQL_DB', 'vigil_ai_db')

    # SQLite database fallback location
    SQLITE_PATH = os.path.join(BASE_DIR, 'vigil_ai.db')

    # Determine database URI: if USE_MYSQL is true, use MySQL; otherwise check if MySQL is available or fallback
    USE_MYSQL = os.environ.get('USE_MYSQL', 'false').lower() in ('true', '1', 'yes')

    if USE_MYSQL:
        SQLALCHEMY_DATABASE_URI = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"
    else:
        # Default to high-reliability SQLite for seamless local demo without requiring running MySQL daemon
        SQLALCHEMY_DATABASE_URI = os.environ.get(
            'DATABASE_URL',
            f"sqlite:///{SQLITE_PATH}"
        )

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Upload folder for incident pictures
    UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16 MB max

    # ML Model directory
    ML_MODEL_DIR = os.path.join(BASE_DIR, 'app', 'ml', 'models')
