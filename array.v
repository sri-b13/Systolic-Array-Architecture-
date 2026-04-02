module systolic_array_3x3 (
    input  clk, rst, acc_clear,
    input  [7:0] p0, p1, p2,
    input  [7:0] w00,w01,w02,
    input  [7:0] w10,w11,w12,
    input  [7:0] w20,w21,w22,
    output signed [21:0] conv_out
);
    wire [7:0]  p01,p02, p11,p12, p21,p22;
    wire [7:0]  w01_d,w02_d, w11_d,w12_d, w21_d,w22_d;
    wire signed [19:0] ps00,ps01,ps02;
    wire signed [19:0] ps10,ps11,ps12;
    wire signed [19:0] ps20,ps21,ps22;

    // Row 0
    pe PE00(.clk(clk),.rst(rst),.pixel_in(p0), .weight_in(w00),.psum_in(20'd0),.acc_clear(acc_clear),.pixel_out(p01), .weight_out(w01_d),.psum_out(ps00));
    pe PE01(.clk(clk),.rst(rst),.pixel_in(p01),.weight_in(w01),.psum_in(ps00), .acc_clear(acc_clear),.pixel_out(p02), .weight_out(w02_d),.psum_out(ps01));
    pe PE02(.clk(clk),.rst(rst),.pixel_in(p02),.weight_in(w02),.psum_in(ps01), .acc_clear(acc_clear),.pixel_out(),    .weight_out(),     .psum_out(ps02));

    // Row 1
    pe PE10(.clk(clk),.rst(rst),.pixel_in(p1), .weight_in(w10),.psum_in(20'd0),.acc_clear(acc_clear),.pixel_out(p11), .weight_out(w11_d),.psum_out(ps10));
    pe PE11(.clk(clk),.rst(rst),.pixel_in(p11),.weight_in(w11),.psum_in(ps10), .acc_clear(acc_clear),.pixel_out(p12), .weight_out(w12_d),.psum_out(ps11));
    pe PE12(.clk(clk),.rst(rst),.pixel_in(p12),.weight_in(w12),.psum_in(ps11), .acc_clear(acc_clear),.pixel_out(),    .weight_out(),     .psum_out(ps12));

    // Row 2
    pe PE20(.clk(clk),.rst(rst),.pixel_in(p2), .weight_in(w20),.psum_in(20'd0),.acc_clear(acc_clear),.pixel_out(p21), .weight_out(w21_d),.psum_out(ps20));
    pe PE21(.clk(clk),.rst(rst),.pixel_in(p21),.weight_in(w21),.psum_in(ps20), .acc_clear(acc_clear),.pixel_out(p22), .weight_out(w22_d),.psum_out(ps21));
    pe PE22(.clk(clk),.rst(rst),.pixel_in(p22),.weight_in(w22),.psum_in(ps21), .acc_clear(acc_clear),.pixel_out(),    .weight_out(),     .psum_out(ps22));

    // ── Sum all three rows ──────────────────────────────────────
    assign conv_out = $signed(ps02) + $signed(ps12) + $signed(ps22);

endmodule
