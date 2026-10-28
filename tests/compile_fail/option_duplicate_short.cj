// expect-error: duplicate short name '-v'
package fixture

import jian.*

@JianCommand
func example(verbose!: Bool = JianOption(short: 'v'), version!: Bool = JianOption(short: 'v')) {}
