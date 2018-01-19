//
//  ViewController.swift
//  SoundWaveForm
//
//  Created by Benoit Pereira da silva on 22/07/2017.
//  Copyright © 2017 Pereira da Silva. All rights reserved.
//

import AVFoundation
import SoundWaveForm

#if os(OSX)
    import AppKit
    public typealias UniversalViewController = NSViewController
    public typealias UniversalImageView = NSImageView
      public typealias UniversalLabel = NSTextField
#elseif os(iOS)
    import UIKit
    public typealias UniversalViewController = UIViewController
    public typealias UniversalImageView = UIImageView
    public typealias UniversalLabel = UILabel
#endif


public class ExampleViewController: UniversalViewController {

    @IBOutlet weak var waveFormView: UniversalImageView!

    @IBOutlet weak var nbLabel: UniversalLabel!

    @IBOutlet weak var samplingDurationLabel: UniversalLabel!

    @IBOutlet weak var drawingDurationLabel: UniversalLabel!

    override public func viewDidLoad() {
        super.viewDidLoad()


        let url = Bundle.main.url(forResource: "Beat110", withExtension: "mp3")!
        let asset = AVAsset(url: url)
        let audioTracks:[AVAssetTrack] = asset.tracks(withMediaType: AVMediaType.audio)
        if let track:AVAssetTrack = audioTracks.first{
            do{

                //let timeRange = CMTimeRangeMake(CMTime(seconds: 0, preferredTimescale: 1000), CMTime(seconds: 1, preferredTimescale: 1000))
                let timeRange:CMTimeRange? = nil
                let width = Int(self.waveFormView.bounds.width)

                // Let's extract the downsampled samples
                let samplingStartTime = CFAbsoluteTimeGetCurrent()
                let sampling = try SamplesExtractor.samples(audioTrack: track,timeRange: timeRange, desiredNumberOfSamples: width)
                let samplingDuration = CFAbsoluteTimeGetCurrent() - samplingStartTime


                // Image Drawing
                // Let's draw the sample into an image.
                let configuration = WaveformConfiguration(size: waveFormView.bounds.size,
                                                          color: WaveColor.red,
                                                          backgroundColor:WaveColor.clear,
                                                          style: .striped(period: 3),
                                                          position: .middle,
                                                          scale: 1,
                                                          borderWidth:0,
                                                          borderColor:WaveColor.red)

                let drawingStartTime = CFAbsoluteTimeGetCurrent()
                self.waveFormView.image = WaveFormDrawer.image(with: sampling, and: configuration)
                let drawingDuration = CFAbsoluteTimeGetCurrent() - drawingStartTime

                // Display the nb of samples, and the processing durations
                #if os(OSX)
                    self.nbLabel.stringValue = "\(width)/\(sampling.samples.count)"
                    self.samplingDurationLabel.stringValue = String(format:"%.3f s",samplingDuration)
                    self.drawingDurationLabel.stringValue = String(format:"%.3f s",drawingDuration)
                #elseif os(iOS)
                    self.nbLabel.text = "\(width)/\(sampling.samples.count)"
                    self.samplingDurationLabel.text = String(format:"%.3f s",samplingDuration)
                    self.drawingDurationLabel.text = String(format:"%.3f s",drawingDuration)
                #endif
            }catch{
                print("\(error)")
            }
        }

    }

}
