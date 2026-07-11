from flask import Flask
import socket

app = Flask(__name__)

@app.route("/")
def home():
    return f"Hello from {socket.gethostname()}! Deployed via Terraform + Docker + Jenkins CI/CD.\n"

@app.route("/health")
def health():
    return {"status": "healthy"}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
