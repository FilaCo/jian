package jian.builders

/**
 * Public entry point for building a CLI application.
 *
 * Usage:
 *   let CLI = commandLine().add(...).add(...)
 *   CLI.buildAndRun(env.args)
 */
public func commandLine(): AppBuilder {
    App.builder()
}
