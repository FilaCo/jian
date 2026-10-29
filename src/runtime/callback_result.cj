package jian.runtime

import std.deriving.*

/**
 * Controls dispatch after an app callback completes normally. Exceptions propagate separately.
 */
@Derive[Equatable, ToString]
public enum JianCallbackResult {
    /**
     * Continues to the selected command or child app.
     */
    | Continue
    /**
     * Returns code from app.run without invoking any remaining callbacks or command, including code 0.
     */
    | Exit(Int64)
}
