//
//  TerminalStateMachine.swift
//  
//
//  Created by Renaud Pradenc on 23/02/2022.
//

import Foundation
import StripeTerminal

protocol SignalHandling {
    func handleSignal(_ signal: TerminalSignal)
}

/// A finite state machine to keep the state of Terminal
class TerminalStateMachine: SignalHandling {
    
    struct Dependencies {
        let discovery: ReadersDiscovery
        let onReadersDiscovered: ([Reader])->()
        let connection: ReaderConnection
        let paymentProcessor: PaymentProcessor
    }
    
    var onSignalReceived: ((TerminalSignal)->())?
    var onStateUpdated: ((TerminalState)->())?
    
    init(dependencies: Dependencies, readerSerialNumber: String?) {
        self.dependencies = dependencies
        if let serialNumber = readerSerialNumber {
            self.state = DisconnectedState(dependencies: dependencies, serialNumber: serialNumber)
        } else {
            self.state = NoReaderState(dependencies: dependencies)
        }
    }
    let dependencies: Dependencies
    
    private(set) var state: TerminalState {
        didSet {
            onStateUpdated?(state)
        }
    }
    
    func handleSignal(_ signal: TerminalSignal) {
        onSignalReceived?(signal)
        guard let newState = state.nextState(after: signal) else {
            handleSignal(.failure(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "[Astral] State machine — Can not update state \(state) with signal \(signal)."])))
            return
        }
        
        self.state = newState
        newState.enter(signalHandler: self)
    }
    
    func cancel(completion: (()->())?) {
        state.cancel { [weak self] in
            self?.handleSignal(.canceled)
        }
    }
}

// MARK: Signals

enum TerminalSignal {
    /// The user picked a Location among the list
    case didSelectLocation (Location)
    /// The user picked a Reader among the list
    case didSelectReader (Reader)
    /// The Reader is asked to connect again
    case reconnect
    /// A Reader was found by its serial number
    case didFindReader (Reader)
    
    /// The reader has just been connected
    case didConnect
    /// The reader has been disconnected volontarily
    case didDisconnect
    /// The Reader was disconnected unintentionally. This might be because it entered standby, ran out of battery, etc.
    case didDisconnectUnexpectedly
    /// The user wants to forget the current Reader
    case forgetReader
    
    /// The installation of a software update has begun
    case didBeginInstallingUpdate
    /// The installation of a software updated has ended
    case didEndInstallingUpdate
    
    /// Begin the Payment process
    case charge (CurrencyAmount)
    /// Charging has ended. This may be because of success, cancelation or failure.
    case didEndCharging (ChargeResult)
    
    /// The user canceled the State's action
    case canceled
    /// An error occurred
    case failure (Error)
}

extension TerminalSignal: CustomStringConvertible {
    var description: String {
        switch self {
            
        case .didSelectLocation(let location):
            return "didSelectLocation(\(location.displayName ?? location.description)"
        case .didSelectReader(let reader):
            return "didSelectReader(\(reader.serialNumber)"
        case .reconnect:
            return "reconnect"
        case .didFindReader(let reader):
            return "didFindReader(\(reader.serialNumber)"
        case .didConnect:
            return "didConnect"
        case .didDisconnect:
            return "didDisconnect"
        case .didDisconnectUnexpectedly:
            return "didDisconnectUnexpectedly"
        case .forgetReader:
            return "forgetReader"
        case .didBeginInstallingUpdate:
            return "didBeginInstallingUpdate"
        case .didEndInstallingUpdate:
            return "didEndInstallingUpdate"
        case .charge(let amount):
            return "charge(\(amount))"
        case .didEndCharging(let result):
            return "didEndCharging(\(result)"
        case .canceled:
            return "canceled"
        case .failure(let error):
            return "failure(\(error)"
        }
    }
}

// MARK: States

protocol TerminalState {
    var dependencies: TerminalStateMachine.Dependencies {get}
    
    /// Create the next state after a signal is received
    ///
    /// nil is returned if the next state is not defined — which is unexpected.
    func nextState(after event: TerminalSignal) -> TerminalState?
    
