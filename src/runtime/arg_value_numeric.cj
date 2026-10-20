package jian.runtime

import jian.runtime.macros.ArgValues

@ArgValues(
    (Int8, "INT", true, None, parseValue<Int8>(raw, "Int8")),
    (Int16, "INT", true, None, parseValue<Int16>(raw, "Int16")),
    (Int32, "INT", true, None, parseValue<Int32>(raw, "Int32")),
    (Int64, "INT", true, None, parseValue<Int64>(raw, "Int64")),
    (UInt8, "INT", true, None, parseValue<UInt8>(raw, "UInt8")),
    (UInt16, "INT", true, None, parseValue<UInt16>(raw, "UInt16")),
    (UInt32, "INT", true, None, parseValue<UInt32>(raw, "UInt32")),
    (UInt64, "INT", true, None, parseValue<UInt64>(raw, "UInt64")),
    (Float16, "FLOAT", true, None, parseValue<Float16>(raw, "Float16")),
    (Float32, "FLOAT", true, None, parseValue<Float32>(raw, "Float32")),
    (Float64, "FLOAT", true, None, parseValue<Float64>(raw, "Float64")),
    (IntNative, "INT", true, None, parseIntNative(raw)),
    (UIntNative, "INT", true, None, parseUIntNative(raw))
)

/**
 * throws InvalidValueException if input is invalid or outside the native range.
 */
func parseIntNative(raw: ?String): IntNative {
    let value = parseValue<Int64>(raw, "IntNative")
    // Native integers may be narrower than the SDK parser's fixed-width result.
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
    // Native integers may be narrower than the SDK parser's fixed-width result.
    if (value < UInt64(UIntNative.Min) || value > UInt64(UIntNative.Max)) {
        throw InvalidValueException(requiredValue(raw), "UIntNative")
    }
    UIntNative(value)
}
