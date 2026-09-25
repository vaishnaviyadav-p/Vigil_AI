import os
from app import create_app

app = create_app()

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    print(f"============================================================")
    print(f" VIGIL AI Central Backend Server Starting")
    print(f" REST API: http://127.0.0.1:{port}/api")
    print(f" Admin Monitoring Console: http://127.0.0.1:{port}/admin")
    print(f"============================================================")
    app.run(host=host, port=port, debug=False)
