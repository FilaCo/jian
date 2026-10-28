package jian.runtime

import jian.runtime.macros.JianArgValues

@JianArgValues(
    value<Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64>(metavar: "INT"),
    value<Float16, Float32, Float64>(metavar: "FLOAT"),
    value<IntNative>(metavar: "INT", accept: parseIntNative(raw)),
    value<UIntNative>(metavar: "INT", accept: parseUIntNative(raw))
)

/**
 * throws JianInvalidValueException if input is invalid or outside the native range.
 */
func parseIntNative(raw: ?String): IntNative {
    let value = parseValue<Int64>(raw, "IntNative")
    // The SDK has no native-integer Parsable; conversion must not truncate on narrower targets.
    if (value < Int64(IntNative.Min) || value > Int64(IntNative.Max)) {
        throw JianInvalidValueException(requiredValue(raw), "IntNative")
    }
    IntNative(value)
}

/**
 * throws JianInvalidValueException if input is invalid or outside the native range.
 */
func parseUIntNative(raw: ?String): UIntNative {
    let value = parseValue<UInt64>(raw, "UIntNative")
    // The SDK has no native-integer Parsable; conversion must not truncate on narrower targets.
    if (value < UInt64(UIntNative.Min) || value > UInt64(UIntNative.Max)) {
        throw JianInvalidValueException(requiredValue(raw), "UIntNative")
    }
    UIntNative(value)
}
