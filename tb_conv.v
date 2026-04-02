`timescale 1ns / 1ps
module tb_conv;

    reg clk = 0;
    always #5 clk = ~clk;  // 10ns period

    reg rst, start;
    reg [7:0] p0,p1,p2;
    reg [7:0] w00,w01,w02;
    reg [7:0] w10,w11,w12;
    reg [7:0] w20,w21,w22;
    wire [19:0] conv_out;
    wire valid;

    top_conv DUT(
        clk, rst, start,
        p0, p1, p2,
        w00, w01, w02,
        w10, w11, w12,
        w20, w21, w22,
        conv_out, valid
    );

    // ── timeout watchdog ──────────────────────────────────────────
    initial begin
        #500;
        $display("TIMEOUT - valid never asserted");
        $finish;
    end

    // ── main stimulus ─────────────────────────────────────────────
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_conv);

        // 1. Hold reset for 2 full cycles
        rst = 1; start = 0;
        repeat(2) @(posedge clk);

        // 2. Release reset, set data (stable before any start)
        @(negedge clk);          // drive on negedge → sampled safely on next posedge
        rst = 0;

        // Image window row (single pixel vector)
        p0 = 8'd1;
        p1 = 8'd2;
        p2 = 8'd3;

        // Kernel weights (signed: -1 = 8'hff)
        w00 = 8'd1;  w01 = 8'd1;  w02 = 8'd1;  // -1
        w10 = 8'd1;  w11 = 8'd1;  w12 = 8'd1;
        w20 = 8'd1;  w21 = 8'd1;  w22 = 8'd1;

        // 3. Pulse start for exactly ONE clock cycle, driven on negedge
        @(negedge clk); start = 1;
        @(negedge clk); start = 0;

        // 4. Wait for valid, with a per-cycle display for debugging
        $display("Time | conv_out | valid");
        repeat(20) begin
            @(posedge clk); #1;
            $display("%4t ns | %d | %b", $time, $signed(conv_out), valid);
            if (valid) begin
                $display(">>> DONE: conv_out = %d (expected 0)", $signed(conv_out));
                $finish;
            end
        end

        $display("valid never asserted in time");
        $finish;
    end

endmodule
