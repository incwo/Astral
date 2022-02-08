//
//  PaymentProcessor.swift
//  Astral
//
//  Created by Renaud Pradenc on 15/12/2021.
//

import Foundation
import StripeTerminal
import UIKit

/// The ability to send requests toward the server so it can process Stripe Payments.
public protocol AstralApiClient {
    /// Perform a POST request toward the server so it returns a Stripe Connection Token.
    ///
    /// On success, returns the secret token.
    func fetchConnectionToken(onSuccess: @escaping (String)->(), onError: @escaping (Error)->())
    
    /// Perform a POST request toward the server so it captures the Payment Intent.
    /// This actually captures the funds and terminates the transaction.
    func capturePaymentIntent(id: String, onSuccess: @escaping ()->(), onError: @escaping (Error)->())
}

class PaymentProcessor: NSObject {
    let apiClient: AstralApiClient
    init(apiClient: AstralApiClient) {
        self.apiClient = apiClient
        
        super.init()
        
        Terminal.setTokenProvider(self)
    }
    
    func charge(amount: Amount, completion: @escaping (ChargeResult)->()) {
        let params = PaymentIntentParameters(amount: amount.smallestUnitAmount, currency: amount.currency)
        Terminal.shared.createPaymentIntent(params) { paymentIntent, error in
            if let error = error {
                completion(.failure(error))
            } else if let paymentIntent = paymentIntent {
                self.collectPaymentMethod(paymentIntent, completion: completion)
            }
        }
    }
    
    func cancel() {
        cancelable?.cancel { error in
            // The completion block does not indicate that the cancelation is complete, but that it's acknowledged.
            if let error = error {
                NSLog("\(#function) \(error)")
            }
        }
    }
    private var cancelable: Cancelable?
    
    private func collectPaymentMethod(_ paymentIntent: PaymentIntent, completion: @escaping (ChargeResult)->()) {
        cancelable = Terminal.shared.collectPaymentMethod(paymentIntent) { paymentIntentToCollect, error in
            self.cancelable = nil
            
            if let error = error {
                if error.isCancelation {
                    completion(.cancelation)
                } else {
                    completion(.failure(error))
                }
            } else if let paymentIntent = paymentIntentToCollect {
                self.processPayment(paymentIntent, completion: completion)
            }
        }
    }
    
    private func processPayment(_ paymentIntent: PaymentIntent, completion: @escaping (ChargeResult)->()) {
        Terminal.shared.processPayment(paymentIntent) { paymentIntentToConfirm, error in
            if let error = error {
                if let updatedPaymentIntent = error.paymentIntent {
                    switch updatedPaymentIntent.status {
                    case .requiresConfirmation: // e.g. the request failed because the app is not connected to the Internet
                        // Retry with the updated PaymentIntent
                        self.processPayment(updatedPaymentIntent, completion: completion)
                    case .requiresPaymentMethod: // e.g., the request failed because the card was declined
                        // Call collectPaymentMethod() with the updated PaymentIntent to try charging another card.
                        self.collectPaymentMethod(updatedPaymentIntent, completion: completion)
                    default:
                        completion(.failure(error))
                    }
                } else {
                    // The request to Stripe's server timed out and the PaymentIntent's status is unknown.
                    // Retry with the original PaymentIntent.
                    self.processPayment(paymentIntent, completion: completion)
                }
            } else if let paymentIntent = paymentIntentToConfirm {
                let charges = paymentIntent.charges
                guard charges.count > 0 else {
                    let error = NSError(domain: NSStringFromClass(self.classForCoder), code: 0, userInfo: [NSLocalizedDescriptionKey: "The PaymentIntent should have charges at this point."])
                    completion(.failure(error))
                    return
                }
                self.apiClient.capturePaymentIntent(id: paymentIntent.stripeId, onSuccess: {
                    let charges = paymentIntent.charges
                        .filter({ $0.status == .succeeded })
                        .map({ $0.asPaymentInfoCharge() })
                    
                    let paymentInfo = PaymentInfo(id: paymentIntent.stripeId, date: Date(), charges: charges)
                    completion(.success(paymentInfo))
                }, onError: { error in
                    completion(.failure(error))
                })
            }
        }
    }
}

extension PaymentProcessor: ConnectionTokenProvider {
    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        apiClient.fetchConnectionToken(onSuccess: { secret in
            completion(secret, nil)
        }, onError: { error in
            completion(nil, error)
        })
    }
}

private extension Charge {
    func asPaymentInfoCharge() -> PaymentInfo.Charge {
        return .init(id: self.stripeId, amount: Amount(smallestUnitAmount: self.amount, currency: self.currency), cardDetails: self.cardDetails)
    }
    
    private var cardDetails: CardDetails? {
        guard self.status == .succeeded,
              let paymentMethodDetails = self.paymentMethodDetails
        else {
            return nil
        }
        
        let present: CardPresentDetails
        switch paymentMethodDetails.type {
        case .cardPresent:
            guard let cardPresent = paymentMethodDetails.cardPresent else { return nil }
            present = cardPresent
            
        case .interacPresent: // For Canada only
            guard let interacPresent = paymentMethodDetails.interacPresent else { return nil }
            present = interacPresent
            
        default:
            return nil
        }
        
        return CardDetails(
            brand: Terminal.stringFromCardBrand(present.brand),
            last4: present.last4)
    }
}

extension Error {
    var isCancelation: Bool {
        let nsError = self as NSError
        return nsError.domain == ErrorCode.errorDomain && nsError.code == ErrorCode.Code.canceled.rawValue
    }
}
