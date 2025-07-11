

class_name Util


# Waits until a node is ready.
# NOTE: this will implicitly turn the function into a coroutine.
# useful to use in on-ready
static func await_ready(node: Node):
    if not node.is_node_ready():
        await node.ready



static func debug(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null):
    var lis = [a,b,c,d]
    while not lis.is_empty() and lis.back() == null:
        lis.pop_back()

    var args := OS.get_cmdline_args()
    var prefix = ""
    if "--server" in args:
        prefix = "[SERVER] "
    elif "--client" in args:
        prefix = "(client) "

    print(prefix, " ".join(lis))
