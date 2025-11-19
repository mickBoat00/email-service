import os
import json
import boto3
from functools import lru_cache
from datetime import datetime

# Initialize AWS clients
apigateway = boto3.client('apigateway')
ssm = boto3.client('ssm')


usage_plan_id = os.environ.get('USAGE_PLAN_ID_PARAM')

def create_api_key(event, collection):
    """Create API key for an app (idempotent)."""
    try:
        # Parse request body
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        app_id = body.get('id')
        app_name = body.get('appName')
        
        if not app_id or not app_name:
            return response(400, {
                "error": "Missing required fields: id and appName"
            })
        
        # Find the app in MongoDB
        from bson import ObjectId
        try:
            app = collection.find_one({"_id": ObjectId(app_id)})
        except Exception:
            return response(400, {"error": "Invalid app ID format"})
        
        if not app:
            return response(404, {"error": "App not found"})
        
        if app.get('apiKey'):
            try:
                apigateway.get_api_key(
                    apiKey=app['apiKey'],
                    includeValue=True
                )
                # Key exists, return existing key
                return response(200, {
                    "message": "API key already exists",
                    "apiKey": app['apiKey'],
                    "appName": app['appName'],
                    "status": "active"
                })
            except apigateway.exceptions.NotFoundException:
                pass
        
        # Create new API key in AWS API Gateway
        api_key_response = apigateway.create_api_key(
            name=f"{app_name}-key",
            description=f"API key for {app_name}",
            enabled=True
        )
        
        api_key_value = api_key_response['value']
        api_key_id = api_key_response['id']
        
        if usage_plan_id:
            try:
                apigateway.create_usage_plan_key(
                    usagePlanId=usage_plan_id,
                    keyId=api_key_id,
                    keyType='API_KEY'
                )
            except apigateway.exceptions.ConflictException:
                pass
        
        collection.update_one(
            {"_id": ObjectId(app_id)},
            {
                "$set": {
                    "apiKey": api_key_value,
                    "apiKeyCreatedAt": datetime.utcnow(),
                    "updatedAt": datetime.utcnow()
                }
            }
        )
        
        return response(201, {
            "message": "API key created successfully",
            "apiKey": api_key_value,
            "apiGatewayKeyId": api_key_id,
            "appName": app_name,
            "status": "active"
        })

    except Exception as e:
        print(f"Error creating API key: {str(e)}")
        return response(500, {
            "error": "Failed to create API key",
            "details": str(e)
        })


def get_api_keys(event, collection):
    """Retrieve all apps with their API key status."""
    try:
        # Get all apps from collection
        apps = list(collection.find({}))
        formatted_apps = [format_app_response(app) for app in apps]
        
        return response(200, {
            "apps": formatted_apps,
            "total": len(formatted_apps)
        })
    
    except Exception as e:
        print(f"Error retrieving API keys: {str(e)}")
        return response(500, {
            "error": "Failed to retrieve API keys",
            "details": str(e)
        })


def delete_api_key(event, collection):
    """Delete API key for an app."""
    try:
        # Parse request body or query params
        app_id = None
        
        # Try query parameters first
        query_params = event.get('queryStringParameters', {}) or {}
        app_id = query_params.get('id')
        
        # Try body if not in query params
        if not app_id and event.get('body'):
            if isinstance(event.get('body'), str):
                body = json.loads(event['body'])
            else:
                body = event.get('body', {})
            app_id = body.get('id')
        
        if not app_id:
            return response(400, {
                "error": "Missing required field: id"
            })
        
        # Find the app
        from bson import ObjectId
        try:
            app = collection.find_one({"_id": ObjectId(app_id)})
        except Exception:
            return response(400, {"error": "Invalid app ID format"})
        
        if not app:
            return response(404, {"error": "App not found"})
        
        # Check if app has an API key
        if not app.get('apiGatewayKeyId'):
            return response(404, {
                "error": "No API key found for this app"
            })
        
        api_key_id = app['apiGatewayKeyId']
        
        try:
            apigateway.delete_api_key(apiKey=api_key_id)
        except Exception as e:
            print(f"Error deleting from API Gateway: {str(e)}")
        collection.update_one(
            {"_id": ObjectId(app_id)},
            {
                "$set": {
                    "apiKey": None,
                    "apiGatewayKeyId": None,
                    "apiKeyCreatedAt": None,
                    "updatedAt": datetime.utcnow()
                }
            }
        )
        
        return response(200, {
            "message": "API key deleted successfully",
            "appId": app_id,
            "appName": app.get('appName')
        })
    
    except Exception as e:
        print(f"Error deleting API key: {str(e)}")
        return response(500, {
            "error": "Failed to delete API key",
            "details": str(e)
        })


def format_app_response(app):
    """Format app document for API response."""
    formatted = {
        "id": str(app["_id"]),
        "appName": app.get("appName"),
        "senderEmail": app.get("senderEmail"),
        "status": app.get("status"),
        "createdAt": app.get("createdAt").isoformat() if app.get("createdAt") else None,
        "updatedAt": app.get("updatedAt").isoformat() if app.get("updatedAt") else None,
    }
    
    if app.get('apiKey'):
        formatted["apiKey"] = {
            "value": app["apiKey"],
            "gatewayKeyId": app.get("apiGatewayKeyId"),
            "createdAt": app.get("apiKeyCreatedAt").isoformat() if app.get("apiKeyCreatedAt") else None,
            "status": "active"
        }
    else:
        formatted["apiKey"] = None
    
    return formatted


def response(status_code, body):
    """Helper function to format API response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
        "body": json.dumps(body, default=str)
    }