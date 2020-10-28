//
//  Extractor.swift
//  SoundWaveForm
//
//  I ve been writing This extractor after analyzing a bunch of existing frameworks
//
//  https://github.com/fulldecent/FDWaveformView
//  https://github.com/dmrschmidt/DSWaveformImage
//  ... 
//  
//  - added supports iOS & macOS
//  - ability to setup a timeRange to restrict automatically the zone of interest.
//  - improved performance
//
//  Created by Benoit Pereira da silva on 22/07/2017. https://pereira-da-silva.com
//  Copyright © 2017 Pereira da Silva. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

public enum SamplesExtractorError: Error {
    case assetNotFound
    case audioTrackNotFound
    case audioTrackMediaTypeMissMatch(mediatype: AVMediaType)
    case readingError(message: String)
    case extractionHasFailed
}


public struct SamplesExtractor{

    
    public fileprivate(set) static var outputSettings: [String : Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]

    public static var noiseFloor: Float = -50.0 // everything below -X dB will be clipped


    /// Samples a sound track
    /// There is no guarantee you will obtain exactly the  desired number of samples
    /// You can compensate in your drawing logic
    ///
    ///
    /// - Parameters:
    ///   - audioTrack: the audio track
    ///   - timeRange: the sampling timerange
    ///   - desiredNumberOfSamples: the desired number of samples
    ///   - onSuccess: the success handler with the samples and the sampleMax
    ///   - onFailure: the failure handler with a contextual error
    ///   - identifiedBy: an optional identifier to be used to support multiple consumers.
    public static func samples( audioTrack: AVAssetTrack,
                                timeRange: CMTimeRange?,
                                desiredNumberOfSamples: Int = 100,
                                onSuccess: @escaping (_ samples: [Float], _ sampleMax: Float,_ identifier: String?)->(),
                                onFailure: @escaping (_ error:Error,_ identifier: String?)->(),
                                identifiedBy: String? = nil){
        do{
            guard let asset = audioTrack.asset else {
                throw SamplesExtractorError.assetNotFound
            }
            let assetReader = try AVAssetReader(asset: asset)
            if let timeRange = timeRange{
                assetReader.timeRange = timeRange
            }

            guard audioTrack.mediaType == .audio else {
                throw SamplesExtractorError.audioTrackMediaTypeMissMatch(mediatype: audioTrack.mediaType)
            }

            let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: SamplesExtractor.outputSettings)
            assetReader.add(trackOutput)

            SamplesExtractor._extract( samplesFrom: assetReader,
                                       asset: assetReader.asset,
                                       track: audioTrack,
                                       downsampledTo: desiredNumberOfSamples,
                                       onSuccess: {samples, sampleMax in
                                        switch assetReader.status {
                                        case .completed:
                                            onSuccess(self._normalize(samples), sampleMax, identifiedBy)
                                        default:
                                            onFailure(SamplesExtractorError.readingError(message:" reading waveform audio data has failed \(assetReader.status)"), identifiedBy)
                                        }
            }, onFailure: { error in
                onFailure(error, identifiedBy)
            })

        }catch{
            onFailure(error,identifiedBy)
        }
    }


    fileprivate static func _extract( samplesFrom reader: AVAssetReader,
                                      asset: AVAsset,
                                      track:AVAssetTrack,
                                      downsampledTo desiredNumberOfSamples: Int,
                                      onSuccess: @escaping (_ samples: [Float], _ sampleMax: Float)->(),
                                      onFailure: @escaping (_ error:Error)->()){

        asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            switch status {
            case .loaded:
                guard
                    let formatDescriptions = track.formatDescriptions as? [CMAudioFormatDescription],
                    let audioFormatDesc = formatDescriptions.first,
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
                    else { break }


                var sampleMax:Float = -Float.infinity

                #if os(OSX)
                let positiveInfinity = kCMTimePositiveInfinity
                #else
                let positiveInfinity = CMTime.positiveInfinity
                #endif

                // By default the reader's timerange is set to CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)
                // So if duration == kCMTimePositiveInfinity we should use the asset duration
                let duration:Double = (reader.timeRange.duration == positiveInfinity) ? Double(asset.duration.value) : Double(reader.timeRange.duration.value)
                let timscale:Double = (reader.timeRange.duration == positiveInfinity) ? Double(asset.duration.timescale) :Double(reader.timeRange.start.timescale)

                let numOfTotalSamples = (asbd.pointee.mSampleRate) * duration / timscale

                var channelCount = 1

                let formatDesc = track.formatDescriptions
                for item in formatDesc {
                    guard let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription) else { continue }
                    channelCount = Int(fmtDesc.pointee.mChannelsPerFrame)
                }

                let samplesPerPixel = Int(max(1,  Double(channelCount) * numOfTotalSamples / Double(desiredNumberOfSamples)))
                let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count:samplesPerPixel)

                var outputSamples = [Float]()
                var sampleBuffer = Data()

                // 16-bit samples
                reader.startReading()

                while reader.status == .reading {
                    guard let readSampleBuffer = reader.outputs[0].copyNextSampleBuffer(),
                        let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                            break
                    }

                    // Append audio sample buffer into our current sample buffer
                    var readBufferLength = 0
                    #if os(OSX)
                    var readBufferPointer: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(readBuffer, 0, &readBufferLength, nil, &readBufferPointer)
                    sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
                    CMSampleBufferInvalidate(readSampleBuffer)
                    #else
                    var readBufferPointer: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(readBuffer, atOffset: 0, lengthAtOffsetOut: &readBufferLength, totalLengthOut: nil, dataPointerOut: &readBufferPointer)
                    sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
                    CMSampleBufferInvalidate(readSampleBuffer)
                    #endif
                    let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
                    let downSampledLength = (totalSamples / samplesPerPixel)
                    let samplesToProcess = downSampledLength * samplesPerPixel

                    guard samplesToProcess > 0 else { continue }

                    self._processSamples(fromData: &sampleBuffer,
                                         sampleMax: &sampleMax,
                                         outputSamples: &outputSamples,
                                         samplesToProcess: samplesToProcess,
                                         downSampledLength: downSampledLength,
                                         samplesPerPixel: samplesPerPixel,
                                         filter: filter)
                }


                // Process the remaining samples at the end which didn't fit into samplesPerPixel
                let samplesToProcess = sampleBuffer.count / MemoryLayout<Int16>.size
                if samplesToProcess > 0 {
                    let downSampledLength = 1
                    let samplesPerPixel = samplesToProcess

                    let filter = [Float](repeating: 1.0 / Float(samplesPerPixel), count: samplesPerPixel)

                    self._processSamples(fromData: &sampleBuffer,
                                         sampleMax: &sampleMax,
                                         outputSamples: &outputSamples,
                                         samplesToProcess: samplesToProcess,
                                         downSampledLength: downSampledLength,
                                         samplesPerPixel: samplesPerPixel,
                                         filter: filter)
                }
                DispatchQueue.main.async {
                    onSuccess(outputSamples, sampleMax)
                }
                return

            case .failed, .cancelled, .loading, .unknown:
                DispatchQueue.main.async {
                    onFailure(SamplesExtractorError.readingError(message: "could not load asset: \(error?.localizedDescription ?? "Unknown error" )"))
                }
            @unknown default:
              DispatchQueue.main.async {
                    onFailure(SamplesExtractorError.readingError(message: "could not load asset unsupported error: \(error?.localizedDescription ?? "" )"))
                }
            }
        }

    }

    private static func _processSamples( fromData sampleBuffer: inout Data,
                                         sampleMax: inout Float,
                                         outputSamples: inout [Float],
                                         samplesToProcess: Int,
                                         downSampledLength: Int,
                                         samplesPerPixel: Int,
                                         filter: [Float]){
        sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int16>) in

            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)

            let sampleCount = vDSP_Length(samplesToProcess)

            //Convert 16bit int samples to floats
            vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)

            //Take the absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)

            //Convert to dB
            var zero: Float = 32768.0
            vDSP_vdbcon(processingBuffer, 1, &zero, &processingBuffer, 1, sampleCount, 1)

            //Clip to [noiseFloor, 0]
            var ceil: Float = 0.0
            var noiseFloorFloat = SamplesExtractor.noiseFloor
            vDSP_vclip(processingBuffer, 1, &noiseFloorFloat, &ceil, &processingBuffer, 1, sampleCount)

            //Downsample and average
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter, &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))

            for element in downSampledData{
                if element > sampleMax { sampleMax = element }
            }
            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
            outputSamples += downSampledData
        }
    }

    fileprivate static func _normalize(_ samples: [Float]) -> [Float] {
        let noiseFloor = SamplesExtractor.noiseFloor
        return samples.map { $0 / noiseFloor }
    }

}

