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

    @IBOutlet weak var topWaveformView: UniversalImageView!
    /*
    @IBOutlet weak var middleWaveformView: UniversalImageView!
    @IBOutlet weak var bottomWaveformView: UniversalImageView!
    @IBOutlet weak var lastWaveformView: UniversalImageView!
    */
    @IBOutlet weak var nbLabel: NSTextField!


    override public func viewDidLoad() {
        super.viewDidLoad()


        let url = Bundle.main.url(forResource: "BBB", withExtension: "mov")!
        let asset = AVURLAsset(url: url)
        let audioTracks:[AVAssetTrack] = asset.tracks(withMediaType: AVMediaTypeAudio)
        if let track:AVAssetTrack = audioTracks.first{
            guard let asset = track.asset else { return }
            do{
                let timeRange = CMTimeRangeMake(CMTime(seconds: 10, preferredTimescale: 1000), CMTime(seconds: 11, preferredTimescale: 1000))
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = timeRange // You Can set up a specific time range (only once)

                // Extract the samples data
                let c = 50// Int(self.topWaveformView.bounds.width)
                guard let samples = Extractor.samples(from: reader, count: c) else { return }

                // Display the nb of samples
                nbLabel.stringValue = "\(c) / \(samples.count)"

                let configuration = WaveformConfiguration(size: topWaveformView.bounds.size,
                                                          color: WaveColor.red,
                                                          style: .gradient,
                                                          position: .middle,
                                                          scale: 1,
                                                          horizontalZoom:1)

                topWaveformView.image = WaveFormDrawer.image(from: samples, with: configuration)
            }catch{
                print("\(error)")
            }
        }

    }

}
