// expect-error: duplicate short name '-v'
package fixture

import jian.*

@Command
func example(verbose!: Bool = Option(short: 'v'), version!: Bool = Option(short: 'v')) {}
