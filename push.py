import subprocess
import time
import os

DEVICE_ID = "finally-honeyed-dashing-jaguarundi-849"
API_TOKEN = "eyJhbGciOiJFUzI1NiIsImtpZCI6IjY1YzFhMmUzNzJjZjljMTQ1MTQyNzk5ODZhMzYyNmQ1Y2QzNTI0N2IiLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJodHRwczovL2FwaS50aWRieXQuY29tIiwiZXhwIjozMzUxNTQ1NDg1LCJpYXQiOjE3NzQ3NDU0ODUsImlzcyI6Imh0dHBzOi8vYXBpLnRpZGJ5dC5jb20iLCJzdWIiOiJSRHRLR0lCWkk4Ym9TVVd4WlFCdHEya0dDbWkyIiwic2NvcGUiOiJkZXZpY2UiLCJkZXZpY2UiOiJmaW5hbGx5LWhvbmV5ZWQtZGFzaGluZy1qYWd1YXJ1bmRpLTg0OSJ9.hyutROL_ZN9MAd3a6mdPtKFMnX2qqAZVJ4OEget1nTUs-fPq4ot5YEz3Fjx46I5m-rXeKEsBTEKG4Lac1NM36w"
STAR_FILE = "mets_mlb.star"
WEBP_FILE = "mets_mlb.webp"
INSTALLATION_ID = "metslive"

def push():
    print("Rendering...")
    result = subprocess.run(
        ["pixlet", "render", STAR_FILE, "-o", WEBP_FILE],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Render error:", result.stderr)
        return

    print("Pushing to Tidbyt...")
    result = subprocess.run(
        [
            "pixlet", "push",
            "--installation-id", INSTALLATION_ID,
            "--background",
            "--api-token", API_TOKEN,
            DEVICE_ID,
            WEBP_FILE,
        ],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Push error:", result.stderr)
    else:
        print("Pushed successfully!")

while True:
    try:
        push()
    except Exception as e:
        print("Error:", e)
    time.sleep(15)
