// expect-error: JianOption settings must be named
package fixture

import jian.*

@JianCommand
func example(value!: Bool = JianOption('v')) {}
