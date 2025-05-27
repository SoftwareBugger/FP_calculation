module FP_add (
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
    logic [3:0] shft_amt;
    logic [3:0] shft_amt2;
    adder #(.WIDTH(5)) adder1 (
        .a(exp_gt),
        .b(-exp_ls),
        .cin(1'b0),
        .sum(shft_amt),
        .cout()
    );
    adder #(.WIDTH(5)) adder2 (
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

    logic [10:0] mant_a, mant_b;      // 1 hidden + 3 frac bits
    logic [10:0] mant_a2, mant_b2;      // 1 hidden + 3 frac bits
    always_comb begin : get_mant
        // rebuild “hidden+explicit” mantissas
        mant_a = fp8 ? e5m2 ? {1'b1, frac_gt[0 +: 2]} 
                            : {1'b1, frac_gt[0 +: 3]} 
                     : {1'b1, frac_gt};
        mant_b = fp8 ? e5m2 ? {1'b1, frac_ls[0 +: 2]} 
                            : {1'b1, frac_ls[0 +: 3]} 
                     : {1'b1, frac_ls};
        mant_a2 = fp8 ? e5m2 ? {1'b1, frac_gt2[0 +: 2]} 
                            : {1'b1, frac_gt2[0 +: 3]} 
                     : {1'b1, frac_gt2};
        mant_b2 = fp8 ? e5m2 ? {1'b1, frac_ls2[0 +: 2]} 
                            : {1'b1, frac_ls2[0 +: 3]}
                     : {1'b1, frac_ls2};
    end


    logic [10:0] shifted_mant_a, shifted_mant_b;
    logic [10:0] shifted_mant_a2, shifted_mant_b2;
    always_comb begin : shifted_mant
        shifted_mant_a = mant_a;
        shifted_mant_b = (mant_b >> shft_amt);
        shifted_mant_a2 = mant_a2;
        shifted_mant_b2 = (mant_b2 >> shft_amt2);
    end

    logic [10:0] mant_sum, mant_sum_overflow;
    logic cout1, cout2, cout3, cout4, cout5;
    logic [2:0] a_1, b_1;
    logic a_2, b_2;
    logic [2:0] a_3, b_3, b_3_unsigned;
    logic a_4, b_4;
    logic diff_sign;
    logic diff_sign2;
    adder #(.WIDTH(3)) adder3 (
        .a(fp8 ? a_3 : a_1),
        .b(fp8 ? b_3 : b_1),
        .cin(fp8 ? diff_sign2 : diff_sign),
        .sum(mant_sum[2:0]),
        .cout(cout1)
    );
    adder #(.WIDTH(1)) adder4 (
        .a(fp8 ? a_4 : a_2),
        .b(fp8 ? b_4 : b_2),
        .cin(cout1),
        .sum(mant_sum[3]),
        .cout(cout2)
    );
    adder #(.WIDTH(3)) adder5 (
        .a(shifted_mant_a[6:4]),
        .b(diff_sign ? ~shifted_mant_b[6:4] : shifted_mant_b[6:4]),
        .cin(cout2),
        .sum(mant_sum[6:4]),
        .cout(cout3)
    );
    adder #(.WIDTH(3)) adder6 (
        .a(fp8 ? a_1 : a_3),
        .b(fp8 ? b_1 : b_3),
        .cin(fp8 ? diff_sign : cout3),
        .sum(mant_sum[9:7]),
        .cout(cout4)
    );
    adder #(.WIDTH(1)) adder7 (
        .a(fp8 ? a_2 : a_4),
        .b(fp8 ? b_2 : b_4),
        .cin(cout4),
        .sum(mant_sum[10]),
        .cout(cout5)
    );
    always_comb begin : adder_operands
        diff_sign = sign_a ^ sign_b;
        diff_sign2 = sign_a2 ^ sign_b2;
        a_1 = shifted_mant_a[2:0];
        b_1 = (~diff_sign) ? shifted_mant_b[2:0] : (~shifted_mant_b[2:0]);
        a_2 = shifted_mant_a[3];
        b_2 = (diff_sign) ^ shifted_mant_b[3];
        a_3 = fp8 ? shifted_mant_a2[2:0] : shifted_mant_a[9:7];
        b_3_unsigned = fp8 ? shifted_mant_b2[2:0] : shifted_mant_b[9:7];
        b_3 = (fp8 ? ~diff_sign2 : ~diff_sign) ? b_3_unsigned : (~b_3_unsigned);
        a_4 = fp8 ? shifted_mant_a2[3] : shifted_mant_a[10];
        b_4 = (fp8 ? diff_sign2 : diff_sign) ^ (fp8 ? shifted_mant_b2[3] : shifted_mant_b[10]);
        mant_sum_overflow = (fp8) ? (e5m2 ? ({mant_sum[10], (~diff_sign & cout4) ? ({cout4, mant_sum[9:8]}) : mant_sum[9:7], mant_sum[6:3], (~diff_sign2 & cout1) ? ({cout1, mant_sum[2:1]}) : mant_sum[2:0]}) 
                                          : ({(~diff_sign & cout5) ? ({cout5, mant_sum[10:8]}) : mant_sum[10:7], mant_sum[6:4], (~diff_sign2 & cout2) ? ({cout2, mant_sum[3:1]}) : mant_sum[3:0]})) 
                                  : (cout5 & (~diff_sign)) ? (({cout5, mant_sum} >> 1)) : mant_sum;
        exp_gt_overflow = exp_gt + ((~diff_sign) & (fp8 ? e5m2 ? cout4 : cout5 : cout5));
        exp_gt_overflow2 = exp_gt2 + ((~diff_sign2) & (e5m2 ? cout1 : cout2));
    end

    logic [10:0] mant_sum_normalized;
    logic signed [5:0] exp_gt_overflow_normalized, exp_gt_overflow_normalized2;
    always_comb begin : normalize
        if (fp8) begin
            if (e5m2) begin
                if (~mant_sum_overflow[9]) begin
                    if (mant_sum_overflow[8] == 1'b1) begin
                        mant_sum_normalized[9:7] = mant_sum_overflow[9:7] << 1;
                        exp_gt_overflow_normalized = exp_gt_overflow - 1;
                    end 
                    else if (mant_sum_overflow[7] == 1'b1) begin
                        mant_sum_normalized[9:7] = mant_sum_overflow[9:7] << 2;
                        exp_gt_overflow_normalized = exp_gt_overflow - 2;
                    end 
                    else begin
                        mant_sum_normalized[9:7] = mant_sum_overflow[9:7];
                        exp_gt_overflow_normalized = 0;
                    end
                end else begin
                    mant_sum_normalized[9:7] = mant_sum_overflow[9:7];
                    exp_gt_overflow_normalized = exp_gt_overflow;
                end
                if (~mant_sum_overflow[2]) begin
                    if (mant_sum_overflow[1] == 1'b1) begin
                        mant_sum_normalized[2:0] = mant_sum_overflow[2:0] << 1;
                        exp_gt_overflow_normalized2 = exp_gt_overflow2 - 1;
                    end 
                    else if (mant_sum_overflow[0] == 1'b1) begin
                        mant_sum_normalized[2:0] = mant_sum_overflow[2:0] << 2;
                        exp_gt_overflow_normalized2 = exp_gt_overflow2 - 2;
                    end 
                    else begin
                        mant_sum_normalized[2:0] = mant_sum_overflow[2:0];
                        exp_gt_overflow_normalized2 = 0;
                    end
                end else begin
                    mant_sum_normalized[2:0] = mant_sum_overflow[2:0];
                    exp_gt_overflow_normalized2 = exp_gt_overflow2;
                end
            end else begin
                if (~mant_sum_overflow[10]) begin
                    if (mant_sum_overflow[9] == 1'b1) begin
                        mant_sum_normalized[10:7] = mant_sum_overflow[10:7] << 1;
                        exp_gt_overflow_normalized = exp_gt_overflow - 1;
                    end 
                    else if (mant_sum_overflow[8] == 1'b1) begin
                        mant_sum_normalized[10:7] = mant_sum_overflow[10:7] << 2;
                        exp_gt_overflow_normalized = exp_gt_overflow - 2;
                    end 
                    else if (mant_sum_overflow[7] == 1'b1) begin
                        mant_sum_normalized[10:7] = mant_sum_overflow[10:7] << 3;
                        exp_gt_overflow_normalized = exp_gt_overflow - 3;
                    end 
                    else begin
                        mant_sum_normalized[10:7] = mant_sum_overflow[10:7];
                        exp_gt_overflow_normalized = 0;
                    end
                end else begin
                    mant_sum_normalized[10:7] = mant_sum_overflow[10:7];
                    exp_gt_overflow_normalized = exp_gt_overflow;
                end
                if (~mant_sum_overflow[3]) begin
                    if (mant_sum_overflow[2] == 1'b1) begin
                        mant_sum_normalized[3:0] = mant_sum_overflow[3:0] << 1;
                        exp_gt_overflow_normalized2 = exp_gt_overflow2 - 1;
                    end 
                    else if (mant_sum_overflow[1] == 1'b1) begin
                        mant_sum_normalized[3:0] = mant_sum_overflow[3:0] << 2;
                        exp_gt_overflow_normalized2 = exp_gt_overflow2 - 2;
                    end 
                    else if (mant_sum_overflow[0] == 1'b1) begin
                        mant_sum_normalized[3:0] = mant_sum_overflow[3:0] << 3;
                        exp_gt_overflow_normalized2 = exp_gt_overflow2 - 3;
                    end 
                    else begin
                        mant_sum_normalized[3:0] = mant_sum_overflow[3:0];
                        exp_gt_overflow_normalized2 = 0;
                    end
                end else begin
                    mant_sum_normalized[3:0] = mant_sum_overflow[3:0];
                    exp_gt_overflow_normalized2 = exp_gt_overflow2;
                end
            end
            mant_sum_normalized[6:4] = mant_sum_overflow[6:4];
        end else begin
            if (mant_sum_overflow [10] == 0) begin 
                if (mant_sum_overflow[9] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 1;
                    exp_gt_overflow_normalized = exp_gt_overflow - 1;
                end
                else if (mant_sum_overflow[8] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 2;
                    exp_gt_overflow_normalized = exp_gt_overflow - 2;
                end
                else if (mant_sum_overflow[7] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 3;
                    exp_gt_overflow_normalized = exp_gt_overflow - 3;
                end 
                else if (mant_sum_overflow[6] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 4;
                    exp_gt_overflow_normalized = exp_gt_overflow - 4;
                end 
                else if (mant_sum_overflow[5] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 5;
                    exp_gt_overflow_normalized = exp_gt_overflow - 5;
                end 
                else if (mant_sum_overflow[4] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 6;
                    exp_gt_overflow_normalized = exp_gt_overflow - 6;
                end 
                else if (mant_sum_overflow[3] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 7;
                    exp_gt_overflow_normalized = exp_gt_overflow - 7;
                end 
                else if (mant_sum_overflow[2] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 8;
                    exp_gt_overflow_normalized = exp_gt_overflow - 8;
                end 
                else if (mant_sum_overflow[1] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 9;
                    exp_gt_overflow_normalized = exp_gt_overflow - 9;
                end 
                else if (mant_sum_overflow[0] == 1'b1) begin
                    mant_sum_normalized = mant_sum_overflow << 10;
                    exp_gt_overflow_normalized = exp_gt_overflow - 10;
                end
                else begin
                    mant_sum_normalized = mant_sum_overflow;
                    exp_gt_overflow_normalized = 0;
                end 
            end
            else begin
                mant_sum_normalized = mant_sum_overflow;
                exp_gt_overflow_normalized = exp_gt_overflow;
            end
        end
    end

    always_comb begin : pack
        if (fp8) begin
            if (exp_gt_overflow_normalized[5] == 1'b1) begin // exponent is negative
                o_c[15:8] = 8'b00000000;
            end else begin
                o_c[15:8] = {result_sign, e5m2 ? {exp_gt_overflow_normalized[4:0], mant_sum_normalized[8:7]} : {exp_gt_overflow_normalized[3:0], mant_sum_normalized[9:7]}};
            end
            if (exp_gt_overflow_normalized2[5] == 1'b1) begin // exponent is negative
                o_c[7:0] = 8'b00000000;
            end else begin
                o_c[7:0] = {result_sign2, e5m2 ? {exp_gt_overflow_normalized2[4:0], mant_sum_normalized[1:0]} : {exp_gt_overflow_normalized2[3:0], mant_sum_normalized[2:0]}};
            end
        end
        else begin
            if (exp_gt_overflow_normalized[5] == 1'b1) begin // exponent is negative
                o_c = 16'b0000000000000000;
            end else begin
                o_c = {result_sign, exp_gt_overflow_normalized[4:0], mant_sum_normalized[9:0]};
            end
        end
    end
endmodule