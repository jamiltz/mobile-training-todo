//
//  UsersViewController.swift
//  Todo
//
//  Created by Pasin Suriyentrakorn on 2/8/16.
//  Copyright © 2016 Couchbase. All rights reserved.
//

import UIKit

class UsersViewController: UITableViewController, UISearchResultsUpdating {
    var searchController: UISearchController!
    
    var username: String!
    var database: CBLDatabase!
    var taskList: CBLDocument!
    var usersLiveQuery: CBLLiveQuery!
    var userRows : [CBLQueryRow]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup SearchController:
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .None
        self.tableView.tableHeaderView = searchController.searchBar
        
        // Get username and database:
        let app = UIApplication.sharedApplication().delegate as! AppDelegate
        database = app.database
        username = Session.username
        
        // Setup view and query:
        setupViewAndQuery()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Setup navigation bar:
        self.tabBarController?.title = taskList["name"] as? String
        self.tabBarController?.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "addAction:")
    }
    
    deinit {
        if usersLiveQuery != nil {
            usersLiveQuery.removeObserver(self, forKeyPath: "rows")
            usersLiveQuery.stop()
        }
    }
    
    // MARK: - KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?,
        change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
            if object as? NSObject == usersLiveQuery {
                reloadUsers()
            }
    }
    
    // MARK: - UITableViewController
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return userRows?.count ?? 0
    }
    
    override func tableView(tableView: UITableView,
        cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCellWithIdentifier("UserCell") as UITableViewCell!
            let key = userRows![indexPath.row].key as? [String]
            cell.textLabel?.text = key![1]
            return cell
    }
    
    override func tableView(tableView: UITableView,
        editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
            let delete = UITableViewRowAction(style: .Normal, title: "Delete") {
                (action, indexPath) -> Void in
                // Dismiss row actions:
                tableView.setEditing(false, animated: true)
                // Delete list document:
                let doc = self.userRows![indexPath.row].document!
                self.deleteUser(doc)
            }
            delete.backgroundColor = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
            return [delete]
    }

    
    // MARK: - UISearchController
    
    func updateSearchResultsForSearchController(searchController: UISearchController) {
        let text = searchController.searchBar.text ?? ""
        if !text.isEmpty {
            usersLiveQuery.startKey = [taskList.documentID, text]
            usersLiveQuery.prefixMatchLevel = 2
        } else {
            usersLiveQuery.startKey = nil
            usersLiveQuery.prefixMatchLevel = 1
        }
        usersLiveQuery.endKey = usersLiveQuery.startKey
        usersLiveQuery.queryOptionsChanged()
    }
    
    // MARK: - Action
    
    func addAction(sender: AnyObject) {
        Ui.showTextInputDialog(
            onController: self,
            withTitle: "Add User",
            withMessage: nil,
            withTextFieldConfig: { textField in
                textField.placeholder = "Username"
                textField.autocapitalizationType = .None
            },
            onOk: { username in
                self.addUser(username)
            }
        )
    }
    
    // MARK: - Database
    
    func setupViewAndQuery() {
        let view = database.viewNamed("usersByUsername")
        if view.mapBlock == nil {
            view.setMapBlock({ (doc, emit) -> Void in
                if let type = doc["type"] as? String,
                       username = doc["username"] as? String,
                       listId = (doc["taskList"] as? [String: AnyObject])?["id"]
                    where type == "task-list.user" {
                        emit([listId, username], nil)
                }
            }, version: "1.0")
        }
        
        usersLiveQuery = view.createQuery().asLiveQuery()
        usersLiveQuery.startKey = [taskList.documentID]
        usersLiveQuery.endKey = [taskList.documentID]
        usersLiveQuery.prefixMatchLevel = 1
        
        usersLiveQuery.addObserver(self, forKeyPath: "rows", options: .New, context: nil)
        usersLiveQuery.start()
    }
    
    
    func reloadUsers() {
        userRows = usersLiveQuery.rows?.allObjects as? [CBLQueryRow] ?? nil
        tableView.reloadData()
    }
    
    func addUser(username: String) {
        let taskListInfo = [
            "id": taskList.documentID,
            "owner": taskList["owner"]!
        ]
        
        let properties: Dictionary<String, AnyObject> = [
            "type": "task-list.user",
            "taskList": taskListInfo,
            "username": username,
        ]
        
        let docId = taskList.documentID + "." + username
        guard let doc = database.documentWithID(docId) else {
            Ui.showMessageDialog(onController: self, withTitle: "Error",
                withMessage: "Couldn't save task list")
            return
        }
        do {
            try doc.putProperties(properties)
        } catch let error as NSError {
            Ui.showMessageDialog(onController: self, withTitle: "Error",
                withMessage: "Couldn't add user", withError: error)
        }
    }
    
    func deleteUser(user: CBLDocument) {
        do {
            try user.deleteDocument()
        } catch let error as NSError {
            Ui.showMessageDialog(onController: self, withTitle: "Error",
                withMessage: "Couldn't delete user", withError: error)
        }
    }
}
