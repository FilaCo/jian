package jian.runtime

import std.fs.Path
import std.math.MaxMinValue
import std.unittest.prop_test.{Arbitrary, random}

// The command macro sees only the alias name; CLI behavior must still follow the underlying type.
type MaybeInt = ?Int64

// This SDK resolves static extension members on aliases through a generic constraint.
private func absentAs<T>(): ?T where T <: JianArgValue<T> {
    T.whenAbsent()
}

private func expectInvalid<T>(raw: String, expected: String) where T <: JianArgValue<T> {
    let error = @AssertThrows[JianInvalidValueException](jianAcceptAs<T>(None, Some(raw)))
    @Expect(error.raw, raw)
    @Expect(error.expected, expected)
    @Expect(error.message.contains(raw), true)
    @Expect(error.message.contains(expected), true)
}

@Test
class ArgValueTest {
    @TestCase
    func nestedContainersDelegateTheirMetadata() {
        // arrange
        let optionalInts = Array<?Int64>.metavar()

        // act
        let optionalFlagsTakeValue = Option<Bool>.takesValue()

        // assert
        @Expect(optionalInts, "INT...")
        @Expect(optionalFlagsTakeValue, false)
        @Expect(String.metavar(), "TEXT")
        @Expect(Path.metavar(), "PATH")
        @Expect(Float64.metavar(), "FLOAT")
        @Expect(Bool.metavar(), "")
    }

    @TestCase
    func repeatedArrayOccurrencesAppendInOrderWithoutMutatingPreviousValues() {
        // arrange
        let first = jianAcceptAs<Array<Int64>>(None, Some("1"))

        // act
        let second = jianAcceptAs<Array<Int64>>(Some(first), Some("2"))
        let third = jianAcceptAs<Array<Int64>>(Some(second), Some("3"))

        // assert
        @Expect(first, [1])
        @Expect(second, [1, 2])
        @Expect(third, [1, 2, 3])
    }

    @TestCase
    func omittedValuesDistinguishOptionalValuesFromRequiredOnes() {
        // arrange
        let optional = Option<Int64>.whenAbsent()

        // act
        let flag = Bool.whenAbsent()
        let array = Array<String>.whenAbsent()
        let integer = Int64.whenAbsent()

        // assert
        @Expect(optional, Some(None))
        @Expect(flag, None)
        @Expect(array, None)
        @Expect(integer, None)
        @Expect(String.whenAbsent(), None)
        @Expect(Path.whenAbsent(), None)
    }

    @TestCase
    func aliasesUseTheUnderlyingOptionalBehavior() {
        // arrange
        let previous: ?MaybeInt = Some(Some(7))

        // act
        let value = jianAcceptAs<MaybeInt>(previous, Some("42"))

        // assert
        @Expect(value, Some(42))
        @Expect(absentAs<MaybeInt>(), Some(None))
        @Expect(jianAcceptAs<Array<MaybeInt>>(None, Some("3")), [Some(3)])
    }

    @TestCase
    func scalarsReplacePreviousOccurrencesAndPreserveEmptyText() {
        // arrange
        let previous: ?String = Some("before")

        // act
        let text = jianAcceptAs<String>(previous, Some(""))
        let number = jianAcceptAs<Int64>(Some(10), Some("20"))

        // assert
        @Expect(text, "")
        @Expect(number, 20)
    }

    @TestCase[input in [(None<String>, true), (Some("true"), true), (Some("false"), false)]]
    func flagsAcceptBareOccurrencesAndExplicitBooleanValues(input: (?String, Bool)) {
        // arrange
        let (raw, expected) = input

        // act
        let flag = jianAcceptAs<Bool>(Some(!expected), raw)
        let optional = jianAcceptAs<Option<Bool>>(None, raw)

        // assert
        @Expect(flag, expected)
        @Expect(optional, Some(expected))
    }

    @TestCase
    func pathsRemainTextualWithoutCheckingTheirExistence() {
        // arrange
        let raw = "a-missing-directory/../file.txt"

        // act
        let value = jianAcceptAs<Path>(None, Some(raw))

        // assert
        @Expect(value, Path(raw))
        @Expect(value.toString(), raw)
    }

    @TestCase[expected in random()]
    @Types[T in <Int8, Int16, Int32, Int64, IntNative, UInt8, UInt16, UInt32, UInt64, UIntNative>]
    @Configure[randomSeed: 21, generationSteps: 100]
    func integerTextRoundTrips<T>(
        expected: T
    ) where T <: JianArgValue<T> & ToString & Equatable<T> & Arbitrary<T> {
        // arrange
        let raw = expected.toString()

        // act
        let actual = jianAcceptAs<T>(None, Some(raw))

        // assert
        @Expect(actual, expected)
    }

