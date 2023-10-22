import os
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pymongo import MongoClient

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

DB_HOST = os.environ.get('DB_HOST')
DB_PORT = os.environ.get('DB_PORT', '27017')
DB_USER = os.environ.get('DB_USER')
DB_PASS = os.environ.get('DB_PASS')
DB_NAME = os.environ.get('DB_NAME')
DB_PROTO = os.environ.get('DB_PROTO', 'mongodb')

MONGO_URI = f"{DB_PROTO}://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}?authSource=admin"

client = MongoClient(MONGO_URI)
db = client[DB_NAME] 
collection = db.hits_collection 

@app.get('/', response_class=HTMLResponse)
async def hello(request: Request):
    # If the counter does not exist, we initialize it with a value of 0
    counter_data = collection.find_one({"_id": "page_counter"})
    if not counter_data:
        collection.insert_one({"_id": "page_counter", "count": 0})
        counter = 0
    else:
        counter = counter_data["count"]
    
    # Increment the counter
    collection.update_one({"_id": "page_counter"}, {"$inc": {"count": 1}})
    counter += 1
    
    return templates.TemplateResponse("index.html", {"request": request, "counter": counter})