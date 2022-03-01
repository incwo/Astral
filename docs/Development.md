# Development documentation

## Architecture

    Astral
        TerminalModel
            TerminalStateMachine
            ReadersDiscovery
            ReaderConnection
            PaymentProcessor
        ChargeCoordinator
            ChargeViewController
        SettingsCoordinator
            SettingsViewModel -> SettingsTableViewController
            DiscoveryViewModel -> DiscoveryTableViewController
            UpdateViewModel -> UpdateTableViewController 
         

### TerminalStateMachine

`TerminalModel` uses a state machine to keep its internal state, which ensures consistency and that all cases are handled.

```mermaid
    stateDiagram-v2 
        [*] --> noReader: No serial number saved
        noReader --> discoveringReaders: didSelectLocation
        discoveringReaders --> connecting: didSelectReader

        [*] --> disconnected: A serial number was saved
        disconnected --> searchingReader: reconnect
        searchingReader --> connecting: didFindReader

        connected --> disconnecting: forgetReader
        disconnecting --> noReader: didDisconnect

        connecting --> automaticUpdate: didBeginInstallingUpdate
        automaticUpdate --> connected: didEndInstallingUpdate

        connecting --> connected: didConnect
        connected --> userInitiatedUpdate: didBeginInstallingUpdate
        userInitiatedUpdate --> connected: didEndInstallingUpdate

        connected --> charging: charge
        charging --> connected: didEndCharging 
```

*In order to make the figure clearer, the .didDisconnectUnexpectedly, and .canceled events are not represented.*
