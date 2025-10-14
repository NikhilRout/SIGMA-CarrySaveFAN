// Note:  first two operands must have the same vec_id
// same vec_ids must be grouped together exactly like SIGMA's baseline FAN 

module CarrySaveFAN #(
    parameter N = 16,    // Number of operands
    parameter W = 8,     // Bit-width of each operand
    parameter V = 3,     // Bit-width of vec id
    parameter S = W + $clog2(N)    // Output width
) (
    input  wire [N-1:0][W-1:0] operands,    // Input operands
    input  wire [N-1:0][V-1:0] vec_ids,     // Input Vector IDs
    output wire [N-2:0][S-1:0] id_sums,     // Output sums
    output wire [N-2:0]        id_valids    // Valid signal for each sum
);
    localparam LEVELS = N-1;    // Number of CSA levels
    localparam WN = W + LEVELS; // Max width of CSA intermediate

    // CSA tree intermediates
    wire [LEVELS-1:0][WN-1:0] St;
    wire [LEVELS-1:0][WN-1:0] Ct;

    // Initial assignment
    assign St[0] = WN'(operands[0]);
    assign Ct[0] = WN'(operands[1]);

    // CSA tree levels
    genvar i;
	generate
	    for (i = 0; i < LEVELS; i++) begin : g_csa_tree
            localparam WI = W+i;
            
            wire [WI-1:0] st_raw = St[i][WI-1:0];
            wire [WI-1:0] ct_raw = Ct[i][WI-1:0];
            wire [WI:0] st_out;
            wire [WI:0] ct_out;
            wire [WI-1:0] ks_out;

            KoggeStoneAdder #(
                .N (WI)
            ) ksa (
                .dataa (st_raw),
                .datab (ct_raw),
                .sum   (ks_out),
                .cout  ()
            );
            
            assign id_sums[i] = S'(ks_out);

            if (i == LEVELS-1) begin
                assign id_valids[i] = 1'b1;    // last sum is always valid
            end else begin
                wire isEq;
                VecIDComp #(
                    .N (V)
                ) vec_cmp (
                    .a  (vec_ids[i+1]),
                    .b  (vec_ids[i+2]),
                    .eq (isEq)
                );
                assign id_valids[i] = ~isEq;    // sum is valid if IDs don't match (end of group)

                // if IDs match, continue accumulation; else reset for next group
                assign St[i+1] = isEq ? WN'(st_out) : WN'(operands[i+2]);
                assign Ct[i+1] = isEq ? WN'(ct_out) : WN'(0);

                CSALevel32 #(
                    .N (WI)
                ) csa_level (
                    .a     (WI'(operands[i+2])),
                    .b     (st_raw),
                    .c     (ct_raw),
                    .sum   (st_out),
                    .carry (ct_out)
                );
            end
        end
	endgenerate
endmodule

module KoggeStoneAdder #(
    parameter N = 16
) (
    input  wire [N-1:0] dataa,
    input  wire [N-1:0] datab,
    output wire [N-1:0] sum,
    output wire         cout
);
    localparam LEVELS = $clog2(N);

    wire [N-1:0] G [LEVELS+1];
    wire [N-1:0] P [LEVELS+1];

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : g_initial_gp
            assign G[0][i] = dataa[i] & datab[i];
            assign P[0][i] = dataa[i] ^ datab[i];
        end
    endgenerate

    genvar k;
    generate
        for (k = 1; k <= LEVELS; k++) begin : g_ks_levels
            localparam STEP = 1 << (k - 1);
            genvar j;
            for (j = 0; j < N; j++) begin : g_ks_nodes
                if (j >= STEP) begin : g_compute_gp
                    assign G[k][j] = G[k-1][j] | (P[k-1][j] & G[k-1][j-STEP]);
                    assign P[k][j] = P[k-1][j] & P[k-1][j-STEP];
                end else begin : g_passthrough_gp
                    assign G[k][j] = G[k-1][j];
                    assign P[k][j] = P[k-1][j];
                end
            end
        end
    endgenerate

    assign sum[0] = P[0][0];
    genvar m;
    generate
        for (m = 1; m < N; m++) begin : g_sum
            assign sum[m] = P[0][m] ^ G[LEVELS][m-1];
        end
    endgenerate

    assign cout = G[LEVELS][N-1];

endmodule

// Vector ID comparator
module VecIDComp #(
    parameter N = 3
) (
    input  wire [N-1:0] a, b,
    output wire         eq
);
    assign eq = ~|(a ^ b);
endmodule

// 3:2 Compressor based reduction tree level
module CSALevel32 #(
    parameter N = 4
) (
    input  wire [N-1:0] a, b, c,
    output wire [N:0]   sum, carry
);
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : g_compress_3_2
            FullAdder FA (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (c[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

    assign carry[0] = 1'b0;
    assign sum[N] = 1'b0;
endmodule

module FullAdder (
    input  wire a, b, cin,
    output wire sum, cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | ((a ^ b) & cin);
endmodule
