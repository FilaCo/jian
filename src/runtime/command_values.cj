package jian.runtime

/** Converts a command's result to its process exit code. */
public func exitCode(_: Unit): Int64 { 0 }

/** Preserves an explicit command exit code. */
public func exitCode(value: Int64): Int64 { value }

/** Resolves value consumption through the declared parameter type, including aliases. */
public func takesValueAs<T>(): Bool where T <: ArgValue<T> { T.takesValue() }

/** Resolves the help placeholder through the declared parameter type. */
public func metavarAs<T>(): String where T <: ArgValue<T> { T.metavar() }

/** Returns the type's implicit default; outer None denotes a required parameter. */
public func whenAbsentAs<T>(): ?T where T <: ArgValue<T> { T.whenAbsent() }
