// expect-error: unknown JianArgument setting 'other'
package fixture

import jian.*

@JianCommand
func example(value!: String = JianArgument(other: true)) {}
