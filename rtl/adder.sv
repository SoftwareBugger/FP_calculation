module adder #(
    parameter WIDTH = 4
)(
    input logic [WIDTH-1:0] a,
    input logic [WIDTH-1:0] b,
    input logic cin,
    output logic [WIDTH-1:0] sum,
    output logic cout
);
    always_comb begin
        {cout, sum} = a + b + cin;
    end
endmodule