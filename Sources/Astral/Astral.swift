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
        let settingsCoordinator = SettingsCoordinator(readersDiscovery: model.discovery)
        settingsCoordinator.delegate = self
        settingsCoordinator.presentSettings(from: presentingViewController, reader: model.reader)
        coordinator = .settings(settingsCoordinator)
    }
    
    private var presentingViewController: UIViewController?
    public func charge(amount: NSDecimalNumber, currency: String, presentFrom presentingViewController: UIViewController, onSuccess: @escaping (PaymentInfo)->(), onError: @escaping (Error)->()) {
        self.presentingViewController = presentingViewController
        
        let amountInCurrency = Amount(amount: amount, currency: currency)
        let chargeCoordinator = ChargeCoordinator()
        chargeCoordinator.delegate = self
        chargeCoordinator.present(for: .charging(amount: amountInCurrency), from: presentingViewController)
        coordinator = .charge(chargeCoordinator)
        
        model.charge(amount: amountInCurrency) { result in
            DispatchQueue.main.async {
                chargeCoordinator.dismiss()
                
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
    }
    
    private func update(for state: TerminalModel.State) {
        switch coordinator {
        case .none:
            NSLog("\(#function) Unexpected: receiving Model state update with no Coordinator presented.")
        case .charge(let coordinator):
            coordinator.update(for: state)
        case .settings(let coordinator):
            coordinator.update(for: state)
        }
    }
    
    func stripeTerminalModel(_sender: TerminalModel, didFailWithError error: Error) {
        NSLog("\(#function) error: \(error)")
    }
    
    func stripeTerminalModelNeedsSettingUp(_ sender: TerminalModel) {
        guard let presentingViewController = presentingViewController else {
            NSLog("\(#function) No presentingViewController")
            return
        }
        presentSettings(from: presentingViewController)
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
