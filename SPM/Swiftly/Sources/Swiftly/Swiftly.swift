import UIKit
import Combine
import Foundation

public enum Switlfy {
    public static func setLog(with logLevel: LogLevel) {
        Log.logLevel = logLevel
    }

    public static func loadImage(from url: URL?) -> AnyPublisher<UIImage?, Error> {
        Current.imageProvider.loadImage(url)
    }

    public static func clearCache(for url: URL) {
        Current.cache.removeImage(for: url)
    }
}
