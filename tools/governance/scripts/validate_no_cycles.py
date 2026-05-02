import json
import sys

def build_graph(data):
    graph = {}
    for target in data.get('targets', []):
        name = target['name']
        dependencies = [d.get('name') for d in target.get('dependencies', []) if 'name' in d]
        graph[name] = dependencies
    return graph

def find_cycles(graph):
    def dfs(node, path, visited):
        visited.add(node)
        path.append(node)
        for neighbor in graph.get(node, []):
            if neighbor in path:
                return path[path.index(neighbor):] + [neighbor]
            if neighbor not in visited:
                cycle = dfs(neighbor, path, visited)
                if cycle: return cycle
        path.pop()
        return None

    visited = set()
    for node in graph:
        if node not in visited:
            cycle = dfs(node, [], visited)
            if cycle: return cycle
    return None

def validate(json_path):
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    graph = build_graph(data)
    cycle = find_cycles(graph)
    
    if cycle:
        print(f"Cycle detected: {' -> '.join(cycle)}")
        sys.exit(1)
    else:
        print("No dependency cycles detected.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 validate_no_cycles.py <path_to_json>")
        sys.exit(1)
    validate(sys.argv[1])
