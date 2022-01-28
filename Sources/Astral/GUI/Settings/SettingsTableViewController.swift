//
//  SettingsTableViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 21/12/2021.
//

import UIKit
import StripeTerminal

class SettingsTableViewController: UITableViewController {
    var onClose: (()->())?
    
    var viewModel: SettingsViewModel? {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }
    
    func reload() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13, *) {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close(_:)))
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: locz("close"), style: .plain, target: self, action: #selector(close(_:)))
        }
    }
    
    @objc private func close(_ sender: UIBarButtonItem) {
        onClose?()
    }
    
    private func section(at index: Int) -> SettingsViewModel.Section {
        guard let viewModel = viewModel else {
            fatalError("No ViewModel set")
        }
        return viewModel.sections[index]
    }
    
    private func row(at indexPath: IndexPath) -> SettingsViewModel.Row {
        return section(at: indexPath.section).rows[indexPath.row]
    }
}

// MARK: UITableViewDataSource

extension SettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.sections.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int {
        guard let _ = viewModel else {
            return 0
        }
        
        return section(at: sectionIndex).rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(in: tableView, at: indexPath, for: row(at: indexPath))
    }
    
    private func cell(in tableView: UITableView, at indexPath: IndexPath, for row: SettingsViewModel.Row) -> UITableViewCell {
        switch row {
        case .setupReader:
            return tableView.dequeueReusableCell(withIdentifier: "setupReader", for: indexPath)
            
        case .searchingReader:
            return tableView.dequeueReusableCell(withIdentifier: "searching", for: indexPath)
            
        case .connecting:
            return tableView.dequeueReusableCell(withIdentifier: "connecting", for: indexPath)
            
        case .readerDescription (let reader):
            let cell = tableView.dequeueReusableCell(withIdentifier: "reader", for: indexPath) as! ReaderCell
            cell.model = Terminal.stringFromDeviceType(reader.deviceType)
            cell.serialNumber = reader.serialNumber
            cell.batteryLevel = reader.batteryLevel?.floatValue
            return cell
            
        case .softwareUpdate:
            return tableView.dequeueReusableCell(withIdentifier: "softwareUpdate", for: indexPath)
            
        case .disconnect:
            let cell = tableView.dequeueReusableCell(withIdentifier: "disconnectReader", for: indexPath)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection sectionIndex: Int) -> String? {
        section(at: sectionIndex).title
    }
}

// MARK: UITableViewDelegate

extension SettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch row(at: indexPath) {
        case .setupReader:
            viewModel?.onSetupNewReader()
            
        case .softwareUpdate:
            viewModel?.onShowUpdate()
            
        case .disconnect:
            viewModel?.onDisconnect()
            
        default:
            break
        }
    }
}
