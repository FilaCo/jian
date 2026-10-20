package jian.runtime

import jian.runtime.macros.ArgValues

@ArgValues(
    value<Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64>(metavar: "INT"),
    value<Float16, Float32, Float64>(metavar: "FLOAT"),
    value<IntNative>(metavar: "INT", accept: parseIntNative(raw)),
    value<UIntNative>(metavar: "INT", accept: parseUIntNative(raw))
)

/**
 * throws InvalidValueException if input is invalid or outside the native range.
 */
func parseIntNative(raw: ?String): IntNative {
    let value = parseValue<Int64>(raw, "IntNative")
    // The SDK has no native-integer Parsable; conversion must not truncate on narrower targets.
    if (value < Int64(IntNative.Min) || value > Int64(IntNative.Max)) {
        throw InvalidValueException(requiredValue(raw), "IntNative")
    }
    IntNative(value)
}

/**
 * throws InvalidValueException if input is invalid or outside the native range.
 */
func parseUIntNative(raw: ?String): UIntNative {
    let value = parseValue<UInt64>(raw, "UIntNative")
    // The SDK has no native-integer Parsable; conversion must not truncate on narrower targets.
    if (value < UInt64(UIntNative.Min) || value > UInt64(UIntNative.Max)) {
        throw InvalidValueException(requiredValue(raw), "UIntNative")
    }
    UIntNative(value)
}
