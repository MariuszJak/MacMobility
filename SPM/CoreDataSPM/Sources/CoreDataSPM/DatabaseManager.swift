//
//  ImagesManager.swift
//  CoreDataSPM
//
//  Created by Mariusz Jakowienko on 23/05/2022.
//

import Foundation
import UIKit
import CoreData
import Combine

public class DatabaseManager {
    let coreDataManager: CoreDataManager

    public static let shared = DatabaseManager()

    public convenience init() {
        self.init(coreDataManager: CoreDataManager(coreDataStack: CoreDataStack()))
    }

    public init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    public func save(items: Data) throws {
        let entity = BasketItemsEntity(context: self.coreDataManager.context, items: items)
        try coreDataManager.save(basket: entity)
    }

    public func save(image: Image) throws {
        let entity = ImageEntity(context: self.coreDataManager.context, image: image)
        try coreDataManager.save(image: entity)
    }

    public func basketItems() throws -> Data? {
        do {
            guard let basketEntity = try coreDataManager.fetchBasket() else { return nil }
            return basketEntity.items
        } catch {
            return nil
        }
    }

    public func image(for url: String) throws -> Image? {
        do {
            guard let imageEntity = try coreDataManager.fetchImage(for: url) else { return nil }
            return Image(from: imageEntity)
        } catch {
            return nil
        }
    }

    public func delete(for url: String) throws {
        try coreDataManager.delete(for: url)
    }

    public func deleteBasket() throws {
        try coreDataManager.deleteBasket()
    }

    public func deleteAll() throws {
        try coreDataManager.deleteAll()
    }
}

public struct Image {
    public let image: Data?
    public let url: String?

    public init(image: Data, url: String) {
        self.url = url
        self.image = image
    }
}

extension Image {
    init(from entity: ImageEntity) {
        self.image = entity.img
        self.url = entity.url
    }
}

extension ImageEntity {
    convenience init(context: NSManagedObjectContext, image: Image) {
        self.init(context: context)
        self.img = image.image
        self.url = image.url
    }
}

extension BasketItemsEntity {
    convenience init(context: NSManagedObjectContext, items: Data) {
        self.init(context: context)
        self.items = items
    }
}
