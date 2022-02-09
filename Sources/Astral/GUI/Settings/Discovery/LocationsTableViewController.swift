//
//  LocationsTableViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit
import StripeTerminal

class LocationsTableViewController: UITableViewController {
    
    var onLocationPicked: ((Location)->())?
    private var locations: [Location]?
    
    var onError: ((Error)->())?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
    }
    
    private var isLoading: Bool = false {
        didSet {
            activityIndicator.isHidden = !isLoading
        }
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isLoading = true
        // By default, only the first 10 locations are returned. This is sufficient for our needs.
        Terminal.shared.listLocations(parameters: nil) { [weak self] locations, hasMore, error in
            guard let self = self else { return }
            self.locations = locations
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isLoading = false
                if let error = error {
                    self.onError?(error)
                }
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: Content
    
    private enum Row {
        case noLocationFound
        case location (Location)
    }
    
    private var rows: [Row] {
        if let locations = locations {  // We have a result
            if locations.count == 0 {  // No locations returned
                return [.noLocationFound]
            } else {
                return locations.map { Row.location($0) }
            }
        } else {  // No result yet
            return []
        }
    }
}

// MARK: UITableViewDataSource

extension LocationsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .noLocationFound:
            return tableView.dequeueReusableCell(withIdentifier: "noLocationDefined", for: indexPath)
            
        case .location(let location):
            let cell = tableView.dequeueReusableCell(withIdentifier: "location", for: indexPath) as! LocationCell
            cell.location = location
            return cell
        }
    }
}

// MARK: UITableViewDelegate

extension LocationsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch rows[indexPath.row] {
        case .noLocationFound:
            break
            
        case .location(let location):
            onLocationPicked?(location)
        }
    }
}
