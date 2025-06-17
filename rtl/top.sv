module top(
    input clk,
    input rst_n,
    input [15:0] i_a,
    input [15:0] i_b,
    input fp8,
    input e5m2,
    output logic [15:0] o_a_nxt,
    output logic [15:0] o_b_nxt 
);
    PE pe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .i_a(i_a),
        .i_b(i_b),
        .fp8(fp8),
        .e5m2(e5m2),
        .o_a_nxt(o_a_nxt),
        .o_b_nxt(o_b_nxt)
);
endmodule