package jian.runtime

import jian.internal_macros.ArgValueImpl

@ArgValueImpl["INT"]
extend Int8 {}

@ArgValueImpl["INT"]
extend Int16 {}

@ArgValueImpl["INT"]
extend Int32 {}

@ArgValueImpl["INT"]
extend Int64 {}

@ArgValueImpl["INT"]
extend UInt8 {}

@ArgValueImpl["INT"]
extend UInt16 {}

@ArgValueImpl["INT"]
extend UInt32 {}

@ArgValueImpl["INT"]
extend UInt64 {}

@ArgValueImpl["FLOAT"]
extend Float16 {}

@ArgValueImpl["FLOAT"]
extend Float32 {}

@ArgValueImpl["FLOAT"]
extend Float64 {}

@ArgValueImpl["INT"]
extend IntNative {
    /**
     * throws InvalidValueException if input is invalid or outside the native range.
     */
    public static func accept(_: ?IntNative, raw: ?String): IntNative {
        let value = parseValue<Int64>(raw, "IntNative")
        // Native integers may be narrower than the SDK parser's fixed-width result.
        if (value < Int64(IntNative.Min) || value > Int64(IntNative.Max)) {
            throw InvalidValueException(requiredValue(raw), "IntNative")
        }
        IntNative(value)
    }
}

@ArgValueImpl["INT"]
extend UIntNative {
    /**
     * throws InvalidValueException if input is invalid or outside the native range.
     */
    public static func accept(_: ?UIntNative, raw: ?String): UIntNative {
        let value = parseValue<UInt64>(raw, "UIntNative")
        // Native integers may be narrower than the SDK parser's fixed-width result.
        if (value < UInt64(UIntNative.Min) || value > UInt64(UIntNative.Max)) {
            throw InvalidValueException(requiredValue(raw), "UIntNative")
        }
        UIntNative(value)
    }
}
