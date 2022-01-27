//
//  StripeSettingsCoordinator.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 24/01/2022.
//

import Foundation
import UIKit
import StripeTerminal

protocol StripeSettingsCoordinatorDelegate: AnyObject {
    /// Tells that the Settings panel is about to close
    func settingsCoordinatorWillDismiss(_ sender: StripeSettingsCoordinator)
    
    /// Tells that the User chose a Location among the list
    func settingsCoordinator(_ sender: StripeSettingsCoordinator, didPick location: Location)
    
    /// Tells that the User chose a Reader among the list of ones available at the current location
    func settingsCoordinator(_ sender: StripeSettingsCoordinator, didPick reader: Reader)
    
    /// Asks the delegate for the Reader to update.
    ///
    /// The reader object is needed to show the current version and the one to install.
    func settingsCoordinatorRequestsReaderToUpdate(_ sender: StripeSettingsCoordinator) -> Reader?
    
    /// Asks the delegate to disconnect the current Reader
    func settingsCoordinatorDisconnectReader(_ sender: StripeSettingsCoordinator)
    
    /// Asks the delegate to install the Reader's software update
    func settingsCoordinatorInstallSoftwareUpdate(_ sender: StripeSettingsCoordinator)
}

/// A coordinator for the Settings panel
class StripeSettingsCoordinator: NSObject {
    init(readersDiscovery: StripeReadersDiscovery) {
        self.readersDiscovery = readersDiscovery
    }
    
    let readersDiscovery: StripeReadersDiscovery
    
    weak var delegate: StripeSettingsCoordinatorDelegate?
    
    func presentSettings(from presentingViewController: UIViewController, reader: Reader?) {
        guard let _ = delegate else {
            NSLog("\(#function) No delegate is set")
            return
        }
        
        let settingsViewModel = StripeSettingsViewModel(
            onSetupNewReader: {
                self.screen = .discovery
            }, onShowUpdate: { [weak self] in
                guard let self = self else { return }
                if let reader = self.delegate?.settingsCoordinatorRequestsReaderToUpdate(self) {
                    self.updateViewController.viewModel?.content = .updateAvailable(reader)
                } else {
                    self.updateViewController.viewModel?.content = .empty
                }
                self.updateViewController.reload()
                self.screen = .update
            }, onDisconnect: { [weak self] in
                guard let self = self else { return }
                self.delegate?.settingsCoordinatorDisconnectReader(self)
            }
        )
        
        if let reader = reader {
            settingsViewModel.content = .connected(reader)
        }
        
        settingsViewController.viewModel = settingsViewModel
        settingsViewController.onClose = { [weak self] in
            self?.navigationController.dismiss(animated: true, completion: nil)
            self?.screen = .none
        }
        
        screen = .settings
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = self
        presentingViewController.present(navigationController, animated: true, completion: nil)
    }
    
    // MARK: Events
    
    enum ModelEvent {
        case didDisconnect
        case didBeginSearchingReader
        case didBeginDiscoveringReaders
        case didBeginConnecting
        case didConnectReader (Reader)
        case didBeginCharging
        case didBeginInstallingUpdate (Reader)
        case didProgressInstallingUpdate (Float)
    }
    
    func update(for modelEvent: ModelEvent) {
        switch modelEvent {
        case .didDisconnect:
            discoveryViewController.viewModel?.location = nil
            settingsViewController.viewModel?.content = .noReaderConnected
            settingsViewController.reload()
            
        case .didBeginSearchingReader:
            settingsViewController.viewModel?.content = .searchingReader
            settingsViewController.reload()
            
        case .didBeginDiscoveringReaders:
            break
            
        case .didBeginConnecting:
            settingsViewController.viewModel?.content = .connecting
            settingsViewController.reload()
            
        case .didConnectReader(let reader):
            settingsViewController.viewModel?.content = .connected(reader)
            settingsViewController.reload()
            screen = .settings
            
        case .didBeginCharging:
            break
            
        case .didBeginInstallingUpdate (let reader):
            updateViewController.viewModel?.content = .updating(reader)
            updateViewController.viewModel?.progress = 0.0
            updateViewController.reload()
            screen = .update // We might already be on this screen, but maybe not because mandatory updates begin right after a connection
            
        case .didProgressInstallingUpdate(let progress):
            updateViewController.viewModel?.progress = progress
            updateViewController.updateProgress(progress)
        }
    }
    
