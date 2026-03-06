import os
import logging
import boto3
from datetime import datetime, date
from decimal import Decimal
from botocore.exceptions import ClientError
from pymongo import MongoClient
from bson import ObjectId
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("clipsense.db")

class Database:
    def __init__(self):
        # Determine if we should use DynamoDB (AWS) or MongoDB (Local)
        # In a real AWS environment, AWS_REGION is almost always set.
        self.use_aws = os.getenv("AWS_REGION") is not None
        
        # Initialize both if possible to allow live fallbacks
        self._init_dynamodb()
        self._init_mongodb()

    def _init_mongodb(self):
        mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
        db_name = os.getenv("MONGO_DB", "clipsense")
        try:
            self.client = MongoClient(mongo_uri)
            self.db = self.client[db_name]
            self.client.admin.command('ping')
            logger.info("MongoDB connected successfully to %s", mongo_uri)
            self.users = self.db.users
            self.projects = self.db.projects
        except Exception as e:
            logger.error("Failed to connect to MongoDB: %s", e)
            self.db = None

    def _init_dynamodb(self):
        try:
            region = os.getenv("AWS_REGION", "ap-south-1")
            self.dynamodb = boto3.resource('dynamodb', region_name=region)
            self.users_table = self.dynamodb.Table(os.getenv("DYNAMO_USERS_TABLE", "ClipSenseUsers"))
            self.projects_table = self.dynamodb.Table(os.getenv("DYNAMO_PROJECTS_TABLE", "ClipSenseProjects"))
            logger.info("DynamoDB initialized successfully")
        except Exception as e:
            logger.error("Failed to initialize DynamoDB: %s", e)
            self.dynamodb = None

    def _decimal_serialize(self, obj):
        """Recursively convert float to Decimal for DynamoDB."""
        if isinstance(obj, list):
            return [self._decimal_serialize(i) for i in obj]
        elif isinstance(obj, dict):
            return {k: self._decimal_serialize(v) for k, v in obj.items()}
        elif isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, (datetime, date)):
            return obj.isoformat()
        return obj

    def is_connected(self):
        if self.use_aws:
            return self.dynamodb is not None
        return self.db is not None

    # --- User Operations ---
    def get_user_by_email(self, email):
        if self.use_aws and self.dynamodb:
            try:
                response = self.users_table.get_item(Key={'email': email})
                return response.get('Item')
            except Exception as e:
                logger.error("DynamoDB get_user primary failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
             return self.users.find_one({"email": email})
        return None

    def get_user_by_username(self, username):
        if self.use_aws:
            # Note: In a production app with unique usernames, you'd use a GSI
            response = self.users_table.scan(
                FilterExpression=boto3.dynamodb.conditions.Attr('username').eq(username)
            )
            items = response.get('Items', [])
            return items[0] if items else None
        return self.users.find_one({"username": username})

    def get_user_by_identifier(self, identifier):
        """Find user by email or username."""
        if self.use_aws:
            user = self.get_user_by_email(identifier)
            if not user:
                user = self.get_user_by_username(identifier)
            return user
        return self.users.find_one({
            "$or": [
                {"email": identifier},
                {"username": identifier}
            ]
        })

    def create_user(self, user_data):
        """
        user_data should include: email, password (hashed), isVerified, otpCode, etc.
        """
        if self.use_aws and self.dynamodb:
            try:
                # DynamoDB support: handle Decimals and Strings
                final_data = self._decimal_serialize(user_data)
                self.users_table.put_item(Item=final_data)
                return user_data['email'] 
            except ClientError as e:
                logger.error("DynamoDB create_user Error: %s", e)
                return None
        
        if self.db is not None:
            result = self.users.insert_one(user_data)
            return str(result.inserted_id)
        return None

    def update_user(self, email, update_data):
        if self.use_aws and self.dynamodb:
            try:
                # Filter out None values and prepare DynamoDB update
                update_items = {k: v for k, v in update_data.items() if v is not None}
                if not update_items:
                    return
                
                final_update = self._decimal_serialize(update_items)
                
                update_expression = "set " + ", ".join([f"#{k} = :{k}" for k in final_update.keys()])
                expression_values = {f":{k}": v for k, v in final_update.items()}
                expression_names = {f"#{k}": k for k in final_update.keys()}
                
                self.users_table.update_item(
                    Key={'email': email},
                    UpdateExpression=update_expression,
                    ExpressionAttributeValues=expression_values,
                    ExpressionAttributeNames=expression_names
                )
            except ClientError as e:
                logger.error("DynamoDB update_user Error: %s", e)
        else:
            self.users.update_one({"email": email}, {"$set": update_data})

    def verify_user(self, email):
        if self.use_aws:
            self.update_user(email, {"isVerified": True, "otpCode": None})
        else:
            self.users.update_one({"email": email}, {"$set": {"isVerified": True, "otpCode": None}})

    def list_all_users_with_stats(self):
        """Return all non-admin users with their project and clip counts."""
        if self.use_aws:
            response = self.users_table.scan(
                FilterExpression=boto3.dynamodb.conditions.Attr('role').ne('admin')
            )
            users = response.get('Items', [])
        else:
            users = list(self.users.find({"role": {"$ne": "admin"}}))
            
        results = []
        for u in users:
            stats = self.get_user_stats(u["email"])
            results.append({
                "email": u["email"],
                "username": u.get("username"),
                "createdAt": u.get("createdAt"),
                "projectCount": stats["projectCount"],
                "clipCount": stats["clipCount"],
                "avgEngagement": self.get_user_avg_engagement(u["email"])
            })
        return results

    def get_user_avg_engagement(self, user_id):
        """Calculate average engagement score across all projects for a user."""
        projects = self.list_projects(user_id)
        valid_scores = [p.get("avgEngagement", 0) for p in projects if p.get("status") == "done"]
        if not valid_scores:
            return 0
        return round(sum(valid_scores) / len(valid_scores), 1)

    # --- Project Operations ---
    def create_project(self, project_data):
        if self.use_aws and self.dynamodb:
            try:
                final_data = self._decimal_serialize(project_data)
                self.projects_table.put_item(Item=final_data)
                return
            except Exception as e:
                logger.error("DynamoDB create_project failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
             self.projects.insert_one(project_data)

    def get_project(self, project_id, user_id=None):
        if self.use_aws and self.dynamodb:
            try:
                response = self.projects_table.get_item(Key={'projectId': project_id})
                project = response.get('Item')
                if project and user_id and project.get('userId') != user_id:
                    return None
                return project
            except Exception as e:
                logger.error("DynamoDB get_project failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
            query = {"projectId": project_id}
            if user_id:
                query["userId"] = user_id
            return self.projects.find_one(query)
        return None

    def list_projects(self, user_id):
        if self.use_aws and self.dynamodb:
            try:
                response = self.projects_table.scan(
                    FilterExpression=boto3.dynamodb.conditions.Attr('userId').eq(user_id)
                )
                return sorted(response.get('Items', []), key=lambda x: x['createdAt'], reverse=True)
            except Exception as e:
                logger.error("DynamoDB list_projects failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
            return list(self.projects.find({"userId": user_id}).sort("createdAt", -1))
        return []

    def update_project(self, project_id, update_data):
        if self.use_aws and self.dynamodb:
            try:
                update_items = {k: v for k, v in update_data.items() if v is not None}
                if update_items:
                    final_update = self._decimal_serialize(update_items)
                    
                    update_expression = "set " + ", ".join([f"#{k} = :{k}" for k in final_update.keys()])
                    expression_values = {f":{k}": v for k, v in final_update.items()}
                    expression_names = {f"#{k}": k for k in final_update.keys()}
                    
                    self.projects_table.update_item(
                        Key={'projectId': project_id},
                        UpdateExpression=update_expression,
                        ExpressionAttributeValues=expression_values,
                        ExpressionAttributeNames=expression_names
                    )
                    return
            except Exception as e:
                logger.error("DynamoDB update_project failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
            self.projects.update_one({"projectId": project_id}, {"$set": update_data})

    def delete_project(self, project_id, user_id):
        if self.use_aws:
            try:
                # In DynamoDB we need to verify ownership first since delete_item is keyed only by projectId
                project = self.get_project(project_id, user_id)
                if project:
                    self.projects_table.delete_item(Key={'projectId': project_id})
                    return True
                return False
            except ClientError as e:
                logger.error("DynamoDB delete_project Error: %s", e)
                return False
        return self.projects.delete_one({"projectId": project_id, "userId": user_id})

    def list_all_projects_admin(self):
        """List all projects on the platform for admin oversight."""
        if self.use_aws and self.dynamodb:
            try:
                response = self.projects_table.scan()
                return sorted(response.get('Items', []), key=lambda x: x['createdAt'], reverse=True)
            except Exception as e:
                logger.error("DynamoDB admin list failed: %s. Trying MongoDB.", e)
        
        if self.db is not None:
            return list(self.projects.find().sort("createdAt", -1))
        return []

    def get_user_stats(self, user_id):
        """Return project count and total clip count for a user."""
        projects = self.list_projects(user_id)
        total_clips = sum(len(p.get("clips", [])) for p in projects)
        return {"projectCount": len(projects), "clipCount": total_clips}

    def delete_user(self, email):
        """Delete user account and all associated projects."""
        if self.use_aws:
            try:
                # Delete all projects first
                projects = self.list_projects(email)
                for p in projects:
                    self.delete_project(p['projectId'], email)
                # Delete user
                self.users_table.delete_item(Key={'email': email})
            except ClientError as e:
                logger.error("DynamoDB delete_user Error: %s", e)
        else:
            self.projects.delete_many({"userId": email})
            self.users.delete_one({"email": email})

# Global instance
db = Database()
