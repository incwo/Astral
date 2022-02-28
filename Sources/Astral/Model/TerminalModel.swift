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
    
    /// Informs about an error
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error)
}

class TerminalModel: NSObject {
    init(apiClient: AstralApiClient) {
        self.discovery = ReadersDiscovery()
        self.connection = ReaderConnection()
        self.paymentProcessor = PaymentProcessor(apiClient: apiClient)
        
        super.init()
        
        Terminal.shared.delegate = self
        connection.delegate = self
    }
    private let paymentProcessor: PaymentProcessor
    let discovery: ReadersDiscovery
    private let connection: ReaderConnection
    
    
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
        switch stateMachine.state {
        case is SearchingReaderState:
            discovery.cancel {
                self.stateMachine.handleSignal(.cancel)
            }
        case is DiscoveringReadersState:
            discovery.cancel() {
                self.stateMachine.handleSignal(.cancel)
            }
        case is ChargingState:
            paymentProcessor.cancel {
                completion?()
            }
        case is UserInitiatedUpdateState:
            NSLog("[Astral] \(#function) Canceling the installation of updates is not implemented yet.")
        default:
            NSLog("[Astral] \(#function) The current operation can not be canceled.")
        }
    }
    

    // MARK: State Machine
    
    lazy var stateMachine: TerminalStateMachine = {
        let stateMachine = TerminalStateMachine(dependencies: .init(discovery: discovery, connection: connection, paymentProcessor: paymentProcessor), readerSerialNumber: Self.serialNumber)
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
                NSLog("[Astral] State = \(state)")
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
