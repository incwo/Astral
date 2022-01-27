//
//  DiscoveryTableViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 23/12/2021.
//

import UIKit
import StripeTerminal

class DiscoveryTableViewController: UITableViewController {
    
    var viewModel: DiscoveryViewModel?
    
    /// Closure called when the user touches the "Pick a location" row
    var onPickLocation: (()->())?
    
    /// Closure called when a Reader is chosen by the user
    var onReaderPicked: ((Reader)->())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    }
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let style: UIActivityIndicatorView.Style
        if #available(iOS 13, *) {
            style = .medium
        } else {
            style = .gray
        }
        let indicator = UIActivityIndicatorView(style: style)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: Table View
    
    func reloadSections(indexes: IndexSet) {
        tableView.reloadSections(indexes, with: .automatic)
    }
    
    private func row(at indexPath: IndexPath) -> DiscoveryViewModel.Row {
        guard let viewModel = viewModel else {
            fatalError("A ViewModel must be set")
        }

        return viewModel.sections[indexPath.section].rows[indexPath.row]
    }
}

// MARK: UITableViewDataSource

extension DiscoveryTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel?.sections[section].rows.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch row(at: indexPath) {
        case .pickLocation:
            return tableView.dequeueReusableCell(withIdentifier: "pickLocation", for: indexPath)
            
        case .location(let location):
            let cell = tableView.dequeueReusableCell(withIdentifier: "location", for: indexPath) as! ShortLocationCell
            cell.location = location
            return cell
            
        case .noLocationPicked:
            return tableView.dequeueReusableCell(withIdentifier: "noLocationPicked", for: indexPath)
            
        case .reader(let reader):
            let cell = tableView.dequeueReusableCell(withIdentifier: "readerIdentity", for: indexPath) as! ReaderIdentityCell
            cell.model = Terminal.stringFromDeviceType(reader.deviceType)
            cell.serialNumber = reader.serialNumber
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel?.sections[section].header
    }
}

// MARK: UITableViewDelegate

extension DiscoveryTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch row(at: indexPath) {
        case .pickLocation:
            onPickLocation?()
        case .reader(let reader):
            onReaderPicked?(reader)
        default:
            break
        }
    }
}
