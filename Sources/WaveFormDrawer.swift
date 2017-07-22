//
//  WaveFormDrawer.swift
//  SoundWaveForm
//  Initially based on https://github.com/dmrschmidt/DSWaveformImage
//
//  Created by Benoit Pereira da silva on 22/07/2017.
//  Copyright © 2017 Pereira da Silva. All rights reserved.
//

import Foundation
import AVFoundation

// MARK : - OSX & iOS compatibilty

#if os(OSX)
    import AppKit

    public typealias WaveImage = NSImage
    public typealias WaveColor = NSColor
    var mainScreenScale:CGFloat = 1

#elseif os(iOS)

    import UIKit

    public typealias WaveImage = UIImage
    public typealias WaveColor = UIColor
    var mainScreenScale = UIScreen.main.scale

    extension Color {

        // Cocoa Touch to Cocoa adaptation
        func highlight(withLevel: CGFloat) -> Color? {
            var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0, alpha: CGFloat = 0.0
            self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            let brightnessAdjustment: CGFloat = withLevel
            let adjustmentModifier: CGFloat = brightness < brightnessAdjustment ? 1 : -1
            let newBrightness = brightness + brightnessAdjustment * adjustmentModifier
            return Color(hue: hue, saturation: saturation, brightness: newBrightness, alpha: alpha)
        }
    }

    
#endif


// MARK : - Enums


/**
 Position of the drawn waveform:
 - **top**: Draws the waveform at the top of the image, such that only the bottom 50% are visible.
 - **top**: Draws the waveform in the middle the image, such that the entire waveform is visible.
 - **bottom**: Draws the waveform at the bottom of the image, such that only the top 50% are visible.
 */
public enum WaveformPosition: Int {
    case top    = -1
    case middle =  0
    case bottom =  1
}

/**
 Style of the waveform which is used during drawing:
 - **filled**: Use solid color for the waveform.
 - **gradient**: Use gradient based on color for the waveform.
 - **striped**: Use striped filling based on color for the waveform.
 */
public enum WaveformStyle{
    case filled
    case gradient
    case striped
}



// MARK : - WaveformConfiguration

/// Allows customization of the waveform output image.
public struct WaveformConfiguration {
    /// Desired output size of the waveform image, works together with scale.
    let size: CGSize

    /// Color of the waveform, defaults to black.
    let color: WaveColor

    /// Background color of the waveform, defaults to clear.
    let backgroundColor: WaveColor

    /// Waveform drawing style, defaults to .gradient.
    let style: WaveformStyle

    /// Waveform drawing position, defaults to .middle.
    let position: WaveformPosition

    /// Scale to be applied to the image, defaults to main screen's scale.
    let scale: CGFloat


    /// Optional padding or vertical shrinking factor for the waveform.
    let paddingFactor: CGFloat?

    public init(size: CGSize,
                color: WaveColor = WaveColor.black,
                backgroundColor: WaveColor = WaveColor.clear,
                style: WaveformStyle = .gradient,
                position: WaveformPosition = .middle,
                scale: CGFloat = mainScreenScale,
                horizontalZoom:CGFloat = 1,
                paddingFactor: CGFloat? = nil) {
        self.color = color
        self.backgroundColor = backgroundColor
        self.style = style
        self.position = position
        self.size = size
        self.scale = scale
        self.paddingFactor = paddingFactor
    }
}

// MARK : - WaveFormDrawer


open class WaveFormDrawer {