    /// Called when the State is entered. The state should begin its processing if any.
    func enter(signalHandler: SignalHandling)
    
    /// Cancel the processing performed by the State
    func cancel(completion: @escaping ()->())
}

extension TerminalState {
    func enter(signalHandler: SignalHandling) {
        // Do nothing
    }
    
    func cancel(completion: @escaping ()->()) {
        NSLog("[Astral] \(#function) The current operation can not be canceled.")
        completion()
    }
}

/// No reader is connected and no serial number is saved either
struct NoReaderState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didSelectLocation(let location):
            return DiscoveringReadersState(dependencies: dependencies, location: location)
        default:
            return nil
        }
    }
}

extension NoReaderState: CustomStringConvertible {
    var description: String {
        "NoReader"
    }
}

/// No reader is connected, but a serial number is saved, so reconnecting can be attempted
struct DisconnectedState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let serialNumber: String
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .reconnect:
            return SearchingReaderState(dependencies: dependencies, serialNumber: serialNumber)
        default:
            return nil
        }
    }
}

extension DisconnectedState: CustomStringConvertible {
    var description: String {
        "Disconnected (serialNumber=\(serialNumber)"
    }
}

/// Nearby readers are being listed
struct DiscoveringReadersState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let location: Location
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didSelectReader(let reader):
            return ConnectingState(dependencies: dependencies, location: location, reader: reader)
            
        case .didSelectLocation(let location):
            // A new location is selected while searching for readers at a previous location
            return DiscoveringReadersState(dependencies: dependencies, location: location)
            
        case .canceled, .failure(_):
            return NoReaderState(dependencies: dependencies)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        dependencies.discovery.cancel {
            dependencies.discovery.discoverReaders(
                onUpdate: dependencies.onReadersDiscovered,
                onError: { error in
                    signalHandler.handleSignal(.failure(error))
            })
        }
    }
    
    func cancel(completion: @escaping () -> ()) {
        dependencies.discovery.cancel(completion: completion)
    }
}

extension DiscoveringReadersState: CustomStringConvertible {
    var description: String {
        "DiscoveringReaders (location='\(location.displayName ?? location.description)')"
    }
}

/// A reader is being searched by its serial number
struct SearchingReaderState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let serialNumber: String
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didFindReader(let reader):
            return ConnectingState(dependencies: dependencies, location: nil, reader: reader)
            
        case .canceled, .failure(_):
            // We might never see the reader again. At least allow selecting an other one
            return NoReaderState(dependencies: dependencies)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        dependencies.discovery.findReader(serialNumber: serialNumber) { result in
            switch result {
            case .found(let reader):
                signalHandler.handleSignal(.didFindReader(reader))
            case .failure(let error):
                signalHandler.handleSignal(.failure(error))
            }
        }
    }
    
    func cancel(completion: @escaping () -> ()) {
        dependencies.discovery.cancel(completion: completion)
    }
}

extension SearchingReaderState: CustomStringConvertible {
    var description: String {
        "SearchingReader (serialNumber = \(serialNumber))"
    }
}

/// Establishing the connection with a Reader
struct ConnectingState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let location: Location?
    let reader: Reader
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didConnect:
            return ConnectedState(dependencies: dependencies, reader: reader)
        case .didBeginInstallingUpdate:
            return AutomaticUpdateState(dependencies: dependencies, location: location, reader: reader)
            
        case .failure(_):
            // Probably we can never connect the reader, just forget it
            return NoReaderState(dependencies: dependencies)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        guard Terminal.shared.connectedReader == nil else {
            signalHandler.handleSignal(.didConnect)
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
            signalHandler.handleSignal(.failure(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not get the locationId"])))
            return
        }
        
        dependencies.connection.connect(reader, locationId: locationId, onSuccess: {
            signalHandler.handleSignal(.didConnect)
        }, onFailure: { error in
            signalHandler.handleSignal(.failure(error))
        })
    }
    
    // Call this method just before connecting the reader; simulatorConfiguration might be nil earlier.
    private func configureSimulator() {
        Terminal.shared.simulatorConfiguration.availableReaderUpdate = .available //.random
    }
}

