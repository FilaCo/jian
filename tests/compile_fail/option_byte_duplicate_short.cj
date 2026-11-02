// expect-error: duplicate short name '-t'
package fixture

import jian.*

@JianCommand
func example(first!: Bool = JianOption(short: 't'), second!: Bool = JianOption(short: b't')) {}
