import os
import json
from datetime import datetime
from pymongo import MongoClient

client = MongoClient(host=os.environ["MONGODB_URI"])
db = client.get_database()
collection = db.get_collection("apps")

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }

def handle_register(body):
    """Register a new app (does not create API key yet)."""
    app_name = body.get("appName")
    sender_email = body.get("senderEmail")

    if not app_name or not sender_email:
        return response(400, {"error": "Missing required fields: appName and senderEmail"})

    existing_app = collection.find_one({"appName": app_name})
    if existing_app:
        return response(409, {
            "error": "App name already exists",
            "message": f"The app '{app_name}' is already registered."
        })

    # Check for existing email
    existing_email = collection.find_one({"senderEmail": sender_email})
    if existing_email:
        return response(409, {
            "error": "Email already registered",
            "message": f"The senderEmail '{sender_email}' is already associated with another app."
        })
# Check for existing email
    existing = collection.find_one({"senderEmail": sender_email})
    if existing:
        return response(409, {
            "error": "Email already registered",
            "message": f"{sender_email} is already linked to an existing app."
        })
    # Create registration record
    document = {
        "appName": app_name,
        "senderEmail": sender_email,
        "apiKey": None,  # API key not yet created
        "status": "pending_verification",
        "message": "Please verify your sender email to activate the app.",
        "createdAt": datetime.utcnow()
    }

    collection.insert_one(document)

    return response(201, {
        "appName": app_name,
        "senderEmail": sender_email,
        "status": document["status"],
        "message": document["message"]
    })

def handle_apikey(event):
    """Placeholder for CRUD operations for API keys."""
    method = event["httpMethod"].upper()

    if method == "POST":
        return response(200, {"message": "API key creation endpoint placeholder"})
    elif method == "GET":
        return response(200, {"message": "API key list endpoint placeholder"})
    elif method == "DELETE":
        return response(200, {"message": "API key deletion endpoint placeholder"})
    else:
        return response(405, {"error": f"Unsupported method {method}"})

def handle_get_apps():
    """Retrieve all registered apps."""
    apps = list(collection.find({}, {"_id": 1, "appName": 1}))
    formatted = [{"id": str(app["_id"]), "appName": app["appName"]} for app in apps]
    return response(200, {"apps": formatted})

def lambda_handler(event, context):
    try:
        path = event.get("path", "")
        method = event.get("httpMethod", "GET").upper()
        body = json.loads(event.get("body", "{}")) if event.get("body") else {}

        if path.endswith("/register") and method == "POST":
            return handle_register(body)
        elif path.endswith("/apps") and method == "GET":
            return handle_get_apps()
        elif path.startswith("/apikey"):
            return handle_apikey(event)
        else:
            return response(404, {"error": "Route not found"})

    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal server error", "details": str(e)})
