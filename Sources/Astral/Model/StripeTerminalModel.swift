//
//  StripeTerminalModel.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 17/01/2022.
//

import Foundation
import StripeTerminal

// All these methods are called on the main thread
protocol StripeTerminalModelDelegate: AnyObject {
    func stripeTerminalModel(_ sender: StripeTerminalModel, didUpdateState state: StripeTerminalModel.State)
    
    /// Make the User pick a reader
    ///
    /// This method is called when trying to charge while no Reader is ready (not connected or updating, etc.).
    func stripeTerminalModelNeedsSettingUp(_ sender: StripeTerminalModel)
    
    /// The installation of an update is progressing
    func stripeTerminalModel(_ sender: StripeTerminalModel, softwareUpdateDidProgress progress: Float)
    
    /// Inform about an error
    func stripeTerminalModel(_sender: StripeTerminalModel, didFailWithError error: Error)
}

class StripeTerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.paymentProcessor = StripePaymentProcessor(apiClient: apiClient)
        super.init()
        
        Terminal.shared.delegate = self
        reconnect()
    }
    
    weak var delegate: StripeTerminalModelDelegate?
    
    enum State {
        case noReaderConnected
        case searchingReader (_ serialNumber: String)
        case discoveringReaders
        case connecting (Reader)
        case readerConnected (Reader)
        case charging (message: String)
        case installingUpdate (Reader)
    }
    private(set) var state: State = .noReaderConnected {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.stripeTerminalModel(self, didUpdateState: self.state)
            }
        }
    }
    
    func charge(amount: NSDecimalNumber, currency: String, completion: @escaping (StripeChargeResult)->()) {
        switch state {
        case .readerConnected (_):
            paymentProcessor.charge(amount: StripeAmount(amount: amount, currency: currency), completion: completion)
        case .charging(_):
            let error = NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Can not charge now. The Terminal is already charging."])
            delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
        default:
            delegate?.stripeTerminalModelNeedsSettingUp(self)
        }
    }
    
    /// Begin the installation of the software update
    func installUpdate() {
        Terminal.shared.installAvailableUpdate()
    }
    
    private let paymentProcessor: StripePaymentProcessor
    let discovery = StripeReadersDiscovery()
    
    // MARK: Connection
    
    var location: Location?
    var reader: Reader? {
        didSet {
            saveReaderSerialNumber()
        }
    }
    
    private var connection: StripeReaderConnection?
    
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
        connection = StripeReaderConnection()
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
            self?.state = .readerConnected(reader)
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
    
    private let serialNumberUserDefaultsKey = "StripeTerminal.reader.serialNumber"
}

extension StripeTerminalModel: TerminalDelegate {
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        // You might want to display UI to notify the user and start re-discovering readers
    }
    
    // Call this method just before connecting the reader; simulatorConfiguration might be nil earlier.
    private func configureSimulator() {
        #warning("Remettre en .random")
        Terminal.shared.simulatorConfiguration.availableReaderUpdate = .available
    }
}

extension StripeTerminalModel: StripeReaderConnectionDelegate {
    func readerConnection(_ sender: StripeReaderConnection, showReaderMessage message: String) {
        state = .charging(message: message)
    }
    
    func readerConnectionDidStartInstallingUpdate(_ sender: StripeReaderConnection) {
        guard let reader = reader else {
            fatalError("\(#function) There should be a reader connected at this point.")
        }
        
        state = .installingUpdate(reader)
    }
    
    func readerConnection(_ sender: StripeReaderConnection, softwareUpdateDidProgress progress: Float) {
        delegate?.stripeTerminalModel(self, softwareUpdateDidProgress: progress)
    }
    
    func readerConnectionDidFinishInstallingUpdate(_ sender: StripeReaderConnection) {
        if let reader = reader,
            Terminal.shared.connectedReader == reader {
            state = .readerConnected(reader)
        } else {
            // I think that for big updates, the reader disconnects after the installation
            state = .noReaderConnected
            reconnect()
        }
    }
}
