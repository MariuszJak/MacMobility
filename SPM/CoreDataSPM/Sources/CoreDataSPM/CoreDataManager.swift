//
//  CoreDataManager.swift
//  CoreDataSPM
//
//  Created by Mariusz Jakowienko on 23/05/2022.
//

import Foundation
import CoreData

public class CoreDataManager {

    private let coreDataStack: CoreDataStack

    public var context: NSManagedObjectContext {
        coreDataStack.mainContext
    }

    init(coreDataStack: CoreDataStack) {
        self.coreDataStack = coreDataStack
    }

    public func fetchImage(for url: String) throws -> ImageEntity? {
        let fetchRequest = NSFetchRequest<ImageEntity>(entityName: "ImageEntity")
        fetchRequest.predicate = NSPredicate(format: "url == %@", url)
        do {
            let fetch = try coreDataStack.mainContext.fetch(fetchRequest)
            guard let image = fetch.first else { return nil }
            return image
        } catch {
            throw error
        }
    }

    public func fetchImages() throws -> [ImageEntity] {
        let fetchRequest = NSFetchRequest<ImageEntity>(entityName: "ImageEntity")
        return try coreDataStack.mainContext.fetch(fetchRequest)
    }

    public func fetchBasket() throws -> BasketItemsEntity? {
        let fetchRequest = NSFetchRequest<BasketItemsEntity>(entityName: "BasketItemsEntity")
        return try coreDataStack.mainContext.fetch(fetchRequest).first
    }

    public func save(basket: BasketItemsEntity) throws {
        coreDataStack.mainContext.insert(basket)
        try coreDataStack.mainContext.save()
    }

    public func save(image: ImageEntity) throws {
        coreDataStack.mainContext.insert(image)
        try coreDataStack.mainContext.save()
    }

    public func delete(for url: String) throws {
        guard let image = try fetchImage(for: url) else {
            return
        }
        coreDataStack.mainContext.delete(image)
        try coreDataStack.mainContext.save()
    }

    public func deleteBasket() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult>
        fetchRequest = NSFetchRequest(entityName: "BasketItemsEntity")

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let context = coreDataStack.mainContext
        let batchDelete = try coreDataStack.mainContext.execute(deleteRequest) as? NSBatchDeleteResult

        guard let deleteResult = batchDelete?.result as? [NSManagedObjectID] else {
            return
        }

        let deletedObjects: [AnyHashable: Any] = [NSDeletedObjectsKey: deleteResult]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: deletedObjects, into: [context])
    }

    public func deleteAll() throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult>
        fetchRequest = NSFetchRequest(entityName: "ImageEntity")

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let context = coreDataStack.mainContext
        let batchDelete = try coreDataStack.mainContext.execute(deleteRequest) as? NSBatchDeleteResult

        guard let deleteResult = batchDelete?.result as? [NSManagedObjectID] else {
            return
        }

        let deletedObjects: [AnyHashable: Any] = [NSDeletedObjectsKey: deleteResult]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: deletedObjects, into: [context])
    }
}
