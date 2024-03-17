import Foundation
import Combine
import UIKit
import CoreDataSPM

class RequestService {
    private let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        return queue
    }()

    func clearCache() {
        Current.cache.removeAllImages()
    }

    func requestImage<T: UIImage>(_ url: URL?) -> AnyPublisher<T?, Error> {
        guard let url = url else {
            return Fail(error: AppError.urlError).eraseToAnyPublisher()
        }
        if let image = Current.cache[url] {
            return Just(image as? T)
                .mapError { _ in AppError.unknown }
                .eraseToAnyPublisher()
        }
        do {
            if let image = try DatabaseManager.shared.image(for: url.absoluteString),
               let data = image.image,
               let image = UIImage(data: data) {
                Current.cache[url] = image
                return Just(image as? T)
                    .mapError { _ in AppError.unknown }
                    .eraseToAnyPublisher()
            }
        } catch {
            Log.error("Failed db operation with error: \(error)")
        }
        Log.info("Fetching image for url: \(url)")
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { data, _ -> T? in T(data: data) }
            .handleEvents(receiveOutput: { image in
                guard let image = image else { return }
                Log.info("Cached image for: \(url)")
                Current.cache[url] = image
                if let imageData = image.pngData() {
                    do {
                        try DatabaseManager.shared.save(image: .init(image: imageData, url: url.absoluteString))
                    } catch {
                        Log.error("Failed db operation with error: \(error)")
                    }
                }
            })
            .catch { error in Fail(error: error) }
            .subscribe(on: backgroundQueue)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
