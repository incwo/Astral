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
            self.state = .disconnected(serialNumber)
        } else {
            self.state = .noReader
        }
    }
    
    enum State: CustomStringConvertible {
        /// No reader is connected and no serial number is saved either
        case noReader
        /// No reader is connected, but a serial number is saved, so reconnecting can be attempted
        case disconnected (_ serialNumber: String)
        /// A reader is being searched by its serial number
        case searchingReader (_ serialNumber: String)
        /// Nearby readers are being listed
        case discoveringReaders
        /// Establishing the connection with a Reader
        case connecting (Reader)
        /// The reader is connected and ready to accept payments
        case connected (Reader)
        /// An update is being installed on the Reader (user-initiated)
        case userInitiatedUpdate (Reader)
        /// A mandatory update is being installed on the Reader (initiated by Stripe Terminal at the end of connection)
        case automaticUpdate (Reader)
        /// Processing a payment
        case charging (Reader)
        
        var description: String {
            switch self {
            case .noReader:
                return "noReader"
            case .disconnected(let serial):
                return "disconnected(\(serial))"
            case .searchingReader(let serial):
                return "searchingReader(\(serial))"
            case .discoveringReaders:
                return "discoveringReaders"
            case .connecting(let reader):
                return "connecting(\(reader.serialNumber))"
            case .connected(let reader):
                return "connected(\(reader.serialNumber))"
            case .userInitiatedUpdate(let reader):
                return "installingUpdate(\(reader.serialNumber))"
            case .automaticUpdate(let reader):
                return "installingMandatoryUpdate(\(reader.serialNumber))"
            case .charging(let reader):
                return "charging(\(reader.serialNumber))"
            }
        }
    }
    
    private(set) var state: State
    
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
    
    func update(with event: Event) -> Result<State, Error> {
        if let state = nextState(after: event) {
            self.state = state
            return .success(state)
        } else {
            return .failure(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "[Astral] State machine — Can not update state \(state) with event \(event)."]))
        }
    }
    
    // nil is returned if the next state is not defined — which is unexpected
    private func nextState(after event: Event) -> State? {
        switch state {
        case .noReader:
            switch event {
            case .didSelectLocation(_):
                return .discoveringReaders
            default:
                return nil
            }
            
        case .disconnected (let serialNumber):
            switch event {
            case .reconnect:
                return .searchingReader(serialNumber)
            default:
                return nil
            }
            
        case .searchingReader(_):
            switch event {
            case .didFindReader(let reader):
                return .connecting(reader)
            default:
                return nil
            }
            
        case .discoveringReaders:
            switch event {
            case .didSelectReader(let reader):
                return .connecting(reader)
            default:
                return nil
            }
            
        case .connecting(let reader):
            switch event {
            case .didConnect:
                return .connected(reader)
            case .didBeginInstallingUpdate:
                return .automaticUpdate(reader)
            default:
                return nil
            }
            
        case .connected(let reader):
            switch event {
            case .didBeginInstallingUpdate:
                return .userInitiatedUpdate(reader)
            case .charge:
                return .charging(reader)
            case .didDisconnectUnexpectedly:
                return .disconnected(reader.serialNumber)
            case .forgetReader:
                return .noReader
            default:
                return nil
            }
            
        case .userInitiatedUpdate(let reader):
            switch event {
            case .didEndInstallingUpdate:
                return .connected(reader)
            default:
                return nil
            }
            
        case .automaticUpdate(let reader):
            switch event {
            case .didEndInstallingUpdate:
                return .connecting(reader)
            default:
                return nil
            }

        case .charging(let reader):
            switch event {
            case .didEndCharging:
                return .connected(reader)
            case .didDisconnectUnexpectedly:
                return .disconnected(reader.serialNumber)
            default:
                return nil
            }

        }
    }
}
