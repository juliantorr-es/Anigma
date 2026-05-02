import Foundation

/// Visitor pattern for traversing DocumentIR trees
/// Supports both depth-first and breadth-first traversal with early termination
public protocol DocumentIRVisitor {
    /// Called when entering a node during traversal
    func visit(_ node: DocumentIRNode) -> VisitAction
    
    /// Called when exiting a container node (after visiting children)
    func visitExit(_ node: DocumentIRNode)
}

/// Control flow action for visitor pattern
public enum VisitAction: Sendable {
    /// Continue visiting children (for container nodes)
    case continueVisit
    /// Skip children but continue with siblings
    case skipChildren
    /// Stop all traversal
    case stop
}

// MARK: - Default Implementation

extension DocumentIRVisitor {
    public func visitExit(_ node: DocumentIRNode) {}
}

// MARK: - Tree Traversal

public struct DocumentIRTraversal {
    private let visitor: DocumentIRVisitor
    
    public init(visitor: DocumentIRVisitor) {
        self.visitor = visitor
    }
    
    /// Perform depth-first traversal of document tree
    public func traverseDepthFirst(_ node: DocumentIRNode) {
        var stack: [(node: DocumentIRNode, phase: TraversalPhase)] = [(node, .enter)]
        
        while !stack.isEmpty {
            let (currentNode, phase) = stack.removeLast()
            
            switch phase {
            case .enter:
                let action = visitor.visit(currentNode)
                switch action {
                case .stop:
                    return
                case .skipChildren:
                    stack.append((currentNode, .exit))
                case .continueVisit:
                    stack.append((currentNode, .exit))
                    if let children = getChildren(currentNode) {
                        // Push children in reverse order for correct left-to-right traversal
                        for child in children.reversed() {
                            stack.append((child, .enter))
                        }
                    }
                }
                
            case .exit:
                visitor.visitExit(currentNode)
            }
        }
    }
    
    /// Perform breadth-first traversal of document tree
    public func traverseBreadthFirst(_ node: DocumentIRNode) {
        var queue: [DocumentIRNode] = [node]
        var visited = Set<String>()
        
        while !queue.isEmpty {
            let currentNode = queue.removeFirst()
            let nodeID = getNodeID(currentNode)
            
            // Avoid revisiting same node
            if visited.contains(nodeID) {
                continue
            }
            visited.insert(nodeID)
            
            let action = visitor.visit(currentNode)
            switch action {
            case .stop:
                return
            case .skipChildren:
                visitor.visitExit(currentNode)
            case .continueVisit:
                if let children = getChildren(currentNode) {
                    queue.append(contentsOf: children)
                }
                visitor.visitExit(currentNode)
            }
        }
    }
    
    private enum TraversalPhase {
        case enter
        case exit
    }
    
    private func getChildren(_ node: DocumentIRNode) -> [DocumentIRNode]? {
        switch node {
        case .document(let doc):
            return doc.children
        case .section(let section):
            return section.children
        case .paragraph(let para):
            return para.children
        case .list(let list):
            return list.children
        case .listItem(let item):
            return item.children
        case .table(let table):
            return table.children
        case .tableRow(let row):
            return row.children
        case .tableCell(let cell):
            return cell.children
        case .blockQuote(let quote):
            return quote.children
        case .emphasis(let em):
            return em.children
        case .strong(let strong):
            return strong.children
        case .link(let link):
            return link.children
        default:
            return nil
        }
    }
    
    private func getNodeID(_ node: DocumentIRNode) -> String {
        switch node {
        case .document(let doc):
            return doc.id
        case .section(let section):
            return section.id
        case .paragraph(let para):
            return para.id
        case .list(let list):
            return list.id
        case .listItem(let item):
            return item.id
        case .table(let table):
            return table.id
        case .tableRow(let row):
            return row.id
        case .tableCell(let cell):
            return cell.id
        case .blockQuote(let quote):
            return quote.id
        case .codeBlock(let code):
            return code.id
        case .emphasis(let em):
            return em.id
        case .strong(let strong):
            return strong.id
        case .code(let code):
            return code.id
        case .link(let link):
            return link.id
        case .image(let image):
            return image.id
        case .text(_):
            return UUID().uuidString // Text nodes don't have IDs
        case .lineBreak, .hardBreak, .softBreak:
            return UUID().uuidString
        }
    }
}

