//
//  ViewController.swift
//  SoundWaveForm
//
//  Created by Benoit Pereira da silva on 22/07/2017.
//  Copyright © 2017 Pereira da Silva. All rights reserved.
//

import AVFoundation

#if os(OSX)
    import AppKit
    import SoundWaveForm
    public typealias UniversalViewController = NSViewController
    public typealias UniversalImageView = NSImageView
#elseif os(iOS)
    import UIKit
    import SoundWaveFormTouch
    public typealias UniversalViewController = UIViewController
    public typealias UniversalImageView = UImageView
#endif



public class ExampleViewController: UniversalViewController {

    @IBOutlet weak var waveFormView: UniversalImageView!


    @IBOutlet weak var nbLabel: NSTextField!


    override public func viewDidLoad() {
        super.viewDidLoad()


        let url = Bundle.main.url(forResource: "BBB", withExtension: "mov")!
        let asset = AVURLAsset(url: url)
        let audioTracks:[AVAssetTrack] = asset.tracks(withMediaType: AVMediaTypeAudio)
        if let track:AVAssetTrack = audioTracks.first{
            guard let asset = track.asset else { return }
            do{
                let timeRange = CMTimeRangeMake(CMTime(seconds: 5, preferredTimescale: 1000), CMTime(seconds: 5 + 1/24, preferredTimescale: 1000))
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = timeRange // You Can set up a specific time range (only once)

                // Let's extract the downsampled samples
                let width = Int(self.waveFormView.bounds.width)
                let samples = try SamplesExtractor.samples(from: reader, audioTrack: track, count: width)

                // Display the nb of samples
                nbLabel.stringValue = "\(width) / \(samples.count)"

                // Let's draw the sample into an image.
                let configuration = WaveformConfiguration(size: waveFormView.bounds.size,
                                                          color: WaveColor.red,
                                                          style: .gradient,
                                                          position: .middle,
                                                          scale: 1)

                waveFormView.image = WaveFormDrawer.image(from: samples, with: configuration)
            }catch{
                print("\(error)")
            }
        }

    }

}
