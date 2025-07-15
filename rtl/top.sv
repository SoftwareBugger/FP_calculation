module top(
    input clk,
    input rst_n,
    input [15:0] i_a,
    input [15:0] i_b,
    input i_o_a_ready, // the successor's ready signal for the right output
    input i_o_b_ready, // the successor's ready signal for the bottom output
    input i_i_a_valid, // the predecessor's valid signal for the right input
    input i_i_b_valid, // the predecessor's valid signal for the bottom input   
    input fp8,
    input e5m2,
    input [1:0] flag, // 00: stop, 01: run one tic, 10: bypass input, 11: save and transfer
    input dataflow, // ssm: 0, matmul: 1
    output logic [15:0] o_a_nxt,
    output logic o_o_a_valid, // the successor's valid signal for the right output
    output logic [15:0] o_b_nxt,
    output logic o_o_b_valid, // the successor's valid signal for the bottom output
    output logic o_i_a_ready, // the predecessor's ready signal for the right input
    output logic o_i_b_ready // the predecessor's ready signal for the bottom input
);
    PE pe_inst (
      .clk       (clk),
      .rst_n     (rst_n),
      .i_a       (i_a),
      .i_b       (i_b),
      .i_o_a_ready(i_o_a_ready),
      .i_o_b_ready(i_o_b_ready),
      .i_i_a_valid(i_i_a_valid),
      .i_i_b_valid(i_i_b_valid),
      .fp8       (fp8),
      .e5m2      (e5m2),
      .flag      (flag),
      .dataflow  (dataflow),
      .o_a_nxt   (o_a_nxt),
      .o_o_a_valid(o_o_a_valid),
      .o_b_nxt   (o_b_nxt),
      .o_o_b_valid(o_o_b_valid),
      .o_i_a_ready(o_i_a_ready),
      .o_i_b_ready(o_i_b_ready)
  );
endmodule