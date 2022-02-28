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
    
    /// Informs that an error occured
    func settingsCoordinator(_ sender: SettingsCoordinator, didFail error: Error)
    
    /// Tells that the User chose a Location among the list
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick location: Location)
    
    /// Tells that the User chose a Reader among the list of ones available at the current location
    func settingsCoordinator(_ sender: SettingsCoordinator, didPick reader: Reader)
    
    /// Asks to cancel Searching for the reader
    func settingsCoordinatorCancelSearchingReader(_ sender: SettingsCoordinator)
    
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
    
    func presentSettings(from presentingViewController: UIViewController, completion: (()->())?) {
        guard let _ = delegate else {
            NSLog("\(#function) No delegate is set")
            return
        }
        
        let settingsViewModel = SettingsViewModel(
            onSetupNewReader: {
                self.screen = .discovery
            }, onShowUpdate: { [weak self] in
                guard let self = self else { return }
                if let reader = self.reader {
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
        
        settingsViewController.viewModel = settingsViewModel
        settingsViewController.onClose = { [weak self] in
            guard let self = self else { return }
            self.delegate?.settingsCoordinatorWillDismiss(self)
            self.navigationController.dismiss(animated: true, completion: nil)
            self.screen = .none
        }
        settingsViewController.onCancelSearching = { [weak self] in
            guard let self = self else { return }
            self.delegate?.settingsCoordinatorCancelSearchingReader(self)
        }
        
        screen = .settings
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = self
        presentingViewController.present(navigationController, animated: true, completion: completion)
    }
    
    var updateProgress: Float = 0.0 {
        didSet {
            updateViewController.viewModel?.progress = updateProgress
            updateViewController.updateProgress(updateProgress)
        }
    }
    
    // MARK: Model State
    
    private var reader: Reader?
    
    /// Returns false if the state can not be handled
    func update(for state: TerminalState) -> Bool {
        switch state {
        case is NoReaderState:
            reader = nil
            discoveryViewController.viewModel?.location = nil
            settingsViewController.viewModel?.content = .needsSettingUpReader
            settingsViewController.reload()
            return true
            
        case is DisconnectedState, is SearchingReaderState:
            reader = nil
            settingsViewController.viewModel?.content = .searchingReader
            settingsViewController.reload()
            return true
            
        case is DiscoveringReadersState:
            reader = nil
            return true
            
        case is ConnectingState:
            reader = nil
            settingsViewController.viewModel?.content = .connecting
            settingsViewController.reload()
            return true
            
        case is ConnectedState:
            let reader = (state as! ConnectedState).reader
            self.reader = reader
            settingsViewController.viewModel?.content = .connected(reader)
            settingsViewController.reload()
            screen = .settings
            return true
            
        case is ChargingState:
            return false
            
        case is UserInitiatedUpdateState:
            let reader = (state as! UserInitiatedUpdateState).reader
            self.reader = reader
            updateViewController.viewModel?.content = .updating(reader)
            updateViewController.reload()
            screen = .update
            return true
            
        case is AutomaticUpdateState:
            let reader = (state as! AutomaticUpdateState).reader
            self.reader = reader
            updateViewController.viewModel?.content = .updating(reader)
            updateViewController.reload()
            screen = .update
            return true
            
        default:
            NSLog("[Astral] \(#function) State not handled: \(state)")
            return false
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
        if #available(iOS 15.0, *) {
            // I don't quite understand why, but in some integrations, the background color is clear whereas it takes the top view controller's background color in other
            navigationController.view.backgroundColor = .systemGroupedBackground
        }
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
            onError: { [weak self] error in
                guard let self = self else { return }
                self.delegate?.settingsCoordinator(self, didFail: error)
            })
        
        discoveryViewController.onPickLocation = {
            self.screen = .locations
        }
        discoveryViewController.onReaderPicked = { [weak self] reader in
            guard let self = self else { return }
            self.delegate?.settingsCoordinator(self, didPick: reader)
            self.readersDiscovery.cancel(completion: nil) // Discovery must be stopped AFTER connecting to the Reader, or we get an error message.
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
            guard let self = self else { return }
            self.delegate?.settingsCoordinator(self, didFail: error)
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
    
    var presentationViewController: UIViewController? {
        viewControllerForScreen(screen)
    }
}

extension SettingsCoordinator: UIAdaptivePresentationControllerDelegate {
    // Called for "Swipe to dismiss" on iOS 13+
    // This is for the navigationController
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        self.screen = .none
    }
}
