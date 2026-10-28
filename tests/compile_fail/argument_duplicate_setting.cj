// expect-error: duplicate JianArgument setting 'default'
package fixture

import jian.*

@JianCommand
func example(value!: String = JianArgument(default: "a", default: "b")) {}
