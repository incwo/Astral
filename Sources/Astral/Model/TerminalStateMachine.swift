//
//  TerminalStateMachine.swift
//  
//
//  Created by Renaud Pradenc on 23/02/2022.
//

import Foundation
import StripeTerminal

/// A finite state machine to keep the state of Terminal
class TerminalStateMachine {
    init(readerSerialNumber: String?) {
        if let serialNumber = readerSerialNumber {
            self.state = DisconnectedState(serialNumber: serialNumber)
        } else {
            self.state = NoReaderState()
        }
    }
    
    private(set) var state: TerminalState
    
    enum Event {
        /// The user picked a Location among the list
        case didSelectLocation (Location)
        /// The user picked a Reader among the list
        case didSelectReader (Reader)
        /// The Reader is asked to connect again
        case reconnect
        /// A Reader was found by its serial number
        case didFindReader (Reader)
        
        /// The reader has just connected, with no pending automatic update
        case didConnect
        /// The Reader was disconnected unintentionally. This might be because it entered standby, ran out of battery, etc.
        case didDisconnectUnexpectedly
        /// The user wants to forget the current Reader
        case forgetReader
        /// The user wants to cancel the current action
        case cancel
        
        /// The installation of a software update has begun
        case didBeginInstallingUpdate
        /// The installation of a software updated has ended
        case didEndInstallingUpdate
        
        /// Begin the Payment process
        case charge
        /// Charging has ended. This may be because of success, cancelation or failure.
        case didEndCharging
    }
    
    func update(with event: Event) -> Result<TerminalState, Error> {
        if let newState = state.nextState(after: event) {
            self.state = newState
            return .success(newState)
        } else {
            return .failure(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "[Astral] State machine — Can not update state \(state) with event \(event)."]))
        }
    }
}

// MARK: States

protocol TerminalState {
    // nil is returned if the next state is not defined — which is unexpected
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState?
}

/// No reader is connected and no serial number is saved either
struct NoReaderState: TerminalState {
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didSelectLocation(_):
            return DiscoveringReadersState()
        default:
            return nil
        }
    }
}

/// No reader is connected, but a serial number is saved, so reconnecting can be attempted
struct DisconnectedState: TerminalState {
    let serialNumber: String
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .reconnect:
            return SearchingReaderState(serialNumber: serialNumber)
        default:
            return nil
        }
    }
}

/// Nearby readers are being listed
struct DiscoveringReadersState: TerminalState {
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didSelectReader(let reader):
            return ConnectingState(reader: reader)
        default:
            return nil
        }
    }
}

/// A reader is being searched by its serial number
struct SearchingReaderState: TerminalState {
    let serialNumber: String
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didFindReader(let reader):
            return ConnectingState(reader: reader)
        default:
            return nil
        }
    }
}

/// Establishing the connection with a Reader
struct ConnectingState: TerminalState {
    let reader: Reader
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didConnect:
            return ConnectedState(reader: reader)
        case .didBeginInstallingUpdate:
            return AutomaticUpdateState(reader: reader)
        default:
            return nil
        }
    }
}

/// The reader is connected and ready to accept payments
struct ConnectedState: TerminalState {
    let reader: Reader
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didBeginInstallingUpdate:
            return UserInitiatedUpdateState(reader: reader)
        case .charge:
            return ChargingState(reader: reader)
        case .didDisconnectUnexpectedly:
            return DisconnectedState(serialNumber: reader.serialNumber)
        case .forgetReader:
            return NoReaderState()
        default:
            return nil
        }
    }
}

/// A mandatory update is being installed on the Reader (initiated by Stripe Terminal at the end of connection)
struct AutomaticUpdateState: TerminalState {
    let reader: Reader
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didEndInstallingUpdate:
            return ConnectingState(reader: reader)
        default:
            return nil
        }
    }
}

/// An update is being installed on the Reader (user-initiated)
struct UserInitiatedUpdateState: TerminalState {
    let reader: Reader
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didEndInstallingUpdate:
            return ConnectedState(reader: reader)
        default:
            return nil
        }
    }
}

/// Processing a payment
struct ChargingState: TerminalState {
    let reader: Reader
    
    func nextState(after event: TerminalStateMachine.Event) -> TerminalState? {
        switch event {
        case .didEndCharging:
            return ConnectedState(reader: reader)
        case .didDisconnectUnexpectedly:
            return DisconnectedState(serialNumber: reader.serialNumber)
        default:
            return nil
        }
    }
}
