module E4M3_adder #(
    parameter WIDTH = 8
)(
    input [WIDTH-1:0] i_a,
    input [WIDTH-1:0] i_b,
    output logic [WIDTH-1:0] o_c
);
/*  
    Input:
        A[7:0] -> E4M3 Float
        B[7:0] -> E4M3 Float
    Output:
        C[7:0] -> E4M3 Float (sum of A and B inputs)
        
    Compute the sum of two E4M3 FP8 numbers, A and B.
    No support for Nans or Infs.
    Rounding is towards +Inf or -Inf as necessary
    Design is purely combinational i.e no delay to result
*/

logic [3:0] exp_a, exp_b;
logic [2:0] _mant_a, _mant_b; 
logic sign_a, sign_b;

logic red_or_exp_a,  red_or_exp_b;

always_comb begin : red_or_exp
    /*
    The reduction OR operation is used to determine if the exponent
    is zero or not. This is important for determining if the number
    is subnormal or not, when the bit is set to 0, the number is subnormal.
    */
    red_or_exp_a = |(exp_a); 
    red_or_exp_b = |(exp_b); 
end

always_comb begin : unpack
    /*
    Unpack the input numbers into their components
    */
    // The sign bit is the most significant bit
    // The exponent is the next 4 bits
    // The mantissa is the last 3 bits
    {sign_a, exp_a, _mant_a} = i_a;
    {sign_b, exp_b, _mant_b} = i_b;
end


logic [3:0] mant_a, mant_b;

always_comb begin : pack
    /*
    Pack the components back into the output number
    */
    // The sign bit is the most significant bit
    // The exponent is the next 4 bits
    // The mantissa is the last 3 bits
    // The mantissa is packed with the reduction OR operation
    // to determine if the number is subnormal or not.
    mant_a = {red_or_exp_a, _mant_a};
    mant_b = {red_or_exp_b, _mant_b};
end


/*
 The arg1, arg2 notation is for internal manipulations
*/

logic sign_diff;
logic [3:0]  exp_diff;

logic [7:0] mant_1, mant_2;
logic [8:0] mant_2s;
logic deg_check; 
logic [8:0] _mant_sum, mant_sum; 
logic [3:0] exp_1;

logic [3:0] exp_sum; 

logic is_roundable;
// logic is_degen;

logic [3:0] exp_a_reg, exp_b_reg; 

logic result_sign;
logic gt;

