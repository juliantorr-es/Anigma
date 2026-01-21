//
//  ModelsUICommand.swift
//  AnigmaCLIExecutable
//
//  Interactive model management TUI.
//

import Foundation
import ArgumentParser
import AnigmaCLITUI

struct ModelsUICommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "models-ui",
        abstract: "Interactive model management interface"
    )

    @Option(name: .long, help: "Models directory")
    var modelsPath: String = "~/.anigma/models"

    func run() async throws {
        let engine = TUIEngine()
        let view = ModelManagerView(engine: engine)
        let inputHandler = InputHandler()

        try await engine.enableRawMode()
        defer {
            Task {
                await engine.disableRawMode()
                await engine.clearScreen()
            }
        }

        // Initial state
        var models = [
            ModelManagerView.ModelInfo(name: "llama-3.1-8b-instruct-4bit", size: "4.5 GB", status: .installed),
            ModelManagerView.ModelInfo(name: "qwen-2.5-7b-coder-4bit", size: "4.2 GB", status: .available),
            ModelManagerView.ModelInfo(name: "phi-3.5-mini-instruct-4bit", size: "2.1 GB", status: .available),
            ModelManagerView.ModelInfo(name: "all-minilm-l6-v2", size: "80 MB", status: .installed)
        ]

        var selectedIndex = 0

        while true {
            await view.render(models: models, selectedIndex: selectedIndex)

            guard let key = await inputHandler.readKey() else { continue }

            switch key {
            case .char("q"), .char("Q"), .ctrlC:
                await engine.disableRawMode()
                await engine.clearScreen()
                return

            case .up:
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }

            case .down:
                if selectedIndex < models.count - 1 {
                    selectedIndex += 1
                }

            case .enter:
                // Mock installation/removal logic
                let model = models[selectedIndex]
                if case .installed = model.status {
                    // Remove
                    let updated = ModelManagerView.ModelInfo(name: model.name, size: model.size, status: .available)
                    models[selectedIndex] = updated
                } else if case .available = model.status {
                    // Install (simulate download)
                    await simulateDownload(view: view, models: &models, index: selectedIndex, inputHandler: inputHandler)
                }

            default:
                break
            }
        }
    }

    private func simulateDownload(view: ModelManagerView, models: inout [ModelManagerView.ModelInfo], index: Int, inputHandler: InputHandler) async {
        let model = models[index]

        // Start download state
        var progress = 0.0
        while progress < 1.0 {
            progress += 0.1
            let downloading = ModelManagerView.ModelInfo(name: model.name, size: model.size, status: .downloading, progress: progress)
            models[index] = downloading

            await view.render(models: models, selectedIndex: index)
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }

        // Completed
        let installed = ModelManagerView.ModelInfo(name: model.name, size: model.size, status: .installed)
        models[index] = installed
    }
}
