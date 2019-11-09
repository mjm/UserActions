import Combine

final class ReplaySubject<Input, Failure: Error>: Subject {
    typealias Output = Input
    private var recording = Record<Input, Failure>.Recording()
    private var isCompleted = false
    private let stream = PassthroughSubject<Input, Failure>()
    private let maxValues: Int
    private var counter = 0

    init(maxValues: Int = 0) {
        self.maxValues = maxValues
    }

    func send(subscription: Subscription) {
        subscription.request(maxValues == 0 ? .unlimited : .max(maxValues))
    }

    func send(_ value: Input) {
        recording.receive(value)
        stream.send(value)
        if recording.output.count == maxValues {
            send(completion: .finished)
        }
    }

    func send(completion: Subscribers.Completion<Failure>) {
        if !isCompleted {
            recording.receive(completion: completion)
            stream.send(completion: completion)
            isCompleted = true
        }
    }

    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Input == S.Input {
        Record(recording: self.recording)
            .append(self.stream)
            .receive(subscriber: subscriber)
    }
}

extension Publisher {
    func shareReplay(maxValues: Int = 0) -> AnyPublisher<Output, Failure> {
        multicast(subject: ReplaySubject(maxValues: maxValues)).autoconnect().eraseToAnyPublisher()
    }
}