    // MARK: Navigation
    
    private enum Screen {
        case none
        case settings
        case discovery
        case locations
        case update
    }
    private var screen: Screen = .none {
        didSet {
            navigate(to: viewControllerForScreen(screen))
        }
    }
    
    private func viewControllerForScreen(_ screen: Screen) -> UIViewController? {
        switch screen {
        case .none:
            return nil
        case .settings:
            return settingsViewController
        case .discovery:
            return discoveryViewController
        case .locations:
            return locationsViewController
        case .update:
            return updateViewController
        }
    }
    
    private func navigate(to viewController: UIViewController?, animated: Bool = true) {
        guard let viewController = viewController else {
            navigationController.popToRootViewController(animated: false)
            return
        }
        
        if navigationController.viewControllers.contains(viewController) {
            navigationController.popToViewController(viewController, animated: animated)
        } else {
            navigationController.pushViewController(viewController, animated: animated)
        }
    }
    
    // MARK: View Controllers
    
    private lazy var storyboard = UIStoryboard(name: "StripeTerminal", bundle: nil)
    
    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.navigationBar.tintColor = UIColor(named: "stripe_accent")
        navigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: labelColor]
        return navigationController
    }()
    
    private lazy var settingsViewController: StripeSettingsTableViewController = {
        storyboard.instantiateViewController(withIdentifier: "settings") as! StripeSettingsTableViewController
    }()
    
    private lazy var discoveryViewController: StripeDiscoveryTableViewController = {
        let discoveryViewController = storyboard.instantiateViewController(withIdentifier: "discovery") as! StripeDiscoveryTableViewController
        
        discoveryViewController.viewModel = StripeDiscoveryViewModel(
            readersDiscovery: readersDiscovery,
            onUpdateDiscovering: { isDiscovering in
                
            },
            onUpdateSections: { indexes in
                discoveryViewController.reloadSections(indexes: indexes)
            },
            onError: { error in
                self.presentAlert(for: error)
            })
        
        discoveryViewController.onPickLocation = {
            self.screen = .locations
        }
        discoveryViewController.onReaderPicked = { [weak self] reader in
            guard let self = self else { return }
            self.delegate?.settingsCoordinator(self, didPick: reader)
            self.screen = .settings
        }
        
        return discoveryViewController
    }()
    
    private lazy var locationsViewController: StripeLocationsTableViewController = {
        let locationsViewController = storyboard.instantiateViewController(withIdentifier: "locations") as! StripeLocationsTableViewController
        
        locationsViewController.onLocationPicked = { [weak self] location in
            guard let self = self else { return }
            self.delegate?.settingsCoordinator(self, didPick: location)
            self.discoveryViewController.viewModel?.location = location
            self.screen = .discovery
        }
        
        return locationsViewController
    }()
    
    private lazy var updateViewController: StripeUpdateTableViewController = {
        let updateViewController = storyboard.instantiateViewController(withIdentifier: "update") as! StripeUpdateTableViewController
        
        let viewModel = StripeUpdateViewModel(onInstallUpdate: { [weak self] in
            guard let self = self else { return }
            self.delegate?.settingsCoordinatorInstallSoftwareUpdate(self)
        })
        updateViewController.viewModel = viewModel
        
        return updateViewController
    }()
    
    private func presentAlert(for error: Error) {
        guard let viewController = viewControllerForScreen(screen) else {
            NSLog(error.localizedDescription)
            return
        }
        
        let alert = UIAlertController(title: "Error from Stripe Terminal", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    // MARK: Appearance
    
    private var accentColor = UIColor(named: "stripe_accent")!
    private var labelColor = UIColor(named: "stripe_label")!
}

extension StripeSettingsCoordinator: UIAdaptivePresentationControllerDelegate {
    // Called for "Swipe to dismiss" on iOS 13+
    // This is for the navigationController
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.screen = .none
    }
}
