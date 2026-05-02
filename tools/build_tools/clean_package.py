import re
import sys

def clean_package_swift(file_path):
    with open(file_path, 'r') as f:
        content = f.read()

    # 1. Remove lone comma lines, but only if they are not part of a comment
    lines = content.splitlines()
    cleaned_lines = []
    for line in lines:
        # Check if the line is just a comma (ignoring whitespace and potential comments)
        # If it's a comment, we leave it.
        if re.match(r'^\s*,\s*(//.*)?$', line):
            continue
        cleaned_lines.append(line)
    
    content = "\n".join(cleaned_lines)

    # 2. Fix `path: "...", ,`
    # We want to avoid matching across comments.
    # We'll use a regex that matches a comma, optional whitespace (NOT newlines), and another comma.
    content = re.sub(r',[ \t]*,', ',', content)

    # 3. Remove trailing commas before closing brackets/parentheses
    # We'll do this line by line to avoid issues with comments.
    lines = content.splitlines()
    cleaned_lines = []
    for i in range(len(lines)):
        line = lines[i]
        
        # Trailing comma on the same line: [a, b,] -> [a, b]
        # But only if the ] is not in a comment.
        # This is hard with regex, so we'll do a simple check.
        # If line has a comma followed by ] or ) and no // before it on that same part.
        
        # Actually, let's just handle the most common case where the comma is at the end of the line
        # and the bracket is on the next line.
        if line.rstrip().endswith(',') and i + 1 < len(lines):
            next_line = lines[i+1].strip()
            if next_line.startswith(']') or next_line.startswith(')'):
                # Check if the comma is not in a comment
                if '//' not in line or line.find('//') > line.find(','):
                    # Remove the comma
                    line = line.rstrip()[:-1]
        
        # Also handle same-line trailing comma: [a, b,]
        # We'll only do it if there's no comment or if the comma is before the comment.
        m = re.search(r',(\s*[\]\)])', line)
        if m:
            # Check if it's before a comment
            comment_idx = line.find('//')
            comma_idx = line.find(',' + m.group(1))
            if comment_idx == -1 or comma_idx < comment_idx:
                line = line[:comma_idx] + m.group(1) + line[comma_idx + len(m.group(0)):]

        cleaned_lines.append(line)
    
    content = "\n".join(cleaned_lines)

    # 4. Fix duplicate arguments in targets
    # We'll use a slightly better block detection
    def fix_target_block(match):
        block = match.group(0)
        lines = block.splitlines()
        seen_keys = set()
        new_lines = []
        for line in lines:
            # Simple key detection: starts with whitespace and then key:
            m = re.search(r'^\s*([a-zA-Z0-9]+)\s*:', line)
            if m:
                key = m.group(1)
                if key in ["path", "name"] and key in seen_keys:
                    continue
                seen_keys.add(key)
            new_lines.append(line)
        return "\n".join(new_lines)

    content = re.sub(r'\.(target|executableTarget|testTarget|library|executable)\s*\((?:[^()]*|\([^()]*\))*\)', 
                    fix_target_block, content, flags=re.DOTALL)

    with open(file_path, 'w') as f:
        f.write(content)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        clean_package_swift(sys.argv[1])