extension ConnectingState: CustomStringConvertible {
    var description: String {
        "Connecting (location='\(location?.displayName ?? "nil")'; reader=\(reader.serialNumber))"
    }
}

struct DisconnectingState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didDisconnect:
            return NoReaderState(dependencies: dependencies)
            
        case .failure(_):
            return NoReaderState(dependencies: dependencies)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        dependencies.connection.disconnect(onSuccess: {
            signalHandler.handleSignal(.didDisconnect)
        }, onFailure: { error in
            signalHandler.handleSignal(.failure(error))
        })
    }
}

extension DisconnectingState: CustomStringConvertible {
    var description: String {
        "Disconnecting"
    }
}

/// The reader is connected and ready to accept payments
struct ConnectedState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let reader: Reader
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
            // Stripe made a poor design decision, since at the end of an automatic update, readerConnectionDidFinishInstallingUpdate() is called BEFORE the completion block of Terminal.connectBluetoothReader().
            // Since the .didConnect signal is emitted at the end of this completion block, it is simply ignored here.
        case .didConnect:
            return self
            
        case .didBeginInstallingUpdate:
            return UserInitiatedUpdateState(dependencies: dependencies, reader: reader)
        case .charge (let amount):
            return ChargingState(dependencies: dependencies, reader: reader, currencyAmount: amount)
        case .didDisconnectUnexpectedly:
            return DisconnectedState(dependencies: dependencies, serialNumber: reader.serialNumber)
        case .forgetReader:
            return DisconnectingState(dependencies: dependencies)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        // Discovery may only be stopped AFTER the Reader is connected
        dependencies.discovery.cancel(completion: nil)
    }
}

extension ConnectedState: CustomStringConvertible {
    var description: String {
        "Connected (reader=\(reader.serialNumber))"
    }
}

/// A mandatory update is being installed on the Reader (initiated by Stripe Terminal at the end of connection)
struct AutomaticUpdateState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let location: Location?
    let reader: Reader
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didEndInstallingUpdate:
            return ConnectedState(dependencies: dependencies, reader: reader)
        default:
            return nil
        }
    }
}

extension AutomaticUpdateState: CustomStringConvertible {
    var description: String {
        "AutomaticUpdate (reader=\(reader.serialNumber)"
    }
}

/// An update is being installed on the Reader (user-initiated)
struct UserInitiatedUpdateState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let reader: Reader
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didEndInstallingUpdate:
            return ConnectedState(dependencies: dependencies, reader: reader)
        default:
            return nil
        }
    }
}

extension UserInitiatedUpdateState: CustomStringConvertible {
    var description: String {
        "UserInitiatedUpdate (reader=\(reader.serialNumber))"
    }
}

/// Processing a payment
struct ChargingState: TerminalState {
    let dependencies: TerminalStateMachine.Dependencies
    let reader: Reader
    let currencyAmount: CurrencyAmount
    
    func nextState(after event: TerminalSignal) -> TerminalState? {
        switch event {
        case .didEndCharging:
            return ConnectedState(dependencies: dependencies, reader: reader)
        case .didDisconnectUnexpectedly:
            return DisconnectedState(dependencies: dependencies, serialNumber: reader.serialNumber)
            
        case .canceled, .failure(_):
            return ConnectedState(dependencies: dependencies, reader: reader)
        default:
            return nil
        }
    }
    
    func enter(signalHandler: SignalHandling) {
        dependencies.paymentProcessor.charge(currencyAmount: currencyAmount) { result in
            signalHandler.handleSignal(.didEndCharging(result))
        }
    }
    
    func cancel(completion: @escaping () -> ()) {
        dependencies.paymentProcessor.cancel(completion: completion)
    }
}

extension ChargingState: CustomStringConvertible {
    var description: String {
        "Charging (reader= \(reader.serialNumber); amount=\(currencyAmount))"
    }
}
