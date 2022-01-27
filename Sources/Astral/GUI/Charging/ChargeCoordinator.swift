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
    func chargeCoordinatorWillDismiss()
}

class ChargeCoordinator: NSObject {
    
    weak var delegate: ChargeCoordinatorDelegate?
    
    enum Operation {
        case charging (amount: NSDecimalNumber, currencyCode: String)
        // case refund  // Not supported yet
    }
    
    private var presentingViewController: UIViewController?
    
    func present(for operation: Operation, from presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        
        presentChargeViewController(for: operation)
        
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = self
        presentingViewController.present(navigationController, animated: true, completion: nil)
    }
    
    func dismiss() {
        delegate?.chargeCoordinatorWillDismiss()
        navigationController.dismiss(animated: true, completion: nil)
    }
    
    enum Status {
        case none
        case searchingReader
        case connectingReader
        case connected
        case charging (message: String)
    }
    var status: Status = .none {
        didSet {
            chargeViewController.status = status.statusString
        }
    }
    
    // MARK: View Controllers
    
    private lazy var storyboard: UIStoryboard = {
        UIStoryboard(name: "Astral", bundle: .module)
    }()
    
    private lazy var navigationController: UINavigationController = {
        UINavigationController()
    }()
    
    private func presentChargeViewController(for operation: Operation) {
        chargeViewController.operationTitle = operation.title
        chargeViewController.amount = operation.amountString
        
        navigationController.viewControllers = [chargeViewController]
    }
    
    private lazy var chargeViewController: ChargeViewController = {
        storyboard.instantiateViewController(withIdentifier: "charge") as! ChargeViewController
    }()
    
}

private extension ChargeCoordinator.Operation {
    var title: String {
        switch self {
        case .charging:
            return "Charging"
        }
    }
    
    var amountString: String {
        switch self {
        case let .charging(amount, currencyCode):
            return Self.localizedAmountString(amount: amount, currencyCode: currencyCode)
        }
    }
    
    private static func localizedAmountString(amount: NSDecimalNumber, currencyCode: String) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = currencyCode
        return numberFormatter.string(from: amount) ?? "\(amount) \(currencyCode)"
    }
}

private extension ChargeCoordinator.Status {
    var statusString: String {
        switch self {
        case .none:
            return ""
        case .searchingReader:
            return "Searching the Reader"
        case .connectingReader:
            return "Connecting to the Reader"
        case .connected:
            return "Connected"
        case .charging(let message):
            return message
        }
    }
}

extension ChargeCoordinator: UIAdaptivePresentationControllerDelegate {
    // Called for "Swipe to dismiss" on iOS 13+
    // This is for the navigationController.
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        delegate?.chargeCoordinatorWillDismiss()
    }
}
