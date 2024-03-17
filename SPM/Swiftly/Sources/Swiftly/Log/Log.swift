import Foundation

enum LogType: String {
    case error = "[‼️]"
    case info = "[ℹ️]"
    case debug = "[💬]"
    case verbose = "[🔬]"
    case warning = "[⚠️]"
}

@objc
public enum LogLevel: Int {
    case disabled
    case error
    case info
    case debug
    case verbose
    case warning
}

enum Log {
    static var dateFormat = "yyyy-MM-dd hh:mm:ssSSS"
    static var logLevel = LogLevel.disabled

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        return formatter
    }

    static func error(_ message: String, fileName: String = #file, line: Int = #line, funcName: String = #function) {
        Log.log(message: message, type: LogType.error, fileName: fileName, line: line, funcName: funcName)
    }

    static func info(_ message: String, fileName: String = #file, line: Int = #line, funcName: String = #function) {
        Log.log(message: message, type: LogType.info, fileName: fileName, line: line, funcName: funcName)
    }

    private static func log(message: String, type: LogType, fileName: String = #file, line: Int = #line, funcName: String = #function) {
        if logLevel == .disabled {
            return
        }

        guard let queue = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) else {
            print("\(Date().toString()) \(type.rawValue)[\(Log.sourceFileName(filePath: fileName)):\(line)] \(funcName) -> \(message)")
            return
        }
        print("[\(queue)] \(Date().toString()) \(type.rawValue)[\(Log.sourceFileName(filePath: fileName)):\(line)] \(funcName) -> \(message)")
    }

    private static func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")

        if let lastComponent = components.last {
            return lastComponent
        }
        return ""
    }
}

internal extension Date {
    func toString() -> String {
        Log.dateFormatter.string(from: self as Date)
    }
}
