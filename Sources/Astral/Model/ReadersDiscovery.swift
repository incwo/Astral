//
//  ReadersDiscovery.swift
//  Astral
//
//  Created by Renaud Pradenc on 17/12/2021.
//

import Foundation
import StripeTerminal

enum ReadersDiscoveryError: Error {
    case alreadyDiscovering
}

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
    
#if targetEnvironment(simulator)
    private let isSimulated = true
#else
    private let isSimulated = false
#endif
    
    /// Launch the discovery of readers
    /// - Parameters:
    ///   - onUpdate: a closure called on updates of the list of detected readers
    ///   - onError: a closure called when an error occurs during the discovery
    func discoverReaders(onUpdate: @escaping OnUpdate, onError: @escaping OnError) {
        guard isDiscovering == false else {
            onError(ReadersDiscoveryError.alreadyDiscovering)
            return
        }
        
        self.onUpdate = onUpdate
        self.onError = onError
        self.onCanceled = nil
        
        isDiscovering = true
        let config = DiscoveryConfiguration(discoveryMethod: .bluetoothScan, simulated: isSimulated)
        cancelable = Terminal.shared.discoverReaders(config, delegate: self, completion: { [weak self] error in
            guard let self = self else { return }
            
            // In opposition with other operations, we don't get a Cancelation error when the Discovery is canceled…
            if let onCanceled = self.onCanceled {
                onCanceled()
                return
            }
            
            if let error = error {
                self.onError?(error)
            }
        })
    }
    
    enum SearchResult {
        /// The reader was found
        case found (Reader)
        
        /// An error occured
        case failure (Error)
    }
    
    /// Find a reader using its serial number
    func findReader(serialNumber: String, completion: @escaping (SearchResult)->()) {
        discoverReaders(onUpdate: { [weak self] readers in
            if let match = readers.first(where: { $0.serialNumber == serialNumber} ) {
                completion(.found(match))
                self?.cancel(completion: nil)
            }
        }, onError: { [weak self] error in
            completion(.failure(error))
            self?.cancel(completion: nil)
        })
    }
    
    
    /// Cancel (end) the discovery of readers
    /// - Parameter completion: a closure called when the discovery has been canceled
    func cancel(completion: OnCanceled?) {
        if let cancelable = cancelable {
            cancelable.cancel { [weak self] error in
                guard let self = self else { return }
                // The completion block does not indicate that the cancelation is complete, only that it's acknowledged.
                self.isDiscovering = false
                self.cancelable = nil
                self.onUpdate = nil
                
                if let error = error {
                    // An error occured when canceling — probably the discovery has already been canceled
                    self.onError?(error)
                    self.onCanceled = nil
                } else {
                    self.onError = nil
                    self.onCanceled = completion // Will be called in discoverReaders()
                }
            }
        } else { // Not cancelable
            completion?()
        }
    }
}

extension ReadersDiscovery: DiscoveryDelegate {
    func terminal(_ terminal: Terminal, didUpdateDiscoveredReaders readers: [Reader]) {
        onUpdate?(readers)
    }
}
