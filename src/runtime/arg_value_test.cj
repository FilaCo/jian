package jian.runtime

import std.fs.Path
import std.math.MaxMinValue
import std.reflect.TypeInfo
import std.unittest.prop_test.{Arbitrary, random}

// The command macro sees only the alias name; CLI behavior must still follow the underlying type.
type MaybeInt = ?Int64

// This SDK resolves static extension members on aliases through a generic constraint.
private func absentAs<T>(): ?T where T <: ArgValue<T> { T.whenAbsent() }

private func expectInvalid<T>(raw: String, expected: String) where T <: ArgValue<T> {
    let error = @AssertThrows[InvalidValueException](acceptAs<T>(None, Some(raw)))
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
        let first = acceptAs<Array<Int64>>(None, Some("1"))

        // act
        let second = acceptAs<Array<Int64>>(Some(first), Some("2"))
        let third = acceptAs<Array<Int64>>(Some(second), Some("3"))

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
        @Expect(flag, Some(false))
        @Expect(array, Some([]))
        @Expect(integer, None)
        @Expect(String.whenAbsent(), None)
        @Expect(Path.whenAbsent(), None)
    }

    @TestCase
    func aliasesUseTheUnderlyingOptionalBehavior() {
        // arrange
        let previous: ?MaybeInt = Some(Some(7))

        // act
        let value = acceptAs<MaybeInt>(previous, Some("42"))

        // assert
        @Expect(value, Some(42))
        @Expect(absentAs<MaybeInt>(), Some(None))
        @Expect(acceptAs<Array<MaybeInt>>(None, Some("3")), [Some(3)])
    }

    @TestCase
    func scalarsReplacePreviousOccurrencesAndPreserveEmptyText() {
        // arrange
        let previous: ?String = Some("before")

        // act
        let text = acceptAs<String>(previous, Some(""))
        let number = acceptAs<Int64>(Some(10), Some("20"))

        // assert
        @Expect(text, "")
        @Expect(number, 20)
    }

    @TestCase[input in [(None<String>, true), (Some("true"), true), (Some("false"), false)]]
    func flagsAcceptBareOccurrencesAndExplicitBooleanValues(input: (?String, Bool)) {
        // arrange
        let (raw, expected) = input

        // act
        let flag = acceptAs<Bool>(Some(!expected), raw)
        let optional = acceptAs<Option<Bool>>(None, raw)

        // assert
        @Expect(flag, expected)
        @Expect(optional, Some(expected))
    }

    @TestCase
    func pathsRemainTextualWithoutCheckingTheirExistence() {
        // arrange
        let raw = "a-missing-directory/../file.txt"

        // act
        let value = acceptAs<Path>(None, Some(raw))

        // assert
        @Expect(value, Path(raw))
        @Expect(value.toString(), raw)
    }

    @TestCase[expected in random()]
    @Types[T in <Int8, Int16, Int32, Int64, IntNative, UInt8, UInt16, UInt32, UInt64, UIntNative>]
    @Configure[randomSeed: 21, generationSteps: 100]
    func integerTextRoundTrips<T>(expected: T) where T <: ArgValue<T> & ToString & Equatable<T> & Arbitrary<T> {
        // arrange
        let raw = expected.toString()

        // act
        let actual = acceptAs<T>(None, Some(raw))

        // assert
        @Expect(actual, expected)
    }

    @TestCase
    @Types[T in <Int8, Int16, Int32, Int64, IntNative, UInt8, UInt16, UInt32, UInt64, UIntNative>]
    func integersAcceptTheirBoundsAndRejectOverflow<T>() where T <: ArgValue<T> & ToString & Equatable<T> & MaxMinValue<T> {
        // arrange
        let minimum = T.getMin()
        let maximum = T.getMax()
        let expectedType = TypeInfo.of<T>().name

        // act
        let low = acceptAs<T>(None, Some(minimum.toString()))
        let high = acceptAs<T>(None, Some(maximum.toString()))

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

    @TestCase[expected in [1.5, -1.5, 0.0]]
    func everyFloatTypeParsesWithoutLosingItsDeclaredType(expected: Float64) {
        // arrange
        let raw = Some(expected.toString())

        // act
        let half = acceptAs<Float16>(None, raw)
        let single = acceptAs<Float32>(None, raw)
        let double = acceptAs<Float64>(None, raw)

        // assert
        @Expect(half, Float16(expected))
        @Expect(single, Float32(expected))
        @Expect(double, expected)
    }

    @TestCase[raw in ["", "oops"]]
    @Types[T in <Int8, Int16, Int32, Int64, IntNative, UInt8, UInt16, UInt32, UInt64, UIntNative, Float16, Float32, Float64, Bool>]
    func invalidScalarsCarryTheRawValueAndExpectedType<T>(raw: String) where T <: ArgValue<T> {
        // arrange
        let expected = TypeInfo.of<T>().name

        // act
        let error = @AssertThrows[InvalidValueException](acceptAs<T>(None, Some(raw)))

        // assert
        @Expect(error.raw, raw)
        @Expect(error.expected, expected)
        @Expect(error.message.contains(raw), true)
        @Expect(error.message.contains(expected), true)
    }

    @TestCase
    @Types[T in <Option<Int64>, Array<Int64>>]
    func containersPreserveTheElementConversionError<T>() where T <: ArgValue<T> {
        // arrange
        let raw = "oops"

        // act
        let error = @AssertThrows[InvalidValueException](acceptAs<T>(None, Some(raw)))

        // assert
        @Expect(error.raw, raw)
        @Expect(error.expected, "Int64")
    }

    @TestCase
    func missingScalarValuesAreUsageErrorsRatherThanOptionUnwrapErrors() {
        // arrange
        let raw = None<String>

        // act
        let error = @AssertThrows[UsageException](acceptAs<Int64>(None, raw))

        // assert
        @Expect(error.message, "missing argument value")
    }

    @TestCase
    func conversionErrorsGainParameterContextAtTheCommandBoundary() {
        // arrange
        let conversion = InvalidValueException("oops", "Int64")

        // act
        let usage = UsageException.invalidValue("--times", conversion.raw, conversion.expected)

        // assert
        @Expect(conversion.toString(), "InvalidValueException: invalid value 'oops': expected Int64")
        @Expect(usage.message, "invalid value 'oops' for '--times': expected Int64")
    }
}
