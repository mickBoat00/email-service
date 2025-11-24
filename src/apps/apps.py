
import json
from datetime import datetime
from bson import ObjectId
import boto3    

ses = boto3.client('ses')


def handle_get_apps(collection, response):
    """Retrieve all registered apps with full details and masked API keys."""
    try:
        apps = list(collection.find({}))
        formatted_apps = []
        
        for app in apps:
            formatted = {
                "id": str(app["_id"]),
                "appName": app.get("appName"),
                "senderEmail": app.get("senderEmail"),
                "status": app.get("status"),
                "createdAt": app.get("createdAt").isoformat() if app.get("createdAt") else None,
                "updatedAt": app.get("updatedAt").isoformat() if app.get("updatedAt") else None,
            }
            
            if app.get('apiKeyHash'):
                formatted["apiKey"] = {
                    "value": "*****",
                    "gatewayKeyId": app.get("apiGatewayKeyId"),
                    "createdAt": app.get("apiKeyCreatedAt").isoformat() if app.get("apiKeyCreatedAt") else None,
                    "status": "active"
                }
            else:
                formatted["apiKey"] = None
            
            formatted_apps.append(formatted)
        
        return response(200, {
            "apps": formatted_apps,
            "total": len(formatted_apps)
        })
    except Exception as e:
        print(f"Error retrieving apps: {str(e)}")
        return response(500, {
            "error": "Failed to retrieve apps",
            "details": str(e)
        })


def handle_post_apps(event, collection, response):
    """Register a new app (does not create API key yet)."""

    body = json.loads(event.get("body", "{}")) if event.get("body") else {}

    app_name = body.get("appName")
    sender_email = body.get("senderEmail")

    if not app_name or not sender_email:
        return response(400, {"error": "Missing required fields: appName and senderEmail"})

    # Check for existing app name
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
            "message": f"{sender_email} is already linked to an existing app."
        })


    response_verify = ses.verify_email_identity(EmailAddress=sender_email)
    print(f"SES verify email response: {response_verify}")
    
    # Create registration record
    document = {
        "appName": app_name,
        "senderEmail": sender_email,
        "apiKeyHash": None,
        "apiGatewayKeyId": None,
        "status": "pending_verification",
        "message": "Please verify your sender email to activate the app.",
        "createdAt": datetime.utcnow()
    }

    result = collection.insert_one(document)

    return response(201, {
        "id": str(result.inserted_id),
        "appName": app_name,
        "senderEmail": sender_email,
        "status": document["status"],
        "message": document["message"]
    })
        


def handle_delete_app(event, collection, response):
    try:
        app_id = None
        
        query_params = event.get('queryStringParameters', {}) or {}
        app_id = query_params.get('id')
        
        if not app_id:
            return response(400, {"error": "Missing required field: id"})
 
        try:
            app = collection.find_one({"_id": ObjectId(app_id)})
        except Exception:
            return response(400, {"error": "Invalid app ID format"})
        
        if not app:
            return response(404, {"error": "App not found"})
        
        ses.delete_identity(Identity=app.get('senderEmail'))
        
        collection.delete_one({"_id": ObjectId(app_id)})

        
        return response(200, {
            "message": "App deleted successfully",
            "appId": app_id,
            "appName": app.get('appName')
        })
    
    except Exception as e:
        print(f"Error deleting app: {str(e)}")
        return response(500, {
            "error": "Failed to delete app",
            "details": str(e)
        })