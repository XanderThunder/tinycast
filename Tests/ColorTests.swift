import Foundation

/// The colour card's parser and notations, which no other surface may depend on drifting.
@main
@MainActor
struct ColorTests {
    static var failures = 0
    static var passes = 0

    static func main() {
        colorParsing()
        colorFormatting()
        colorSpaceConversions()
        colorFormatsRoundTrip()
        print("\(passes)/\(passes + failures) passed")
        if failures > 0 { exit(1) }
    }

    static func colorParsing() {
        let cases: [(String, ColorValue)] = [
            ("#FF5733", ColorValue(red: 1, green: 87 / 255, blue: 51 / 255)),
            // Shorthand doubles each digit rather than padding it with a zero.
            ("#0f0", ColorValue(red: 0, green: 1, blue: 0)),
            ("#0f08", ColorValue(red: 0, green: 1, blue: 0, alpha: 136 / 255)),
            ("rgb(255, 87, 51)", ColorValue(red: 1, green: 87 / 255, blue: 51 / 255)),
            ("rgb(0 255 0 / 0.5)", ColorValue(red: 0, green: 1, blue: 0, alpha: 0.5)),
            ("rgba(255,87,51,0.5)", ColorValue(red: 1, green: 87 / 255, blue: 51 / 255, alpha: 0.5)),
            ("hsl(120, 100%, 50%)", ColorValue(red: 0, green: 1, blue: 0)),
            ("hsl(10.6deg 100% 60%)", ColorValue(red: 1, green: 87 / 255, blue: 51 / 255)),
            // The notation a colour picker hands an extension, and its percentage chroma.
            ("oklch(62.7955% 0.257683 29.2338)", ColorValue(red: 1, green: 0, blue: 0)),
            ("oklch(0.627955 64.42% 29.2338deg / 0.5)", ColorValue(red: 1, green: 0, blue: 0, alpha: 0.5))
        ]
        for (text, expected) in cases {
            guard let parsed = ColorValue.parse(text) else {
                expect(false, "\(text) parses")
                continue
            }
            expect(near(parsed, expected), "\(text) resolves to its components")
        }

        // The byte-level reject runs before any trimming, so its shapes are pinned here too.
        for text in ["#FF5733 and more", "rgb(255, 87, 51) plus", "(255, 87, 51)", "#", "rgb"] {
            expect(ColorValue.parse(text) == nil, "\(text) is not a colour")
        }

        // A hex-shaped word and a malformed digit count must never read as a colour.
        let rejected = [
            "#GGGGGG", "#12345", "#", "report.pdf", "rgb(1, 2)", "rgb(1, 2, 3", "hsl(1, 2, 3, 4, 5)",
            "cmyk(0, 1, 1, 0)", "255, 87, 51", "#" + String(repeating: "f", count: 96),
            // Non-finite literals parse as Doubles, and every notation ends in an `Int(_:)`.
            "rgb(nan, 0, 0)", "hsl(inf, 100%, 50%)", "rgb(1e400, 0, 0)", "rgba(0, 0, 0, nan)",
            // CSS writes an HSL channel as a percentage; `100` would otherwise clamp to white.
            "hsl(120, 100, 50)", "hsl(120 100 50)", "hsla(120, 100, 50, 1)",
            // An argument list is counted, so a hole in it is malformed rather than dropped.
            "rgb(255,,87,51)", "rgb(255,87,51,)", "rgb(255, 87)", "rgb()", "rgb(1,2,3,4,5)",
            // The spellings never mix, so a comma body may not also carry a slash.
            "rgb(1/2, 3, 4)", "rgb(255, 87, 51 / 0.5)", "rgb(0 255 0 / 0.5 / 1)", "rgb(/0.5)",
            // Each side of the slash is counted: flattening reads an alpha as a blue channel.
            "rgb(0 255 / 0.5)", "hsl(120 100% / 50%)", "rgb(0 / 255 0)", "rgb(0 255 0 0)",
            // `Double` reads Swift literals CSS never writes, and `isHexDigit` reads fullwidth.
            "rgb(0x10, 0, 0)", "rgb(1e2, 0, 0)", "rgb(+255, 0, 0)", "#\u{ff46}\u{ff46}\u{ff46}"
        ]
        for text in rejected {
            expect(ColorValue.parse(text) == nil, "\(String(text.prefix(20))) is not a colour")
        }

        // `rgba()` is an alias of `rgb()` under CSS Color 4, so alpha is optional in both.
        for text in [
            "rgba(255, 87, 51)", "rgb(255, 87, 51, 0.5)", "hsla(120, 100%, 50%)",
            "hsl(120, 100%, 50%, 0.5)", "hsl(120, 100%, 50%, 50%)", "rgb(0 255 0)",
            // CSS treats every whitespace alike, and a copied declaration spans lines.
            "rgb(255,\n87,\n51)", "rgb(0\n255\n0)"
        ] {
            expect(ColorValue.parse(text) != nil, "\(String(text.prefix(20))) is a colour")
        }

        // Rounding leaves a chroma of ~1e-16 at a lightness of 1, whose saturation divisor is 0.
        guard let almostWhite = ColorValue.parse("rgb(100%, 100%, 99.99999999999999%)") else {
            expect(false, "an almost-white colour parses")
            return
        }
        expect(
            ColorFormat.offered(for: almostWhite).allSatisfy { !$0.string(for: almostWhite).isEmpty },
            "every notation of an almost-white colour states a value rather than trapping")
        expect(
            almostWhite.hsl.saturation.isFinite, "a zero-span lightness reports no saturation")

        // Four-digit shorthand doubles its alpha digit like the three-digit form doubles the rest.
        expect(
            ColorValue.parse("#0f0f").map { ColorFormat.hexWithAlpha.string(for: $0) }
                == "#00FF00FF",
            "#0f0f is opaque green")
        expect(
            ColorValue.parse("#000000FF")?.hasAlpha == false,
            "an alpha that rounds back to opaque is opaque, so no alpha row is offered")

        // The two directions of the HSL conversion must agree, or a copied value drifts.
        let round = ColorValue(red: 0.2, green: 0.6, blue: 0.9)
        let hsl = round.hsl
        expect(
            near(
                ColorValue(hue: hsl.hue, saturation: hsl.saturation, lightness: hsl.lightness),
                round),
            "HSL round-trips back to the same sRGB components")
    }

