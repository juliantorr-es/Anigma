import sys
import re

def migrate(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    # 1. Replace XCTest import
    content = content.replace("import XCTest", "import Testing")
    
    # 2. Replace test class boilerplate (simplified)
    content = re.sub(r"final class \w+: XCTestCase \{", "struct MigrationSuite {", content)
    
    # 3. Replace test methods
    content = re.sub(r"func test(\w+)\(\) throws", r"@Test func \1() throws", content)
    
    # 4. Replace assertions (partial)
    content = content.replace("XCTAssertEqual", "#expect")
    content = content.replace("XCTAssertTrue", "#expect")
    content = content.replace("XCTAssertFalse", "#expect")
    
    with open(file_path, 'w') as f:
        f.write(content)

if __name__ == "__main__":
    migrate(sys.argv[1])
