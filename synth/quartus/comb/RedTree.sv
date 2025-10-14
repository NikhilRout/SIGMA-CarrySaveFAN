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
    // Number of tree levels needed
    localparam TREE_LEVELS = $clog2(N);
    
    // Tree storage: level by operand index
    // Each level can have at most N operands, progressively reducing
    wire [S-1:0] tree_sum [0:TREE_LEVELS] [N-1:0];
    
    genvar i, lvl;
    generate
        for (i = 0; i < N; i++) begin : g_init_level
            assign tree_sum[0][i] = {{(S-W){1'b0}}, operands[i]};
        end
        
        for (lvl = 0; lvl < TREE_LEVELS; lvl++) begin : g_sum_tree_levels
            localparam integer CURSZ = N >> lvl;        // Current level size
            localparam integer OUTSZ = CURSZ >> 1;      // Output pairs count
            localparam integer BASE_IDX = N - (N >> lvl);  // Starting index for this level's outputs
            
            for (i = 0; i < OUTSZ; i++) begin : g_sum_tree_add          
                KoggeStoneAdder #(
                    .N(S)
                ) ksa (
                    .dataa(tree_sum[lvl][2*i]),
                    .datab(tree_sum[lvl][2*i+1]),
                    .sum(tree_sum[lvl+1][i]),
                    .cout()
                );
                
                assign id_sums[BASE_IDX + i] = tree_sum[lvl+1][i];
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
