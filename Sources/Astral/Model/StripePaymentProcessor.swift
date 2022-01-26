//
//  StripePaymentProcessor.swift
//  ProtoStripe
//
//  Created by Renaud Pradenc on 15/12/2021.
//

import Foundation
import StripeTerminal
import UIKit

/// The ability to send requests toward the server so it can process Stripe Payments.
protocol StripeApiClient {
    /// Perform a POST request toward the server so it returns a Stripe Connection Token.
    ///
    /// On success, returns the secret token.
    func fetchConnectionToken(onSuccess: @escaping (String)->(), onError: @escaping (Error)->())
    
    /// Perform a POST request toward the server so it captures the Payment Intent.
    /// This actually captures the funds and terminates the transaction.
    func capturePaymentIntent(id: String, onSuccess: @escaping ()->(), onError: @escaping (Error)->())
}

enum StripeChargeResult {
    case success (StripePaymentInfo)
    case cancelled
    case error (Error)
}

class StripePaymentProcessor: NSObject {
    let apiClient: StripeApiClient
    init(apiClient: StripeApiClient) {
        self.apiClient = apiClient
        
        super.init()
        
        Terminal.setTokenProvider(self)
    }
    
    func charge(amount: StripeAmount, completion: @escaping (StripeChargeResult)->()) {
        let params = PaymentIntentParameters(amount: amount.smallestUnitAmount, currency: amount.currency)
        Terminal.shared.createPaymentIntent(params) { paymentIntent, error in
            if let error = error {
                completion(.error(error))
            } else if let paymentIntent = paymentIntent {
                self.collectPaymentMethod(paymentIntent, completion: completion)
            }
        }
    }
    
    func cancel() {
        collectCancellable?.cancel { error in
            if let _ = error {
                print("The operation is not cancelable.")
            }
        }
    }
    
    private var collectCancellable: Cancelable?
    private func collectPaymentMethod(_ paymentIntent: PaymentIntent, completion: @escaping (StripeChargeResult)->()) {
        self.collectCancellable = Terminal.shared.collectPaymentMethod(paymentIntent) { paymentIntentToCollect, error in
            self.collectCancellable = nil
            
            if let error = error {
                completion(.error(error))
            } else if let paymentIntent = paymentIntentToCollect {
                self.processPayment(paymentIntent, completion: completion)
            }
        }
    }
    
    private func processPayment(_ paymentIntent: PaymentIntent, completion: @escaping (StripeChargeResult)->()) {
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
                        completion(.error(error))
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
                    completion(.error(error))
                    return
                }
                self.apiClient.capturePaymentIntent(id: paymentIntent.stripeId, onSuccess: {
                    let charges = paymentIntent.charges
                        .filter({ $0.status == .succeeded })
                        .map({ $0.asPaymentInfoCharge() })
                    
                    let paymentInfo = StripePaymentInfo(id: paymentIntent.stripeId, date: Date(), charges: charges)
                    completion(.success(paymentInfo))
                }, onError: { error in
                    completion(.error(error))
                })
            }
        }
    }
}

extension StripePaymentProcessor: ConnectionTokenProvider {
    func fetchConnectionToken(_ completion: @escaping ConnectionTokenCompletionBlock) {
        apiClient.fetchConnectionToken(onSuccess: { secret in
            completion(secret, nil)
        }, onError: { error in
            completion(nil, error)
        })
    }
}

private extension Charge {
    func asPaymentInfoCharge() -> StripePaymentInfo.Charge {
        return .init(id: self.stripeId, amount: StripeAmount(smallestUnitAmount: self.amount, currency: self.currency), cardDetails: self.cardDetails)
    }
    
    private var cardDetails: StripeCardDetails? {
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
        
        return StripeCardDetails(
            brand: Terminal.stringFromCardBrand(present.brand),
            last4: present.last4)
    }
}


