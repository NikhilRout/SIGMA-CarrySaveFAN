// Vector ID comparator
module VecIDComp #(
    parameter N = 3
) (
    input  wire [N-1:0] a, b,
    output wire         eq
);
    wire [N:0] csa_sum, csa_carry;
    wire [N+1:0] diff;

    CSALevel32 #(
        .N (N)
    ) csa (
        .a (a),
        .b (~b),
        .c (N'(1)),
        .sum (csa_sum),
        .carry (csa_carry)
    );

    KoggeStoneAdder #(
        .N(N+1)
    ) ksa (
        .dataa (csa_sum),
        .datab (csa_carry),
        .sum (diff[N:0]),
        .cout (diff[N+1])
    );

    assign eq = ~|diff;
endmodule
