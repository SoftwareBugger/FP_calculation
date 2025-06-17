module PE (
    input clk,
    input rst_n,
    input [15:0] i_a,
    input [15:0] i_b,
    input fp8,
    input e5m2,
    output logic [15:0] o_a_nxt,
    output logic [15:0] o_b_nxt 
);
    logic [15:0] op_1, op_2, op_3, mac_a, mac_b, mac_c, o_c;
    logic add_en;
    logic st_op2, st_op3, ld_op2;
    logic rt_out_sel; // high if right output is op_1, low otherwise

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
    typedef enum reg [1:0] {CYCLE_0, CYCLE_1, CYCLE_2} state_t;
    state_t state, nxt_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) state <= CYCLE_0;
        else state <= nxt_state; 
    end

    always_comb begin
        // Default values
        mac_a = op_1;
        mac_b = op_2;
        mac_c = op_3;
        add_en = 1'b0; // Default to no addition
        st_op2 = 1'b0; // Default to not storing op2
        st_op3 = 1'b0; // Default to not storing op3
        rt_out_sel = 1'b0; // Default to left output
        ld_op2 = 1'b1; // Default to not loading op2
        case (state)
            CYCLE_0: begin
                st_op2 = 1'b1; // Store op2 in the first cycle
                ld_op2 = 1'b0; // Load input b into op_2
                nxt_state = CYCLE_1;
            end
            CYCLE_1: begin
                mac_b = op_3;
                st_op3 = 1'b1; // Store op3 in the second cycle
                add_en = 1'b1; // Enable addition in this cycle
                nxt_state = CYCLE_2;
            end
            CYCLE_2: begin
                mac_a = op_3;
                mac_c = op_1;
                add_en = 1'b1; // Enable addition in this cycle
                rt_out_sel = 1'b1; // Select right output for the next operation
                nxt_state = CYCLE_0; // Go back to the initial state for the next operation
            end
            default: begin
                nxt_state = CYCLE_0; // Default case to avoid latches
            end
        endcase
    end

    always_comb begin
        if (rt_out_sel) begin
            o_a_nxt = o_c;
            o_b_nxt = op_2;
        end else begin
            o_a_nxt = op_1; 
            o_b_nxt = op_2;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            op_1 <= 16'b0;
        end else begin
            op_1 <= i_a; // Always load input a into op_1
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            op_2 <= 16'b0;
        end else if (ld_op2) begin
            op_2 <= i_b; // Load input b into op_2 if not already loaded
        end else if (st_op2) begin
            op_2 <= o_c; // Store the result in op_2 if required
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            op_3 <= 16'b0;
        end else if (st_op3) begin
            op_3 <= o_c; // Store the result in op_3 if required
        end
    end

endmodule