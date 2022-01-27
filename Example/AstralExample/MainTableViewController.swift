//
//  MainTableViewController.swift
//  ProtoStripeTerminal
//
//  Created by Renaud Pradenc on 21/12/2021.
//

import UIKit
import Astral

class MainTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    private lazy var stralApiClient = ExampleApiClient()
    private lazy var stripeManager = Astral(apiClient: stralApiClient)

    @IBAction private func setup(_ sender: Any) {
        stripeManager.presentSettings(from: self)
    }
    
    @IBOutlet private weak var amountTextField: UITextField!
    @IBOutlet private weak var currencyTextField: UITextField!
    @IBAction private func charge(_ sender: Any) {
        guard let amountString = amountTextField.text,
                !amountString.isEmpty,
                let amount = amountNumberFormatter.number(from: amountString) as? NSDecimalNumber else {
            presentAlert(title: "Invalid amount", message: "Please type the amount as a decimal number.")
            return
        }
        
        guard let currency = currencyTextField.text,
                currency.count == 3
        else {
            presentAlert(title: "Invalid currency", message: "The currency is a 3-letter ISO code such as USD or EUR.")
            return
        }
        
        stripeManager.charge(amount: amount, currency: currency, presentFrom: self, onSuccess: { paymentInfo in
            DispatchQueue.main.async {
                let message: String
                if paymentInfo.charges.count == 1, let charge = paymentInfo.charges.first {
                    if let cardDetails = charge.cardDetails {
                        message = "The card \(cardDetails.brand) ending with \(cardDetails.last4) was charged an amount of \(charge.amount.amount) \(charge.amount.currency.uppercased()) successfully."
                    } else {
                        message = "The amount of \(charge.amount.amount) \(charge.amount.currency.uppercased()) was charged successfully."
                    }
                } else {
                    message = "The amounts were charged successfully."
                }
                self.presentAlert(title: "Transaction completed", message: message)
            }
        }, onError: { error in
            DispatchQueue.main.async {
                self.presentAlert(title: "An error occured", message: error.localizedDescription)
            }
        })
    }
    
    private lazy var amountNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.generatesDecimalNumbers = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    

}
