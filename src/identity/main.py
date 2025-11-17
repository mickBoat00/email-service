import os
import json
import uuid
from datetime import datetime

from pymongo import MongoClient

client = MongoClient(host=os.environ["MONGODB_URI"])
db = client.get_database()
collection = db.get_collection("lambda")

def lambda_handler(event, context):
    try:
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body', {})
        
        app_name = body.get('appName')
        sender_email = body.get('senderEmail')
        
        if not app_name or not sender_email:
            return {
                "statusCode": 400,
                "body": json.dumps({
                    "error": "Missing required fields: appName and senderEmail"
                })
            }
        

        existing_email = collection.find_one({"senderEmail": sender_email})
        
        if existing_email:
            return {
                "statusCode": 409,
                "headers": {
                    "Content-Type": "application/json"
                },
                "body": json.dumps({
                    "error": "Email already exists",
                    "message": "This senderEmail is already registered"
                })
            }
        
        api_key = str(uuid.uuid4())
        
        document = {
            "appName": app_name,
            "senderEmail": sender_email,
            "apiKey": api_key,
            "status": "pending",
            "message": "Identity created. Please verify the email address.",
            "createdAt": datetime.utcnow()
        }
        
        result = collection.insert_one(document)
        
        response_body = {
            "appName": document["appName"],
            "senderEmail": document["senderEmail"],
            "apiKey": document["apiKey"],
            "status": document["status"],
            "message": document["message"]
        }
        
        return {
            "statusCode": 201,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps(response_body)
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Internal server error",
                "details": str(e)
            })
        }