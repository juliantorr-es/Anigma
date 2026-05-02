import Combine
import ContractsCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PDFImportViewModel: ObservableObject {
    @Published var progressValue: Double = 0
    @Published var statusText: String = "Waiting for PDF import"
    @Published var isImporterPresented: Bool = false
    @Published private(set) var latestResult: OperationResult<PDFImportJob.ImportResult>?

    var progressPublisher: AnyPublisher<OperationResult<PDFImportJob.ImportResult>, Never> {
        job.progressPublisher
    }

    private let job: PDFImportJob
    private var cancellables: Set<AnyCancellable> = []

    init(job: PDFImportJob) {
        self.job = job

        job.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    func importPDF(url: URL) async -> OperationResult<PDFImportJob.ImportResult> {
        let result = await job.importPDF(at: url)
        latestResult = result
        return result
    }

    private func handle(_ result: OperationResult<PDFImportJob.ImportResult>) {
        latestResult = result
        if let progress = result.progress {
            progressValue = progress.percent
            statusText = progress.message ?? statusText
        }

        switch result.state {
        case .success:
            progressValue = max(progressValue, 100)
            statusText = "Import completed"
        case .failure:
            if let failure = result.failure {
                statusText = "Import failed: \(failure.message)"
            }
        default:
            break
        }
    }
}

struct PDFImportView: View {
    @ObservedObject var viewModel: PDFImportViewModel
    @StateObject private var progressViewModel: OperationProgressViewModel<PDFImportJob.ImportResult>
    var onCompletion: (OperationResult<PDFImportJob.ImportResult>) -> Void

    init(
        viewModel: PDFImportViewModel,
        onCompletion: @escaping (OperationResult<PDFImportJob.ImportResult>) -> Void
    ) {
        self.viewModel = viewModel
        self.onCompletion = onCompletion
        _progressViewModel = StateObject(
            wrappedValue: OperationProgressViewModel(
                publisher: viewModel.progressPublisher,
                label: "PDF import"
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Bauhaus.Grid.x2) {
            HStack {
                VStack(alignment: .leading, spacing: Bauhaus.Grid.unit) {
                    Text("PDF Import")
                        .font(Bauhaus.Font.body)
                        .accessibilityAddTraits(.isHeader)
                    Text("Track progress with accessible announcements.")
                        .font(Bauhaus.Font.caption)
                        .foregroundStyle(Bauhaus.Color.textSecondary)
                }
                Spacer()
                Button {
                    viewModel.isImporterPresented = true
                } label: {
                    Label("Import PDF", systemImage: "doc.badge.plus")
                        .font(Bauhaus.Font.body)
                }
                .primaryButtonStyle()
             .accessibilityLabel("Import a PDF")
             .accessibilityHint("Opens a file picker for PDF documents.")
         }

         OperationProgressView(
             viewModel: progressViewModel,
             title: "PDF Import Progress"
         )
         .tint(Bauhaus.Color.accentHighContrast)
        }
        .padding(Bauhaus.Grid.x3)
        .background(Bauhaus.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Bauhaus.Grid.cornerRadius)
                .stroke(Bauhaus.Color.border, lineWidth: 1)
        )
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
         ) { result in
             switch result {
             case .success(let urls):
                 Task {
                     if let url = urls.first {
                        _ = await viewModel.importPDF(url: url)
                    }
                }
             case .failure(let error):
                progressViewModel.statusText = "Import cancelled: \(error.localizedDescription)"
             }
         }
         .onReceive(viewModel.progressPublisher) { result in
             guard result.state != .running else { return }
             onCompletion(result)
        }
    }
}
