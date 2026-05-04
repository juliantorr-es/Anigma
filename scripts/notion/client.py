import os
import requests
import json

TOKEN = os.environ.get("NOTION_TOKEN")
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Notion-Version": "2022-06-28"
}
BASE_URL = "https://api.notion.com/v1"

def notion_request(endpoint, method="GET", body=None):
    print(f"DEBUG: Request {method} {endpoint} body={json.dumps(body)}")
    url = f"{BASE_URL}/{endpoint}"
    response = requests.request(method, url, headers=HEADERS, json=body)
    response.raise_for_status()
    return response.json()

def query_database(database_id, filter_query):
    return notion_request(f"databases/{database_id}/query", "POST", {"filter": filter_query})

def create_page(parent_id, properties, parent_type="database_id"):
    return notion_request("pages", "POST", {"parent": {parent_type: parent_id}, "properties": properties})

def update_page(page_id, properties):
    return notion_request(f"pages/{page_id}", "PATCH", {"properties": properties})

def create_database(parent_page_id, title, properties):
    return notion_request("databases", "POST", {
        "parent": {"page_id": parent_page_id},
        "title": [{"type": "text", "text": {"content": title}}],
        "properties": properties
    })

def update_database(database_id, properties):
    return notion_request(f"databases/{database_id}", "PATCH", {"properties": properties})

def append_block_children(block_id, children):
    return notion_request(f"blocks/{block_id}/children", "PATCH", {"children": children})

def get_database(database_id):
    return notion_request(f"databases/{database_id}", "GET")

def search_pages(query):
    return notion_request("search", "POST", {"filter": {"property": "object", "value": "page"}, "query": query})

def retrieve_page(page_id):
    return notion_request(f"pages/{page_id}", "GET")

def get_block(block_id):
    return notion_request(f"blocks/{block_id}", "GET")
