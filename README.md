# SoundWave Form

Allows to extract samples from Video or Sounds very efficiently (it relies on the Accelerate framework). You can define specific time range to constraint the AVAssetReader.

I m busy at the moment, but i will provide soon improvements and Playgrounds.

## It supports 

- macOS 10.11 & + 
- iOS 8 & + 
- swift 3.x

## Installation via Carthage

Add to your Cartfile : ` github "benoit-pereira-da-silva/SoundWaveForm"` 

# Usage sample 

```swift 
        let asset = AVURLAsset(url: url)
        let audioTracks:[AVAssetTrack] = asset.tracks(withMediaType: AVMediaTypeAudio)
        if let track:AVAssetTrack = audioTracks.first{
            guard let asset = track.asset else { return }
            do{
		// Select from second 1 to second 10
                let timeRange = CMTimeRangeMake(CMTime(seconds: 1, preferredTimescale: 1000), CMTime(seconds: 10, preferredTimescale: 1000))
                let reader = try AVAssetReader(asset: asset)
                reader.timeRange = timeRange 

                // Extract the downsampled samples
                let samples = try SamplesExtractor.samples(from: reader, audioTrack: track, desiredNumberOfSamples: 500)


                // Draw the sample into an image.
                let configuration = WaveformConfiguration(size: waveFormView.bounds.size,
                                                          color: WaveColor.red,
                                                          style: .striped,
                                                          position: .middle,
                                                          scale: 1)
                // Let's display the waveform in a view                     
                self.waveFormView.image = WaveFormDrawer.image(from: samples, with: configuration)
            }catch{
                print("\(error)")
            }
        }

```


# Screen Shots

![MacDown Screenshot](screenshot-1.png)
![MacDown Screenshot](screenshot-2.png)
![MacDown Screenshot](screenshot-3.png)


## This project has been largely inspired by :

- [FDWaveformView](https://github.com/fulldecent/FDWaveformView)
- [DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage)

Thanks to William aka [@fulldecent](https://github.com/fulldecent/) and Daniel [@dmrschmidt](https://github.com/dmrschmidt/).
