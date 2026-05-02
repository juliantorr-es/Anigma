import Foundation

/// Internal editor state management for multi-line text input
internal struct MultiLineEditor {
    var lines: [String] = [""]
    var cursorRow: Int = 0
    var cursorCol: Int = 0
    
    var text: String {
        get { lines.joined(separator: "\n") }
        set {
            lines = newValue.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.isEmpty { lines = [""] }
            moveToEnd()
        }
    }
    
    mutating func insert(_ character: String) {
        let line = lines[cursorRow]
        let index = line.index(line.startIndex, offsetBy: cursorCol)
        var newLine = line
        newLine.insert(contentsOf: character, at: index)
        lines[cursorRow] = newLine
        cursorCol += character.count
    }
    
    mutating func insert(_ char: Character) {
        insert(String(char))
    }
    
    mutating func backspace() {
        if cursorCol > 0 {
            var line = lines[cursorRow]
            let index = line.index(line.startIndex, offsetBy: cursorCol - 1)
            line.remove(at: index)
            lines[cursorRow] = line
            cursorCol -= 1
        } else if cursorRow > 0 {
            let currentLine = lines.remove(at: cursorRow)
            cursorRow -= 1
            cursorCol = lines[cursorRow].count
            lines[cursorRow] += currentLine
        }
    }
    
    mutating func moveLeft() {
        if cursorCol > 0 {
            cursorCol -= 1
        } else if cursorRow > 0 {
            cursorRow -= 1
            cursorCol = lines[cursorRow].count
        }
    }
    
    mutating func moveRight() {
        if cursorCol < lines[cursorRow].count {
            cursorCol += 1
        } else if cursorRow < lines.count - 1 {
            cursorRow += 1
            cursorCol = 0
        }
    }
    
    mutating func moveUp() {
        if cursorRow > 0 {
            cursorRow -= 1
            cursorCol = min(cursorCol, lines[cursorRow].count)
        }
    }
    
    mutating func moveDown() {
        if cursorRow < lines.count - 1 {
            cursorRow += 1
            cursorCol = min(cursorCol, lines[cursorRow].count)
        }
    }
    
    mutating func moveToEnd() {
        cursorRow = lines.count - 1
        cursorCol = lines[cursorRow].count
    }
    
    mutating func clear() {
        lines = [""]
        cursorRow = 0
        cursorCol = 0
    }
}
