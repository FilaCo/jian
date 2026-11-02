package jian.api_tests

import jian.*
import jian.api_tests.exported.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

@JianEnumArgValue
enum PaintColor { | Red | DeepBlue | RGBValue | snake_case }

private func paintCode(color: PaintColor): Int64 {
    match (color) {
        case Red => 1
        case DeepBlue => 2
        case RGBValue => 3
        case snake_case => 4
    }
}

@JianCommand
func enumPositional(color: PaintColor): Int64 { paintCode(color) }

@JianCommand
func enumOption(color!: PaintColor): Int64 { paintCode(color) }

@JianCommand
func enumDefault(color!: PaintColor = DeepBlue): Int64 { paintCode(color) }

@JianCommand
func enumOptional(color!: ?PaintColor): Int64 {
    match (color) { case Some(value) => paintCode(value); case None => 0 }
}

@JianCommand
func enumArray(colors: Array<PaintColor>): Int64 {
    var result: Int64 = 0
    for (color in colors) { result = result * 10 + paintCode(color) }
    result
}

@JianCommand
func enumArrayOption(colors!: Array<PaintColor> = []): Int64 {
    enumArray(colors)
}

@JianCallback
func enumCallback(color!: PaintColor): JianCallbackResult { Exit(paintCode(color)) }

@JianCallback
func enumArgumentCallback(color: PaintColor): JianCallbackResult { Exit(paintCode(color)) }

@JianCommand
func enumExported(quality: PaintQuality): Int64 {
    match (quality) { case Normal => 1; case HighQuality => 2 }
}

@Test
class EnumArgValueMacroTest {
    @TestCase
    func variantsUseExactKebabCaseAndPreserveTheirType() {
        // arrange
        let command = EnumPositionalCommand()

        // act
        let results = ["red", "deep-blue", "rgb-value", "snake-case"].map({ text =>
            command.run(JianArgCursor([text]))
        })

        // assert
        @Expect(results, [1, 2, 3, 4])
        @Expect(enumPositional(PaintColor.DeepBlue), 2)
        @Expect(EnumExportedCommand().run(JianArgCursor(["high-quality"])), 2)
        @Expect(PaintColor.takesValue(), true)
        @Expect(PaintColor.whenAbsent().isNone(), true)
        @Expect(PaintColor.metavar(), "PAINT-COLOR")
        let invalid = @AssertThrows[JianUsageException](command.run(JianArgCursor(["Red"])))
        @Expect(invalid.message,
            "invalid value 'Red' for 'COLOR': expected red or deep-blue or rgb-value or snake-case")
        @AssertThrows[JianUsageException](PaintColor.accept(None, None))
    }

    @TestCase
    func scalarOptionsReplaceAndDefaultsAndCollectionsCompose() {
        // arrange
        let scalar = EnumOptionCommand()

        // act
        let code = scalar.run(JianArgCursor(["--color=red", "--color=deep-blue"]))

        // assert
        @Expect(code, 2)
        @Expect(EnumDefaultCommand().run(JianArgCursor([])), 2)
        @Expect(EnumDefaultCommand().run(JianArgCursor(["--color=red"])), 1)
        @Expect(enumDefault(), 2)
        @Expect(EnumOptionalCommand().run(JianArgCursor([])), 0)
        @Expect(EnumOptionalCommand().run(JianArgCursor(["--color=rgb-value"])), 3)
        @Expect(EnumArrayCommand().run(JianArgCursor(["red", "deep-blue"])), 12)
        @Expect(EnumArrayOptionCommand().run(JianArgCursor([])), 0)
        @Expect(EnumArrayOptionCommand().run(JianArgCursor(["--colors=red", "--colors=deep-blue"])), 12)
        @AssertThrows[JianUsageException](scalar.run(JianArgCursor([])))
        @AssertThrows[JianUsageException](EnumPositionalCommand().run(JianArgCursor([])))
        @AssertThrows[JianUsageException](EnumArrayCommand().run(JianArgCursor([])))
        let missing = @AssertThrows[JianUsageException](scalar.run(JianArgCursor(["--color"])))
        @Expect(missing.message, "missing argument '--color'")
        let invalid = @AssertThrows[JianUsageException](scalar.run(JianArgCursor(["--color=green"])))
        @Expect(invalid.message,
            "invalid value 'green' for '--color': expected red or deep-blue or rgb-value or snake-case")
        @AssertThrows[JianUsageException](EnumArrayCommand().run(JianArgCursor(["green"])))
    }

    @TestCase
    func callbacksParseEnumsAndHelpAndErrorsKeepInputContext() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stdout: output, stderr: errors).callback(enumCallback)

        // act
        let helpCode = app.run(["--help"])

        // assert
        @Expect(helpCode, 0)
        @Expect(String.fromUtf8(output.bytes()).contains("--color PAINT-COLOR"), true)
        @Expect(app.run(["--color=deep-blue"]), 2)
        @Expect(JianApp().callback(enumArgumentCallback).run(["rgb-value"]), 3)
        @Expect(app.run(["--color=green"]), 2)
        @Expect(String.fromUtf8(errors.bytes()).contains(
            "invalid value 'green' for '--color': expected red or deep-blue or rgb-value or snake-case"), true)
        @Expect(EnumArrayCommand().spec.inputs[0].metavar, "PAINT-COLOR...")
        @Expect(EnumDefaultCommand().spec.inputs[0].required, false)
        @Expect(EnumOptionalCommand().spec.inputs[0].required, false)
        @Expect(EnumOptionCommand().spec.inputs[0].required, true)
    }
}
