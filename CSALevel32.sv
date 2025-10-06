// 3:2 Compressor based reduction tree level
module CSALevel32 #(
    parameter N = 4
) (
    input  wire [N-1:0] a, b, c,
    output wire [N:0]   sum, carry
);
    for (genvar i = 0; i < N; i++) begin : g_compress_3_2
        FullAdder FA (
            .a    (a[i]),
            .b    (b[i]),
            .cin  (c[i]),
            .sum  (sum[i]),
            .cout (carry[i+1])
        );
    end

    assign carry[0] = 1'b0;
    assign sum[N] = 1'b0;
endmodule
