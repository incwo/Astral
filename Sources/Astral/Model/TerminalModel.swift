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
    func stripeTerminalModel(_ sender: TerminalModel, didUpdateState state: TerminalState)
    
    /// Asks to show a payment message issued by the terminal
    func stripeTerminalModel(_ sender: TerminalModel, display message: String)
    
    /// Informs about the progress of the installation of the update
    func stripeTerminalModel(_ sender: TerminalModel, installingUpdateDidProgress progress: Float)
    
    /// Informs whether the Discovering of readers is being performed.
    func stripeTerminalModel(_ sender: TerminalModel, isDiscovering: Bool)
    
    /// Informs about the discovery of readers.
    ///
    /// This method is called repeatedly while discovering and the list of readers is updated.
    func stripeTerminalModel(_ sender: TerminalModel, didDiscoverReaders readers: [Reader])
    
    /// Informs about an error
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error)
}

class TerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.paymentProcessor = PaymentProcessor(apiClient: apiClient)
        
        super.init()
        
        Terminal.shared.delegate = self
        connection.delegate = self
    }
    private let paymentProcessor: PaymentProcessor
    private let connection = ReaderConnection()
    
    private lazy var discovery: ReadersDiscovery = {
        return ReadersDiscovery(onIsDiscovering: { [weak self] isDiscovering in
            guard let self = self else { return }
            self.delegate?.stripeTerminalModel(self, isDiscovering: isDiscovering)
        })
    }()
    
    weak var delegate: TerminalModelDelegate?

    // MARK: Events
    
    /// Handle a Location picked by the user
    func didSelectLocation(_ location: Location) {
        stateMachine.handleSignal(.didSelectLocation(location))
    }
    
    /// Handle a Reader picked by the user
    func didSelectReader(_ reader: Reader) {
        stateMachine.handleSignal(.didSelectReader(reader))
    }
    
    /// Forget the current reader, so it's disconnected and its serial number is forgotten
    func forgetReader() {
        stateMachine.handleSignal(.forgetReader)
    }
    
    func reconnect() {
        stateMachine.handleSignal(.reconnect)
    }
    
    /// Charge an amount
    func charge(currencyAmount: CurrencyAmount, completion: @escaping (ChargeResult)->()) {
        self.chargeCompletion = { [weak self] result in
            completion(result)
            self?.chargeCompletion = nil
        }
        stateMachine.handleSignal(.charge(currencyAmount))
    }
    // The charge completion closure is kept until a .didEndCharging signal is received
    var chargeCompletion: ((ChargeResult)->())?
    
    /// Begin the installation of the software update
    func installUpdate() {
        Terminal.shared.installAvailableUpdate()
    }
    
    /// Cancel the current operation
    func cancel(completion: (()->())?) {
        stateMachine.cancel(completion: completion)
    }
    

    // MARK: State Machine
    
    lazy var stateMachine: TerminalStateMachine = {
        let onReadersDiscovered = { [weak self] (readers: [Reader]) in
            guard let self = self else { return }
            self.delegate?.stripeTerminalModel(self, didDiscoverReaders: readers)
        }
        let stateMachine = TerminalStateMachine(
            dependencies: .init(discovery: discovery, onReadersDiscovered: onReadersDiscovered, connection: connection, paymentProcessor: paymentProcessor),
            readerSerialNumber: Self.serialNumber)
        stateMachine.onSignalReceived = { [weak self] signal in
            switch signal {
            case .didSelectReader(let reader):
                self?.saveReaderSerialNumber(reader.serialNumber)
            case .didDisconnect:
                self?.saveReaderSerialNumber(nil)
            case .didEndCharging(let result):
                DispatchQueue.main.async { [weak self] in
                    self?.chargeCompletion?(result)
                }
                
            case .failure(let error):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.stripeTerminalModel(_sender: self, didFailWithError: error)
                }
                
            default:
                break
            }
        }
        stateMachine.onStateUpdated = { state in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                #if DEBUG
                NSLog("[Astral] State = \(state)")
                #endif
                self.delegate?.stripeTerminalModel(self, didUpdateState: state)
            }
        }
        
        return stateMachine
    }()
    
    /// Relays the current state of the state machine
    var state: TerminalState {
        stateMachine.state
    }

    // MARK: Serial Number
    
    // The serial number of the last reader is saved to the User defaults, so it can be reconnected automatically
    
    private func saveReaderSerialNumber(_ serialNumber: String?) {
        UserDefaults.standard.set(serialNumber, forKey: Self.serialNumberUserDefaultsKey)
    }
    
    private static var serialNumber: String? {
        UserDefaults.standard.string(forKey: serialNumberUserDefaultsKey)
    }
    
    private static let serialNumberUserDefaultsKey = "Astral.reader.serialNumber"
}

extension TerminalModel: TerminalDelegate {
    func terminal(_ terminal: Terminal, didReportUnexpectedReaderDisconnect reader: Reader) {
        stateMachine.handleSignal(.didDisconnectUnexpectedly)
    }
}

extension TerminalModel: ReaderConnectionDelegate {
    func readerConnection(_ sender: ReaderConnection, showReaderMessage message: String) {
        delegate?.stripeTerminalModel(self, display: message)
    }
    
    func readerConnectionDidStartInstallingUpdate(_ sender: ReaderConnection) {
        // In the case of mandatory updates, this method is called even before the connect() completion block is called!
        // The state machine handles it, as a transition from .connecting to .installingUpdate.
        stateMachine.handleSignal(.didBeginInstallingUpdate)
    }
    
    func readerConnection(_ sender: ReaderConnection, softwareUpdateDidProgress progress: Float) {
        delegate?.stripeTerminalModel(self, installingUpdateDidProgress: progress)
    }
    
    func readerConnectionDidFinishInstallingUpdate(_ sender: ReaderConnection) {
        stateMachine.handleSignal(.didEndInstallingUpdate)
    }
}


 extension Reader {
    var requiresImmediateUpdate: Bool {
        guard let availableUpdate = availableUpdate else { return false }
        return availableUpdate.requiredAt < Date()
    }
}
