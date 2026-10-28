// expect-error: Option takes its type from the parameter declaration
package fixture

import jian.*

@Command
func example(value!: Int64 = Option<Int64>()) {}
