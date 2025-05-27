//
//  LiveStreamClient.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 22/05/2025.
//

import Foundation
import Network
import VideoToolbox
import CoreImage
import UIKit
import AVFoundation

class LiveStreamClient: ObservableObject {
    private var listener: NWListener!
    private var connection: NWConnection?
    private var formatDesc: CMFormatDescription?
    private var decompressionSession: VTDecompressionSession?
    private let decodeQueue = DispatchQueue(label: "LiveStreamClient.decodeQueue")
    private let decodeSemaphore = DispatchSemaphore(value: 8)
    private let ciContext = CIContext()
    let videoLayer = AVSampleBufferDisplayLayer()
    var frameCount: Int64 = 0
    let frameRate: Int32 = 60

    private var sps: Data?
    private var pps: Data?

    private var receiveBuffer = Data()

    func connect(to host: String, port: UInt16 = 8888) {
        let nwEndpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        connection = NWConnection(host: nwEndpoint, port: nwPort, using: .tcp)
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            print("Connection state: \(newState)")
        }
        connection?.start(queue: .global())
        startReceiveLoop()
    }

    func disconnect() {
        formatDesc = nil
        listener?.cancel()
        connection?.cancel()
        connection = nil
        listener = nil
        frameCount = 0
        decompressionSession = nil
    }

    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data else { return }

            self.receiveBuffer.append(data)
            self.processNALUnits()

            if isComplete == false && error == nil {
                self.startReceiveLoop()
            }
        }
    }

    private func processNALUnits() {
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]

        while let startRange = receiveBuffer.range(of: Data(startCode)) {
            let nextSearchStart = startRange.upperBound
            guard let nextRange = receiveBuffer.range(of: Data(startCode), options: [], in: nextSearchStart..<receiveBuffer.endIndex) else {
                break // Wait for more data
            }

            let nalUnit = receiveBuffer[startRange.upperBound..<nextRange.lowerBound]
            decodeQueue.async { [nalUnit, weak self] in
                self?.decodeSemaphore.wait()
                defer { self?.decodeSemaphore.signal() }
                self?.decode(nalUnit: nalUnit)
            }

            receiveBuffer.removeSubrange(..<nextRange.lowerBound)
        }
    }

    private func decode(nalUnit: Data) {
        guard nalUnit.count > 0 else {
            return
        }
        
        // Safely access the first byte
        guard let firstByte = nalUnit.first else {
            return
        }
        
        let nalType = firstByte & 0x1F

        switch nalType {
        case 7: // SPS
            sps = nalUnit
            createFormatDescriptionIfNeeded()
            return
        case 8: // PPS
            pps = nalUnit
            createFormatDescriptionIfNeeded()
            return
        default:
            break
        }

        guard let formatDesc = formatDesc else {
            return
        }

        let nalWithLength = withNALLengthPrefix(nalUnit)

        var blockBuffer: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: nalWithLength.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: nalWithLength.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        nalWithLength.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            guard let buffer = blockBuffer else {
                print("Failed to create block buffer")
                return
            }
            CMBlockBufferReplaceDataBytes(with: base, blockBuffer: buffer, offsetIntoDestination: 0, dataLength: nalWithLength.count)
        }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: frameRate),
                presentationTimeStamp: CMTime(value: frameCount, timescale: frameRate),
                decodeTimeStamp: .invalid
            )

        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [nalWithLength.count],
            sampleBufferOut: &sampleBuffer
        )

        if decompressionSession == nil {
            createDecompressionSession()
        }

        if let sampleBuffer = sampleBuffer {
            frameCount += 1
            DispatchQueue.main.async {
                self.videoLayer.enqueue(sampleBuffer)
            }
        }
    }

    private func withNALLengthPrefix(_ nal: Data) -> Data {
        var length = UInt32(nal.count).bigEndian
        var result = Data(bytes: &length, count: 4)
        result.append(nal)
        return result
    }

    private func createFormatDescriptionIfNeeded() {
        guard let sps = sps, let pps = pps, formatDesc == nil else { return }

        let parameterSetPointers: [UnsafePointer<UInt8>] = [
            sps.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) },
            pps.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) }
        ]
        let parameterSetSizes: [Int] = [sps.count, pps.count]

        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: 2,
            parameterSetPointers: parameterSetPointers,
            parameterSetSizes: parameterSetSizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &formatDesc
        )

        if status != noErr {
            print("Failed to create format description: \(status)")
        }
    }

    private func createDecompressionSession() {
        guard let formatDesc = formatDesc else { return }

        var callback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: nil,
            decompressionOutputRefCon: nil
        )

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDesc,
            decoderSpecification: nil,
            imageBufferAttributes: nil,
            outputCallback: &callback,
            decompressionSessionOut: &decompressionSession
        )

        if status != noErr {
            print("Failed to create decompression session: \(status)")
        }
    }
}

enum MoveUpdateType {
    case click
    case drag
    case doubleClick
    case selectAndDragStart
    case selectAndDragUpdate
    case selectAndDragEnd
    case scroll
}

extension LiveStreamClient {
    func sendMouseClick(moveUpdateType: MoveUpdateType, dx: CGFloat, dy: CGFloat) {
        switch moveUpdateType {
        case .click:
            let command = ["type": "click", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
        case .doubleClick:
            let command = ["type": "doubleClick", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
        case .drag:
            let command = ["type": "drag", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
            
        case .selectAndDragStart:
            let command = ["type": "selectAndDragStart", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
            
        case .selectAndDragUpdate:
            let command = ["type": "selectAndDragUpdate", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
            
        case .selectAndDragEnd:
            let command = ["type": "selectAndDragEnd", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
            
        case .scroll:
            let command = ["type": "scroll", "dx": dx, "dy": dy] as [String : Any]
            sendControlPacket(command)
        }
    }

    func sendControlPacket(_ dict: [String: Any]) {
        guard let connection = connection else {
            return
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else { return }
        var length = UInt32(jsonData.count).bigEndian
        let packet = Data(bytes: &length, count: 4) + jsonData
        connection.send(content: packet, completion: .contentProcessed({ _ in }))
    }
}
