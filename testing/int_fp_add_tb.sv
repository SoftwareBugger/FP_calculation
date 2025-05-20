`define PATTERN "C:/intelFPGA/18.1/mult_fp16_golden_pattern.txt"
`define PATTERN_NUM 1000
module int_fp_add_tb ();

reg [15:0] input1,input2;
reg [15:0] expected;
reg mode;
reg [48:0] pattern [0:`PATTERN_NUM-1];
reg [10:0] error_cnt;

integer i, j;

wire [15:0] result;
// FP_add u1 (.i_a(input1),.i_b(input2), .fp8(1'b1), .e5m2(1'b0), .o_c(result));
// Float16Add u1 (input1, input2, result);
Float16Mul u1 (.i_a(input1),.i_b(input2), .fp8(1'b0), .e5m2(1'b1), .o_c(result));

initial begin
    j = $fopen("./result_analysis.txt", "w");
    error_cnt = 0;
    #30;
    for(i=0;i<`PATTERN_NUM;i=i+1) begin
        {input1,input2,expected,mode} = pattern[i];
        #40
        $display("#%d expected: %b actual:%b",i, expected,result);
        $fwrite(j,"%b %b\n",expected,result);
        if (expected == result) begin 
            $display("Check PASSED");
            $display("--------------------");
        end else begin
            error_cnt = error_cnt + 1;
        end
    end
    #10;
    $display("Total error count: %d",error_cnt);
    #10;
    $fclose(j);
    $finish;
end

initial begin 
    $dumpfile("int_fp_add.vcd");
    $dumpvars;
end


initial begin 
    $readmemb(`PATTERN,pattern);
end

endmodule