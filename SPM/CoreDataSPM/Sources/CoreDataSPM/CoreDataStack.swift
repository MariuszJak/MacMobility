//
//  CoreDataStack.swift
//  CoreDataSPM
//
//  Created by Mariusz Jakowienko on 23/05/2022.
//

import Foundation
import CoreData

open class CoreDataStack {
    public static let modelName = "ImagesDataModel"

    public static let model: NSManagedObjectModel = {
        guard let objectModelURL = Bundle.module.url(forResource: modelName, withExtension: "momd"),
              let objectModel = NSManagedObjectModel(contentsOf: objectModelURL) else {
            fatalError("Failed to retrieve the object model")
        }
        return objectModel
    }()

    public init() {}

    public lazy var mainContext: NSManagedObjectContext = {
        self.storeContainer.viewContext
    }()

    public lazy var storeContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: CoreDataStack.modelName, managedObjectModel: CoreDataStack.model)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    public func newDerivedContext() -> NSManagedObjectContext {
        let context = storeContainer.newBackgroundContext()
        return context
    }

    public func saveContext(completion: @escaping () -> Void) {
        saveContext(mainContext) {
            completion()
        }
    }

    public func saveContext(_ context: NSManagedObjectContext, completion: @escaping () -> Void) {
        if context != mainContext {
            saveDerivedContext(context) {
                completion()
            }
            return
        }

        context.perform {
            do {
                try context.save()
                completion()
            } catch let error as NSError {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }

    public func saveDerivedContext(_ context: NSManagedObjectContext, completion: @escaping () -> Void) {
        context.perform {
            do {
                try context.save()
            } catch let error as NSError {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            self.saveContext(self.mainContext) {
                completion()
            }
        }
    }
}
