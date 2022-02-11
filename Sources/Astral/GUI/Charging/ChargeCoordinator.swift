//
//  ChargeCoordinator.swift
//  Astral
//
//  Created by Renaud Pradenc on 25/01/2022.
//

import Foundation
import UIKit

protocol ChargeCoordinatorDelegate: AnyObject {
    /// Tells that the panel is about to close
    func chargeCoordinatorWillDismiss(_ sender: ChargeCoordinator)
    
    /// The Cancel button was pressed
    func chargeCoordinatorCancel(_ sender: ChargeCoordinator)
}

class ChargeCoordinator: NSObject {
    
    weak var delegate: ChargeCoordinatorDelegate?
    
    enum Operation {
        case charging (amount: CurrencyAmount)
        // case refund  // Not supported yet
    }
    
    private var presentingViewController: UIViewController?
    private var isPresented: Bool = false
    
    func present(for operation: Operation, from presentingViewController: UIViewController, completion: (()->())?) {
        self.presentingViewController = presentingViewController
        
        presentChargeViewController(for: operation)
        
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = self
        presentingViewController.present(navigationController, animated: true) {
            self.isPresented = true
            completion?()
        }
    }
    
    func dismiss() {
        isPresented = false
        delegate?.chargeCoordinatorWillDismiss(self)
        navigationController.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Status
    
    /// Returns false if the state can not be handled
    func update(for state: TerminalModel.State) -> Bool {
        switch state {
        case .noReader:
            return false
            
        case .readerSavedNotConnected:
            return true
            
        case .searchingReader(_):
            status = .searchingReader
            return true
            
        case .discoveringReaders:
            return false
            
        case .connecting:
            status = .connectingReader
            return true
            
        case .readerConnected (_):
            status = .connected
            return true
            
        case .ready:
            status = .ready
            return true
            
        case .charging(let message):
            status = .charging(message: message)
            return true
            
        case .installingUpdate:
            return false
        }
    }
    
    
    enum Status {
        case none
        case searchingReader
        case connectingReader
        case connected
        case ready
        case charging (message: String)
    }
    private var status: Status = .none {
        didSet {
            chargeViewController.status = status.statusString
        }
    }
    
    // MARK: View Controllers
    
    private lazy var storyboard: UIStoryboard = {
        UIStoryboard(name: "Astral", bundle: .module)
    }()
    
    private lazy var navigationController: UINavigationController = {
        let navigationController = UINavigationController()
        navigationController.navigationBar.tintColor = .astralAccent
        navigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.astralLabel as Any]
        return navigationController
    }()
    
    private func presentChargeViewController(for operation: Operation) {
        chargeViewController.operationTitle = operation.title
        chargeViewController.amount = operation.amountString
        chargeViewController.status = status.statusString
        
        navigationController.viewControllers = [chargeViewController]
    }
    
    private lazy var chargeViewController: ChargeViewController = {
        let viewController = storyboard.instantiateViewController(withIdentifier: "charge") as! ChargeViewController
        viewController.onCancel = { [weak self] in
            guard let self = self else { return }
            self.delegate?.chargeCoordinatorCancel(self)
        }
        return viewController
    }()
    
    var presentationViewController: UIViewController? {
        guard isPresented else {
            return nil
        }
        return chargeViewController
    }
}

private extension ChargeCoordinator.Operation {
    var title: String {
        switch self {
        case .charging:
            return locz("ChargeCoordinator.operation.charging")
        }
    }
    
    var amountString: String {
        switch self {
        case let .charging(amount):
            return amount.localizedString
        }
    }
}

private extension ChargeCoordinator.Status {
    var statusString: String {
        switch self {
        case .none:
            return ""
        case .searchingReader:
            return locz("ChargeCoordinator.status.searchingReader")
        case .connectingReader:
            return locz("ChargeCoordinator.status.connectingReader")
        case .connected:
            return locz("ChargeCoordinator.status.connected")
        case .ready:
            return locz("ChargeCoordinator.status.ready")
        case .charging(let message):
            return message
        }
    }
}

extension ChargeCoordinator: UIAdaptivePresentationControllerDelegate {
    // Called for "Swipe to dismiss" on iOS 13+
    // This is for the navigationController.
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        delegate?.chargeCoordinatorWillDismiss(self)
        isPresented = false
    }
}
