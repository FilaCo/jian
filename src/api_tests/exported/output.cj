package jian.api_tests.exported

import jian.*

@JianCommand
public func exportedOutput(output!: JianOutput = JianCurrentOutput()) {
    output.stdout.write("exported;".toArray())
}
