module RedTreeFAN #(
    parameter N = 4,    // Number of operands
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
    
    // Initialize the first level with zero-extended input operands
    for (genvar i = 0; i < N; i++) begin : g_init_level
        assign tree_sum[0][i] = {{(S-W){1'b0}}, operands[i]};
    end
        
    for (genvar lvl = 0; lvl < TREE_LEVELS; lvl++) begin : g_sum_tree_levels
        localparam integer CURSZ = N >> lvl;        // Current level size
        localparam integer OUTSZ = CURSZ >> 1;      // Output pairs count
        
        for (genvar i = 0; i < OUTSZ; i++) begin : g_sum_tree_add          
            // Instantiate KSA to add pairs of operands at current level
            KoggeStoneAdder #(
                .N(S)
            ) ksa (
                .dataa(tree_sum[lvl][2*i]),
                .datab(tree_sum[lvl][2*i+1]),
                .sum(tree_sum[lvl+1][i]),
                .cout()
            );
            
            // Connect intermediate sum to output
            assign id_sums[lvl * (N >> 1) + i] = tree_sum[lvl+1][i];
        end
        
        // Odd operand handling - carry forward to next level unchanged
        if (CURSZ % 2 == 1) begin : g_sum_odd_handle
            assign tree_sum[lvl+1][OUTSZ] = tree_sum[lvl][CURSZ-1];
        end
    end
    
endmodule
