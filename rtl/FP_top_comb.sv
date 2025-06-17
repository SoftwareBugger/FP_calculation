module FP_top_comb (
    input [15:0] i_a,
    input [15:0] i_b,
    input [15:0] i_c,
    input fp8,
    input e5m2,
    input add_en,
    output logic [15:0] o_c
);
    logic [15:0] mul_result;
    logic [15:0] mac_result;
    FloatMul u1 (
        .i_a(i_a),
        .i_b(i_b),
        .fp8(fp8),
        .e5m2(e5m2),
        .o_c(mul_result)
    );
    FP_adder u2 (
        .i_a(mul_result),
        .i_b(i_c),
        .fp8(fp8),
        .e5m2(e5m2),
        .o_c(mac_result)
    );
    always_comb begin : assign_output
        if (add_en) begin
            o_c = mac_result; // Use the output from the adder
        end else begin
            o_c = mul_result; // Use the multiplication result directly
        end
    end
endmodule