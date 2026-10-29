package jian.runtime

/** Read-only metadata for one invocation at one application level, independent of dependency context. */
public struct JianInvocation {
    /**
     * The next command operand after parsing the callback's arguments and options, or None.
     * This is a requested name, not a validated command: unknown names remain Some(name).
     * For a requested child app this is its mount name; no arguments are consumed by injection.
     */
    public JianInvocation(public let requestedSubcommand!: ?String = None) {}
}

/**
 * Injects JianInvocation into a named JianInvocation parameter of @JianCallback.
 * Creates no CLI input. Direct callers must supply the metadata explicitly.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianCurrentInvocation(): JianInvocation {
    throw IllegalArgumentException("JianCurrentInvocation must be a function parameter default in @JianCallback")
}
