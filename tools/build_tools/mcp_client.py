
import urllib.request
import json
import threading
from urllib.parse import urljoin

def talk_to_mcp(url):
    print(f"Connecting to {url}...")
    
    # We need a separate thread to listen to the SSE stream
    results = {}
    
    def listen(url, results):
        req = urllib.request.Request(url)
        try:
            with urllib.request.urlopen(req) as response:
                event_type = None
                while True:
                    line = response.readline()
                    if not line:
                        break
                    line = line.decode('utf-8').strip()
                    if not line:
                        continue
                    
                    if line.startswith('event:'):
                        event_type = line[6:].strip()
                    elif line.startswith('data:'):
                        data = line[5:].strip()
                        if event_type == 'endpoint':
                            results['post_url'] = data
                        elif event_type == 'message':
                            msg = json.loads(data)
                            results['last_message'] = msg
                            if 'id' in msg:
                                results[f"res_{msg['id']}"] = msg
        except Exception as e:
            results['error'] = str(e)

    listener = threading.Thread(target=listen, args=(url, results))
    listener.daemon = True
    listener.start()
    
    # Wait for post_url
    start_time = threading.Event()
    for _ in range(50):
        if 'post_url' in results:
            break
        time_to_wait = 0.1
        import time
        time.sleep(time_to_wait)
    
    if 'post_url' not in results:
        print("Failed to get POST endpoint")
        return

    post_url = results['post_url']
    if not post_url.startswith('http'):
        post_url = urljoin(url, post_url)
    print(f"POST endpoint: {post_url}")
    
    # List tools
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }
    print(f"Sending tools/list...")
    req = urllib.request.Request(
        post_url, 
        data=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )
    urllib.request.urlopen(req)
    
    # Wait for response 1
    for _ in range(50):
        if 'res_1' in results:
            break
        import time
        time.sleep(0.1)
    
    if 'res_1' in results:
        print("Tools List:")
        tools = results['res_1'].get('result', {}).get('tools', [])
        for tool in tools:
            print(f" - {tool['name']}")
    else:
        print("Timed out waiting for tools/list response")

    # Try search if port 8000
    if "8000" in url:
        payload = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "search_code",
                "arguments": {"query": "SystemPhase"}
            }
        }
        print("\nSearching for 'SystemPhase'...")
        req = urllib.request.Request(
            post_url, 
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req)
        
        for _ in range(100):
            if 'res_2' in results:
                break
            import time
            time.sleep(0.1)
        
        if 'res_2' in results:
            print("Search Result (truncated):")
            content = results['res_2'].get('result', {}).get('content', [])
            if content:
                print(content[0].get('text', '')[:500] + "...")
        else:
            print("Timed out waiting for search_code response")

if __name__ == "__main__":
    import sys
    url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000/sse"
    talk_to_mcp(url)
