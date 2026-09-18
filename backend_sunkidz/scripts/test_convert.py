import urllib.request
import urllib.parse
import json

url_login = "https://api.sunkidz.org/api/v1/auth/login"
data_login = json.dumps({
    "email": "admin@sunkidz.com",
    "password": "password123"
}).encode("utf-8")

req = urllib.request.Request(url_login, data=data_login, headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req) as response:
    token = json.loads(response.read().decode('utf-8'))['access_token']

headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

# 1. Get an enquiry
req_enq = urllib.request.Request("https://api.sunkidz.org/api/v1/admin/enquiries", headers=headers)
with urllib.request.urlopen(req_enq) as resp:
    enquiries = json.loads(resp.read().decode('utf-8'))

if not enquiries:
    print("No enquiries found.")
    exit(0)

# get a pending enquiry
enq = next((e for e in enquiries if e.get('status') != 'converted' and e.get('status') != 'rejected'), None)
if not enq:
    print("No pending enquiry.")
    exit(0)
    
print("Attempting to convert enquiry:", enq['id'])
    
# 2. Convert to admission
payload = {
    "enquiry_id": enq["id"],
    "branch_id": enq.get("branch_id") or "ba69969a-5184-48fb-ab2f-ab8e0275891e",
    "class_id": "6cc83223-3bf7-4291-9981-3c37017ff4ac", 
    "name": enq.get("child_name") or "Test Child",
    "date_of_birth": enq.get("date_of_birth") or "2020-01-01",
    "parent_name": enq.get("father_name") or "Test Parent",
    "parent_contact": enq.get("father_contact_no") or "1111111111"
}

req_conv = urllib.request.Request("https://api.sunkidz.org/api/v1/admin/admissions/from-enquiry", 
                                  data=json.dumps(payload).encode("utf-8"), 
                                  headers=headers)
try:
    with urllib.request.urlopen(req_conv) as resp_conv:
        result = json.loads(resp_conv.read().decode('utf-8'))
        print("CONVERSION SUCCESS:", result)
except urllib.error.HTTPError as e:
    print(f"HTTP ERROR {e.code}: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"ERROR: {e}")
