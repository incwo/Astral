//
//  Astral.swift
//  Stral
//
//  Created by Renaud Pradenc on 21/12/2021.
//

import Foundation
import UIKit
import StripeTerminal

public class Astral {
    public init(apiClient: AstralApiClient) {
        self.model = TerminalModel(apiClient: apiClient)
        self.model.delegate = self
    }
    
    private let model: TerminalModel
    
    public func presentSettings(from presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        
        coordinator = .settings(presentSettingsCoordinator())
    }
    
    private func presentSettingsCoordinator() -> SettingsCoordinator {
        guard let presentingViewController = presentingViewController else {
            fatalError("The presentingViewController should be set")
        }
        
        let settingsCoordinator = SettingsCoordinator(readersDiscovery: model.discovery)
        settingsCoordinator.delegate = self
        settingsCoordinator.presentSettings(from: presentingViewController, reader: model.reader)
        
        return settingsCoordinator
    }
    
    private var presentingViewController: UIViewController?
    public func charge(amount: NSDecimalNumber, currency: String, presentFrom presentingViewController: UIViewController, onSuccess: @escaping (PaymentInfo)->(), onError: @escaping (Error)->()) {
        self.presentingViewController = presentingViewController
        
        // Present the charge panel immediately. It can show the Reader connecting.
        let amountInCurrency = Amount(amount: amount, currency: currency)
        coordinator = .charge(presentChargeCoordinator(for: amountInCurrency))
        
        let charging = {
            self.chargeInternal(amount: amountInCurrency, onSuccess: onSuccess, onError: onError)
        }
        
        switch model.state {
        case .readerConnected:
            charging()
            
        default:
            // No reader is connected yet, so we'll charge later
            chargeLater = charging
        }
    }
    
    /// A block to charge later, after the reader is set up and ready
    private var chargeLater: (()->())?
    
    private func chargeInternal(amount: Amount, onSuccess: @escaping (PaymentInfo)->(), onError: @escaping (Error)->()) {
        model.charge(amount: amount) { result in
            DispatchQueue.main.async {
                self.presentingViewController?.dismiss(animated: true)
                self.coordinator = .none
                
                switch result {
                case .success(let stripePaymentInfo):
                    onSuccess(stripePaymentInfo)
                case .cancelled:
                    break
                case .error(let error):
                    onError(error)
                }
            }
        }
    }
    
    private func presentChargeCoordinator(for amount: Amount) -> ChargeCoordinator {
        guard let presentingViewController = presentingViewController else {
            fatalError("The presentingViewController should be set")
        }
        
        let chargeCoordinator = ChargeCoordinator()
        chargeCoordinator.delegate = self
        chargeCoordinator.present(for: .charging(amount: amount), from: presentingViewController)
    
        return chargeCoordinator
    }
    
    private enum PresentedCoordinator {
        case none
        case charge (ChargeCoordinator)
        case settings (SettingsCoordinator)
    }
    private var coordinator: PresentedCoordinator = .none
}

extension Astral: TerminalModelDelegate {
    func stripeTerminalModel(_ sender: TerminalModel, didUpdateState state: TerminalModel.State) {
        switch state {
        case .readerConnected(_):
            // A reader has just been connected, this is our chance to charge.
            if let chargeLater = chargeLater {
                chargeLater()
                self.chargeLater = nil
            } else {
                update(for: state)
            }
        default:
            update(for: state)
        }
    }
    
    private func update(for state: TerminalModel.State) {
        switch coordinator {
        case .none:
            NSLog("\(#function) Unexpected: receiving Model state update (\(state)) with no Coordinator presented.")
        case .charge(let coordinator):
            if !coordinator.update(for: state) {
                switchCoordinator(andHandle: state)
            }
        case .settings(let coordinator):
            if !coordinator.update(for: state) {
                switchCoordinator(andHandle: state)
            }
        }
    }
    
    private func switchCoordinator(andHandle state: TerminalModel.State) {
        presentingViewController?.dismiss(animated: true, completion: {
            self.coordinator = .none
            
            switch self.coordinator {
            case .none:
                break
            case .charge:
                let settingsCoordinator = self.presentSettingsCoordinator()
                self.coordinator = .settings(settingsCoordinator)
                let _ = settingsCoordinator.update(for: state)
            case .settings:
                #warning("Amount en dur")
                let chargeCoordinator = self.presentChargeCoordinator(for: Amount(amount: 1.0, currency: "EUR"))
                self.coordinator = .charge(chargeCoordinator)
                let _ = chargeCoordinator.update(for: state)
            }
        })

    }
    
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error) {
        NSLog("\(#function) error: \(error)")
    }
    
    func stripeTerminalModelNeedsSettingUp(_ sender: TerminalModel) {
//        guard let presentingViewController = presentingViewController else {
//            NSLog("\(#function) No presentingViewController")
//            return
//        }
//        presentSettings(from: presentingViewController)
    }
}

extension Astral: ChargeCoordinatorDelegate {
    func chargeCoordinatorWillDismiss() {
        coordinator = .none
    }
}

extension Astral: SettingsCoordinatorDelegate {
    func settingsCoordinatorWillDismiss(_ sender: SettingsCoordinator) {
        coordinator = .none
    }
    
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick location: Location) {
        model.location = location
    }
    
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick reader: Reader) {
        model.reader = reader
        model.connect()
    }
    
    func settingsCoordinatorRequestsReaderToUpdate(_ sender: SettingsCoordinator) -> Reader? {
        model.reader
    }
    
    func settingsCoordinatorDisconnectReader(_ sender: SettingsCoordinator) {
        model.disconnect()
    }
    
    func settingsCoordinatorInstallSoftwareUpdate(_ sender: SettingsCoordinator) {
        model.installUpdate()
    }
}
