// This is implemented according to SSM_Systolic_v1/PE_3cycle/PE_class.py
module PE (
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
    logic [15:0] op_1, op_2, op_3, mac_a, mac_b, mac_c, o_c;
    logic add_en;
    logic st_op2, st_op3, ld_op1, ld_op2, ld_op3;

    FP_top_comb mac (
        .i_a(mac_a),
        .i_b(mac_b),
        .i_c(mac_c),
        .fp8(fp8),
        .e5m2(e5m2),
        .add_en(add_en),
        .o_c(o_c)
    );
    
    // standard state code
    typedef enum reg [2:0] {IDLE, CYCLE_0, CYCLE_1, CYCLE_2, BYPASS, SAVE_TRANSFER, MATMUL} state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= nxt_state; 
    end

    always_comb begin
        // default values
        nxt_state = state;
        mac_a = op_1;
        mac_b = op_2;   
        mac_c = op_3;
        add_en = 1'b0;
        o_a_nxt = 16'h0;
        o_b_nxt = 16'h0;
        ld_op2 = 1'b0;
        st_op2 = 1'b0;
        ld_op3 = 1'b0;
        st_op3 = 1'b0;
        ld_op1 = 1'b0;
        o_o_a_valid = 1'b0;
        o_o_b_valid = 1'b0;
        o_i_a_ready = 1'b0; // not ready to accept left input
        o_i_b_ready = 1'b0; // not ready to accept top input
        case (state)
            IDLE: begin
                if (flag == 2'b01) nxt_state = dataflow ? MATMUL : CYCLE_0;
                else if (flag == 2'b10) nxt_state = BYPASS;
                else if (flag == 2'b11) nxt_state = SAVE_TRANSFER;
                else nxt_state = IDLE;
            end
            // all cycles load left input i_a into op_1
            CYCLE_0: begin // output the MAC result op_1 + op_2*op_3 to the right output and load op_2 from i_b, bottom output is op_2
                nxt_state = CYCLE_1;
                o_i_a_ready = 1'b1; // ready to accept left input
                o_i_b_ready = 1'b1; // ready to accept top input
                o_o_a_valid = 1'b1; // output valid for right output
                o_o_b_valid = 1'b1; // output valid for bottom output
                o_b_nxt = op_2;
                o_a_nxt = o_c;
                // MAC: op_1 + op_2*op_3
                mac_a = op_3;
                mac_c = op_1;
                add_en = 1'b1; // enable addition
                // next state is CYCLE_1 if successors are ready to accept and the predecessors' outputs are valid
                if (i_o_a_ready & i_o_b_ready & i_i_a_valid & i_i_b_valid) begin
                    nxt_state = CYCLE_1;
                    ld_op2 = 1'b1; // load op_2 from i_b
                    ld_op1 = 1'b1; // load op_1 from i_a
                end
            end
            CYCLE_1: begin // op_1 * op_2 => op_2, output op_2 to the bottom output, op_1 to the right output, store o_c to op_2
                // MUL only: op_1 * op_2 => op_2
                st_op2 = 1'b1; // store o_c to op_2
                o_b_nxt = op_2;
                o_a_nxt = op_1;
                o_i_a_ready = 1'b1; // ready to accept left input
                o_o_a_valid = 1'b1; // output valid for right output
                o_o_b_valid = 1'b1; // output valid for bottom output
                if (i_o_a_ready & i_o_b_ready & i_i_a_valid) begin
                    nxt_state = CYCLE_2;
                    ld_op1 = 1'b1; // load i_a into op_1
                end
            end
            CYCLE_2: begin // op_2 + op_1*op_3 => op_3, output op_1 to the right output, 0 to the bottom output, store o_c to op_3
                if (i_o_a_ready & i_i_b_valid & i_i_a_valid) begin
                    if (flag == 2'b01) nxt_state = dataflow ? MATMUL : CYCLE_0;
                    else if (flag == 2'b10) nxt_state = BYPASS;
                    else if (flag == 2'b11) nxt_state = SAVE_TRANSFER;
                    else nxt_state = IDLE;
                    ld_op2 = 1'b1; // load i_b into op_2
                    ld_op1 = 1'b1; // load i_a into op_1
                end
                // MAC: op_2 + op_3*op_1
                mac_c = op_2;
                mac_b = op_3;
                st_op3 = 1'b1; // store o_c in op_3
                o_a_nxt = op_1;
                o_b_nxt = 16'h0; // output 0 to the bottom output
                add_en = 1'b1; // enable addition
                o_i_a_ready = 1'b1; // ready to accept left input
                o_i_b_ready = 1'b1; // ready to accept top input
                o_o_a_valid = 1'b1; // output valid for right output
            end
            BYPASS: begin
                if (i_o_a_ready & i_o_b_ready & i_i_a_valid & i_i_b_valid) begin
                    if (flag == 2'b01) nxt_state = dataflow ? MATMUL : CYCLE_0;
                    else if (flag == 2'b10) nxt_state = BYPASS;
                    else if (flag == 2'b11) nxt_state = SAVE_TRANSFER;
                    else nxt_state = IDLE;
                    // TODO: not sure if this part is sequential or combinational, the simulator seems to indicate a direct wire connection
                    ld_op2 = 1'b1; // load i_b into op_2
                    ld_op1 = 1'b1; // load i_a into op_1
                end
                // // left => op_1, right => op_2
                o_a_nxt = op_1; // output op_1 to the right output
                o_b_nxt = op_2; // output op_2 to the bottom output
                // o_a_nxt = i_a; // output i_a to the right output
                // o_b_nxt = i_b; // output i_b to the bottom output
                o_i_a_ready = 1'b1; // ready to accept left input
                o_i_b_ready = 1'b1; // ready to accept top input
                o_o_a_valid = 1'b1; // output valid for right output
                o_o_b_valid = 1'b1; // output valid for bottom output
            end
            SAVE_TRANSFER: begin // i_a => op_3, the simulator runs i_a -> op_1 -> op_3 in a blocking manner
                if (i_o_a_ready & i_i_a_valid) begin
                    if (flag == 2'b01) nxt_state = dataflow ? MATMUL : CYCLE_0;
                    else if (flag == 2'b10) nxt_state = BYPASS;
                    else if (flag == 2'b11) nxt_state = SAVE_TRANSFER;
                    else nxt_state = IDLE;
                    ld_op3 = 1'b1; // load i_a into op_3
                end
                // i_a => op_3
                // o_a_nxt = op_3
                // The logic is simplified to just load i_a into op_3
                o_a_nxt = op_3; // output op_3 to the right output
                o_o_a_valid = 1'b1; // output valid for right output
                o_i_a_ready = 1'b1; // ready to accept left input
            end
            MATMUL: begin
                if (i_o_a_ready & i_o_b_ready & i_i_a_valid & i_i_b_valid) begin
                    if (flag == 2'b01) nxt_state = dataflow ? MATMUL : CYCLE_0;
                    else if (flag == 2'b10) nxt_state = BYPASS;
                    else if (flag == 2'b11) nxt_state = SAVE_TRANSFER;
                    else nxt_state = IDLE;
                    // TODO: not sure if this part is sequential or combinational, the simulator seems to indicate a direct wire connection
                    ld_op2 = 1'b1; // load i_b into op_2
                    ld_op1 = 1'b1; // load i_a into op_1
                    add_en = 1'b1; // enable addition
                    st_op3 = 1'b1; // store o_c in op_3
                end
                o_b_nxt = op_2; // output op_2 to the bottom output
                o_a_nxt = op_1; // output op_1 to the right output
                o_i_a_ready = 1'b1; // ready to accept left input
                o_i_b_ready = 1'b1; // ready to accept top input
                o_o_a_valid = 1'b1; // output valid for right output
                o_o_b_valid = 1'b1; // output valid for bottom output
                // MAC: op_3 + op_2*op_1, output stationary
            end
        endcase
    end

    // op1 update
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) op_1 <= 16'h0;
        else if (ld_op1) op_1 <= i_a;
    end

    // op2 update
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) op_2 <= 16'h0;
        else if (st_op2) op_2 <= o_c;
        else if (ld_op2) op_2 <= i_b;
    end

    // op3 update
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) op_3 <= 16'h0;
        else if (st_op3) op_3 <= o_c;
        else if (ld_op3) op_3 <= i_a;
    end

endmodule