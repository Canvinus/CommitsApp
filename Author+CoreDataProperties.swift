//
//  Author+CoreDataProperties.swift
//  CommitsApp
//
//  Created by Andrey Gruzdev on 28.11.2020.
//
//

import Foundation
import CoreData


extension Author {

    @nonobjc public class func createFetchRequest() -> NSFetchRequest<Author> {
        return NSFetchRequest<Author>(entityName: "Author")
    }

    @NSManaged public var email: String
    @NSManaged public var name: String
    @NSManaged public var commits: Author

}

extension Author : Identifiable {

}
