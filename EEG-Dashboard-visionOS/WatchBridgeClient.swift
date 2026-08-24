//
//  WatchBridgeClient.swift
//  EEG-Dashboard-visionOS
//
//  Connects to the iPhone Simulator's WatchBridgeServer over localhost TCP
//  and decodes the newline-delimited BridgeMessage stream. See
//  WatchBridgeMessage.swift for why 127.0.0.1 reaches across Simulator
//  processes. Auto-reconnects every few seconds — harmless no-op on real
//  hardware, where each device's loopback is its own and the connection
//  simply never succeeds (CloudKitWatchPuller covers that case instead).

import Foundation
import Network

final class WatchBridgeClient {
    var onConnectionChange: ((Bool) -> Void)?
    var onMessage:          ((BridgeMessage) -> Void)?

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "WatchBridgeClient")
    private var buffer = Data()
    private var reconnectTask: Task<Void, Never>?

    func start() {
        guard reconnectTask == nil else { return }
        reconnectTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.connectOnce()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() {
        reconnectTask?.cancel()
        reconnectTask = nil
        connection?.cancel()
        connection = nil
    }

    private func connectOnce() async {
        guard connection == nil, let port = NWEndpoint.Port(rawValue: watchBridgePort) else { return }
        let conn = NWConnection(host: "127.0.0.1", port: port, using: .tcp)

        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.onConnectionChange?(true)
            case .failed, .cancelled:
                self.onConnectionChange?(false)
                self.queue.async { self.connection = nil }
            default:
                break
            }
        }
        conn.start(queue: queue)
        queue.async { self.connection = conn }
        receive(on: conn)

        // Give the attempt a moment; the outer loop retries regardless of outcome.
        try? await Task.sleep(for: .seconds(2))
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drainBuffer()
            }
            if isComplete || error != nil {
                self.onConnectionChange?(false)
                self.queue.async { self.connection = nil }
                return
            }
            self.receive(on: connection)
        }
    }

    private func drainBuffer() {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            guard !lineData.isEmpty,
                  let message = try? JSONDecoder().decode(BridgeMessage.self, from: lineData)
            else { continue }
            onMessage?(message)
        }
    }
}
