//
//  ReadersDiscovery.swift
//  Astral
//
//  Created by Renaud Pradenc on 17/12/2021.
//

import Foundation
import StripeTerminal

/// Discover Stripe Readers
class ReadersDiscovery: NSObject {
    typealias OnUpdate = ([Reader])->()
    typealias OnError = (Error)->()
    typealias OnCanceled = ()->()
    private var onUpdate: OnUpdate?
    private var onError: OnError?
    private var onCanceled: OnCanceled?
    private var cancelable: Cancelable?
    
    private(set) var isDiscovering: Bool = false
    
    func discoverReaders(onUpdate: @escaping OnUpdate, onError: @escaping OnError) {
        guard isDiscovering == false else {
            NSLog("\(#function) Already discovering")
            return
        }
        
        self.onUpdate = onUpdate
        self.onError = onError
        self.onCanceled = nil
        
#if targetEnvironment(simulator)
        let simulated = true
#else
        let simulated = false
#endif
        
        isDiscovering = true
        let config = DiscoveryConfiguration(discoveryMethod: .bluetoothScan, simulated: simulated)
        cancelable = Terminal.shared.discoverReaders(config, delegate: self, completion: { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                if error.isCancelation {
                    self.onCanceled?()
                } else {
                    self.onError?(error)
                }
            }
        })
    }
    
    enum SearchResult {
        case found (Reader)
        case notFound
        case failure (Error)
    }
    
    /// Find a reader using its serial number
    func findReader(serialNumber: String, completion: @escaping (SearchResult)->()) {
        let start = Date()
        let timeOut = TimeInterval(60.0)
        discoverReaders(onUpdate: { readers in
            if let match = readers.first(where: { $0.serialNumber == serialNumber} ) {
                completion(.found(match))
            } else {
                if Date() > start + timeOut {
                    completion(.notFound)
                }
            }
        }, onError: { error in
            completion(.failure(error))
        })
    }
    
    func cancel(completion: @escaping OnCanceled) {
        if let cancelable = cancelable {
            cancelable.cancel { [weak self] error in
                // The completion block does not indicate that the cancelation is complete, only that it's acknowledged.
                if let error = error {
                    self?.onError?(error)
                } else {
                    self?.isDiscovering = false
                    self?.cancelable = nil
                    self?.onUpdate = nil
                    self?.onError = nil
                    self?.onCanceled = completion
                }
            }
        } else {
            completion()
        }
    }
}

extension ReadersDiscovery: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        onUpdate?(readers)
    }
}
