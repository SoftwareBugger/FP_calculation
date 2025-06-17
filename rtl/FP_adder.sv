module FP_adder #(
    
)(
    input [15:0] i_a,
    input [15:0] i_b,
    input fp8,
    input e5m2,
    output logic [15:0] o_c
);
    logic signed [5:0] exp_a, exp_b, exp_gt, exp_ls, exp_gt_overflow; // 5 bits for E5M2
    logic signed [5:0] exp_a2, exp_b2, exp_gt2, exp_ls2, exp_gt_overflow2; // 5 bits for E5M2
    logic [9:0] frac_a, frac_b, frac_gt, frac_ls;      // we keep 3 bits, zero?pad in E5M2
    logic [2:0] frac_a2, frac_b2, frac_gt2, frac_ls2;     // we keep 3 bits, zero?pad in E5M2
    logic sign_a, sign_b;
    logic sign_a2, sign_b2;
    logic gt; // if a > b
    logic gt2; // if a > b
    logic result_sign;
    logic result_sign2;
    logic [5:0] shft_amt;
    logic [5:0] shft_amt2;

    adder #(.WIDTH(6)) adder1 (
        .a(exp_gt),
        .b(-exp_ls),
        .cin(1'b0),
        .sum(shft_amt),
        .cout()
    );
    adder #(.WIDTH(6)) adder2 (
        .a(exp_gt2),
        .b(-exp_ls2),
        .cin(1'b0),
        .sum(shft_amt2),
        .cout()
    );
    always_comb begin : unpack
        sign_a = i_a[15];  
        sign_b = i_b[15];
        sign_a2 = i_a[7];
        sign_b2 = i_b[7];
        // E5M2 layout:   S | EEEEE | FF
        exp_a  = (~fp8 | e5m2) ? {1'b0, i_a[14:10]} : {2'b00, i_a[14:11]};
        exp_b  = (~fp8 | e5m2) ? {1'b0, i_b[14:10]} : {2'b00, i_b[14:11]};
        exp_a2 = (fp8 & e5m2) ? {1'b0, i_a[6:2]} : {2'b00, i_a[6:3]};
        exp_b2 = (fp8 & e5m2) ? {1'b0, i_b[6:2]} : {2'b00, i_b[6:3]};
        frac_a = (fp8) ? (e5m2) ? i_a[9:8] : i_a[10:8] : i_a[9:0];
        frac_b = (fp8) ? (e5m2) ? i_b[9:8] : i_b[10:8] : i_b[9:0];
        frac_a2 = (e5m2) ? i_a[1:0] : i_a[2:0];
        frac_b2 = (e5m2) ? i_b[1:0] : i_b[2:0];
        gt = {exp_a, frac_a} > {exp_b, frac_b};
        gt2 = {exp_a2, frac_a2} > {exp_b2, frac_b2};
        result_sign = gt ? sign_a : sign_b;
        result_sign2 = gt2 ? sign_a2 : sign_b2;
        exp_gt = gt ? exp_a : exp_b;
        exp_ls = gt ? exp_b : exp_a;
        exp_gt2 = gt2 ? exp_a2 : exp_b2;
        exp_ls2 = gt2 ? exp_b2 : exp_a2;
        frac_gt = gt ? frac_a : frac_b;
        frac_ls = gt ? frac_b : frac_a;
        frac_gt2 = gt2 ? frac_a2 : frac_b2;
        frac_ls2 = gt2 ? frac_b2 : frac_a2;
    end

    logic [13:0] mant_a, mant_b;      // 1 hidden + 3 frac bits
    logic [13:0] mant_a2, mant_b2;      // 1 hidden + 3 frac bits
    always_comb begin : get_mant
        // rebuild “hidden+explicit” mantissas
        mant_a = fp8 ? e5m2 ? {|exp_gt, frac_gt[0 +: 2], 3'b000} 
                            : {|exp_gt, frac_gt[0 +: 3], 3'b000} 
                     : {|exp_gt, frac_gt, 3'b000};
        mant_b = fp8 ? e5m2 ? {|exp_ls, frac_ls[0 +: 2], 3'b000} 
                            : {|exp_ls, frac_ls[0 +: 3], 3'b000} 
                     : {|exp_ls, frac_ls, 3'b000};
        mant_a2 = fp8 ? e5m2 ? {|exp_gt2, frac_gt2[0 +: 2], 3'b000} 
                            : {|exp_gt2, frac_gt2[0 +: 3], 3'b000} 
                     : {|exp_gt2, frac_gt2, 3'b000};
        mant_b2 = fp8 ? e5m2 ? {|exp_ls2, frac_ls2[0 +: 2], 3'b000} 
                            : {|exp_ls2, frac_ls2[0 +: 3], 3'b000}
                     : {|exp_ls2, frac_ls2, 3'b000};
    end


    logic [13:0] shifted_mant_a, shifted_mant_b;
    logic [13:0] shifted_mant_a2, shifted_mant_b2;
    always_comb begin : shifted_mant
        shifted_mant_a = mant_a;
        shifted_mant_b = (mant_b >> shft_amt);
        shifted_mant_a2 = mant_a2;
        shifted_mant_b2 = (mant_b2 >> shft_amt2);
    end

    logic [13:0] sticky_mant_a, sticky_mant_b;
    logic [13:0] sticky_mant_a2, sticky_mant_b2;
    always_comb begin : round_mant
        sticky_mant_a = shifted_mant_a;
        sticky_mant_b = (shifted_mant_b | (|(mant_b & ((1 << shft_amt)-1))));
        sticky_mant_a2 = shifted_mant_a2;
        sticky_mant_b2 = (shifted_mant_b2 | (|(mant_b2 & ((1 << shft_amt2)-1))));
    end

    logic [13:0] mant_sum, mant_sum_overflow;
    logic cout1, cout2, cout3, cout4;
    logic [5:0] a_1, b_1;
    logic a_2, b_2;
    logic [5:0] a_3, b_3, b_3_unsigned;
    logic a_4, b_4;
    logic diff_sign;
    logic diff_sign2;
    adder #(.WIDTH(6)) adder3 (
        .a(fp8 ? a_3 : a_1),
        .b(fp8 ? b_3 : b_1),
        .cin(fp8 ? diff_sign2 : diff_sign),
        .sum(mant_sum[5:0]),
        .cout(cout1)
    );
    adder #(.WIDTH(1)) adder4 (
        .a(fp8 ? a_4 : a_2),
        .b(fp8 ? b_4 : b_2),
        .cin(cout1),
        .sum(mant_sum[6]),
        .cout(cout2)
    );
    adder #(.WIDTH(6)) adder5 (
        .a(fp8 ? a_1 : a_3),
        .b(fp8 ? b_1 : b_3),
        .cin(fp8 ? diff_sign : cout2),
        .sum(mant_sum[12:7]),
        .cout(cout3)
    );
    adder #(.WIDTH(1)) adder6 (
        .a(fp8 ? a_2 : a_4),
        .b(fp8 ? b_2 : b_4),
        .cin(cout3),
        .sum(mant_sum[13]),
        .cout(cout4)
    );
    always_comb begin : adder_operands
        diff_sign = sign_a ^ sign_b;
        diff_sign2 = sign_a2 ^ sign_b2;
        a_1 = sticky_mant_a[5:0];
        b_1 = (~diff_sign) ? sticky_mant_b[5:0] : (~sticky_mant_b[5:0]);
        a_2 = sticky_mant_a[6];
        b_2 = (diff_sign) ^ sticky_mant_b[6];
        a_3 = fp8 ? sticky_mant_a2[5:0] : sticky_mant_a[12:7];
        b_3_unsigned = fp8 ? sticky_mant_b2[5:0] : sticky_mant_b[12:7];
        b_3 = (fp8 ? ~diff_sign2 : ~diff_sign) ? b_3_unsigned : (~b_3_unsigned);
        a_4 = fp8 ? sticky_mant_a2[6] : sticky_mant_a[13];
        b_4 = (fp8 ? diff_sign2 : diff_sign) ^ (fp8 ? sticky_mant_b2[6] : sticky_mant_b[13]);
        mant_sum_overflow = (fp8) ? (e5m2 ? ({mant_sum[13], (~diff_sign & cout3) ? ({cout3, mant_sum[12:8]} | mant_sum[7]) : mant_sum[12:7], mant_sum[6], (~diff_sign2 & cout1) ? ({cout1, mant_sum[5:1]} | mant_sum[0]) : mant_sum[5:0]}) 
                                          : ({(~diff_sign & cout4) ? ({cout4, mant_sum[13:8]} | mant_sum[7]) : mant_sum[13:7], (~diff_sign2 & cout2) ? ({cout2, mant_sum[6:1]} | mant_sum[0]) : mant_sum[6:0]})) 
                                  : ((cout4 & (~diff_sign)) ? (({cout4, mant_sum} >> 1) | {13'h0000, mant_sum[0]}) : mant_sum);
        exp_gt_overflow = exp_gt + ((~diff_sign) & (fp8 ? e5m2 ? cout3 : cout4 : cout4));
        exp_gt_overflow2 = exp_gt2 + ((~diff_sign2) & (e5m2 ? cout1 : cout2));
    end
    // always_comb begin : mant_sum_block
    //     if (~diff_sign) begin
    //         {cout, mant_sum} = sticky_mant_a + sticky_mant_b;
    //         mant_sum_overflow = (cout) ? (({cout, mant_sum} >> 1) | {13'h0000, mant_sum[0]}) : mant_sum;
    //         exp_overflow = (cout) ? (exp_gt + 1) : exp_gt;
    //     end else begin
    //         cout = 1'b0;
    //         mant_sum = gt ? (sticky_mant_a - sticky_mant_b) : (sticky_mant_b - sticky_mant_a);
    //         mant_sum_overflow = mant_sum;
    //         exp_overflow = exp_gt;
    //     end
    // end

    // lower and upper half of mant_sum_overflow
    logic [10:0] mant_sum_round;
    logic [10:0] mant_sum_overflow_round;
    logic [5:0] exp_round;
    logic [5:0] exp_round2;
    logic cout5, cout6, cout7, cout8, cout9, cout10;
    adder #(.WIDTH(3)) adder7 (
        .a(mant_sum_overflow[5:3]),
        .b({2'b00, (mant_sum_overflow[2] & (mant_sum_overflow[1] | mant_sum_overflow[0] | mant_sum_overflow[3]))}),
        .cin(1'b0),
        .sum(mant_sum_round[2:0]),
        .cout(cout6)
    );
    adder #(.WIDTH(1)) adder8 (
        .a(mant_sum_overflow[6]),
        .b(1'b0),
        .cin(cout6),
        .sum(mant_sum_round[3]),
        .cout(cout7)
    );
    adder #(.WIDTH(3)) adder9 (
        .a(mant_sum_overflow[9:7]),
        .b(3'h0),
        .cin(cout7),
        .sum(mant_sum_round[6:4]),
        .cout(cout8)
    );
    adder #(.WIDTH(3)) adder10 (
        .a(mant_sum_overflow[12:10]),
        .b({2'b00, (fp8 & mant_sum_overflow[9] & (mant_sum_overflow[8] | mant_sum_overflow[7] | mant_sum_overflow[10]))}),
        .cin(~fp8 & cout8),
        .sum(mant_sum_round[9:7]),
        .cout(cout9)
    );
    adder #(.WIDTH(1)) adder11 (
        .a(mant_sum_overflow[13]),
        .b(1'b0),
        .cin(cout9),
        .sum(mant_sum_round[10]),
        .cout(cout10)
    );

    always_comb begin : rounding_block
        mant_sum_overflow_round = fp8 ? (e5m2 ? {mant_sum_round[10], cout9 ? ({cout9, mant_sum_round[9:8]} | mant_sum_round[7]) : mant_sum_round[9:7], mant_sum_round[6:3], cout6 ? ({cout6, mant_sum_round[2:1]} | mant_sum_round[0]) : mant_sum_round[2:0]}
                                              : {cout10 ? ({cout10, mant_sum_round[10:8]} | mant_sum_round[7]) : mant_sum_round[10:7], mant_sum_round[6:4], cout7 ? ({cout7, mant_sum_round[3:1]} | mant_sum_round[0]) : mant_sum_round[3:0]}) 
                                      : ((cout10) ? (mant_sum_round >> 1) : mant_sum_round);
        exp_round = exp_gt_overflow + ((fp8 & e5m2 & cout9) | cout10);
        exp_round2 = exp_gt_overflow2 + (fp8 & (e5m2 & cout6 | cout7));
    end

    // logic [10:0] mant_sum_round, mant_sum_overflow_round;
    // logic round_overflow;
    // logic signed [5:0] exp_round;
    // always_comb begin : mant_sum_round_block
    //     {round_overflow, mant_sum_round} = mant_sum_overflow[13:3] + (mant_sum_overflow[2] & (mant_sum_overflow[1] | mant_sum_overflow[0] | mant_sum_overflow[3]));
    //     mant_sum_overflow_round = (round_overflow) ? (mant_sum_round >> 1) : mant_sum_round;
    //     exp_round = (round_overflow) ? (exp_overflow + 1) : exp_overflow;
    // end

    logic [10:0] mant_sum_overflow_round_normalized;
    logic signed [5:0] exp_round_normalized, exp_round_normalized2;
    always_comb begin : normalize
        if (fp8) begin
            if (e5m2) begin
                if (~mant_sum_overflow_round[9]) begin
                    if (mant_sum_overflow_round[8] == 1'b1) begin
                        mant_sum_overflow_round_normalized[9:7] = mant_sum_overflow_round[9:7] << 1;
                        exp_round_normalized = exp_round - 1;
                    end 
                    else if (mant_sum_overflow_round[7] == 1'b1) begin
                        mant_sum_overflow_round_normalized[9:7] = mant_sum_overflow_round[9:7] << 2;
                        exp_round_normalized = exp_round - 2;
                    end 
                    else begin
                        mant_sum_overflow_round_normalized[9:7] = mant_sum_overflow_round[9:7];
                        exp_round_normalized = diff_sign ? 0 : exp_round;
                    end
                end else begin
                    mant_sum_overflow_round_normalized[9:7] = mant_sum_overflow_round[9:7];
                    exp_round_normalized = exp_round;
                end
                if (~mant_sum_overflow_round[2]) begin
                    if (mant_sum_overflow_round[1] == 1'b1) begin
                        mant_sum_overflow_round_normalized[2:0] = mant_sum_overflow_round[2:0] << 1;
                        exp_round_normalized2 = exp_round2 - 1;
                    end 
                    else if (mant_sum_overflow_round[0] == 1'b1) begin
                        mant_sum_overflow_round_normalized[2:0] = mant_sum_overflow_round[2:0] << 2;
                        exp_round_normalized2 = exp_round2 - 2;
                    end 
                    else begin
                        mant_sum_overflow_round_normalized[2:0] = mant_sum_overflow_round[2:0];
                        exp_round_normalized2 = diff_sign2 ? 0 : exp_round2;
                    end
                end else begin
                    mant_sum_overflow_round_normalized[2:0] = mant_sum_overflow_round[2:0];
                    exp_round_normalized2 = exp_round2;
                end
            end else begin
                if (~mant_sum_overflow_round[10]) begin
                    if (mant_sum_overflow_round[9] == 1'b1) begin
                        mant_sum_overflow_round_normalized[10:7] = mant_sum_overflow_round[10:7] << 1;
                        exp_round_normalized = exp_round - 1;
                    end 
                    else if (mant_sum_overflow_round[8] == 1'b1) begin
                        mant_sum_overflow_round_normalized[10:7] = mant_sum_overflow_round[10:7] << 2;
                        exp_round_normalized = exp_round - 2;
                    end 
                    else if (mant_sum_overflow_round[7] == 1'b1) begin
                        mant_sum_overflow_round_normalized[10:7] = mant_sum_overflow_round[10:7] << 3;
                        exp_round_normalized = exp_round - 3;
                    end 
                    else begin
                        mant_sum_overflow_round_normalized[10:7] = mant_sum_overflow_round[10:7];
                        exp_round_normalized = diff_sign ? 0 : exp_round;
                    end
                end else begin
                    mant_sum_overflow_round_normalized[10:7] = mant_sum_overflow_round[10:7];
                    exp_round_normalized = exp_round;
                end
                if (~mant_sum_overflow_round[3]) begin
                    if (mant_sum_overflow_round[2] == 1'b1) begin
                        mant_sum_overflow_round_normalized[3:0] = mant_sum_overflow_round[3:0] << 1;
                        exp_round_normalized2 = exp_round2 - 1;
                    end 
                    else if (mant_sum_overflow_round[1] == 1'b1) begin
                        mant_sum_overflow_round_normalized[3:0] = mant_sum_overflow_round[3:0] << 2;
                        exp_round_normalized2 = exp_round2 - 2;
                    end 
                    else if (mant_sum_overflow_round[0] == 1'b1) begin
                        mant_sum_overflow_round_normalized[3:0] = mant_sum_overflow_round[3:0] << 3;
                        exp_round_normalized2 = exp_round2 - 3;
                    end 
                    else begin
                        mant_sum_overflow_round_normalized[3:0] = mant_sum_overflow_round[3:0];
                        exp_round_normalized2 = diff_sign2 ? 0 : exp_round2;
                    end
                end else begin
                    mant_sum_overflow_round_normalized[3:0] = mant_sum_overflow_round[3:0];
                    exp_round_normalized2 = exp_round2;
                end
            end
            mant_sum_overflow_round_normalized[6:4] = mant_sum_overflow_round[6:4];
        end else begin
            if (mant_sum_overflow_round [10] == 0) begin 
                if (mant_sum_overflow_round[9] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 1;
                    exp_round_normalized = exp_round - 1;
                end
                else if (mant_sum_overflow_round[8] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 2;
                    exp_round_normalized = exp_round - 2;
                end
                else if (mant_sum_overflow_round[7] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 3;
                    exp_round_normalized = exp_round - 3;
                end 
                else if (mant_sum_overflow_round[6] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 4;
                    exp_round_normalized = exp_round - 4;
                end 
                else if (mant_sum_overflow_round[5] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 5;
                    exp_round_normalized = exp_round - 5;
                end 
                else if (mant_sum_overflow_round[4] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 6;
                    exp_round_normalized = exp_round - 6;
                end 
                else if (mant_sum_overflow_round[3] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 7;
                    exp_round_normalized = exp_round - 7;
                end 
                else if (mant_sum_overflow_round[2] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 8;
                    exp_round_normalized = exp_round - 8;
                end 
                else if (mant_sum_overflow_round[1] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 9;
                    exp_round_normalized = exp_round - 9;
                end 
                else if (mant_sum_overflow_round[0] == 1'b1) begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round << 10;
                    exp_round_normalized = exp_round - 10;
                end 
                else begin
                    mant_sum_overflow_round_normalized = mant_sum_overflow_round;
                    exp_round_normalized = diff_sign ? 0 : exp_round;
                end
            end
            else begin
                mant_sum_overflow_round_normalized = mant_sum_overflow_round;
                exp_round_normalized = exp_round;
            end
        end
    end

    always_comb begin : pack
        if (fp8) begin
            if (exp_round_normalized[5] == 1'b1) begin // exponent is negative
                o_c[15:8] = 8'b00000000;
            end else begin
                o_c[15:8] = {result_sign, e5m2 ? {exp_round_normalized[4:0], mant_sum_overflow_round_normalized[8:7]} : {exp_round_normalized[3:0], mant_sum_overflow_round_normalized[9:7]}};
            end
            if (exp_round_normalized2[5] == 1'b1) begin // exponent is negative
                o_c[7:0] = 8'b00000000;
            end else begin
                o_c[7:0] = {result_sign2, e5m2 ? {exp_round_normalized2[4:0], mant_sum_overflow_round_normalized[1:0]} : {exp_round_normalized2[3:0], mant_sum_overflow_round_normalized[2:0]}};
            end
        end
        else begin
            if (exp_round_normalized[5] == 1'b1) begin // exponent is negative
                o_c = 16'b0000000000000000;
            end else begin
                o_c = {result_sign, exp_round_normalized[4:0], mant_sum_overflow_round_normalized[9:0]};
            end
        end
    end
    
endmodule