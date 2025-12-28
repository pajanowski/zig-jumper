const std = @import("std");

// This function takes a comptime type `T` and returns a struct type.
fn LinkedList(comptime T: type) type {
    return struct {
        // A field that is a pointer to `T`.
        // The actual value is stored elsewhere.
        data: *T,
        next: ?*Node, // A pointer to the next node in the list.

        // A member function to create a new node.
        pub fn init(value: *T) Node {
            return Node{ .data = value, .next = null };
        }

        // A member function to print the node's data.
        pub fn print(self: Node) void {
            std.debug.print("Node value: {}\n", .{self.data.*});
        }
    };
}

// Usage
test "comptime struct with pointer field" {
    var number: u32 = 100;
    // `Node` is now a concrete type: a struct for `u32`.
    const Node = LinkedList(u32);

    // Create a node that holds a pointer to `number`.
    var node = Node.init(&number);
    node.print(); // Prints: Node value: 100
}
