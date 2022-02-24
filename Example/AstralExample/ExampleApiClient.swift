//
//  ExampleApiClient.swift
//  AstralExample
//
//  Created by Renaud Pradenc on 20/12/2021.
//

import Foundation
import Astral

/* You must provide a class which conforms to the AstralApiClient protocol
 
 Your application performs POST requests to your company's backend
 - to get a connection token (which identifies the Stripe account)
 - to capture the payment intent (which "blocks funds")
*/

/*
 The backend will need your Stripe secret key, that you'll find on:
 https://dashboard.stripe.com/test/apikeys
 (the key which begins with sk_test)
 */

class ExampleApiClient: AstralApiClient {
    /* Stripe provides an example backend:
     https://github.com/stripe/example-terminal-backend
     which is quite simple but will allow testing your integration easily.
     In this example, we've chosen to deploy this example using Docker. */
    static let backendUrl: String = "http://localhost:4567"  //"http://192.168.1.61:4567"  // Docker
    
    func fetchConnectionToken(onSuccess: @escaping (String) -> (), onError: @escaping (Error) -> ()) {
        guard let url = URL(string: "\(Self.backendUrl)/connection_token") else {
            fatalError("Invalid backend URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { (data, response, error) in
            if let data = data {
//                data.saveDocument(as: "connection_token.json")
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let secret = json?["secret"] as? String {
                        onSuccess(secret)
                    } else if let errorMessage = json?["error"] as? String {
                        onError(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "The server answered: \(errorMessage)"]))
                    } else {
                        onError(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing `secret` in ConnectionToken JSON response"]))
                    }
                }
                catch {
                    onError(error)
                }
            }
            else {
                onError(NSError(domain: #function, code: 1000, userInfo: [NSLocalizedDescriptionKey: "No data in response from ConnectionToken endpoint"]))
            }
        }
        task.resume()
    }
    
    func capturePaymentIntent(id: String, onSuccess: @escaping ()->(), onError: @escaping (Error)->()) {
        let json = ["id": id]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            onError(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not convert data to JSON."]))
            return
        }
        
        guard let url = URL(string: "\(Self.backendUrl)/create_payment_intent") else {
            fatalError("Invalid backend URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setContentTypeAsJson()
        
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                onError(error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else {
                onError(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "No response"]))
                return
            }
            guard 200...299 ~= response.statusCode else {
                onError(NSError(domain: #function, code: 0, userInfo: [NSLocalizedDescriptionKey: "The server responded with status code \(response.statusCode)"]))
                return
            }
            
            onSuccess()
        }
        task.resume()
    }
}

extension URLRequest {
    mutating func setContentTypeAsJson() {
        setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    }
}

extension Data {
    /// Save the data to a file in /Documents.
    ///
    /// Very useful for debugging.
    func saveDocument(as filename: String) {
        guard let documentsDirUrl = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileUrl = documentsDirUrl.appendingPathComponent(filename)
        try? write(to: fileUrl)
    }
}
