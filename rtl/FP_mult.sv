module FloatMul(
    input [15:0] i_a,
    input [15:0] i_b,
    input fp8,
    input e5m2,
    output logic [15:0] o_c
);

    logic sign;
    logic sign2;
    logic signed[5:0] exponent_a, exponent_b; //fifth bit is sign
    logic signed [5:0] exponent_a2, exponent_b2;
    logic signed [5:0] exponent_sum, exponent_sum2;
    logic [5:0] bias_1, bias_2;
    logic [9:0] mantissa;
    logic [2:0] mantissa2;
    logic [10:0] fractionA;
    logic [3:0] fractionA2;
    logic [10:0] fractionB;
    logic [3:0] fractionB2;
    logic exp_inf_a, exp_inf_b;
    logic exp_inf_a2, exp_inf_b2;
    logic is_nan_a, is_nan_b;
    logic is_nan_a2, is_nan_b2;
    logic is_inf_a, is_inf_b;
    logic is_inf_a2, is_inf_b2;
    logic is_zero_a, is_zero_b;
    logic is_zero_a2, is_zero_b2;
    localparam [7:0] fp8_nan = 8'b11111111; // NaN for E5M2
    localparam [15:0] fp16_nan = 16'b1111111111111111; // NaN for FP16

    adder #(.WIDTH(6)) adder1 (
        .a(exponent_a),
        .b(exponent_b-bias_1),
        .cin(1'b0),
        .sum(exponent_sum),
        .cout()
    );
    adder #(.WIDTH(6)) adder2 (
        .a(exponent_a2),
        .b(exponent_b2-bias_2),
        .cin(1'b0),
        .sum(exponent_sum2),
        .cout()
    );
    
    always_comb begin : unpack
        if (fp8) begin
            sign2 = i_a[7] ^ i_b[7];
            sign = i_a[15] ^ i_b[15];
            bias_1 = e5m2 ? 5'd15 : 5'd7;
            bias_2 = e5m2 ? 5'd15 : 5'd7;
            exponent_a = e5m2 ? {1'b0, i_a[14:10]} : {2'b00, i_a[14:11]};
            exponent_b = e5m2 ? {1'b0, i_b[14:10]} : {2'b00, i_b[14:11]};
            exponent_a2 = e5m2 ? {1'b0, i_a[6:2]} : {2'b00, i_a[6:3]};
            exponent_b2 = e5m2 ? {1'b0, i_b[6:2]} : {2'b00, i_b[6:3]};
            fractionA = e5m2 ? {1'b1, i_a[9:8]} : {1'b1, i_a[10:8]};
            fractionB = e5m2 ? {1'b1, i_b[9:8]} : {1'b1, i_b[10:8]};
            fractionA2 = e5m2 ? {1'b1, i_a[1:0]} : {1'b1, i_a[2:0]};
            fractionB2 = e5m2 ? {1'b1, i_b[1:0]} : {1'b1, i_b[2:0]};
            exp_inf_a = (~e5m2 | i_a[10]) & (&i_a[14:11]);
            exp_inf_b = (~e5m2 | i_b[10]) & (&i_b[14:11]);
            exp_inf_a2 = (~e5m2 | i_a[2]) & (&i_a[6:3]);
            exp_inf_b2 = (~e5m2 | i_b[2]) & (&i_b[6:3]);
            is_nan_a = exp_inf_a & (|i_a[10:8]);
            is_nan_b = exp_inf_b & (|i_b[10:8]);
            is_nan_a2 = exp_inf_a2 & (|i_a[2:0]);
            is_nan_b2 = exp_inf_b2 & (|i_b[2:0]);
            is_inf_a = exp_inf_a & (~|i_a[10:8]);
            is_inf_b = exp_inf_b & (~|i_b[10:8]);
            is_inf_a2 = exp_inf_a2 & (~|i_a[2:0]);
            is_inf_b2 = exp_inf_b2 & (~|i_b[2:0]);
            is_zero_a = ~|exponent_a;
            is_zero_b = ~|exponent_b;
            is_zero_a2 = ~|exponent_a2;
            is_zero_b2 = ~|exponent_b2;
        end else begin
            sign = i_a[15] ^ i_b[15];
            sign2 = 1'b0; // No second sign bit in FP16
            bias_1 = 5'd15;
            bias_2 = 5'hxx;
            exponent_a = {1'b0, i_a[14:10]};
            exponent_b = {1'b0, i_b[14:10]};
            exponent_a2 = 6'hxx;
            exponent_b2 = 6'hxx;
            fractionA = {1'b1, i_a[9:0]};
            fractionB = {1'b1, i_b[9:0]};
            fractionA2 = 11'hxxx;
            fractionB2 = 11'hxxx;
            exp_inf_a = (&i_a[14:10]);
            exp_inf_b = (&i_b[14:10]);
            exp_inf_a2 = 1'b0;  
            exp_inf_b2 = 1'b0;
            is_nan_a = exp_inf_a && (|i_a[9:0]);
            is_nan_b = exp_inf_b && (|i_b[9:0]);
            is_nan_a2 = 1'b0;
            is_nan_b2 = 1'b0;
            is_inf_a = exp_inf_a && (~|i_a[9:0]);
            is_inf_b = exp_inf_b && (~|i_b[9:0]);
            is_inf_a2 = 1'b0;
            is_inf_b2 = 1'b0;
            is_zero_a = ~|exponent_a;
            is_zero_b = ~|exponent_b;
            is_zero_a2 = 1'b0;
            is_zero_b2 = 1'b0;
        end
    end

    // logic [21:0] partial_product1, partial_product2, partial_product3;
    // logic [9:0] partial_product4;
    // logic [21:0] partial_sum1, partial_sum2;
    // logic [21:0] final_product;
    // logic [5:0] op_a1, op_b1;
    // logic [4:0] op_a2, op_b2;
    // always_comb begin : partial_product
    //     op_a1 = fractionA[5:0];
    //     op_a2 = fp8 ? fractionA2 : fractionA[10:6];
    //     op_b1 = fractionB[5:0];
    //     op_b2 = fp8 ? fractionB2 : fractionB[10:6];
    //     partial_product1 = op_a1 * op_b1;
    //     partial_product2 = op_a1 * op_b2;
    //     partial_product3 = op_a2 * op_b1;
    //     partial_product4 = op_a2 * op_b2;
    //     partial_sum1 = partial_product1 + {partial_product2, 6'b000000};
    //     partial_sum2 = {partial_product3, 6'b000000} + {partial_product4[9:0], 12'b000000000000};
    //     final_product = partial_sum1 + partial_sum2;
    // end

    logic [21:0] product, product2;
    always_comb begin : partial_product
        product = fractionA * fractionB; // 11x11=22
        product2 = fractionA2 * fractionB2; // 4x4=8
    end

    logic signed [6:0] exponent_overflow, exponent_overflow2;
    logic signed [5:0] exponent_offset, exponent_offset2;
    logic mant_c_out, mant_c_out2;
    always_comb begin : normalize
        if (~fp8) begin
            if (product[21]) begin//final_product[21] == 1'b1) begin
                {mant_c_out, mantissa[9:0]} = product[20:11] + (product[10] & (product[9] | product[8] | product[11]));//final_product[20:11];
                exponent_offset = 1 + mant_c_out;
            end else begin
                {mant_c_out, mantissa[9:0]} = product[19:10]  + (product[9] & (product[8] | product[7] | product[10]));//final_product[19:10];
                exponent_offset = {4'b0000, mant_c_out};
            end
            mantissa2 = 3'bxxx;
            exponent_overflow2 = 6'hxx;
            exponent_offset2 = 6'hxx;
        end else begin
            if (e5m2) begin
                if (product2[5]) begin//partial_product4[5] == 1'b1) begin
                    // mantissa2 = product2[4:3];//partial_product4[4:3];
                    // exponent_offset2 = 1;
                    {mant_c_out2, mantissa2[1:0]} = product2[4:3] + (product2[2] & (product2[1] | product2[0] | product2[3]));//partial_product4[4:3];
                    exponent_offset2 = 1 + mant_c_out2;
                end else begin
                    // mantissa2 = product2[3:2];//partial_product4[3:2];
                    // exponent_offset2 = 0;
                    {mant_c_out2, mantissa2[1:0]} = product2[3:2] + (product2[1] & (product2[0] | product2[2]));//partial_product4[3:2];
                    exponent_offset2 = {4'b0000, mant_c_out2};
                end
                if (product[5]) begin//partial_product1[5] == 1'b1) begin
                    // mantissa = product[4:3];//partial_product1[4:3];
                    // exponent_offset = 1;
                    {mant_c_out, mantissa[1:0]} = product[4:3] + (product[2] & (product[1] | product[0] | product[3]));//partial_product1[4:3];
                    exponent_offset = 1 + mant_c_out;
                end else begin
                    // mantissa = product[3:2];//partial_product1[3:2];
                    // exponent_offset = 0;
                    {mant_c_out, mantissa[1:0]} = product[3:2] + (product[1] & (product[0] | product[2]));//partial_product1[3:2];
                    exponent_offset = {4'b0000, mant_c_out};
                end
            end else begin
                if (product2[7]) begin //partial_product4[7] == 1'b1) begin
                    {mant_c_out2, mantissa2[2:0]} = product2[6:4] + (product2[3] & (product2[2] | product2[1] | product2[4]));//partial_product4[6:4];
                    exponent_offset2 = 1 + mant_c_out2;
                end else begin
                    {mant_c_out2, mantissa2[2:0]} = product2[5:3] + (product2[2] & (product2[1] | product2[0] | product2[3]));//partial_product4[5:3];
                    exponent_offset2 = {4'b0000, mant_c_out2};
                end 
                if (product[7]) begin //partial_product1[7] == 1'b1) begin
                    {mant_c_out, mantissa[2:0]}= product[6:4] + (product[3] & (product[2] | product[1] | product[4]));//partial_product1[6:4];
                    exponent_offset = 1 + mant_c_out;
                end else begin
                    {mant_c_out, mantissa[2:0]} = product[5:3] + (product[2] & (product[1] | product[0] | product[3]));//partial_product1[5:3];
                    exponent_offset = {4'b0000, mant_c_out};
                end
            end
        end
        exponent_overflow = exponent_sum + exponent_offset;
        exponent_overflow2 = exponent_sum2 + exponent_offset2;
    end

    always_comb begin : result
        if (fp8) begin
            if (e5m2) begin
                if (is_nan_a2 || is_nan_b2 || (is_inf_a2 & is_zero_b2) || (is_zero_a2 & is_inf_b2)) begin
                    o_c[7:0] = fp8_nan;
                end
                else if (exponent_overflow2[6] || is_zero_a2 || is_zero_b2) begin
                    o_c[7:0] = 8'b00000000;
                end else begin
                    o_c[7:0] = exponent_overflow[5] ? {sign2, 5'b11111, 2'b00} : (&exponent_overflow2[4:0]) ? {sign2, 5'b11110, 2'b11} : {sign2, exponent_overflow2[4:0], mantissa2[1:0]};
                end
                if (is_nan_a || is_nan_b || (is_inf_a & is_zero_b) || (is_zero_a & is_inf_b)) begin
                    o_c[15:8] = fp8_nan;
                end
                else if (exponent_overflow[6] || is_zero_a || is_zero_b) begin
                    o_c[15:8] = 8'b00000000;
                end else begin
                    o_c[15:8] = exponent_overflow[5] ? {sign, 5'b11111, 2'b00} : (&exponent_overflow[4:0]) ? {sign, 5'b11110, 2'b11} : {sign, exponent_overflow[4:0], mantissa[1:0]};
                end
            end else begin
                if (is_nan_a2 || is_nan_b2 || (is_inf_a2 & is_zero_b2) || (is_zero_a2 & is_inf_b2)) begin
                    o_c[7:0] = fp8_nan;
                end
                else if (exponent_overflow2[6] || is_zero_a2 || is_zero_b2) begin
                    o_c[7:0] = 8'b00000000;
                end else begin
                    o_c[7:0] = exponent_overflow2[4] ? {sign2, 4'b1111, 3'b000} : (&exponent_overflow2[3:0]) ? {sign2, 4'b1110, 3'b111} : {sign2, exponent_overflow2[3:0], mantissa2[2:0]};
                end
                if (is_nan_a || is_nan_b || (is_inf_a & is_zero_b) || (is_zero_a & is_inf_b)) begin
                    o_c[15:8] = fp8_nan;
                end else if (exponent_overflow[6] || is_zero_a || is_zero_b) begin
                    o_c[15:8] = 8'b00000000;
                end else begin
                    o_c[15:8] = exponent_overflow[4] ? {sign, 4'b1111, 3'b000} : (&exponent_overflow[3:0]) ? {sign, 4'b1110, 3'b111} : {sign, exponent_overflow[3:0], mantissa[2:0]};
                end
            end
        end else begin
            if (is_nan_a || is_nan_b || (is_inf_a & is_zero_b) || (is_zero_a & is_inf_b)) begin
                o_c = fp16_nan;
            end else if (exponent_overflow[6] || is_zero_a || is_zero_b) begin
                o_c = 16'b0000000000000000;
            end else begin
                o_c = exponent_overflow[5] ? {sign, 5'b11111, 10'h000} : (&exponent_overflow[4:0]) ? {sign, 5'b11110, 10'hfff} : {sign, exponent_overflow[4:0], mantissa};
            end
        end 
    end
endmodule