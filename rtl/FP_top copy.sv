module FP_top (
    input [15:0] i_a,
    input [15:0] i_b,
    input [15:0] i_c,
    input fp8,
    input e5m2,
    output logic [15:0] o_c
);
    logic [15:0] mul_result;
    FloatMul u1 (
        .i_a(i_a),
        .i_b(i_b),
        .fp8(fp8),
        .e5m2(e5m2),
        .o_c(mul_result)
    );
    FP_add u2 (
        .i_a(mul_result),
        .i_b(i_c),
        .fp8(fp8),
        .e5m2(e5m2),
        .o_c(o_c)
    );
endmodule
    