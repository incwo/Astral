//
//  TerminalModel.swift
//  Astral
//
//  Created by Renaud Pradenc on 17/01/2022.
//

import Foundation
import StripeTerminal

// All these methods are called on the main thread
protocol TerminalModelDelegate: AnyObject {
    func stripeTerminalModel(_ sender: TerminalModel, didUpdateState state: TerminalModel.State)
    
    /// Inform about an error
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error)
}

class TerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.paymentProcessor = PaymentProcessor(apiClient: apiClient)
        
        if let _ = Self.serialNumber {
            self.state = .readerSavedNotConnected
        } else {
            self.state = .noReader
        }
        
        super.init()
        
        Terminal.shared.delegate = self
        if let serialNumber = Self.serialNumber {
            reconnect(serialNumber: serialNumber)
        }
    }
    
    weak var delegate: TerminalModelDelegate?
    
    /// Charge an amount
    func charge(amount: Amount, completion: @escaping (ChargeResult)->()) {
        switch state {
        case .ready:
            state = .charging(message: "")
            paymentProcessor.charge(amount: amount) { result in
                if let reader = Terminal.shared.connectedReader { // Still connected
                    self.state = .ready (reader)
                } else {
                    self.state = .readerSavedNotConnected
                }
                completion(result)
            }
        default:
            let error = NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Can not charge now. The Terminal is in the state \(state)."])
            delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
        }
    }
    
    func cancelCharging() {
        paymentProcessor.cancel()
    }
    
    /// Begin the installation of the software update
    func installUpdate() {
        Terminal.shared.installAvailableUpdate()
    }
    
    private let paymentProcessor: PaymentProcessor
    let discovery = ReadersDiscovery()
    

    // MARK: State
    
    enum State {
        /// No reader is connected and no serial number is saved either
        case noReader
        
        /// No reader is connected, but a serial number is saved, so reconnecting can be attempted
        case readerSavedNotConnected
        
        /// A reader is being searched by its serial number
        case searchingReader (_ serialNumber: String)
        
        case discoveringReaders
        case connecting (Reader)
        case readerConnected (Reader)
        case ready (Reader)
        case charging (message: String)
        case installingUpdate (Reader, Float)
    }
    private(set) var state: State {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.stripeTerminalModel(self, didUpdateState: self.state)
            }
        }
    }
    
    // MARK: Connection
    
    var location: Location?
    var reader: Reader? {
        didSet {
            saveReaderSerialNumber()
        }
    }
    
    private var connection: ReaderConnection?
    
    func connect() {
        guard Terminal.shared.connectionStatus == .notConnected else {
            NSLog("A Reader is already connected or connecting")
            return
        }
        
        guard let reader = reader else {
            fatalError("a reader must be set at this point")
        }
        
        state = .connecting(reader)
        
        self.configureSimulator()
        connection = ReaderConnection()
        connection?.delegate = self
        
        let locationId: String?
        if let location = location {
            locationId = location.stripeId
        } else {
            locationId = reader.locationId
        }
        guard let locationId = locationId else {
            NSLog("\(#function) Could not get the locationId")
            return
        }
        
        connection?.connect(reader, locationId: locationId, onSuccess: { [weak self] in
            guard let self = self else { return }
            self.state = .readerConnected(reader)
            if !reader.requiresImmediateUpdate {
                /// The reader will not start updating right now
                self.state = .ready (reader)
            }
        }, onFailure: { [weak self] error in
            guard let self = self else { return }
            self.reader = nil // Forget this reader, an other one should probably be set up
            self.state = .readerSavedNotConnected
            DispatchQueue.main.async {
                self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
            }
        })
    }
    
    func disconnect() {
        connection?.disconnect(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.location = nil
            self.reader = nil
            self.state = .noReader
        }, onFailure: { error in
            DispatchQueue.main.async {
                self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
            }
        })
    }
    
    private func reconnect(serialNumber: String) {
        state = .searchingReader(serialNumber)
        
        discovery.findReader(serialNumber: serialNumber) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .found(let reader):
                self.reader = reader
                self.connect()
                
            case .notFound:
                self.state = .readerSavedNotConnected
                
            case .failure(let error):
                self.reader = nil // Forget this reader, an other one should probably be set up
                self.state = .noReader
                DispatchQueue.main.async {
                    self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
                }
            }
        }
    }
    
    // MARK: Serial Number
    
    // The serial number of the last reader is saved to the User defaults, so it can be reconnected automatically
    
    private func saveReaderSerialNumber() {
        UserDefaults.standard.set(reader?.serialNumber, forKey: Self.serialNumberUserDefaultsKey)
    }
    
    private static var serialNumber: String? {
        UserDefaults.standard.string(forKey: serialNumberUserDefaultsKey)
    }
    
    private static let serialNumberUserDefaultsKey = "Astral.reader.serialNumber"
}

extension TerminalModel: TerminalDelegate {
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        // You might want to display UI to notify the user and start re-discovering readers
    }
    
    // Call this method just before connecting the reader; simulatorConfiguration might be nil earlier.
    private func configureSimulator() {
        Terminal.shared.simulatorConfiguration.availableReaderUpdate = .available // .random
    }
}

extension TerminalModel: ReaderConnectionDelegate {
    func readerConnection(_ sender: ReaderConnection, showReaderMessage message: String) {
        state = .charging(message: message)
    }
    
    func readerConnectionDidStartInstallingUpdate(_ sender: ReaderConnection) {
        guard let reader = reader else {
            fatalError("\(#function) There should be a reader connected at this point.")
        }
        
        state = .installingUpdate(reader, 0.0)
    }
    
    func readerConnection(_ sender: ReaderConnection, softwareUpdateDidProgress progress: Float) {
        guard let reader = reader else {
            fatalError("\(#function) There should be a reader connected at this point.")
        }
        
        state = .installingUpdate(reader, progress)
    }
    
    func readerConnectionDidFinishInstallingUpdate(_ sender: ReaderConnection) {
        if let reader = reader,
            Terminal.shared.connectedReader == reader {
            state = .ready (reader)
        } else {
            // I think that for big updates, the reader disconnects after the installation
            if let serialNumber = Self.serialNumber {
                self.state = .readerSavedNotConnected
                reconnect(serialNumber: serialNumber)
            } else {
                self.state = .noReader
            }
        }
    }
}

extension Reader {
    var requiresImmediateUpdate: Bool {
        guard let availableUpdate = availableUpdate else { return false }
        return availableUpdate.requiredAt < Date()
    }
}
