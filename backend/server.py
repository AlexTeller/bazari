from fastapi import FastAPI, APIRouter
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional
import uuid
from datetime import datetime
import mysql.connector
from mysql.connector import Error
import json


ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MySQL connection for Qbox compatibility
def get_mysql_connection():
    try:
        connection = mysql.connector.connect(
            host=os.environ.get('MYSQL_HOST', 'localhost'),
            database=os.environ.get('MYSQL_DATABASE', 'qbox'),
            user=os.environ.get('MYSQL_USER', 'root'),
            password=os.environ.get('MYSQL_PASSWORD', ''),
            port=int(os.environ.get('MYSQL_PORT', 3306))
        )
        return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")


# Define Models
class StatusCheck(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    client_name: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class StatusCheckCreate(BaseModel):
    client_name: str

# Market Stand Models
class MarketStandLocation(BaseModel):
    x: float
    y: float
    z: float
    h: float

class MarketStand(BaseModel):
    id: Optional[int] = None
    owner_id: str
    owner_name: str
    name: str
    location: MarketStandLocation
    zone_id: Optional[int] = None
    status: str = "active"
    rent_expires: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    earnings: int = 0
    total_sales: int = 0

class MarketStandCreate(BaseModel):
    owner_id: str
    name: str
    location: MarketStandLocation
    zone_id: Optional[int] = None

class MarketStandItem(BaseModel):
    id: Optional[int] = None
    stand_id: int
    item_name: str
    display_name: str
    price: int
    stock: int
    max_stock: int = 100
    description: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class MarketStandItemCreate(BaseModel):
    stand_id: int
    item_name: str
    display_name: str
    price: int
    stock: int
    max_stock: int = 100
    description: Optional[str] = None

class MarketStandStaff(BaseModel):
    id: Optional[int] = None
    stand_id: int
    player_id: str
    player_name: str
    role: str = "seller"
    wage_per_hour: int = 50
    working_hours: dict
    hired_at: Optional[datetime] = None
    is_active: bool = True

class MarketStandTransaction(BaseModel):
    id: Optional[int] = None
    stand_id: int
    player_id: str
    player_name: str
    transaction_type: str
    item_name: Optional[str] = None
    quantity: int = 1
    amount: int
    description: Optional[str] = None
    created_at: Optional[datetime] = None

class DashboardStats(BaseModel):
    total_stands: int
    active_stands: int
    total_earnings: int
    total_transactions: int
    recent_transactions: List[MarketStandTransaction]

# Add your routes to the router instead of directly to app
@api_router.get("/")
async def root():
    return {"message": "Hello World"}

@api_router.post("/status", response_model=StatusCheck)
async def create_status_check(input: StatusCheckCreate):
    status_dict = input.dict()
    status_obj = StatusCheck(**status_dict)
    
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            # Create table if it doesn't exist
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS status_checks (
                    id VARCHAR(36) PRIMARY KEY,
                    client_name VARCHAR(255) NOT NULL,
                    timestamp DATETIME NOT NULL
                )
            """)
            
            # Insert the status check
            cursor.execute(
                "INSERT INTO status_checks (id, client_name, timestamp) VALUES (%s, %s, %s)",
                (status_obj.id, status_obj.client_name, status_obj.timestamp)
            )
            connection.commit()
        except Error as e:
            print(f"Error inserting status check: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return status_obj

@api_router.get("/status", response_model=List[StatusCheck])
async def get_status_checks():
    status_checks = []
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("SELECT * FROM status_checks ORDER BY timestamp DESC LIMIT 1000")
            results = cursor.fetchall()
            status_checks = [StatusCheck(**row) for row in results]
        except Error as e:
            print(f"Error fetching status checks: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return status_checks

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    # No longer needed for MySQL connections
    pass
