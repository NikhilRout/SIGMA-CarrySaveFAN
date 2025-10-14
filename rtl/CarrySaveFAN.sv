// Note:  first two operands must have the same vec_id
// same vec_ids must be grouped together exactly like SIGMA's baseline FAN 

module CarrySaveFAN #(
    parameter N = 32,    // Number of operands
    parameter W = 8,     // Bit-width of each operand
    parameter V = 3,     // Bit-width of vec id
    parameter S = W + $clog2(N)    // Output width
) (
    input  wire [N-1:0][W-1:0] operands,    // Input operands
    input  wire [N-1:0][V-1:0] vec_ids,     // Input Vector IDs
    output wire [N-2:0][S-1:0] id_sums,     // Output sums
    output wire [N-2:0]        id_valids    // Valid signal for each sum
);
    localparam LEVELS = N - 1;     // Number of CSA levels
    localparam WN = W + LEVELS;    // Max width of CSA intermediate

    // CSA tree intermediates
    wire [LEVELS-1:0][WN-1:0] St;
    wire [LEVELS-1:0][WN-1:0] Ct;

    // Initial first level assignment
    assign St[0] = WN'(operands[0]);
    assign Ct[0] = WN'(operands[1]);

    // CSA tree levels
    for (genvar i = 0; i < LEVELS; i++) begin : g_csa_tree

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

        if (i != LEVELS - 1) begin : g_32_compressors
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
        end else begin : g_last_level
            assign id_valids[i] = 1'b1; // last sum is always valid
        end
    end

endmodule
