# Astral

An integration of Stripe Terminal for iOS.

![AstralSettings](./docs/AstralSettings.png)



## Description

⚠️ **This library is neither endorsed nor supported by Stripe.** ⚠️

Astral relies on [Stripe Terminal iOS SDK](https://github.com/stripe/stripe-terminal-ios) to provide an out-of-the-box solution for handling payments:

- Distinctive User interface
- Connection and reconnections to Readers
- Handling of the payment process 
- Management of errors

It is currently used in our Point-of-Sale app, [incwo POS](https://go.incwo.com/fonctionnalite-caisse-connectee/).

### Features

#### User interface

- Based on UIKit, so it can run on a version as low as iOS 11
- Adapted to iPhone and iPad
- Localized in: en, fr
- Supports ☀️ Light and 🌙 Dark modes

#### Readers

- Handling of updates, either automatic or manual

### Limitations

- Only Bluetooth readers are supported
- Refunds are not supported

## Integration

### Installation in an iOS app

Only Swift Package Manager is supported. 

In Xcode, go to `File > Add Packages` and paste https://github.com/incwo/Astral.

### Configuration of your project

Since Astral relies on the Stripe Terminal SDK, your app needs be configured as [described here](https://stripe.com/docs/terminal/payments/setup-sdk?terminal-sdk-platform=ios#configure). In particular, don't forget to set the keys in the app's Info.plist.


### Support on the backend

Your backend needs to call Stripe's API to:

- provide a Connection Token
- capture the funds for a Payment Intent.

Stripe has an extensive documentation:
https://stripe.com/docs/terminal/quickstart

## Usage

Make a class (or struct) which conforms to the `AstralApiClient` protocol. The methods of this object will be called when your app must send requests to your backend. See `ExampleApiClient` for an example.

    let apiClient = YourApiClient()

Create an instance of `Astral`:

    let astral = Astral(apiClient: apiClient)

Then you can show settings:

    astral.presentSettings(from: viewController)

Or charge an amount:

    astral.charge(amount: 9.90, currency: "EUR", presentFrom: viewController) { result in
        switch result {
            case .success (let paymentInfo):
                …
            case .cancelation:
                …
            case .failure (let error):
                …
        }
    }

## Example project

Open `Example/AstralExample.xcodeproj` for an example of integration. The URL of the backend is set in `ExampleApiClient.swift`.

You will need a sample backend running, like the one provided by Stripe: https://github.com/stripe/example-terminal-backend.

## License

MIT License

Copyright (c) 2022 incwo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
