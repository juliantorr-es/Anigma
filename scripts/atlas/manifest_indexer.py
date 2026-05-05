import re

def index(path, text):
    targets = []
    products = []
    if path.endswith("Package.swift"):
        for name in re.findall(r'\.(?:executableTarget|target|testTarget)\((?:.|\n)*?name:\s*"([^"]+)"', text):
            targets.append(name)
        for name in re.findall(r'\.(?:library|executable)\((?:.|\n)*?name:\s*"([^"]+)"', text):
            products.append(name)
    return {"targets": sorted(set(targets)), "products": sorted(set(products))}
