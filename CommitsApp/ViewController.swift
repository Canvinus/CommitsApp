//
//  ViewController.swift
//  CommitsApp
//
//  Created by Andrey Gruzdev on 28.11.2020.
//

import UIKit
import CoreData

class ViewController: UITableViewController {
    
    var commitPredicate: NSPredicate?
    var commits = [Commit] ()
    var container: NSPersistentContainer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        container = NSPersistentContainer(name: "CommitsApp")
        container.loadPersistentStores { storeDescription, error in
            self.container.viewContext.mergePolicy =
                NSMergeByPropertyObjectTrumpMergePolicy
            if let error = error {
                print("Unresolved error \(error)")
            }
        }
        
        let commit = Commit()
        commit.message = "Woo"
        commit.url = "http://www.example.com"
        commit.date = Date()
        
        performSelector(inBackground: #selector(fetchCommits), with: nil)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Filter",
                                                            style: .plain, target: self, action: #selector(changeFilter))
    }
    
    func configure(commit: Commit, usingJSON json: JSON) {
        commit.sha = json["sha"].stringValue
        commit.message = json["commit"]["message"].stringValue
        commit.url = json["html_url"].stringValue
        let formatter = ISO8601DateFormatter()
        commit.date = formatter.date(from: json["commit"]["committer"]["date"].stringValue) ?? Date()
        var commitAuthor: Author!
        // see if this author exists already
        let authorRequest = Author.createFetchRequest()
        authorRequest.predicate = NSPredicate(format: "name == %@", json["commit"]["committer"]["name"].stringValue)
        if let authors = try? container.viewContext.fetch(authorRequest) {
            if authors.count > 0 {
                // we have this author already
                commitAuthor = authors[0]
            }
        }
        if commitAuthor == nil {
        // we didn't find a saved author - create a new one!
        let author = Author(context: container.viewContext)
        author.name = json["commit"]["committer"]["name"].stringValue
        author.email = json["commit"]["committer"]["email"].stringValue
        commitAuthor = author
        }
        // use the author, either saved or new
        commit.author = commitAuthor
    }
    
    func fetchCommits() {
        if let data = try? Data(contentsOf: URL(string: "https://api.github.com/repos/apple/swift/commits?per_page=100")!) {
            let jsonCommits = JSON(data: data)
            let jsonCommitArray = jsonCommits.arrayValue
            print("Received \(jsonCommitArray.count) new commits.")
            DispatchQueue.main.async { [unowned self] in
                for jsonCommit in jsonCommitArray {
                    // the following three lines are new
                    let commit = Commit(context: self.container.viewContext)
                    self.configure(commit, usingJSON: jsonCommit)
                }
                self.saveContext()
            }
        }
    }
    
    func saveContext(){
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("An error occurred while saving: \(error)")
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection
                                section: Int) -> Int {
        return commits.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath:
                                IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Commit", for:
                                                    indexPath)
        cell.detailTextLabel!.text = "By\(commit.author.name)on\(commit.date.description)"
        let commit = commits[indexPath.row]
        cell.textLabel!.text = commit.message
        cell.detailTextLabel!.text = commit.date.description
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath:
                                IndexPath) {
        if let vc = storyboard?.instantiateViewController(withIdentifier:
                                                            "Detail") as? DetailViewController {
            vc.detailItem = commits[indexPath.row]
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func loadSavedData() {
        let request = Commit.createFetchRequest()
        let sort = NSSortDescriptor(key: "date", ascending: false)
        request.sortDescriptors = [sort]
        request.predicate = commitPredicate
        do {
            commits = try container.viewContext.fetch(request)
            print("Got \(commits.count) commits")
            tableView.reloadData()
        } catch {
            print("Fetch failed")
        }
    }
    
    func changeFilter() {
        let ac = UIAlertController(title: "Filter commits...", message: nil,
                                   preferredStyle: .actionSheet)
        commitPredicate = NSPredicate(format: "message == 'I fixed a bug in Swift'")
        let filter = "I fixed a bug in Swift"
        commitPredicate = NSPredicate(format: "message == %@", filter)
        ac.addAction(UIAlertAction(title: "Show only fixes", style: .default)
        { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "message CONTAINS[c] 'fix'")
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Ignore Pull Requests", style: .default)
        { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "NOT message BEGINSWITH 'Merge pull request'")
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Show only recent", style: .default)
        { [unowned self] _ in
            let twelveHoursAgo = Date().addingTimeInterval(-43200)
            self.commitPredicate = NSPredicate(format: "date > %@", twelveHoursAgo as
                                                NSDate)
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Show all commits", style: .default)
        { [unowned self] _ in
            self.commitPredicate = nil
            self.loadSavedData()
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
        ac.addAction(UIAlertAction(title: "Show only Durian commits",
                                   style: .default) { [unowned self] _ in
            self.commitPredicate = NSPredicate(format: "author.name == 'Joe Groff'")
            self.loadSavedData()
        })
    }
    
}
