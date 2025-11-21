import os
import json
from pymongo import MongoClient
from apps import handle_get_apps, handle_post_apps, handle_delete_app

client = MongoClient(host=os.environ["MONGODB_URI"])
db = client.get_database()
collection = db.get_collection("apps")

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body, default=str)
    }

def handle_apps(event):
    """Handle CRUD operations for Apps keys."""
    method = event["httpMethod"].upper()

    if method == "GET":
        return handle_get_apps(collection, response)
    elif method == "POST":
        return handle_post_apps(event, collection, response)
    elif method == "DELETE":
        return handle_delete_app(event, collection, response)
    else:
        return response(405, {"error": "Method not allowed"})

def lambda_handler(event, context):
    try:
        path = event.get("path", "")

        if path.startswith("/apps"):
            return handle_apps(event)
        else:
            return response(404, {"error": "Route not found"})

    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {"error": "Internal server error", "details": str(e)})