    @TestCase
    func integersAcceptTheirBoundsAndRejectOverflow() {
        // Explicit names keep the error contract testable on SDKs without std.reflect (macOS).
        expectIntegerBounds<Int8>("Int8")
        expectIntegerBounds<Int16>("Int16")
        expectIntegerBounds<Int32>("Int32")
        expectIntegerBounds<Int64>("Int64")
        expectIntegerBounds<IntNative>("IntNative")
        expectIntegerBounds<UInt8>("UInt8")
        expectIntegerBounds<UInt16>("UInt16")
        expectIntegerBounds<UInt32>("UInt32")
        expectIntegerBounds<UInt64>("UInt64")
        expectIntegerBounds<UIntNative>("UIntNative")
    }

    @TestCase[expected in [1.5, -1.5, 0.0]]
    func everyFloatTypeParsesWithoutLosingItsDeclaredType(expected: Float64) {
        // arrange
        let raw = Some(expected.toString())

        // act
        let half = jianAcceptAs<Float16>(None, raw)
        let single = jianAcceptAs<Float32>(None, raw)
        let double = jianAcceptAs<Float64>(None, raw)

        // assert
        @Expect(half, Float16(expected))
        @Expect(single, Float32(expected))
        @Expect(double, expected)
    }

    @TestCase[raw in ["", "oops"]]
    func invalidScalarsCarryTheRawValueAndExpectedType(raw: String) {
        expectInvalid<Int8>(raw, "Int8")
        expectInvalid<Int16>(raw, "Int16")
        expectInvalid<Int32>(raw, "Int32")
        expectInvalid<Int64>(raw, "Int64")
        expectInvalid<IntNative>(raw, "IntNative")
        expectInvalid<UInt8>(raw, "UInt8")
        expectInvalid<UInt16>(raw, "UInt16")
        expectInvalid<UInt32>(raw, "UInt32")
        expectInvalid<UInt64>(raw, "UInt64")
        expectInvalid<UIntNative>(raw, "UIntNative")
        expectInvalid<Float16>(raw, "Float16")
        expectInvalid<Float32>(raw, "Float32")
        expectInvalid<Float64>(raw, "Float64")
        expectInvalid<Bool>(raw, "Bool")
    }

    @TestCase
    @Types[T in <Option<Int64>, Array<Int64>>]
    func containersPreserveTheElementConversionError<T>() where T <: JianArgValue<T> {
        // arrange
        let raw = "oops"

        // act
        let error = @AssertThrows[JianInvalidValueException](jianAcceptAs<T>(None, Some(raw)))

        // assert
        @Expect(error.raw, raw)
        @Expect(error.expected, "Int64")
    }

    @TestCase
    func missingScalarValuesAreUsageErrorsRatherThanOptionUnwrapErrors() {
        // arrange
        let raw = None<String>

        // act
        let error = @AssertThrows[JianUsageException](jianAcceptAs<Int64>(None, raw))

        // assert
        @Expect(error.message, "missing argument value")
    }

    @TestCase
    func conversionErrorsGainInputContextAtTheCommandBoundary() {
        // arrange
        let conversion = JianInvalidValueException("oops", "Int64")

        // act
        let usage = JianUsageException.invalidValue("--times", conversion.raw, conversion.expected)

        // assert
        @Expect(conversion.toString(), "JianInvalidValueException: invalid value 'oops': expected Int64")
        @Expect(usage.message, "invalid value 'oops' for '--times': expected Int64")
    }
}

private func expectIntegerBounds<T>(
    expectedType: String
) where T <: JianArgValue<T> & ToString & Equatable<T> & MaxMinValue<T> {
    // arrange
    let minimum = T.getMin()
    let maximum = T.getMax()

    // act
    let low = jianAcceptAs<T>(None, Some(minimum.toString()))
    let high = jianAcceptAs<T>(None, Some(maximum.toString()))

    // assert
    @Expect(low, minimum)
    @Expect(high, maximum)
    expectInvalid<T>(maximum.toString() + "0", expectedType)
    if (minimum.toString().startsWith("-")) {
        expectInvalid<T>(minimum.toString() + "0", expectedType)
    } else {
        expectInvalid<T>("-1", expectedType)
    }
}
