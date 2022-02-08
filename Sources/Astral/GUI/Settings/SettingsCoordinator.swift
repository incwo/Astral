//
//  SettingsCoordinator.swift
//  Astral
//
//  Created by Renaud Pradenc on 24/01/2022.
//

import Foundation
import UIKit
import StripeTerminal

protocol SettingsCoordinatorDelegate: AnyObject {
    /// Tells that the Settings panel is about to close
    func settingsCoordinatorWillDismiss(_ sender: SettingsCoordinator)
    
    /// Tells that the User chose a Location among the list
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick location: Location)
    
    /// Tells that the User chose a Reader among the list of ones available at the current location
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick reader: Reader)
    
    /// Asks the delegate for the Reader to update.
    ///
    /// The reader object is needed to show the current version and the one to install.
    func settingsCoordinatorRequestsReaderToUpdate(_ sender: SettingsCoordinator) -> Reader?
    
    /// Asks the delegate to disconnect the current Reader
    func settingsCoordinatorDisconnectReader(_ sender: SettingsCoordinator)
    
    /// Asks the delegate to install the Reader's software update
    func settingsCoordinatorInstallSoftwareUpdate(_ sender: SettingsCoordinator)
}

/// A coordinator for the Settings panel
class SettingsCoordinator: NSObject {
    init(readersDiscovery: ReadersDiscovery) {
        self.readersDiscovery = readersDiscovery
    }
    
    let readersDiscovery: ReadersDiscovery
    
    weak var delegate: SettingsCoordinatorDelegate?
    
    func presentSettings(from presentingViewController: UIViewController, reader: Reader?, completion: (()->())?) {
        guard let _ = delegate else {
            NSLog("\(#function) No delegate is set")
            return
        }
        
        let settingsViewModel = SettingsViewModel(
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
            guard let self = self else { return }
            self.delegate?.settingsCoordinatorWillDismiss(self)
            self.navigationController.dismiss(animated: true, completion: nil)
            self.screen = .none
        }
        
        screen = .settings
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = self
        presentingViewController.present(navigationController, animated: true, completion: completion)
    }
    
    // MARK: Model State
    
    /// Returns false if the state can not be handled
    func update(for state: TerminalModel.State) -> Bool {
        switch state {
        case .noReader, .readerSavedNotConnected:
            discoveryViewController.viewModel?.location = nil
            settingsViewController.viewModel?.content = .needsSettingUpReader
            settingsViewController.reload()
            return true
            
        case .searchingReader(_):
            settingsViewController.viewModel?.content = .searchingReader
            settingsViewController.reload()
            return true
            
        case .discoveringReaders:
            return true
            
        case .connecting:
            settingsViewController.viewModel?.content = .connecting
            settingsViewController.reload()
            return true
            
        case .readerConnected (let reader), .ready (let reader):
            settingsViewController.viewModel?.content = .connected(reader)
            settingsViewController.reload()
            screen = .settings
            return true
            
        case .charging(_):
            return false
            
        case .installingUpdate (let reader, let progress):
            if progress == 0.0 { // Beginning
                updateViewController.viewModel?.content = .updating(reader)
                updateViewController.viewModel?.progress = progress
                updateViewController.reload()
                screen = .update // We might already be on this screen, but maybe not because mandatory updates begin right after a connection
            } else {
                updateViewController.viewModel?.progress = progress
                updateViewController.updateProgress(progress)
            }
            return true
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
    
    private lazy var storyboard = UIStoryboard(name: "Astral", bundle: .module)
    
    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.navigationBar.tintColor = .astralAccent
        navigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.astralLabel as Any]
        return navigationController
    }()
    
    private lazy var settingsViewController: SettingsTableViewController = {
        storyboard.instantiateViewController(withIdentifier: "settings") as! SettingsTableViewController
    }()
    
    private lazy var discoveryViewController: DiscoveryTableViewController = {
        let discoveryViewController = storyboard.instantiateViewController(withIdentifier: "discovery") as! DiscoveryTableViewController
        
        discoveryViewController.viewModel = DiscoveryViewModel(
            readersDiscovery: readersDiscovery,
            onUpdateDiscovering: { isDiscovering in
                discoveryViewController.isDiscovering = isDiscovering
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
            //self.readersDiscovery.cancel { }
            self.delegate?.settingsCoordinator(self, didPick: reader)
            self.screen = .settings
        }
        
        return discoveryViewController
    }()
    
    private lazy var locationsViewController: LocationsTableViewController = {
        let locationsViewController = storyboard.instantiateViewController(withIdentifier: "locations") as! LocationsTableViewController
        
        locationsViewController.onLocationPicked = { [weak self] location in
            guard let self = self else { return }
            self.delegate?.settingsCoordinator(self, didPick: location)
            self.discoveryViewController.viewModel?.location = location
            self.screen = .discovery
        }
        locationsViewController.onError = { [weak self] error in
            self?.presentAlert(for: error)
        }
        
        return locationsViewController
    }()
    
    private lazy var updateViewController: UpdateTableViewController = {
        let updateViewController = storyboard.instantiateViewController(withIdentifier: "update") as! UpdateTableViewController
        
        let viewModel = UpdateViewModel(onInstallUpdate: { [weak self] in
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
        
        let alert = UIAlertController(title: "Stripe Terminal", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
}

extension SettingsCoordinator: UIAdaptivePresentationControllerDelegate {
    // Called for "Swipe to dismiss" on iOS 13+
    // This is for the navigationController
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.screen = .none
    }
}
