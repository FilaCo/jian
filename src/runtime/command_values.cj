package jian.runtime

/**
 * Converts a command's result to its process exit code.
 */
public func jianExitCode(_: Unit): Int64 { 0 }

/**
 * Preserves an explicit command exit code.
 */
public func jianExitCode(value: Int64): Int64 { value }

/**
 * Resolves value consumption through the declared parameter type, including aliases.
 */
public func jianTakesValueAs<T>(): Bool where T <: JianArgValue<T> { T.takesValue() }

/**
 * Resolves the help placeholder through the declared parameter type.
 */
public func jianMetavarAs<T>(): String where T <: JianArgValue<T> { T.metavar() }

/**
 * Returns the type's implicit default; outer None denotes a required parameter.
 */
public func jianWhenAbsentAs<T>(): ?T where T <: JianArgValue<T> { T.whenAbsent() }
