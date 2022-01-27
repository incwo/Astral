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
        self.model = StripeTerminalModel(apiClient: apiClient)
        //super.init()
        self.model.delegate = self
    }
    
    private let model: StripeTerminalModel
    
    public func presentSettings(from presentingViewController: UIViewController) {
        let settingsCoordinator = StripeSettingsCoordinator(readersDiscovery: model.discovery)
        settingsCoordinator.delegate = self
        settingsCoordinator.presentSettings(from: presentingViewController, reader: model.reader)
        coordinator = .settings(settingsCoordinator)
    }
    
    private var presentingViewController: UIViewController?
    public func charge(amount: NSDecimalNumber, currency: String, presentFrom presentingViewController: UIViewController, onSuccess: @escaping (StripePaymentInfo)->(), onError: @escaping (Error)->()) {
        self.presentingViewController = presentingViewController
        
        let chargeCoordinator = StripeChargeCoordinator()
        chargeCoordinator.delegate = self
        chargeCoordinator.present(for: .charging(amount: amount, currencyCode: currency), from: presentingViewController)
        coordinator = .charge(chargeCoordinator)
        
        model.charge(amount: amount, currency: currency) { result in
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
        case charge (StripeChargeCoordinator)
        case settings (StripeSettingsCoordinator)
    }
    private var coordinator: PresentedCoordinator = .none
}

extension Astral: StripeTerminalModelDelegate {
    func stripeTerminalModel(_ sender: StripeTerminalModel, didUpdateState state: StripeTerminalModel.State) {
        switch coordinator {
        case .none:
            NSLog("\(#function) Unexpected: receiving Model state update with no Coordinator presented.")
        case .charge(let coordinator):
            updateChargeCoordinator(coordinator, for: state)
        case .settings(let coordinator):
            updateSettingsCoordinator(coordinator, for: state)
        }
    }
    
    private func updateChargeCoordinator(_ chargeCoordinator: StripeChargeCoordinator, for state: StripeTerminalModel.State) {
        switch state {
        case .noReaderConnected:
            break
            
        case .searchingReader(_):
            chargeCoordinator.status = .searchingReader
            
        case .discoveringReaders:
            break
            
        case .connecting:
            chargeCoordinator.status = .connectingReader
            
        case .readerConnected (_):
            chargeCoordinator.status = .connected
            
        case .charging(let message):
            chargeCoordinator.status = .charging(message: message)
            
        case .installingUpdate (_):
            break
        }
    }
    
    private func updateSettingsCoordinator(_ settingsCoordinator: StripeSettingsCoordinator, for state: StripeTerminalModel.State) {
        switch state {
        case .noReaderConnected:
            settingsCoordinator.update(for: .didDisconnect)
            
        case .searchingReader(_):
            settingsCoordinator.update(for: .didBeginSearchingReader)
            
        case .discoveringReaders:
            settingsCoordinator.update(for: .didBeginDiscoveringReaders)
            
        case .connecting:
            settingsCoordinator.update(for: .didBeginConnecting)
            
        case .readerConnected (let reader):
            settingsCoordinator.update(for: .didConnectReader(reader))
            
        case .charging(_):
            break
            
        case .installingUpdate (let reader):
            settingsCoordinator.update(for: .didBeginInstallingUpdate(reader))
        }
    }
    
    func stripeTerminalModel(_sender: StripeTerminalModel, didFailWithError error: Error) {
        NSLog("\(#function) error: \(error)")
    }
    
    func stripeTerminalModelNeedsSettingUp(_ sender: StripeTerminalModel) {
        guard let presentingViewController = presentingViewController else {
            NSLog("\(#function) No presentingViewController")
            return
        }
        presentSettings(from: presentingViewController)
    }
    
    func stripeTerminalModel(_ sender: StripeTerminalModel, softwareUpdateDidProgress progress: Float) {
        switch coordinator {
        case .settings(let coordinator):
            coordinator.update(for: .didProgressInstallingUpdate(progress))
        default:
            break
        }
    }
}

extension Astral: StripeChargeCoordinatorDelegate {
    func chargeCoordinatorWillDismiss() {
        coordinator = .none
    }
}

extension Astral: StripeSettingsCoordinatorDelegate {
    func settingsCoordinatorWillDismiss(_ sender: StripeSettingsCoordinator) {
        coordinator = .none
    }
    
    func settingsCoordinator(_ sender: StripeSettingsCoordinator, didPick location: Location) {
        model.location = location
    }
    
    func settingsCoordinator(_ sender: StripeSettingsCoordinator, didPick reader: Reader) {
        model.reader = reader
        model.connect()
    }
    
    func settingsCoordinatorRequestsReaderToUpdate(_ sender: StripeSettingsCoordinator) -> Reader? {
        model.reader
    }
    
    func settingsCoordinatorDisconnectReader(_ sender: StripeSettingsCoordinator) {
        model.disconnect()
    }
    
    func settingsCoordinatorInstallSoftwareUpdate(_ sender: StripeSettingsCoordinator) {
        model.installUpdate()
    }
}
