import os
import json
import boto3
import hashlib
import secrets

from datetime import datetime

from bson import ObjectId

apigateway = boto3.client('apigateway')
USAGE_PLAN_ID = os.environ.get("USAGE_PLAN_ID")
ses = boto3.client('ses')


def is_email_verified(email):
    """Check if email is verified in SES using v1 API"""
    try:
        response = ses.get_identity_verification_attributes(
            Identities=[email]
        )
        
        verification_attrs = response.get('VerificationAttributes', {})
        
        if email not in verification_attrs:
            return False
            
        status = verification_attrs[email].get('VerificationStatus')
        return status == 'Success'
        
    except Exception as e:
        print(f"Error checking email verification for {email}: {str(e)}")
        return False

def hash_key(key):
    return hashlib.sha256(key.encode()).hexdigest()

def handle_post_apikey(event, collection, response):
    try:
        body = json.loads(event.get("body", "{}")) if event.get("body") else {}

        app_id = body.get("id")
        app_name = body.get("appName")

        if not app_id:
            return response(400, {
                "error": "Missing required fields: id"
            })

        try:
            app = collection.find_one({"_id": ObjectId(app_id)})
        except Exception:
            return response(400, {"error": "Invalid app ID format"})

        if not app:
            return response(404, {"error": "App not found"})

        sender_email = app.get("senderEmail")


        if not is_email_verified(sender_email):
            return response(400, {
                "error": "Email not verified",
                "message": f"Please verify {sender_email} before creating API key."
            })

        if app.get("apiGatewayKeyId"):
            try:
                existing = apigateway.get_api_key(
                    apiKey=app["apiGatewayKeyId"],
                    includeValue=True
                )
                return response(200, {
                    "message": "API key already exists",
                    "apiKey": existing["value"], 
                    "status": "active",
                    "appName": app["appName"]
                })
            except apigateway.exceptions.NotFoundException:
                pass 

        plaintext_key = secrets.token_urlsafe(32)

        api_key_res = apigateway.create_api_key(
            name=f"{app_name}-key",
            description=f"API key for {app_name}",
            enabled=True,
            value=plaintext_key
        )

        api_key_id = api_key_res["id"]

        if USAGE_PLAN_ID:
            try:
                apigateway.create_usage_plan_key(
                    usagePlanId=USAGE_PLAN_ID,
                    keyId=api_key_id,
                    keyType="API_KEY"
                )
            except apigateway.exceptions.ConflictException:
                pass  

        hashed_key = hash_key(plaintext_key)

        collection.update_one(
            {"_id": ObjectId(app_id)},
            {
                "$set": {
                    "apiGatewayKeyId": api_key_id,
                    "apiKeyHash": hashed_key,
                    "apiKeyCreatedAt": datetime.utcnow(),
                    "updatedAt": datetime.utcnow(),
                    "status": "active"
                }
            }
        )

        return response(201, {
            "message": "API key created successfully",
            "apiKey": plaintext_key,      
            "apiGatewayKeyId": api_key_id,
            "status": "active",
            "appName": app_name
        })

    except Exception as e:
        print(f"Error creating API key: {str(e)}")
        return response(500, {
            "error": "Failed to create API key",
            "details": str(e)
        })