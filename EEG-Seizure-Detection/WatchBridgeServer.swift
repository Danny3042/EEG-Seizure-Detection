//
//  WatchBridgeServer.swift
//  EEGSeizureDetection
//
//  Simulator-friendly bridge server: listens on 127.0.0.1 and broadcasts the
//  Watch's live data + detection events to any connected client (the
//  visionOS app's WatchBridgeClient). See WatchBridgeMessage.swift for why
//  this works reliably in Simulator where Bonjour/Multipeer don't.

import Foundation
import Network

final class WatchBridgeServer {
    static let shared = WatchBridgeServer()

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "WatchBridgeServer")

    func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: watchBridgePort) else { return }
        do {
            let newListener = try NWListener(using: .tcp, on: port)
            newListener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            newListener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    print("WatchBridgeServer failed: \(error)")
                }
            }
            newListener.start(queue: queue)
            listener = newListener
        } catch {
            print("WatchBridgeServer could not start: \(error)")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .cancelled, .failed:
                self.queue.async { self.connections.removeAll { $0 === connection } }
            default:
                break
            }
        }
        connection.start(queue: queue)
        queue.async { self.connections.append(connection) }
    }

    func broadcast(_ message: BridgeMessage) {
        guard var data = try? JSONEncoder().encode(message) else { return }
        data.append(0x0A) // newline delimiter
        queue.async {
            for connection in self.connections {
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }
}
