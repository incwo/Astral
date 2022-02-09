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
        
        presentSettingsCoordinator() { coordinator in
            self.coordinator = .settings(coordinator)
        }
    }
    
    private func presentSettingsCoordinator(completion: ((SettingsCoordinator)->())?) {
        guard let presentingViewController = presentingViewController else {
            fatalError("The presentingViewController should be set")
        }
        
        let settingsCoordinator = SettingsCoordinator(readersDiscovery: model.discovery)
        settingsCoordinator.delegate = self
        settingsCoordinator.presentSettings(from: presentingViewController, reader: model.reader) {
            let _ = settingsCoordinator.update(for: self.model.state)
            completion?(settingsCoordinator)
        }
    }
    
    private var presentingViewController: UIViewController?
    public func charge(amount: NSDecimalNumber, currency: String, presentFrom presentingViewController: UIViewController, completion: @escaping (ChargeResult)->()) {
        switch coordinator {
        case .none:
            break
        case .charge(_):
            completion(.failure(NSError(domain: #file, code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot charge. The Charge panel is already shown."])))
            return
        case .settings(_):
            completion(.failure(NSError(domain: #file, code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot charge. The Setup panel is already shown."])))
            return
        }
        
        self.presentingViewController = presentingViewController
        
        // If no reader is set up, show the Settings panel
        switch model.state {
        case .noReader:
            presentSettings(from: presentingViewController)
            return
        default:
            break
        }
        
        // Present the charge panel.
        // It might close soon if a required update begins
        
        let amountInCurrency = CurrencyAmount(amount: amount, currency: currency)
        let charging = {
            self.chargeInternal(amount: amountInCurrency, completion: completion)
        }
    
        presentChargeCoordinator(for: amountInCurrency) { coordinator in
            self.coordinator = .charge(coordinator)
            
            switch self.model.state {
            case .ready:
                charging()
                
            default:
                // No reader is connected yet, so we'll charge later
                self.chargeLater = charging
            }
        }
    }
    
    /// A block to charge later, after the reader is set up and ready
    private var chargeLater: (()->())?
    
    private func chargeInternal(amount: CurrencyAmount, completion: @escaping (ChargeResult)->()) {
        model.charge(currencyAmount: amount) { result in
            DispatchQueue.main.async {
                self.presentingViewController?.dismiss(animated: true) {
                    self.coordinator = .none
                    completion(result)
                }
            }
        }
    }
    
    private func presentChargeCoordinator(for amount: CurrencyAmount, completion: ((ChargeCoordinator)->())?) {
        guard let presentingViewController = presentingViewController else {
            fatalError("The presentingViewController should be set")
        }
        
        let chargeCoordinator = ChargeCoordinator()
        chargeCoordinator.delegate = self
        chargeCoordinator.present(for: .charging(amount: amount), from: presentingViewController, completion: {
            completion?(chargeCoordinator)
        })
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
        update(for: state)
        
        switch state {
        case .ready:
            // The reader has just become ready, this is our chance to charge.
            if let chargeLater = chargeLater {
                chargeLater()
                self.chargeLater = nil
            }
        default:
            break
        }
    }
    
    private func update(for state: TerminalModel.State) {
        switch coordinator {
        case .none:
            //NSLog("\(#function) Unexpected: receiving Model state update with no Coordinator presented.")
            break
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
        // Updates to the state can be received while the coordinator is presenting
        let previousPresentedCoordinator = self.coordinator
        self.coordinator = .none
        
        presentingViewController?.dismiss(animated: true, completion: {
            switch previousPresentedCoordinator {
            case .none:
                break
            case .charge:
                self.presentSettingsCoordinator() { coordinator in
                    self.coordinator = .settings(coordinator)
                    let _ = coordinator.update(for: state)
                }
            case .settings:
            #warning("Amount en dur")
                self.presentChargeCoordinator(for: CurrencyAmount(amount: 1.0, currency: "EUR")) { coordinator in
                    self.coordinator = .charge(coordinator)
                    let _ = coordinator.update(for: state)
                }
            }
        })
    }
    
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error) {
        NSLog("\(#function) error: \(error)")
    }
}

extension Astral: ChargeCoordinatorDelegate {
    func chargeCoordinatorWillDismiss() {
        coordinator = .none
    }
    
    func chargeCoordinatorCancel() {
        model.cancelCharging()
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
