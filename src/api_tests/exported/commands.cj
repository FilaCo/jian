package jian.api_tests.exported

import jian.*

@JianCommand
public func exportedCreate(first!: Int64 = 1, second!: Int64 = first + 2,
    third!: Int64 = second + 4): Int64 {
    first + second + third
}

@JianCallback
public func exportedConfigure(stop!: Int64 = 0): JianCallbackResult {
    if (stop == 0) { JianCallbackResult.Continue } else { JianCallbackResult.Exit(stop) }
}
