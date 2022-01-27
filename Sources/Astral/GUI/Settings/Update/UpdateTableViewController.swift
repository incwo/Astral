//
//  UpdateTableViewController.swift
//  Astral
//
//  Created by Renaud Pradenc on 05/01/2022.
//

import UIKit

class UpdateTableViewController: UITableViewController {
    var viewModel: UpdateViewModel?

    func reload() {
        tableView.reloadData()
    }
    
    func updateProgress(_ progress: Float) {
        updatingCell?.progress = progress
    }
    // Keep a reference to update the progress
    private var updatingCell: UpdatingCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    private func row(at indexPath: IndexPath) -> UpdateViewModel.Row {
        viewModel!.sections[indexPath.section].rows[indexPath.row]
    }

}

// MARK: UITableViewDataSource

extension UpdateTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel?.sections.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection sectionIndex: Int) -> Int {
        guard let section = viewModel?.sections[sectionIndex] else {
            return 0
        }
        
        return section.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch row(at: indexPath) {
        case .currentVersion(let version):
            let cell = tableView.dequeueReusableCell(withIdentifier: "currentVersion", for: indexPath) as! VersionCell
            cell.version = version
            return cell
            
        case .updateVersion(let version):
            let cell = tableView.dequeueReusableCell(withIdentifier: "updateVersion", for: indexPath) as! VersionCell
            cell.version = version
            return cell
            
        case .upToDate:
            return tableView.dequeueReusableCell(withIdentifier: "upToDate", for: indexPath)
            
        case .update:
            return tableView.dequeueReusableCell(withIdentifier: "update", for: indexPath)
            
        case .updating (let progress):
            let cell = tableView.dequeueReusableCell(withIdentifier: "updating", for: indexPath) as! UpdatingCell
            self.updatingCell = cell
            cell.progress = progress
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        viewModel?.sections[section].footer
    }
}

// MARK: UITableViewDelegate

extension UpdateTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch row(at: indexPath) {
        case .update:
            viewModel?.onInstallUpdate()
        default:
            break
        }
    }
}