    static func colorFormatting() {
        guard let color = ColorValue.parse("#FF5733") else {
            expect(false, "the fixture parses")
            return
        }
        expect(ColorFormat.hex.string(for: color) == "#FF5733", "hex is uppercase")
        expect(
            ColorFormat.rgba.string(for: color) == "rgba(255, 87, 51, 1)", "rgba states channels")
        // One decimal, since whole degrees cost up to 5/255 on the way back.
        expect(
            ColorFormat.hsl.string(for: color) == "hsl(10.6deg, 100%, 60%)",
            "hsl keeps the precision that survives a round trip")
        // An exact channel drops its trailing zeros rather than reading `0.210`.
        expect(
            ColorFormat.oklch.string(for: color) == "oklch(68% 0.21 33.7deg)",
            "oklch states three decimals of chroma")
        expect(
            !ColorFormat.offered(for: color).contains(.hslWithAlpha),
            "an opaque colour is offered no alpha-bearing duplicate")

        guard let translucent = ColorValue.parse("rgba(255, 87, 51, 0.5)") else {
            expect(false, "the translucent fixture parses")
            return
        }
        expect(
            ColorFormat.offered(for: translucent) == ColorFormat.allCases,
            "a colour with alpha is offered every notation")
        expect(
            ColorFormat.hexWithAlpha.string(for: translucent) == "#FF573380",
            "alpha is the fourth hex channel")
        expect(
            ColorFormat.primary(for: translucent) == .hexWithAlpha,
            "the notation ↵ copies keeps a translucent colour whole")
        expect(ColorFormat.primary(for: color) == .hex, "an opaque colour copies as plain hex")
    }

    /// The CSS Color 4 spaces, against values a neutral and a known colour must produce.
    static func colorSpaceConversions() {
        guard let grey = ColorValue.parse("#DDDDDD"), let orange = ColorValue.parse("#FF5733")
        else {
            expect(false, "the fixtures parse")
            return
        }
        // A neutral has no hue, and `atan2` over two rounding errors would still name one.
        expect(ColorFormat.oklch.string(for: grey) == "oklch(89.8% 0 0deg)", "nor an Oklch hue")
        // Oklab's axes run to about ±0.4, so a tenth would state most colours as zero.
        expect(
            ColorFormat.oklch.string(for: orange) == "oklch(68% 0.21 33.7deg)", "and Oklch with it")

        // The CSS4 spellings carry alpha behind a slash, and say nothing when there is none.
        guard let translucent = ColorValue.parse("rgba(0, 255, 0, 0.5)") else {
            expect(false, "the translucent fixture parses")
            return
        }
        expect(
            ColorFormat.oklch.string(for: translucent) == "oklch(86.6% 0.295 142.5deg / 0.5)",
            "a slash carries alpha")
        expect(
            ColorFormat.oklch.string(for: orange) == "oklch(68% 0.21 33.7deg)",
            "and an opaque colour states none")
        expect(
            ColorFormat.offered(for: orange).count == ColorFormat.allCases.count - 2,
            "only the two alpha-named spellings are dropped from an opaque colour")
    }

    /// Every offered notation must re-parse to its own colour: one sweep for loss and lost alpha.
    static func colorFormatsRoundTrip() {
        var checked = 0
        for red in stride(from: 0, through: 255, by: 17) {
            for green in stride(from: 0, through: 255, by: 29) {
                for blue in stride(from: 0, through: 255, by: 43) {
                    for alpha in [255, 128] {
                        let color = ColorValue(
                            red: Double(red) / 255, green: Double(green) / 255,
                            blue: Double(blue) / 255, alpha: Double(alpha) / 255)
                        for format in ColorFormat.offered(for: color) {
                            // `oklch()` re-parses, but states too few digits to land on a channel.
                            guard format != .oklch else { continue }
                            let text = format.string(for: color)
                            guard let back = ColorValue.parse(text) else {
                                expect(false, "\(text) re-parses")
                                return
                            }
                            // An alpha-free notation is an opaque spelling by design.
                            guard near(back, color, matchingAlpha: back.hasAlpha == color.hasAlpha)
                            else {
                                expect(false, "\(text) states the colour it came from")
                                return
                            }
                            checked += 1
                        }
                    }
                }
            }
        }
        expect(checked > 500, "the sweep actually covered the notations")
    }

    /// 8-bit channels are what every notation states, so agreement to a channel is agreement.
    static func near(_ lhs: ColorValue, _ rhs: ColorValue, matchingAlpha: Bool = true) -> Bool {
        var channels = [(lhs.red, rhs.red), (lhs.green, rhs.green), (lhs.blue, rhs.blue)]
        if matchingAlpha { channels.append((lhs.alpha, rhs.alpha)) }
        return channels.allSatisfy { abs($0 - $1) < 1.0 / 255 }
    }

    /// Each filter returns only its own kind, and a pin still leads the block.

    static func expect(_ condition: Bool, _ label: String) {
        if condition {
            passes += 1
        } else {
            fail(label)
        }
    }

    static func fail(_ label: String) {
        print("FAIL: \(label)")
        failures += 1
    }
}
