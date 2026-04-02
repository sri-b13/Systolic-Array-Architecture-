module top_conv(
    input clk, rst, start,
    input [7:0] p0,p1,p2,
    input [7:0] w00,w01,w02,
    input [7:0] w10,w11,w12,
    input [7:0] w20,w21,w22,
    output [19:0] conv_out,    // wire, not reg
    output output_valid
);
    wire acc_clear, compute_en;

    controller ctrl(
        clk, rst, start,
        acc_clear, compute_en, output_valid
    );

    systolic_array_3x3 SA(
        clk, rst, acc_clear,
        p0, p1, p2,
        w00, w01, w02,
        w10, w11, w12,
        w20, w21, w22,
        conv_out              // directly wired, no register
    );

endmodule