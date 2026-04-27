import sys
import time
import subprocess
import json

uuid = "o3nbpa6qofsrdm4ddhbxww82"
url = f"http://146.196.64.92:8000/api/v1/deployments/{uuid}"
headers = ["-H", "Authorization: Bearer 8|Dx6SQrOixfL38vmffaQB6Qnqp0myh78F7GKJ7AH928b75859"]

max_retries = 15  # 15 * 25s = 375s (~6 mins)
for i in range(max_retries):
    result = subprocess.run(["curl", "-s"] + headers + [url], capture_output=True, text=True)
    try:
        data = json.loads(result.stdout)
        status = data.get("deployment", {}).get("status")
        print(f"Status: {status}")
        if status in ["finished", "failed"]:
            sys.exit(0 if status == "finished" else 1)
    except Exception as e:
        print(f"Error parsing JSON: {e}")
    
    if i < max_retries - 1:
        time.sleep(25)

sys.exit(1)
