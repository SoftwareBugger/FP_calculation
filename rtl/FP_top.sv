module FP_top (
    input clk,
    input rst_n,
    input [15:0] i_a,
    input [15:0] i_b,
    input [15:0] i_c,
    input fp8,
    input e5m2,
    output logic [15:0] o_c
);
    logic [15:0] mul_result;
    logic [15:0] o_c_in, i_a_in, i_b_in, i_c_in;
    logic fp8_in, e5m2_in;
    FloatMul u1 (
        .i_a(i_a_in),
        .i_b(i_b_in),
        .fp8(fp8_in),
        .e5m2(e5m2_in),
        .o_c(mul_result)
    );
    FP_adder u2 (
        .i_a(mul_result),
        .i_b(i_c_in),
        .fp8(fp8_in),
        .e5m2(e5m2_in),
        .o_c(o_c_in)
    );
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_c <= 16'b0;
            i_a_in <= 16'b0;
            i_b_in <= 16'b0;
            i_c_in <= 16'b0;
            fp8_in <= 1'b0;
            e5m2_in <= 1'b0;
        end else begin
            i_a_in <= i_a;
            i_b_in <= i_b;
            i_c_in <= i_c;
            fp8_in <= fp8;
            e5m2_in <= e5m2;
            o_c <= o_c_in;
        end
    end
endmodule
    