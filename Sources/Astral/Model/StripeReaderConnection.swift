//
//  StripeReaderConnection.swift
//  ProtoStripe
//
//  Created by Renaud Pradenc on 17/12/2021.
//

import Foundation
import StripeTerminal

protocol StripeReaderConnectionDelegate: AnyObject {
    func readerConnection(_ sender: StripeReaderConnection, showReaderMessage message: String)
    func readerConnectionDidStartInstallingUpdate(_ sender: StripeReaderConnection)
    func readerConnection(_ sender: StripeReaderConnection, softwareUpdateDidProgress progress: Float)
    func readerConnectionDidFinishInstallingUpdate(_ sender: StripeReaderConnection)
}

/// Handle connections with Stripe terminals
class StripeReaderConnection: NSObject {
    
    weak var delegate: StripeReaderConnectionDelegate?
    
    /// Connect a Bluetooth Reader
    func connect(_ reader: Reader, locationId: String, onSuccess: @escaping ()->(), onFailure: @escaping (Error)->()) {
        guard reader.deviceType.usesBluetoothConnection else {
            onFailure(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Only Bluetooth readers are supported."]))
            return
        }
        
        let config = BluetoothConnectionConfiguration(locationId: locationId)
        Terminal.shared.connectBluetoothReader(reader, delegate: self, connectionConfig: config, completion: { reader, error in
            if let _ = reader {
                onSuccess()
            } else if let error = error {
                onFailure(error)
            }
        })
    }
    
    /// Disconnect the Reader
    func disconnect(onSuccess: @escaping ()->(), onFailure: @escaping (Error)->()) {
        Terminal.shared.disconnectReader { error in
            if let error = error {
                onFailure(error)
            } else {
                onSuccess()
            }
        }
    }
}

extension StripeReaderConnection: BluetoothReaderDelegate {
    func reader(_ reader: Reader, didReportAvailableUpdate update: ReaderSoftwareUpdate) {
        // This method is not used.
    }
    
    func reader(_ reader: Reader, didStartInstallingUpdate update: ReaderSoftwareUpdate, cancelable: Cancelable?) {
        // Updates become mandatory after a while, so this method may be called just after connecting the reader without explicitely requiring an update.
        delegate?.readerConnectionDidStartInstallingUpdate(self)
    }
    
    func reader(_ reader: Reader, didReportReaderSoftwareUpdateProgress progress: Float) {
        delegate?.readerConnection(self, softwareUpdateDidProgress: progress)
    }
    
    func reader(_ reader: Reader, didFinishInstallingUpdate update: ReaderSoftwareUpdate?, error: Error?) {
        delegate?.readerConnectionDidFinishInstallingUpdate(self)
    }
    
    func reader(_ reader: Reader, didRequestReaderInput inputOptions: ReaderInputOptions = []) {
        // The reader is waiting for the user to pay with her card.
        // inputOptions describes the payment action (swipe, insert or tap the card).
        delegate?.readerConnection(self, showReaderMessage: inputOptions.localizedString)
    }
    
    func reader(_ reader: Reader, didRequestReaderDisplayMessage displayMessage: ReaderDisplayMessage) {
        // It is asked to show a message to the user like "Insert your card"
        // It looks redundant with reader(_:, didRequestReaderInput:) but they do not seem to be called simultaneously.
        delegate?.readerConnection(self, showReaderMessage: displayMessage.localizedString)
    }
    
    /* Optional methods
    
    func reader(_ reader: Reader, didReportReaderEvent event: ReaderEvent, info: [AnyHashable : Any]?) {
        
    }
    
    func reader(_ reader: Reader, didReportBatteryLevel batteryLevel: Float, status: BatteryStatus, isCharging: Bool) {
        
    }
    
    func readerDidReportLowBatteryWarning(_ reader: Reader) {
        
    }
     
    */
}


extension DeviceType {
    var usesBluetoothConnection: Bool {
        switch self {
        case .chipper1X, .chipper2X, .wisePad3, .stripeM2, .wiseCube:
            return true
        case .verifoneP400, .wisePosE:
            return false
        @unknown default:
            return false
        }
    }
}

extension ReaderInputOptions {
    var localizedString: String {
        guard self == [] else {
            return ""
        }
        
        var options = [String]()
        if self.contains(.swipeCard) {
            options.append("swipe")
        }
        if self.contains(.insertCard) {
            options.append("insert")
        }
        if self.contains(.tapCard) {
            options.append("tap")
        }
        let localizationKey = "Terminal.inputOption.\(options.joined(separator: "_"))"
        return locz(localizationKey)
    }
}

extension ReaderDisplayMessage {
    var localizedString: String {
        let prefix = "Terminal.readerDisplayMessage."
        switch self {
        case .retryCard:
            return locz(prefix+"retryCard")
        case .insertCard:
            return locz(prefix+"insertCard")
        case .insertOrSwipeCard:
            return locz(prefix+"insertOrSwipeCard")
        case .swipeCard:
            return locz(prefix+"swipeCard")
        case .removeCard:
            return locz(prefix+"removeCard")
        case .multipleContactlessCardsDetected:
            return locz(prefix+"multipleContactlessCardsDetected")
        case .tryAnotherReadMethod:
            return locz(prefix+"tryAnotherReadMethod")
        case .tryAnotherCard:
            return locz(prefix+"tryAnotherCard")
        @unknown default:
            return Terminal.stringFromReaderDisplayMessage(self)
        }
    }
}