    public static func image(from samples: [Float], with configuration: WaveformConfiguration) -> WaveImage? {
        #if os(OSX)
            if let context = NSGraphicsContext.current(){
                // Let's use an Image
                let image = NSImage(size: configuration.size)
                image.lockFocus()
                context.shouldAntialias = true
                self._drawBackground(on: context.cgContext, with: configuration)
                self._drawGraph(from: samples, on: context.cgContext, with: configuration)
                return image
            }else{
                // Let's draw Off screen
                NSGraphicsContext.saveGraphicsState()
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                           pixelsWide: Int(configuration.size.width),
                                           pixelsHigh: Int(configuration.size.height),
                                           bitsPerSample: 8,
                                           samplesPerPixel: 4,
                                           hasAlpha: true,
                                           isPlanar: false,
                                           colorSpaceName: NSCalibratedRGBColorSpace,
                                           bytesPerRow: 4  * Int(configuration.size.width),
                                           bitsPerPixel: 32)!
                NSGraphicsContext.setCurrent(NSGraphicsContext(bitmapImageRep: rep))
                let context = NSGraphicsContext.current()!
                context.shouldAntialias = true
                self._drawBackground(on: context.cgContext, with: configuration)
                self._drawGraph(from: samples, on: context.cgContext, with: configuration)
                let image = NSImage(size: configuration.size)
                image.addRepresentation(rep)
                NSGraphicsContext.restoreGraphicsState()
                return image
            }
        #elseif os(iOS)

            UIGraphicsBeginImageContextWithOptions(configuration.size, false, configuration.scale)
            let context = UIGraphicsGetCurrentContext()!
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)

            self.drawBackground(on: context, with: configuration)
            self.drawGraph(from: samples, on: context, with: configuration)

            let graphImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return graphImage
        #endif
    }

    private static func _drawBackground(on context: CGContext, with configuration: WaveformConfiguration) {
        context.setFillColor(configuration.backgroundColor.cgColor)
        context.fill(CGRect(origin: CGPoint.zero, size: configuration.size))
    }

    private static func _drawGraph(from samples: [Float],
                           on context: CGContext,
                           with configuration: WaveformConfiguration) {
        let graphRect = CGRect(origin: CGPoint.zero, size: configuration.size)
        let graphCenter = graphRect.size.height / 2.0
        let positionAdjustedGraphCenter = graphCenter + CGFloat(configuration.position.rawValue) * graphCenter
        let verticalPaddingDivisor = configuration.paddingFactor ?? CGFloat(configuration.position == .middle ? 2.5 : 1.5)
        let drawMappingFactor = graphRect.size.height / verticalPaddingDivisor
        let minimumGraphAmplitude: CGFloat = 1 // we want to see at least a 1pt line for silence

        let path = CGMutablePath()
        var maxAmplitude: CGFloat = 0.0 // we know 1 is our max in normalized data, but we keep it 'generic'
        context.setLineWidth(1.0 / configuration.scale)
        for (x, sample) in samples.enumerated() {
            let xPos = CGFloat(x) / configuration.scale
            let invertedDbSample = 1 - CGFloat(sample) // sample is in dB, linearly normalized to [0, 1] (1 -> -50 dB)
            let drawingAmplitude = max(minimumGraphAmplitude, invertedDbSample * drawMappingFactor)
            let drawingAmplitudeUp = positionAdjustedGraphCenter - drawingAmplitude
            let drawingAmplitudeDown = positionAdjustedGraphCenter + drawingAmplitude
            maxAmplitude = max(drawingAmplitude, maxAmplitude)

            if configuration.style == .striped && (Int(xPos) % 5 != 0) { continue }

            path.move(to: CGPoint(x: xPos, y: drawingAmplitudeUp))
            path.addLine(to: CGPoint(x: xPos, y: drawingAmplitudeDown))
        }
        context.addPath(path)

        switch configuration.style {
        case .filled, .striped:
            context.setStrokeColor(configuration.color.cgColor)
            context.strokePath()
        case .gradient:
            context.replacePathWithStrokedPath()
            context.clip()
            let highlightedColor = configuration.color.highlight(withLevel: 0.5) ?? WaveColor.lightGray
            let colors = NSArray(array: [
                configuration.color.cgColor,
                highlightedColor.cgColor
                ]) as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: nil)!
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: positionAdjustedGraphCenter - maxAmplitude),
                                       end: CGPoint(x: 0, y: positionAdjustedGraphCenter + maxAmplitude),
                                       options: .drawsAfterEndLocation)
        }
    }
}
