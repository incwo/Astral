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
    
    /*
     func stripeTerminalWillBeginInstallingUpdate(_ sender: TerminalModel, on reader: Reader)
    
    func stripeTerminalDidProgressInstallingUpdate(_ sender: TerminalModel, progress: Float)
    
    func stripeTerminalDidEndInstallingUpdate(_ sender: TerminalModel)
     */
    
    /// Inform about an error
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error)
}

class TerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.paymentProcessor = PaymentProcessor(apiClient: apiClient)
        super.init()
        
        Terminal.shared.delegate = self
        reconnect()
    }
    
    weak var delegate: TerminalModelDelegate?
    
    /// Charge an amount
    func charge(amount: Amount, completion: @escaping (ChargeResult)->()) {
        switch state {
        case .ready:
            paymentProcessor.charge(amount: amount) { result in
                if let _ = Terminal.shared.connectedReader { // Still connected
                    self.state = .ready
                } else {
                    self.state = .noReaderConnected
                }
                completion(result)
            }
        default:
            let error = NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Can not charge now. The Terminal is in the state \(state)."])
            delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
        }
    }
    
    /// Begin the installation of the software update
    func installUpdate() {
        Terminal.shared.installAvailableUpdate()
    }
    
    private let paymentProcessor: PaymentProcessor
    let discovery = ReadersDiscovery()
    

    // MARK: State
    
    enum State {
        case noReaderConnected
        case searchingReader (_ serialNumber: String)
        case discoveringReaders
        case connecting (Reader)
        case readerConnected (Reader)
        case ready
        case charging (message: String)
        case installingUpdate (Reader, Float)
    }
    private(set) var state: State = .noReaderConnected {
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
                self.state = .ready
            }
        }, onFailure: { [weak self] error in
            guard let self = self else { return }
            self.reader = nil // Forget this reader, an other one should probably be set up
            self.state = .noReaderConnected
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
            self.state = .noReaderConnected
        }, onFailure: { error in
            DispatchQueue.main.async {
                self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
            }
        })
    }
    
    private func saveReaderSerialNumber() {
        UserDefaults.standard.set(reader?.serialNumber, forKey: serialNumberUserDefaultsKey)
    }
    
    private func reconnect() {
        guard let serialNumber = UserDefaults.standard.string(forKey: serialNumberUserDefaultsKey) else {
            return
        }
        
        state = .searchingReader(serialNumber)
        
        discovery.findReader(serialNumber: serialNumber) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .found(let reader):
                self.reader = reader
                self.connect()
                
            case .notFound:
                self.state = .noReaderConnected
                
            case .failure(let error):
                self.reader = nil // Forget this reader, an other one should probably be set up
                self.state = .noReaderConnected
                DispatchQueue.main.async {
                    self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
                }
            }
        }
    }
    
    private let serialNumberUserDefaultsKey = "Astral.reader.serialNumber"
}

extension TerminalModel: TerminalDelegate {
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        // You might want to display UI to notify the user and start re-discovering readers
    }
    
    // Call this method just before connecting the reader; simulatorConfiguration might be nil earlier.
    private func configureSimulator() {
        Terminal.shared.simulatorConfiguration.availableReaderUpdate = .required // .random
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
            state = .ready
        } else {
            // I think that for big updates, the reader disconnects after the installation
            state = .noReaderConnected
            reconnect()
        }
    }
}

extension Reader {
    var requiresImmediateUpdate: Bool {
        guard let availableUpdate = availableUpdate else { return false }
        return availableUpdate.requiredAt < Date()
    }
}
