// expect-error: JianOption takes its type from the parameter declaration
package fixture

import jian.*

@JianCommand
func example(value!: Int64 = JianOption<Int64>()) {}
