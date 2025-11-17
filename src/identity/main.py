import json 

def lambda_handler(event, context):
    return {
        "statusCode": 201,
        "body": json.dumps({
        "appName": "Gabnet",
        "senderEmail": "gabnet@gmail.com",
        "apiKey": "12345-abcde-67890-fghij",
        "status": "pending",
        "message": "Identity created. Please verify the email address."
        })
    }