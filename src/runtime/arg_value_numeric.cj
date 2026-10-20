package jian.runtime

extend Int8 <: ArgValue<Int8> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?Int8, raw: ?String): Int8 { parseValue<Int8>(raw, "Int8") }
    public static func whenAbsent(): ?Int8 { None }
}

extend Int16 <: ArgValue<Int16> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?Int16, raw: ?String): Int16 { parseValue<Int16>(raw, "Int16") }
    public static func whenAbsent(): ?Int16 { None }
}

extend Int32 <: ArgValue<Int32> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?Int32, raw: ?String): Int32 { parseValue<Int32>(raw, "Int32") }
    public static func whenAbsent(): ?Int32 { None }
}

extend Int64 <: ArgValue<Int64> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?Int64, raw: ?String): Int64 { parseValue<Int64>(raw, "Int64") }
    public static func whenAbsent(): ?Int64 { None }
}

extend UInt8 <: ArgValue<UInt8> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?UInt8, raw: ?String): UInt8 { parseValue<UInt8>(raw, "UInt8") }
    public static func whenAbsent(): ?UInt8 { None }
}

extend UInt16 <: ArgValue<UInt16> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?UInt16, raw: ?String): UInt16 { parseValue<UInt16>(raw, "UInt16") }
    public static func whenAbsent(): ?UInt16 { None }
}

extend UInt32 <: ArgValue<UInt32> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?UInt32, raw: ?String): UInt32 { parseValue<UInt32>(raw, "UInt32") }
    public static func whenAbsent(): ?UInt32 { None }
}

extend UInt64 <: ArgValue<UInt64> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    public static func accept(_: ?UInt64, raw: ?String): UInt64 { parseValue<UInt64>(raw, "UInt64") }
    public static func whenAbsent(): ?UInt64 { None }
}

extend Float16 <: ArgValue<Float16> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "FLOAT" }
    public static func accept(_: ?Float16, raw: ?String): Float16 { parseValue<Float16>(raw, "Float16") }
    public static func whenAbsent(): ?Float16 { None }
}

extend Float32 <: ArgValue<Float32> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "FLOAT" }
    public static func accept(_: ?Float32, raw: ?String): Float32 { parseValue<Float32>(raw, "Float32") }
    public static func whenAbsent(): ?Float32 { None }
}

extend Float64 <: ArgValue<Float64> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "FLOAT" }
    public static func accept(_: ?Float64, raw: ?String): Float64 { parseValue<Float64>(raw, "Float64") }
    public static func whenAbsent(): ?Float64 { None }
}

extend IntNative <: ArgValue<IntNative> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    /** @throws InvalidValueException if input is invalid or outside the native range. */
    public static func accept(_: ?IntNative, raw: ?String): IntNative {
        let value = parseValue<Int64>(raw, "IntNative")
        // Native integers may be narrower than the SDK parser's fixed-width result.
        if (value < Int64(IntNative.Min) || value > Int64(IntNative.Max)) {
            throw InvalidValueException(requiredValue(raw), "IntNative")
        }
        IntNative(value)
    }
    public static func whenAbsent(): ?IntNative { None }
}

extend UIntNative <: ArgValue<UIntNative> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "INT" }
    /** @throws InvalidValueException if input is invalid or outside the native range. */
    public static func accept(_: ?UIntNative, raw: ?String): UIntNative {
        let value = parseValue<UInt64>(raw, "UIntNative")
        // Native integers may be narrower than the SDK parser's fixed-width result.
        if (value < UInt64(UIntNative.Min) || value > UInt64(UIntNative.Max)) {
            throw InvalidValueException(requiredValue(raw), "UIntNative")
        }
        UIntNative(value)
    }
    public static func whenAbsent(): ?UIntNative { None }
}
