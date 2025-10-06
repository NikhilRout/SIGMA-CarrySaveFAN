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

    // Level 0: initial generate & propagate
    for (genvar i = 0; i < N; i++) begin : g_initial_gp
        assign G[0][i] = dataa[i] & datab[i];
        assign P[0][i] = dataa[i] ^ datab[i];
    end

    // Kogge-Stone tree levels
    for (genvar k = 1; k <= LEVELS; k++) begin : g_ks_levels
        localparam STEP = 1 << (k - 1);
        for (genvar i = 0; i < N; i++) begin : g_ks_nodes
            if (i >= STEP) begin : g_compute_gp
                assign G[k][i] = G[k-1][i] | (P[k-1][i] & G[k-1][i-STEP]);
                assign P[k][i] = P[k-1][i] & P[k-1][i-STEP];
            end else begin : g_passthrough_gp
                assign G[k][i] = G[k-1][i];
                assign P[k][i] = P[k-1][i];
            end
        end
    end

    // Final sum
    assign sum[0] = P[0][0];
    for (genvar i = 1; i < N; i++) begin : g_sum
        assign sum[i] = P[0][i] ^ G[LEVELS][i-1];
    end

    assign cout = G[LEVELS][N-1];

endmodule
