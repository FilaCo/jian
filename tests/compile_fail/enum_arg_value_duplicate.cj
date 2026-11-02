// expect-error: duplicate enum CLI spelling 'deep-blue'
package fixture

import jian.*

@JianEnumArgValue
enum Value { | DeepBlue | Deep_Blue }
