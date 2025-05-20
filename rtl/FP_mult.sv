module Float16Mul(
    input [15:0] i_a,
    input [15:0] i_b,
    input fp8,
    input e5m2,
    output logic [15:0] o_c
);

    logic sign;
    logic sign2;
    logic [5:0] exponent_a, exponent_b; //fifth bit is sign
    logic [5:0] exponent_a2, exponent_b2;
    logic [5:0] exponent_sum, exponent_sum2;
    logic [5:0] bias_1, bias_2;
    logic [9:0] mantissa;
    logic [2:0] mantissa2;
    logic [10:0] fractionA;
    logic [3:0] fractionA2;
    logic [10:0] fractionB;
    logic [3:0] fractionB2;
    logic [21:0] fraction;

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
            fractionA = e5m2 ? {|exponent_a, i_a[9:8]} : {|exponent_a, i_a[10:8]};
            fractionB = e5m2 ? {|exponent_b, i_b[9:8]} : {|exponent_b, i_b[10:8]};
            fractionA2 = e5m2 ? {|exponent_a2, i_a[1:0]} : {|exponent_a2, i_a[2:0]};
            fractionB2 = e5m2 ? {|exponent_b2, i_b[1:0]} : {|exponent_b2, i_b[2:0]};
        end else begin
            sign = i_a[15] ^ i_b[15];
            bias_1 = 5'd15;
            bias_2 = 5'hxx;
            exponent_a = {1'b0, i_a[14:10]};
            exponent_b = {1'b0, i_b[14:10]};
            exponent_a2 = 6'hxx;
            exponent_b2 = 6'hxx;
            fractionA = {|exponent_a, i_a[9:0]};
            fractionB = {|exponent_b, i_b[9:0]};
            fractionA2 = 11'hxxx;
            fractionB2 = 11'hxxx;
        end
    end

    logic [21:0] partial_product1, partial_product2, partial_product3, partial_product4;
    logic [21:0] partial_sum1, partial_sum2;
    logic [21:0] final_product;
    logic [5:0] op_a1, op_b1;
    logic [4:0] op_a2, op_b2;
    always_comb begin : partial_product
        op_a1 = fractionA[5:0];
        op_a2 = fp8 ? fractionA2 : fractionA[10:6];
        op_b1 = fractionB[5:0];
        op_b2 = fp8 ? fractionB2 : fractionB[10:6];
        partial_product1 = op_a1 * op_b1;
        partial_product2 = (op_a1 * op_b2) << 6;
        partial_product3 = (op_a2 * op_b1) << 6;
        partial_product4 = op_a2 * op_b2;
        partial_sum1 = partial_product1 + partial_product2;
        partial_sum2 = partial_product3 + (partial_product4 << 12);
        final_product = partial_sum1 + partial_sum2;
    end

    logic [5:0] exponent_overflow, exponent_overflow2;

    always_comb begin : normalize
        if (~fp8) begin
            if (final_product[21] == 1'b1) begin
                mantissa = final_product[20:11];
                exponent_overflow = exponent_sum + 1;
            end else if (final_product[20] == 1'b1) begin
                mantissa = final_product[19:10];
                exponent_overflow = exponent_sum;
            end else if (final_product[19] == 1'b1) begin
                mantissa = final_product[18:9];
                exponent_overflow = exponent_sum - 1;
            end else if (final_product[18] == 1'b1) begin
                mantissa = final_product[17:8];
                exponent_overflow = exponent_sum - 2;
            end else if (final_product[17] == 1'b1) begin
                mantissa = final_product[16:7];
                exponent_overflow = exponent_sum - 3;
            end else if (final_product[16] == 1'b1) begin
                mantissa = final_product[15:6];
                exponent_overflow = exponent_sum - 4;
            end else if (final_product[15] == 1'b1) begin
                mantissa = final_product[14:5];
                exponent_overflow = exponent_sum - 5;
            end else if (final_product[14] == 1'b1) begin
                mantissa = final_product[13:4];
                exponent_overflow = exponent_sum - 6;
            end else if (final_product[13] == 1'b1) begin
                mantissa = final_product[12:3];
                exponent_overflow = exponent_sum - 7;
            end else if (final_product[12] == 1'b1) begin
                mantissa = final_product[11:2];
                exponent_overflow = exponent_sum - 8;
            end else if (final_product[11] == 1'b1) begin
                mantissa = final_product[10:1];
                exponent_overflow = exponent_sum - 9;
            end else if (final_product[10] == 1'b1) begin
                mantissa = final_product[9:0];
                exponent_overflow = exponent_sum - 10;
            end else if (final_product[9] == 1'b1) begin
                mantissa = final_product[8:0] << 1;
                exponent_overflow = exponent_sum - 11;
            end else if (final_product[8] == 1'b1) begin
                mantissa = final_product[7:0] << 2;
                exponent_overflow = exponent_sum - 12;
            end else if (final_product[7] == 1'b1) begin
                mantissa = final_product[6:0] << 3;
                exponent_overflow = exponent_sum - 13;
            end else if (final_product[6] == 1'b1) begin
                mantissa = final_product[5:0] << 4;
                exponent_overflow = exponent_sum - 14;
            end else if (final_product[5] == 1'b1) begin
                mantissa = final_product[4:0] << 5;
                exponent_overflow = exponent_sum - 15;
            end else if (final_product[4] == 1'b1) begin
                mantissa = final_product[3:0] << 6;
                exponent_overflow = exponent_sum - 16;
            end else if (final_product[3] == 1'b1) begin
                mantissa = final_product[2:0] << 7;
                exponent_overflow = exponent_sum - 17;
            end else if (final_product[2] == 1'b1) begin
                mantissa = final_product[1:0] << 8;
                exponent_overflow = exponent_sum - 18;
            end else if (final_product[1] == 1'b1) begin
                mantissa = final_product[0:0] << 9;
                exponent_overflow = exponent_sum - 19;
            end else if (final_product[0] == 1'b1) begin
                mantissa = final_product[0:0] << 10;
                exponent_overflow = exponent_sum - 20;
            end else begin
                mantissa = 10'b0000000000;
                exponent_overflow = 0;
            end
            mantissa2 = 3'bxxx;
        end else begin
            if (e5m2) begin
                if (partial_product4[5] == 1'b1) begin
                    mantissa2 = partial_product4[4:3];
                    exponent_overflow2 = exponent_sum2 + 1;
                end else if (partial_product4[4] == 1'b1) begin
                    mantissa2 = partial_product4[3:2];
                    exponent_overflow2 = exponent_sum2;
                end else if (partial_product4[3] == 1'b1) begin
                    mantissa2 = partial_product4[2:1];
                    exponent_overflow2 = exponent_sum2 - 1;
                end else if (partial_product4[2] == 1'b1) begin
                    mantissa2 = partial_product4[1:0];
                    exponent_overflow2 = exponent_sum2 - 2;
                end else if (partial_product4[1] == 1'b1) begin
                    mantissa2 = partial_product4[0] << 1;
                    exponent_overflow2 = exponent_sum2 - 3;
                end else if (partial_product4[0] == 1'b1) begin
                    mantissa2 = partial_product4[0] << 2;
                    exponent_overflow2 = exponent_sum2 - 4;
                end else begin
                    mantissa2 = 3'b000;
                    exponent_overflow2 = 0;
                end
                if (partial_product1[5] == 1'b1) begin
                    mantissa = partial_product1[4:3];
                    exponent_overflow = exponent_sum + 1;
                end else if (partial_product1[4] == 1'b1) begin
                    mantissa = partial_product1[3:2];
                    exponent_overflow = exponent_sum;
                end else if (partial_product1[3] == 1'b1) begin
                    mantissa = partial_product1[2:1];
                    exponent_overflow = exponent_sum - 1;
                end else if (partial_product1[2] == 1'b1) begin
                    mantissa = partial_product1[1:0];
                    exponent_overflow = exponent_sum - 2;
                end else if (partial_product1[1] == 1'b1) begin
                    mantissa = partial_product1[0] << 1;
                    exponent_overflow = exponent_sum - 3;
                end else if (partial_product1[0] == 1'b1) begin
                    mantissa = partial_product1[0] << 2;
                    exponent_overflow = exponent_sum - 4;
                end else begin
                    mantissa = 10'b0000000000;
                    exponent_overflow = 0;
                end
            end else begin
                if (partial_product4[7] == 1'b1) begin
                    mantissa2 = partial_product4[6:4];
                    exponent_overflow2 = exponent_sum2 + 1;
                end else if (partial_product4[6] == 1'b1) begin
                    mantissa2 = partial_product4[5:3];
                    exponent_overflow2 = exponent_sum2;
                end else if (partial_product4[5] == 1'b1) begin 
                    mantissa2 = partial_product4[4:2];
                    exponent_overflow2 = exponent_sum2 - 1;
                end else if (partial_product4[4] == 1'b1) begin
                    mantissa2 = partial_product4[3:1];
                    exponent_overflow2 = exponent_sum2 - 2;
                end else if (partial_product4[3] == 1'b1) begin
                    mantissa2 = partial_product4[2:0];
                    exponent_overflow2 = exponent_sum2 - 3;
                end else if (partial_product4[2] == 1'b1) begin
                    mantissa2 = partial_product4[1:0] << 1;
                    exponent_overflow2 = exponent_sum2 - 4;
                end else if (partial_product4[1] == 1'b1) begin
                    mantissa2 = partial_product4[0] << 2;
                    exponent_overflow2 = exponent_sum2 - 5;
                end else if (partial_product4[0] == 1'b1) begin
                    mantissa2 = partial_product4[0] << 3;
                    exponent_overflow2 = exponent_sum2 - 6;
                end else begin
                    mantissa2 = 3'b000;
                    exponent_overflow2 = 0;
                end
                if (partial_product1[7] == 1'b1) begin
                    mantissa = partial_product1[6:4];
                    exponent_overflow = exponent_sum + 1;
                end else if (partial_product1[6] == 1'b1) begin
                    mantissa = partial_product1[5:3];
                    exponent_overflow = exponent_sum;
                end else if (partial_product1[5] == 1'b1) begin
                    mantissa = partial_product1[4:2];
                    exponent_overflow = exponent_sum - 1;
                end else if (partial_product1[4] == 1'b1) begin
                    mantissa = partial_product1[3:1];
                    exponent_overflow = exponent_sum - 2;
                end else if (partial_product1[3] == 1'b1) begin
                    mantissa = partial_product1[2:0];
                    exponent_overflow = exponent_sum - 3;
                end else if (partial_product1[2] == 1'b1) begin
                    mantissa = partial_product1[1:0] << 1;
                    exponent_overflow = exponent_sum - 4;
                end else if (partial_product1[1] == 1'b1) begin
                    mantissa = partial_product1[0] << 2;
                    exponent_overflow = exponent_sum - 5;
                end else if (partial_product1[0] == 1'b1) begin
                    mantissa = partial_product1[0] << 3;
                    exponent_overflow = exponent_sum - 6;
                end else begin
                    mantissa = 10'b0000000000;
                    exponent_overflow = 0;
                end
            end
        end
    end

    always_comb begin : result
        if (fp8) begin
            if (e5m2) begin
                if (exponent_overflow2[5] == 1'b1) begin
                    o_c[7:0] = 8'b00000000;
                end else begin
                    o_c[7:0] = {sign2, exponent_overflow2[4:0], mantissa2[1:0]};
                end
                if (exponent_overflow[5] == 1'b1) begin
                    o_c[15:8] = 8'b00000000;
                end else begin
                    o_c[15:8] = {sign, exponent_overflow[4:0], mantissa[1:0]};
                end
            end else begin
                if (exponent_overflow2[4] == 1'b1) begin
                    o_c[7:0] = 8'b00000000;
                end else begin
                    o_c[7:0] = {sign2, exponent_overflow2[3:0], mantissa2[2:0]};
                end
                if (exponent_overflow[4] == 1'b1) begin
                    o_c[15:8] = 8'b00000000;
                end else begin
                    o_c[15:8] = {sign, exponent_overflow[3:0], mantissa[2:0]};
                end
            end
        end else begin
            if (exponent_overflow[5] == 1'b1) begin
                o_c = 16'b0000000000000000;
            end else begin
                o_c = {sign, exponent_overflow[4:0], mantissa};
            end
        end 
    end
endmodule