import Foundation
import Combine

@MainActor
public final class StreamController {
    public lazy var output: some Publisher<StreamContent, Never> = {
        $input
            .throttle(for: .milliseconds(8), scheduler: DispatchQueue.main, latest: true)
            .receive(on: DispatchQueue.global())
            .map { buffer in
                StreamContentBuilder(buffer: buffer).build()
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] (content: StreamContent) in
                for error in content.errors {
                    self?.notifyError(error)
                }
            })
            .share()
    }()

    private var notifiedErrors: Set<IdentifiableError.ID> = []

    @Published private var input: String = ""

    public init() {}

    public func processChunk(_ chunk: String) {
        input += chunk
    }

    private func notifyError(_ error: IdentifiableError) {
        guard notifiedErrors.insert(error.id).inserted else { return }
        print("Stream parsing error: \(String(reflecting: error.underlyingError))")
    }
}
