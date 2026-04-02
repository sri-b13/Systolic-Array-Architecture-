module pe (
    input  clk,
    input  rst,
    input  signed [7:0]  pixel_in,
    input  signed [7:0]  weight_in,
    input  signed [19:0] psum_in,
    input  acc_clear,
    output reg signed [7:0]  pixel_out,
    output reg signed [7:0]  weight_out,
    output reg signed [19:0] psum_out
);
    wire signed [15:0] mult;
    assign mult = pixel_in * weight_in;   // combinational, use registered inputs below

    reg signed [7:0]  R_pixel, R_weight;
    reg signed [19:0] R_acc;

    // ── Stage 1: register inputs + accumulate ──────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            R_pixel  <= 8'd0;
            R_weight <= 8'd0;
            R_acc    <= 20'd0;
        end else begin
            R_pixel  <= pixel_in;
            R_weight <= weight_in;
            if (acc_clear)
                R_acc <= 20'd0;
            else
                R_acc <= psum_in + $signed(pixel_in * weight_in);
        end
    end

    // ── Stage 2: register outputs (pipeline forwarding) ────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pixel_out  <= 8'd0;   // ← THIS was the X-prop bug
            weight_out <= 8'd0;
            psum_out   <= 20'd0;
        end else begin
            pixel_out  <= R_pixel;
            weight_out <= R_weight;
            psum_out   <= R_acc;
        end
    end

endmodule