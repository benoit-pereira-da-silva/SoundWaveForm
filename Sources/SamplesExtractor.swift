//
//  Extractor.swift
//  SoundWaveForm
//
//  I ve been writing This extractor after analyzing
//  I think that it is more flexible to sample from an AVAssetReader
//  You can setup a timeRange to restrict automatically the zone of interest.
//
//  https://github.com/fulldecent/FDWaveformView 
//  https://github.com/dmrschmidt/DSWaveformImage
//  https://github.com/JagieChen/SFAudioWaveformHelper/
//
//  Created by Benoit Pereira da silva on 22/07/2017. https://pereira-da-silva.com
//  Copyright © 2017 Pereira da Silva. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

enum SamplesExtractorError:Error {
    case audioTrackNotFound
    case readingError(message:String)
}

public struct SamplesExtractor{

    fileprivate static let _outputSettings : [String : Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
    ]

    fileprivate static let _noiseFloor: Float = -50.0 // everything below -50 dB will be clipped

    public static func samples(from assetReader: AVAssetReader,audioTrack:AVAssetTrack?, count: Int = 100) throws ->  [Float] {

        guard let audioTrack = audioTrack ?? assetReader.asset.tracks(withMediaType: AVMediaTypeAudio).first else {
            throw SamplesExtractorError.audioTrackNotFound
        }
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: _outputSettings)
        assetReader.add(trackOutput)
        let requiredNumberOfSamples = count
        if let samples = self._extract(samplesFrom: assetReader,asset:assetReader.asset,track:audioTrack, downsampledTo: requiredNumberOfSamples){
            switch assetReader.status {
            case .completed:
                return self._normalize(samples)
            default:
                throw SamplesExtractorError.readingError(message:" reading waveform audio data has failed \(assetReader.status)")
            }
        }
        throw SamplesExtractorError.readingError(message:"Extraction failed")
    }


    fileprivate static func _extract(samplesFrom reader: AVAssetReader,asset:AVAsset, track:AVAssetTrack,  downsampledTo targetSampleCount: Int) -> [Float]? {
        if let audioFormatDesc = track.formatDescriptions.first {
            let item = audioFormatDesc as! CMAudioFormatDescription     // TODO: Can this be safer?
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(item) {

                let duration = Double(reader.timeRange.duration.value)// Float64(asset.duration.value)
                let timscale = Double(reader.timeRange.start.timescale) //Float64(asset.duration.timescale)

                let numOfTotalSamples = (asbd.pointee.mSampleRate) * duration / timscale

                var channelCount = 1

                let formatDesc = track.formatDescriptions
                for item in formatDesc {
                    guard let fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item as! CMAudioFormatDescription) else { continue }
                    channelCount = Int(fmtDesc.pointee.mChannelsPerFrame)
                }

                let widthInPixels = targetSampleCount
                let samplesPerPixel = Int(max(1,  Double(channelCount) * numOfTotalSamples / Double(widthInPixels)))
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
                    var readBufferPointer: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(readBuffer, 0, &readBufferLength, nil, &readBufferPointer)
                    sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
                    CMSampleBufferInvalidate(readSampleBuffer)

                    let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
                    let downSampledLength = (totalSamples / samplesPerPixel)
                    let samplesToProcess = downSampledLength * samplesPerPixel

                    guard samplesToProcess > 0 else { continue }

                    processSamples(fromData: &sampleBuffer,
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

                    processSamples(fromData: &sampleBuffer,
                                   outputSamples: &outputSamples,
                                   samplesToProcess: samplesToProcess,
                                   downSampledLength: downSampledLength,
                                   samplesPerPixel: samplesPerPixel,
                                   filter: filter)
                }

                return outputSamples

            }
        }
        return nil
    }

    private static func processSamples(fromData sampleBuffer: inout Data,  outputSamples: inout [Float], samplesToProcess: Int, downSampledLength: Int, samplesPerPixel: Int, filter: [Float]) {
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
            var noiseFloorFloat = SamplesExtractor._noiseFloor
            vDSP_vclip(processingBuffer, 1, &noiseFloorFloat, &ceil, &processingBuffer, 1, sampleCount)

            //Downsample and average
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(samplesPerPixel),
                        filter, &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(samplesPerPixel))

            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
            outputSamples += downSampledData
        }
    }

    fileprivate static func _normalize(_ samples: [Float]) -> [Float] {
        let noiseFloor = SamplesExtractor._noiseFloor
        return samples.map { $0 / noiseFloor }
    }

}

