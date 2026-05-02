//
//  RichUI.swift
//  AnigmaTUI
//
//  Rich terminal UI components for high-fidelity CLI experiences.
//  Inspired by Ratatui and Codex.
//

import Foundation

public struct TUIPanel {
    public let title: String
    public let borderStyle: BorderStyle

    public enum BorderStyle {
        case single, double, rounded, none
    }

    public func render(content: String, width: Int = 40) -> String {
        let horizontal = "─"
        let vertical = "│"
        let topLeft = "┌"
        let topRight = "┐"
        let bottomLeft = "└"
        let bottomRight = "┘"

        var output = "\u{1B}[1m" // Bold title
        output += topLeft + " " + title + " " + String(repeating: horizontal, count: max(0, width - title.count - 4)) + topRight + "\u{1B}[0m\n"

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let padded = line.padding(toLength: width - 2, withPad: " ", startingAt: 0)
            output += vertical + padded + vertical + "\n"
        }

        output += bottomLeft + String(repeating: horizontal, count: width - 2) + bottomRight
        return output
    }
}

public class TUISpinner {
    private let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0

    public init() {}

    public func nextFrame() -> String {
        let frame = frames[currentFrame]
        currentFrame = (currentFrame + 1) % frames.count
        return "\u{1B}[34m" + frame + "\u{1B}[0m" // Blue spinner
    }
}

public struct TUIProgressBar {
    public func render(progress: Double, width: Int = 20) -> String {
        let filled = Int(progress * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
        let percentage = Int(progress * 100)

        return "\u{1B}[32m" + bar + "\u{1B}[0m \(percentage)%"
    }
}