logic [3:0] exp_sub_arg_1, exp_sub_arg_2;
always_comb begin : decode
    /*
    Important to note that in E4M3, exponents of 0000 and 0001
    are technically the same. They both represent and exponent of -7
    with `0000` merely indicating that the significand is subnormal.
    
    As such, it is beneficial for futher processing to 'normalize' the exponent.
    We do this here by simply ORing the negation of the reduction OR operation on
    the exponent
    */
    exp_a_reg = exp_a | (!red_or_exp_a);
    exp_b_reg = exp_b | (!red_or_exp_b); 
    sign_diff = sign_a ^ sign_b;
    mant_1[3:0] = 4'b0;
    mant_2[3:0] = 4'b0;
    gt = {exp_a, mant_a} >= {exp_b, mant_b};
    exp_sub_arg_1 = gt? exp_a_reg: exp_b_reg; // exp_sub_arg_1 is the larger of the two
    exp_sub_arg_2 = gt? exp_b_reg: exp_a_reg; // exp_sub_arg_2 is the smaller of the two
    exp_diff = exp_sub_arg_1 - exp_sub_arg_2;
    
    mant_1[7:4] = gt? mant_a: mant_b; // mant_1 is the larger of the two
    mant_2[7:4] = gt? mant_b: mant_a; // mant_2 is the smaller of the two
    result_sign = gt? sign_a: sign_b;
    exp_1 = gt? exp_a_reg: exp_b_reg;
    
    /*
    This design doesn't use a full-width significand shift/extension.
    
    My intuition was that big shift values would ultimately not affect 
    results significantly, so I thought to take advantage of that to keep
    the mantissa widths to 8 bits

    And it mostly works, save for the case where a a mantissa of x001 is
    shifted right by 5 places.

    The deg_check signal detects that case and remedies it by masquerading
    x001 values as x010 values.

    As this issue only really arises with subtraction, it is handled for that case.
    
    See the next always_comb_comb_comb block 

_       mant_sum = mant_1 + (sign_diff? (-(mant_2s|deg_check)): mant_2s);    
                                              ^^^^^
*/

    {mant_2s, deg_check} = {mant_2, 1'b0} >> exp_diff; 
end
/* 
{8765} is rounded when bit 4 is set
{7654} is rounded when bit 3 is set
in both cases, adding 1 to bit 4 accomplishes rounding

{6543} is rounded when bit 2 is set
{5432} is rounded when bit 1 is set
in both cases, adding 1 to bit 2 accomplishes rounding

*/

logic [1:0] round; 
always_comb begin : mant_acc
    _mant_sum = mant_1 + (sign_diff? (-(mant_2s|deg_check)): mant_2s); 
    
    // rounding value generation
    round[1] = (_mant_sum[8] & _mant_sum[4]) || (_mant_sum[7] & _mant_sum[3]);
    round[0] =  !round[1] && ((_mant_sum[6] & _mant_sum[2]) || ( (_mant_sum[5]) && _mant_sum[1])); 

    // rounding value
    mant_sum = {_mant_sum[8:2] + {round[1], 1'b0, round[0]}, _mant_sum[1:0]}; 

end

logic [1:0] exp_neg;// computer number of places to shift left
logic [2:0] sh_req; // number of places to shift left. See comment at signal assignment

logic left_shift; // Attempt left shift

always_comb begin : sh_req_calc
    left_shift = !(mant_sum[8] || mant_sum[7]); // left shift if mantissa is not normalized (bit 8 and 7 are both 0)
    exp_neg[1] = (left_shift && !mant_sum[6]) && (mant_sum[5] || mant_sum[4]);
    exp_neg[0] = left_shift && (!mant_sum[5] && mant_sum[4] || mant_sum[6]);
end


logic [3:0] final_exp;

logic [3:0] true_shift_or_exp; // 
logic [4:0] exp_sum_arg; // value to add to exponent
logic over_under_flow; // overflow or underflow


always_comb begin: exp_sum_up
    /*
    There is a special case where mant_1 = b1000_0000 and mant_2s = b0111_1000.
    The resulting subtration is b0000_1000.
    As it is the only case where a left shift by 4 is required, we detect it here
    and set the sh_req as ncessary (exp_neg is guaranteed to be b00 when this occurs, so it's alright)
    */
    sh_req = {mant_sum==5'b1000, exp_neg};

    // The logic on the next line inverts (by means of the XOR gate), the value to be shifted
    // as if to find it's 2's complement (but stopping short of adding '1'). As it turns out,
    // this \cancels out' in subsequent computations, while makeing the detection of overflows a
    // lot simpler.
    // The XOR clears sh_req when no left shift is necessary and OR mant_sum[8] makes exp_sum_arg '1'
    // for the case where the mantissa sum overflows to the 8th bit

    exp_sum_arg = ({2'b00, sh_req} ^ {5{left_shift}}) | mant_sum[8]; 
    {over_under_flow, exp_sum} = exp_1 + exp_sum_arg;

    // When underflow occurs, the exponent has to be set to 0000, and we need to
    // readjust the left shift as necessary.
    // Note that when underflow does not occur, the left shift amount will always be sh_req
    // when underflow does occur, we must use the value of (exp_sum + 1) as the shift value.
    // The '+1' compensates for the incomplete two's complement on sh_req. This allows us to
    // compute the exponent without introducing any new adder!
    true_shift_or_exp = exp_sum + (over_under_flow?sh_req:1'b1);
end

logic[3:0] final_mant;
logic[8:0] shifted_mant;


always_comb begin : compute_final
    // shift by true_shift_or exp when underflow occurs, sh_req when no underflow
    shifted_mant = mant_sum << (over_under_flow? true_shift_or_exp: sh_req);

    if (shifted_mant[8])
        // mantissa should be set to b1111 when overflow occurs (max_value) 
        final_mant = mant_sum[8:5] | {4{over_under_flow}}; 
    else
        final_mant = shifted_mant[7:4];

    if (left_shift) begin
        // exponent set to 0 when underflow occurs, true_shift_or_exp otherwise
        final_exp = {4{!over_under_flow}} & true_shift_or_exp;
    end else begin
        // exponent set to b1111 when overflow occurs
        final_exp = {4{over_under_flow}} | exp_sum[3:0];
    end
    
end


always_comb begin : output_calc
    o_c = {result_sign, final_exp, final_mant[2:0]}; 
end

    
endmodule