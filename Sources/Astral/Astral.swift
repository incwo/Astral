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
    public static func initSharedInstance(apiClient: AstralApiClient) {
        guard shared == nil else {
            NSLog("[Astral] initSharedInstance may only be called once.")
            return
        }
        shared = Astral(apiClient: apiClient)
    }
    public static var shared: Astral?
    
    private init(apiClient: AstralApiClient) {
        self.model = TerminalModel(apiClient: apiClient)
        self.model.delegate = self
    }
    
    private let model: TerminalModel
    
    public func presentSettings(from presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        
        presentSettingsCoordinator() { coordinator in
            self.presentedCoordinator = .settings(coordinator)
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
        switch presentedCoordinator {
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
            self.presentedCoordinator = .charge(coordinator)
            
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
                    self.presentedCoordinator = .none
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
            let _ = chargeCoordinator.update(for: self.model.state)
            completion?(chargeCoordinator)
        })
    }
    
    private enum PresentedCoordinator {
        case none
        case charge (ChargeCoordinator)
        case settings (SettingsCoordinator)
    }
    private var presentedCoordinator: PresentedCoordinator = .none
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
        switch presentedCoordinator {
        case .none:
            //NSLog("\(#function) Unexpected: receiving Model state update with no Coordinator presented.")
            break
        case .charge(let coordinator):
            if !coordinator.update(for: state) {
                switchToSettingsCoordinator(andHandle: state)
            }
        case .settings(let coordinator):
            if !coordinator.update(for: state) {
                NSLog("\(#function) Unexpected state received by SettingsCoordinator: \(state)")
            }
        }
    }
    
    private func switchToSettingsCoordinator(andHandle state: TerminalModel.State) {
        self.presentedCoordinator = .none
        presentingViewController?.dismiss(animated: true, completion: {
            self.presentSettingsCoordinator() { coordinator in
                self.presentedCoordinator = .settings(coordinator)
                if !coordinator.update(for: state) {
                    NSLog("\(#function) Unexpected state received by SettingsCoordinator: \(state)")
                }
            }
        })
    }
    
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error) {
        presentAlert(for: error)
    }
    
    private func presentAlert(for error: Error) {
        let presentationViewController: UIViewController?
        switch presentedCoordinator {
        case .none:
            presentationViewController = nil
        case .charge(let coordinator):
            presentationViewController = coordinator.presentationViewController
        case .settings(let coordinator):
            presentationViewController = coordinator.presentationViewController
        }
        
        if let presentationViewController = presentationViewController {
            let alert = UIAlertController(title: "Stripe Terminal", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            presentationViewController.present(alert, animated: true, completion: nil)
        } else {
            NSLog("[Astral] an error occured: \(error)")
        }
    }
}

extension Astral: ChargeCoordinatorDelegate {
    func chargeCoordinatorWillDismiss(_ sender: ChargeCoordinator) {
        presentedCoordinator = .none
        model.cancel(completion: nil)
    }
    
    func chargeCoordinatorCancel(_ sender: ChargeCoordinator) {
        model.cancel {
            sender.dismiss()
        }
    }
}

extension Astral: SettingsCoordinatorDelegate {
    func settingsCoordinatorWillDismiss(_ sender: SettingsCoordinator) {
        presentedCoordinator = .none
    }
    
    func settingsCoordinator(_ sender: SettingsCoordinator, didFail error: Error) {
        presentAlert(for: error)
    }
    
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick location: Location) {
        model.location = location
    }
    
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick reader: Reader) {
        model.reader = reader
        model.connect()
    }
    
    func settingsCoordinatorCancelSearchingReader(_ sender: SettingsCoordinator) {
        model.cancel(completion: nil)
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
