# SoundWaveForm

Allows to extract sound samples from Video or Sounds files very efficiently (it relies on the Accelerate framework). SoundWaveForm expose an optimized cross platform drawing that renders the waveform into an Image.

## It supports 

- macOS 10.11 & + 
- iOS 8 & + 
- swift 3.x

# Screen Shots

![MacDown Screenshot](screenshot-1.png)
![MacDown Screenshot](screenshot-2.png)
![MacDown Screenshot](screenshot-3.png)

# Usage sample 

The framework is composed of a SamplesExtractor and a WaveFormDrawer.

```swift 
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
```

## How to extract sample from a specified timeRange?

You can define AVAssetReader.timeRange.

```swift

let asset = AVURLAsset(url: url)
// Choose an audio track
let audioTracks:[AVAssetTrack] = asset.tracks(withMediaType: AVMediaTypeAudio)
if let track:AVAssetTrack = audioTracks.first{
    guard let asset = track.asset else { return }
    do{
	// Select from second 1 to second 10
	let startTime = CMTime(seconds: 1, preferredTimescale: 1000)
	let endTime = CMTime(seconds: 10, preferredTimescale: 1000)
        let timeRange = CMTimeRangeMake(startTime, endTime)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange 
	// Proceed to extraction (refer to previous code)
	...
    }catch{
    	...
    }	
}
```

## Installation via Carthage

Add to your Cartfile : ` github "benoit-pereira-da-silva/SoundWaveForm"` 


## Inspiration

This project has been largely inspired by [FDWaveformView](https://github.com/fulldecent/FDWaveformView) and [DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage). Thanks to William aka [@fulldecent](https://github.com/fulldecent/) and Daniel [@dmrschmidt](https://github.com/dmrschmidt/).
	