// MARK: - Concrete Visitors

/// Visitor that collects all text content from the tree
public final class TextCollectionVisitor: DocumentIRVisitor {
    private let lock = NSLock()
    private var textParts: [String] = []
    
    public func visit(_ node: DocumentIRNode) -> VisitAction {
        switch node {
        case .text(let text):
            lock.lock()
            defer { lock.unlock() }
            textParts.append(text.content)
            return .continueVisit
            
        default:
            return .continueVisit
        }
    }
    
    public func getAllText() -> String {
        lock.lock()
        defer { lock.unlock() }
        return textParts.joined()
    }
}

/// Visitor that collects all images
public final class ImageCollectionVisitor: DocumentIRVisitor {
    private let lock = NSLock()
    private var images: [DocumentIRNode.Image] = []
    
    public func visit(_ node: DocumentIRNode) -> VisitAction {
        switch node {
        case .image(let img):
            lock.lock()
            defer { lock.unlock() }
            images.append(img)
            return .continueVisit
            
        default:
            return .continueVisit
        }
    }
    
    public func getImages() -> [DocumentIRNode.Image] {
        lock.lock()
        defer { lock.unlock() }
        return images
    }
}

/// Visitor that collects all links
public final class LinkCollectionVisitor: DocumentIRVisitor {
    private let lock = NSLock()
    private var links: [DocumentIRNode.Link] = []
    
    public func visit(_ node: DocumentIRNode) -> VisitAction {
        switch node {
        case .link(let link):
            lock.lock()
            defer { lock.unlock() }
            links.append(link)
            return .continueVisit
            
        default:
            return .continueVisit
        }
    }
    
    public func getLinks() -> [DocumentIRNode.Link] {
        lock.lock()
        defer { lock.unlock() }
        return links
    }
}

/// Visitor that collects all code blocks
public final class CodeCollectionVisitor: DocumentIRVisitor {
    private let lock = NSLock()
    private var codeBlocks: [DocumentIRNode.CodeBlock] = []
    
    public func visit(_ node: DocumentIRNode) -> VisitAction {
        switch node {
        case .codeBlock(let code):
            lock.lock()
            defer { lock.unlock() }
            codeBlocks.append(code)
            return .continueVisit
            
        default:
            return .continueVisit
        }
    }
    
    public func getCodeBlocks() -> [DocumentIRNode.CodeBlock] {
        lock.lock()
        defer { lock.unlock() }
        return codeBlocks
    }
}

/// Visitor that counts node types
public final class NodeCountingVisitor: DocumentIRVisitor {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    
    public func visit(_ node: DocumentIRNode) -> VisitAction {
        lock.lock()
        defer { lock.unlock() }
        
        let nodeType: String
        switch node {
        case .document: nodeType = "document"
        case .section: nodeType = "section"
        case .paragraph: nodeType = "paragraph"
        case .list: nodeType = "list"
        case .listItem: nodeType = "listItem"
        case .table: nodeType = "table"
        case .tableRow: nodeType = "tableRow"
        case .tableCell: nodeType = "tableCell"
        case .blockQuote: nodeType = "blockQuote"
        case .codeBlock: nodeType = "codeBlock"
        case .text: nodeType = "text"
        case .emphasis: nodeType = "emphasis"
        case .strong: nodeType = "strong"
        case .code: nodeType = "code"
        case .link: nodeType = "link"
        case .image: nodeType = "image"
        case .lineBreak: nodeType = "lineBreak"
        case .hardBreak: nodeType = "hardBreak"
        case .softBreak: nodeType = "softBreak"
        }
        
        counts[nodeType, default: 0] += 1
        return .continueVisit
    }
    
    public func getCounts() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return counts
    }
}

/// Visitor that transforms nodes
public protocol TransformingVisitor: DocumentIRVisitor {
    func transform(_ node: DocumentIRNode) -> DocumentIRNode?
}

extension TransformingVisitor {
    public func visitExit(_ node: DocumentIRNode) {}
}
