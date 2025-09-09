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

# Market Stand API Endpoints

@api_router.get("/market-stands", response_model=List[MarketStand])
async def get_market_stands():
    """Get all market stands"""
    stands = []
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT id, owner_id, owner_name, name, location, zone_id, status, 
                       rent_expires, created_at, updated_at, earnings, total_sales 
                FROM market_stands 
                ORDER BY created_at DESC
            """)
            results = cursor.fetchall()
            
            for row in results:
                if row['location']:
                    location_data = json.loads(row['location'])
                    row['location'] = MarketStandLocation(**location_data)
                stands.append(MarketStand(**row))
                
        except Error as e:
            print(f"Error fetching market stands: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return stands

@api_router.get("/market-stands/{stand_id}", response_model=MarketStand)
async def get_market_stand(stand_id: int):
    """Get a specific market stand"""
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT id, owner_id, owner_name, name, location, zone_id, status, 
                       rent_expires, created_at, updated_at, earnings, total_sales 
                FROM market_stands 
                WHERE id = %s
            """, (stand_id,))
            result = cursor.fetchone()
            
            if result:
                if result['location']:
                    location_data = json.loads(result['location'])
                    result['location'] = MarketStandLocation(**location_data)
                return MarketStand(**result)
                
        except Error as e:
            print(f"Error fetching market stand: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return None

@api_router.get("/market-stands/{stand_id}/items", response_model=List[MarketStandItem])
async def get_stand_items(stand_id: int):
    """Get items for a specific market stand"""
    items = []
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT id, stand_id, item_name, display_name, price, stock, max_stock, 
                       description, created_at, updated_at 
                FROM market_stand_items 
                WHERE stand_id = %s
                ORDER BY created_at DESC
            """, (stand_id,))
            results = cursor.fetchall()
            items = [MarketStandItem(**row) for row in results]
                
        except Error as e:
            print(f"Error fetching stand items: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return items

@api_router.get("/market-stands/{stand_id}/staff", response_model=List[MarketStandStaff])
async def get_stand_staff(stand_id: int):
    """Get staff for a specific market stand"""
    staff = []
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT id, stand_id, player_id, player_name, role, wage_per_hour, 
                       working_hours, hired_at, is_active 
                FROM market_stand_staff 
                WHERE stand_id = %s AND is_active = 1
                ORDER BY hired_at DESC
            """, (stand_id,))
            results = cursor.fetchall()
            
            for row in results:
                if row['working_hours']:
                    row['working_hours'] = json.loads(row['working_hours'])
                staff.append(MarketStandStaff(**row))
                
        except Error as e:
            print(f"Error fetching stand staff: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return staff

@api_router.get("/market-stands/{stand_id}/transactions", response_model=List[MarketStandTransaction])
async def get_stand_transactions(stand_id: int, limit: int = 50):
    """Get transactions for a specific market stand"""
    transactions = []
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            cursor.execute("""
                SELECT id, stand_id, player_id, player_name, transaction_type, 
                       item_name, quantity, amount, description, created_at 
                FROM market_stand_transactions 
                WHERE stand_id = %s
                ORDER BY created_at DESC 
                LIMIT %s
            """, (stand_id, limit))
            results = cursor.fetchall()
            transactions = [MarketStandTransaction(**row) for row in results]
                
        except Error as e:
            print(f"Error fetching stand transactions: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return transactions

@api_router.get("/dashboard/stats", response_model=DashboardStats)
async def get_dashboard_stats():
    """Get dashboard statistics"""
    stats = DashboardStats(
        total_stands=0,
        active_stands=0,
        total_earnings=0,
        total_transactions=0,
        recent_transactions=[]
    )
    
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor(dictionary=True)
            
            # Get stand counts
            cursor.execute("SELECT COUNT(*) as total FROM market_stands")
            result = cursor.fetchone()
            stats.total_stands = result['total'] if result else 0
            
            cursor.execute("SELECT COUNT(*) as active FROM market_stands WHERE status = 'active'")
            result = cursor.fetchone()
            stats.active_stands = result['active'] if result else 0
            
            # Get total earnings
            cursor.execute("SELECT SUM(earnings) as total_earnings FROM market_stands")
            result = cursor.fetchone()
            stats.total_earnings = result['total_earnings'] if result and result['total_earnings'] else 0
            
            # Get transaction count
            cursor.execute("SELECT COUNT(*) as total FROM market_stand_transactions")
            result = cursor.fetchone()
            stats.total_transactions = result['total'] if result else 0
            
            # Get recent transactions
            cursor.execute("""
                SELECT id, stand_id, player_id, player_name, transaction_type, 
                       item_name, quantity, amount, description, created_at 
                FROM market_stand_transactions 
                ORDER BY created_at DESC 
                LIMIT 10
            """)
            results = cursor.fetchall()
            stats.recent_transactions = [MarketStandTransaction(**row) for row in results]
                
        except Error as e:
            print(f"Error fetching dashboard stats: {e}")
        finally:
            cursor.close()
            connection.close()
    
    return stats

@api_router.delete("/market-stands/{stand_id}")
async def delete_market_stand(stand_id: int):
    """Delete a market stand (Admin only)"""
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("DELETE FROM market_stands WHERE id = %s", (stand_id,))
            connection.commit()
            
            if cursor.rowcount > 0:
                return {"message": "Market stand deleted successfully"}
            else:
                return {"error": "Market stand not found"}
                
        except Error as e:
            print(f"Error deleting market stand: {e}")
            return {"error": "Failed to delete market stand"}
        finally:
            cursor.close()
            connection.close()
    
    return {"error": "Database connection failed"}

@api_router.put("/market-stands/{stand_id}/status")
async def update_stand_status(stand_id: int, status: str):
    """Update market stand status (Admin only)"""
    valid_statuses = ['active', 'inactive', 'expired', 'suspended']
    if status not in valid_statuses:
        return {"error": "Invalid status"}
    
    connection = get_mysql_connection()
    if connection:
        try:
            cursor = connection.cursor()
            cursor.execute("""
                UPDATE market_stands 
                SET status = %s, updated_at = NOW() 
                WHERE id = %s
            """, (status, stand_id))
            connection.commit()
            
            if cursor.rowcount > 0:
                return {"message": f"Market stand status updated to {status}"}
            else:
                return {"error": "Market stand not found"}
                
        except Error as e:
            print(f"Error updating stand status: {e}")
            return {"error": "Failed to update stand status"}
        finally:
            cursor.close()
            connection.close()
    
    return {"error": "Database connection failed"}

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
