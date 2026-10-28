// expect-error: duplicate Argument setting 'default'
package fixture

import jian.*

@Command
func example(value!: String = Argument(default: "a", default: "b")) {}
