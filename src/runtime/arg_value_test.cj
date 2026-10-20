package jian.runtime

import std.fs.Path

type MaybeInt = ?Int64

private func absentAs<T>(): ?T where T <: ArgValue<T> { T.whenAbsent() }

private func expectInvalid<T>(raw: String, expected: String) where T <: ArgValue<T> {
    var caught = false
    try {
        let _ = acceptAs<T>(None, Some(raw))
    } catch (error: InvalidValueException) {
        caught = true
        @Expect(error.raw, raw)
        @Expect(error.expected, expected)
        @Expect(error.message.contains(raw), true)
        @Expect(error.message.contains(expected), true)
    }
    @Expect(caught, true)
}

@Test
class ArgValueTest {
    @TestCase
    func nestedContainersDelegateTheirMetadata() {
        // arrange
        let optionalInts = Array<MaybeInt>.metavar()
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
        let optional = absentAs<MaybeInt>()
        // act
        let flag = absentAs<Bool>()
        let array = absentAs<Array<String>>()
        let integer = absentAs<Int64>()
        // assert
        @Expect(optional, Some(None))
        @Expect(flag, Some(false))
        @Expect(array, Some([]))
        @Expect(integer, None)
        @Expect(absentAs<String>(), None)
        @Expect(absentAs<Path>(), None)
    }

    @TestCase
    func aliasesUseTheUnderlyingOptionalBehavior() {
        // arrange
        let previous: ?MaybeInt = Some(Some(7))
        // act
        let value = acceptAs<MaybeInt>(previous, Some("42"))
        // assert
        @Expect(value, Some(42))
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

    @TestCase
    func flagsAcceptBareOccurrencesAndExplicitBooleanValues() {
        // arrange
        let previous = Some(false)
        // act
        let bare = acceptAs<Bool>(previous, None)
        let explicitFalse = acceptAs<Bool>(Some(true), Some("false"))
        // assert
        @Expect(bare, true)
        @Expect(explicitFalse, false)
        @Expect(acceptAs<Bool>(None, Some("true")), true)
        @Expect(acceptAs<Option<Bool>>(None, None), Some(true))
        expectInvalid<Bool>("yes", "Bool")
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

    @TestCase
    func everyIntegerTypeParsesWithoutLosingItsDeclaredType() {
        // arrange
        let negative = Some("-12")
        let positive = Some("12")
        // act / assert
        @Expect(acceptAs<Int8>(None, negative), Int8(-12))
        @Expect(acceptAs<Int16>(None, negative), Int16(-12))
        @Expect(acceptAs<Int32>(None, negative), Int32(-12))
        @Expect(acceptAs<Int64>(None, negative), -12)
        @Expect(acceptAs<IntNative>(None, negative), IntNative(-12))
        @Expect(acceptAs<UInt8>(None, positive), UInt8(12))
        @Expect(acceptAs<UInt16>(None, positive), UInt16(12))
        @Expect(acceptAs<UInt32>(None, positive), UInt32(12))
        @Expect(acceptAs<UInt64>(None, positive), UInt64(12))
        @Expect(acceptAs<UIntNative>(None, positive), UIntNative(12))
    }

    @TestCase
    func nativeIntegersAcceptTheirBoundsAndRejectOverflow() {
        // arrange
        let minimum = IntNative.Min.toString()
        let maximum = IntNative.Max.toString()
        let unsignedMaximum = UIntNative.Max.toString()
        // act
        let low = acceptAs<IntNative>(None, Some(minimum))
        let high = acceptAs<IntNative>(None, Some(maximum))
        let unsignedHigh = acceptAs<UIntNative>(None, Some(unsignedMaximum))
        // assert
        @Expect(low, IntNative.Min)
        @Expect(high, IntNative.Max)
        @Expect(unsignedHigh, UIntNative.Max)
        expectInvalid<IntNative>(minimum + "0", "IntNative")
        expectInvalid<IntNative>(maximum + "0", "IntNative")
        expectInvalid<UIntNative>(unsignedMaximum + "0", "UIntNative")
    }

    @TestCase
    func everyFloatTypeParsesWithoutLosingItsDeclaredType() {
        // arrange
        let raw = Some("1.5")
        // act / assert
        @Expect(acceptAs<Float16>(None, raw), Float16(1.5))
        @Expect(acceptAs<Float32>(None, raw), Float32(1.5))
        @Expect(acceptAs<Float64>(None, raw), 1.5)
    }

    @TestCase
    func invalidNumbersCarryTheRawValueAndExpectedType() {
        // arrange / act / assert
        expectInvalid<Int8>("128", "Int8")
        expectInvalid<Int16>("32768", "Int16")
        expectInvalid<Int32>("2147483648", "Int32")
        expectInvalid<Int64>("9223372036854775808", "Int64")
        expectInvalid<IntNative>("oops", "IntNative")
        expectInvalid<UInt8>("256", "UInt8")
        expectInvalid<UInt16>("65536", "UInt16")
        expectInvalid<UInt32>("4294967296", "UInt32")
        expectInvalid<UInt64>("18446744073709551616", "UInt64")
        expectInvalid<UIntNative>("-1", "UIntNative")
        expectInvalid<Float16>("oops", "Float16")
        expectInvalid<Float32>("oops", "Float32")
        expectInvalid<Float64>("oops", "Float64")
        expectInvalid<MaybeInt>("oops", "Int64")
        expectInvalid<Array<Int64>>("oops", "Int64")
    }

    @TestCase
    func missingScalarValuesAreUsageErrorsRatherThanOptionUnwrapErrors() {
        // arrange
        var caught = false
        // act
        try {
            let _ = acceptAs<Int64>(None, None)
        } catch (error: UsageException) {
            caught = true
            @Expect(error.message, "missing argument value")
        }
        // assert
        @Expect(caught, true)
    }

    @TestCase
    func invalidValueExceptionsAreUsageErrors() {
        // arrange
        var caught = false
        // act
        try {
            let _ = acceptAs<Int64>(None, Some("not-an-integer"))
        } catch (error: UsageException) {
            caught = true
            @Expect(error.message.contains("Int64"), true)
        }
        // assert
        @Expect(caught, true)
    }
}
