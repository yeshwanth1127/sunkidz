import urllib.request
import urllib.parse
import json

url = "https://api.sunkidz.org/api/v1/auth/login"
data = json.dumps({
    "email": "admin@sunkidz.com",
    "password": "password123"
}).encode("utf-8")

req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        token = result['access_token']
        print(f"LOGIN SUCCESS. Token: {token[:10]}...")
        
        # Test branches endpoint
        headers = {"Authorization": f"Bearer {token}"}
        req2 = urllib.request.Request("https://api.sunkidz.org/api/v1/admin/branches", headers=headers)
        with urllib.request.urlopen(req2) as resp2:
            print("BRANCHES HTTP", resp2.getcode(), resp2.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(f"HTTP ERROR {e.code}: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"FAILED: {e}")
