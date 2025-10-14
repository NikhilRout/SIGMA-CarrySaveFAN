// Vector ID comparator
module VecIDComp #(
    parameter N = 3
) (
    input  wire [N-1:0] a, b,
    output wire         eq
);
    assign eq = ~|(a ^ b);
endmodule
