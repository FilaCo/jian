// expect-error: unknown JianArgument setting 'short'
package fixture

import jian.*

@JianCommand
func example(value!: String = JianArgument(short: 'v')) {}
