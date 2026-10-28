// expect-error: expected
package fixture

import jian.*

@JianCommand
func example(value!: Int64 = JianOption(default: "bad")) {}
