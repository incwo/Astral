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
    func stripeTerminalModel(_ sender: TerminalModel, didUpdateState state: TerminalStateMachine.State)
    
    /// Asks to show a payment message issued by the terminal
    func stripeTerminalModel(_ sender: TerminalModel, display message: String)
    
    /// Informs about the progress of the installation of the update
    func stripeTerminalModel(_ sender: TerminalModel, installingUpdateDidProgress progress: Float)
    
    /// Informs about an error
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error)
}

class TerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.paymentProcessor = PaymentProcessor(apiClient: apiClient)
        self.stateMachine = TerminalStateMachine(readerSerialNumber: Self.serialNumber)
        
        super.init()
        
        Terminal.shared.delegate = self
    }
    
    weak var delegate: TerminalModelDelegate?
    

    // MARK: Events
    
    /// Handle a Location picked by the user
    func didSelectLocation(_ location: Location) {
        handleEvent(.didSelectLocation(location))
        self.location = location
    }
    private var location: Location?
    
    /// Handle a Reader picked by the user
    func didSelectReader(_ reader: Reader) {
        self.reader = reader
        saveReaderSerialNumber()
        handleEvent(.didSelectReader(reader))
    }
    private(set) var reader: Reader?
    
    /// Forget the current reader, so it's disconnected and its serial number is forgotten
    func forgetReader() {
        handleEvent(.forgetReader)
    }
    
    func reconnect() {
        handleEvent(.reconnect)
    }
    
    /// Charge an amount
    func charge(currencyAmount: CurrencyAmount, completion: @escaping (ChargeResult)->()) {
        handleEvent(.charge)
        self.paymentProcessor.charge(currencyAmount: currencyAmount) { result in
            // Whatever the result (success, error, cancelation), charging has ended
            self.handleEvent(.didEndCharging)
            completion(result)
        }
    }
    
    /// Begin the installation of the software update
    func installUpdate() {
        Terminal.shared.installAvailableUpdate()
    }
    
    /// Cancel the current operation
    func cancel(completion: (()->())?) {
        switch stateMachine.state {
        case .searchingReader:
            discovery.cancel {
                self.handleEvent(.cancel)
            }
        case .discoveringReaders:
            discovery.cancel() {
                self.handleEvent(.cancel)
            }
        case .charging:
            paymentProcessor.cancel {
                completion?()
            }
        case .userInitiatedUpdate:
            NSLog("[Astral] \(#function) Canceling the installation of updates is not implemented yet.")
        default:
            NSLog("[Astral] \(#function) The current operation can not be canceled.")
        }
    }
    

    // MARK: State Machine
    
    private let paymentProcessor: PaymentProcessor
    let discovery = ReadersDiscovery()
    private lazy var connection: ReaderConnection = {
        let connection = ReaderConnection()
        connection.delegate = self
        return connection
    }()
    
    let stateMachine: TerminalStateMachine
    
    /// Relays the current state of the state machine
    var state: TerminalStateMachine.State {
        stateMachine.state
    }

    private func handleEvent(_ event: TerminalStateMachine.Event) {
        switch stateMachine.update(with: event) {
        case .success(let state):
            handleTransition(to: state) { error in
                if let error = error {
                    self.reportErrorOnMainQueue(error)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        NSLog("[Astral] State = \(state)")
                        self.delegate?.stripeTerminalModel(self, didUpdateState: state)
                    }
                }
            }
        case .failure(let error):
            reportErrorOnMainQueue(error)
        }
    }
    
    private func reportErrorOnMainQueue(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
        }
    }
    
    private func handleTransition(to newState: TerminalStateMachine.State, completion: @escaping ((Error?)->())) {
        switch newState {
        case .noReader:
            disconnectReader(completion: completion)
            
        case .disconnected(_):
            completion(nil)
            
        case .searchingReader(let serialNumber):
            discovery.findReader(serialNumber: serialNumber) { result in
                switch result {
                case .found(let reader):
                    self.reader = reader
                    completion(nil)
                    self.handleEvent(.didFindReader(reader))
                case .failure(let error):
                    completion(error)
                }
            }
            
        case .discoveringReaders:
            // Discovering is done by the DiscoveryTableViewController
            completion(nil)
            
        case .connecting(let reader):
            connect(to: reader) { error in
                if let error = error {
                    completion(error)
                } else {
                    completion(nil)
                    self.handleEvent(.didConnect)
                }
            }
            
        case .connected(_):
            completion(nil)
            
        case .userInitiatedUpdate(_):
            completion(nil)
            
        case .automaticUpdate(_):
            completion(nil)
            
        case .charging(_):
            // Charging is done in charge()
            completion(nil)
        }
    }
    
    private func disconnectReader(completion: @escaping (Error?)->()) {
        connection.disconnect(onSuccess: { [weak self] in
            guard let self = self else { return }
            self.location = nil
            self.reader = nil
            self.saveReaderSerialNumber()
            completion(nil)
        }, onFailure: { [weak self] error in
            guard let self = self else { return }
            self.location = nil
            self.reader = nil
            self.saveReaderSerialNumber()
            completion(error)
        })
    }
    
    private func connect(to reader: Reader, completion: @escaping (Error?)->()) {
        guard Terminal.shared.connectionStatus == .notConnected else {
            NSLog("A Reader is already connected or connecting")
            return
        }
        
        configureSimulator()
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
        
        connection.connect(reader, locationId: locationId, onSuccess: {
            completion(nil)
        }, onFailure: { error in
            completion(error)
        })
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
        handleEvent(.didDisconnectUnexpectedly)
    }
    
    // Call this method just before connecting the reader; simulatorConfiguration might be nil earlier.
    private func configureSimulator() {
        Terminal.shared.simulatorConfiguration.availableReaderUpdate = .random
    }
}

extension TerminalModel: ReaderConnectionDelegate {
    func readerConnection(_ sender: ReaderConnection, showReaderMessage message: String) {
        delegate?.stripeTerminalModel(self, display: message)
    }
    
    func readerConnectionDidStartInstallingUpdate(_ sender: ReaderConnection) {
        // In the case of mandatory updates, this method is called even before the connect() completion block is called!
        // The state machine handles it, as a transition from .connecting to .installingUpdate.
        handleEvent(.didBeginInstallingUpdate)
    }
    
    func readerConnection(_ sender: ReaderConnection, softwareUpdateDidProgress progress: Float) {
        delegate?.stripeTerminalModel(self, installingUpdateDidProgress: progress)
    }
    
    func readerConnectionDidFinishInstallingUpdate(_ sender: ReaderConnection) {
        handleEvent(.didEndInstallingUpdate)
    }
}


 extension Reader {
    var requiresImmediateUpdate: Bool {
        guard let availableUpdate = availableUpdate else { return false }
        return availableUpdate.requiredAt < Date()
    }
}
