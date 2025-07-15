`timescale 1ns/1ps

module tb_PE;
    // DUT interface
    logic clk;
    logic rst_n;
    logic [15:0] i_a;
    logic [15:0] i_b;
    logic i_o_a_ready; // the successor's ready signal for the right output
    logic i_o_b_ready; // the successor's ready signal for the bottom output
    logic i_i_a_valid; // the predecessor's valid signal for the right input
    logic i_i_b_valid; // the predecessor's valid signal for the bottom input
    logic fp8;
    logic e5m2;
    logic [1:0] flag; // 00: stop, 01: run one tic, 10: bypass input, 11: save and transfer
    logic dataflow; // ssm: 0, matmul: 1  
    logic [15:0] o_a_nxt;
    logic o_o_a_valid; // the successor's valid signal for the right output
    logic [15:0] o_b_nxt;
    logic o_o_b_valid; // the successor's valid signal for the bottom output
    logic o_i_a_ready; // the predecessor's ready signal for the right input
    logic o_i_b_ready; // the predecessor's ready signal for the bottom input
    PE dut (
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
    // Reference FP MAC module
    logic [15:0] result, input1, input2, input3;
    FP_top_comb FP_inst (
      .i_a(input1),
      .i_b(input2),
      .i_c(input3),
      .fp8(fp8),
      .add_en(dut.add_en),
      .e5m2(e5m2),
      .o_c(result)
    );

    task automatic test_SSM_3cycle(input [15:0] a, b, input fp8_val, e5m2_val, input [2:0] cycle, input dataflow_val);
        reg [15:0] expected_o_a, expected_o_b;
        begin
            i_a = a;
            i_b = b;
            flag = 2'b01; // run one tic
            fp8 = fp8_val;
            e5m2 = e5m2_val;
            dataflow = dataflow_val;
            i_o_a_ready = 1'b1; // assume the successor is ready
            i_o_b_ready = 1'b1; // assume the successor is ready
            i_i_a_valid = 1'b1; // assume the predecessor is valid
            i_i_b_valid = 1'b1; // assume the predecessor is valid
            @(negedge clk); // wait for the clock edge
            case (cycle)
                3'd0: begin
                    // Cycle 0 op_3 = op_1 + op_2 * op_3
                    expected_o_a = result; // output is MAC result
                    expected_o_b = dut.op_2; // bottom output is op_2
                end
                3'd1: begin
                    // Cycle 1 op_2 = op_1 * op_2
                    expected_o_a = dut.op_1; // right output is op_1
                    expected_o_b = dut.op_2; // output is op_2
                end
                3'd2: begin
                    expected_o_a = dut.op_1; // right output is op_1
                    expected_o_b = 0; // no output
                end
                default: begin
                    expected_o_a = 16'hxxxx;
                    expected_o_b = 16'hxxxx;
                end
            endcase
            $display("-----------------------------");
            $display("Cycle %d:", cycle);
            $display("PE op_1 = %h, op_2 = %h, op_3 = %h", dut.op_1, dut.op_2, dut.op_3);
            if (o_a_nxt !== expected_o_a) begin
                $display("Error in cycle %d: expected o_a_nxt = %h, got %h", cycle, expected_o_a, o_a_nxt);
            end else begin
                $display("Cycle %d: o_a_nxt = %h as expected", cycle, o_a_nxt);
            end
            if (o_b_nxt !== expected_o_b) begin
                $display("Error in cycle %d: expected o_b_nxt = %h, got %h", cycle, expected_o_b, o_b_nxt);
            end else begin
                $display("Cycle %d: o_b_nxt = %h as expected", cycle, o_b_nxt);
            end
        end
    endtask

    task automatic idle_cycle(input [1:0] flag_val, input fp8_val, e5m2_val, input dataflow_val);
        begin
            i_a = 16'h0;
            i_b = 16'h0;
            flag = flag_val; // stop
            fp8 = fp8_val;
            e5m2 = e5m2_val;
            dataflow = dataflow_val;
            i_o_a_ready = 1'b1; // assume the successor is ready
            i_o_b_ready = 1'b1; // assume the successor is ready
            i_i_a_valid = 1'b1; // assume the predecessor is valid
            i_i_b_valid = 1'b1; // assume the predecessor is valid
        end
    endtask

    task automatic bypass_cycle(input [15:0] a, b, input fp8_val, e5m2_val, input dataflow_val);
        begin
            @(negedge clk); // wait for the clock edge
            i_a = a;
            i_b = b;
            flag = 2'b10; // bypass input
            fp8 = fp8_val;
            e5m2 = e5m2_val;
            dataflow = dataflow_val;
            i_o_a_ready = 1'b1; // assume the successor is ready
            i_o_b_ready = 1'b1; // assume the successor is ready
            i_i_a_valid = 1'b1; // assume the predecessor is valid
            i_i_b_valid = 1'b1; // assume the predecessor is valid
            @(posedge clk); // wait for the clock edge
            #1;
            $display("-----------------------------");
            $display("Bypass Cycle:");
            $display("Input a = %h, b = %h", a, b);
            if (o_a_nxt !== a) begin
                $display("Error in bypass: expected o_a_nxt = %h, got %h", a, o_a_nxt);
            end else begin
                $display("Bypass: o_a_nxt = %h as expected", o_a_nxt);
            end
            if (o_b_nxt !== b) begin
                $display("Error in bypass: expected o_b_nxt = %h, got %h", b, o_b_nxt);
            end else begin
                $display("Bypass: o_b_nxt = %h as expected", o_b_nxt);
            end
        end
    endtask

    task automatic test_save_transfer(input [15:0] a, b, input fp8_val, e5m2_val, input dataflow_val);
        begin
            @(negedge clk); // wait for the clock edge
            b = 16'h0; // b is not used in save and transfer
            i_a = a;
            i_b = b;
            flag = 2'b11; // save and transfer
            fp8 = fp8_val;
            e5m2 = e5m2_val;
            dataflow = dataflow_val;
            i_o_a_ready = 1'b1; // assume the successor is ready
            i_o_b_ready = 1'b1; // assume the successor is ready
            i_i_a_valid = 1'b1; // assume the predecessor is valid
            i_i_b_valid = 1'b1; // assume the predecessor is valid

            @(posedge clk); // wait for the clock edge
            #1;
            $display("-----------------------------");
            $display("Save and Transfer Cycle:");
            $display("Input a = %h, b = %h", a, b);
            if (o_a_nxt !== dut.op_3) begin
                $display("Error in save and transfer: expected o_a_nxt = %h, got %h", dut.op_3, o_a_nxt);
            end else begin
                $display("Save and Transfer: o_a_nxt = %h as expected", o_a_nxt);
            end
            if (o_b_nxt !== b) begin
                $display("Error in save and transfer: expected o_b_nxt = %h, got %h", b, o_b_nxt);
            end else begin
                $display("Save and Transfer: o_b_nxt = %h as expected", o_b_nxt);
            end
        end
    endtask

    task automatic test_matmul_cycle(input [15:0] a, b, input fp8_val, e5m2_val);
        begin
            @(negedge clk); // wait for the clock edge
            i_a = a;
            i_b = b;
            flag = 2'b01; // run one tic
            fp8 = fp8_val;
            e5m2 = e5m2_val;
            dataflow = 1'b1; // matmul mode
            i_o_a_ready = 1'b1; // assume the successor is ready
            i_o_b_ready = 1'b1; // assume the successor is ready
            i_i_a_valid = 1'b1; // assume the predecessor is valid
            i_i_b_valid = 1'b1; // assume the predecessor is valid
            @(posedge clk); // wait for the clock edge
            #1;
            $display("-----------------------------");
            $display("MatMul Cycle:");
            $display("PE op_1 = %h, op_2 = %h, op_3 = %h", dut.op_1, dut.op_2, dut.op_3);
            if (o_a_nxt !== dut.op_1) begin
                $display("Error in matmul: expected o_a_nxt = %h, got %h", dut.op_1, o_a_nxt);
            end else begin
                $display("MatMul: o_a_nxt = %h as expected", o_a_nxt);
            end
            if (o_b_nxt !== dut.op_2) begin
                $display("Error in matmul: expected o_b_nxt = %h, got %h", dut.op_2, o_b_nxt);
            end else begin
                $display("MatMul: o_b_nxt = %h as expected", o_b_nxt);
            end
        end
    endtask

    // initial block begins
    logic [15:0] test_a, test_b, last_op3_value;
    logic fp8_test, e5m2_test;
    logic signed [5:0] cycle_count;
    logic dataflow_test;
    initial begin
        input1 = dut.op_3;
        input2 = dut.op_2;
        input3 = dut.op_1;
        test_a = 16'hd200; // -2.0 in FP16
        test_b = 16'h4000; // 2.0 in FP16
        fp8_test = 1'b0; // FP16 mode
        e5m2_test = 1'b0; // FP16 mode
        dataflow_test = 1'b0; // SSM mode
        cycle_count = 3'd0;
        clk = 1'b1;
        rst_n = 1'b0;
        #15;
        rst_n = 1'b1;
        // idle for a few cycles
        @(posedge clk) idle_cycle(2'b01, fp8_test, e5m2_test, dataflow_test);
        for (cycle_count = 0; cycle_count < 15; cycle_count = cycle_count + 1) begin
            @(posedge clk) test_SSM_3cycle(test_a, test_b, fp8_test, e5m2_test, (cycle_count % 3), dataflow_test);
        end
        // bypass test
        for (cycle_count = 0; cycle_count < 5; cycle_count = cycle_count + 1) begin
            bypass_cycle(test_a + cycle_count, test_b, fp8_test, e5m2_test, dataflow_test);
        end
        // save and transfer test
        for (cycle_count = 0; cycle_count < 5; cycle_count = cycle_count + 1) begin
            test_save_transfer(test_a + cycle_count, test_b, fp8_test, e5m2_test, dataflow_test);
        end
        input1 = dut.op_1;
        input2 = dut.op_2;
        input3 = dut.op_3;
        // matmul test
        dataflow_test = 1'b1; // matmul mode
        for (cycle_count = 0; cycle_count < 10; cycle_count = cycle_count + 1) begin
            test_matmul_cycle(test_a , test_b, fp8_test, e5m2_test);
        end
        $finish;
    end
    always @(posedge clk) begin
        last_op3_value <= dut.op_3;
    end
    always #5 clk = ~clk; // clock
endmodule