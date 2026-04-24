// ============================================================================
// UART Receiver - 115200 baud, 8N1, for Edge Artix 7 (50 MHz clock)
// ============================================================================
// Samples RX line at mid-bit using a baud-rate counter.
// Outputs rx_data[7:0] and a single-cycle rx_valid pulse per received byte.
// ============================================================================
module uart_rx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,          // serial input (active-low start bit)
    output reg  [7:0] rx_data,     // received byte
    output reg        rx_valid     // one-cycle pulse when byte is ready
);

    // ── Baud-rate constants ────────────────────────────────────────
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;        // 434
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;       // 217

    // ── State encoding ─────────────────────────────────────────────
    localparam [2:0]
        S_IDLE  = 3'd0,
        S_START = 3'd1,
        S_DATA  = 3'd2,
        S_STOP  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_cnt;     // counts clocks within one bit period
    reg [2:0]  bit_idx;     // which data bit (0-7)
    reg [7:0]  shift_reg;   // shift register for incoming bits

    // ── Double-flop synchroniser for metastability ─────────────────
    reg rx_sync1, rx_sync2;
    always @(posedge clk) begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

    // ── Main state machine ─────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
        end else begin
            rx_valid <= 1'b0;  // default: de-assert

            case (state)

                // ── IDLE: wait for falling edge (start bit) ────────
                S_IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync2 == 1'b0)
                        state <= S_START;
                end

                // ── START: wait half-bit, re-check still low ───────
                S_START: begin
                    if (clk_cnt == HALF_BIT[15:0]) begin
                        clk_cnt <= 16'd0;
                        if (rx_sync2 == 1'b0)
                            state <= S_DATA;   // valid start bit
                        else
                            state <= S_IDLE;   // glitch, abort
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                // ── DATA: sample 8 bits at mid-bit ─────────────────
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT[15:0] - 16'd1) begin
                        clk_cnt <= 16'd0;
                        shift_reg[bit_idx] <= rx_sync2;  // LSB first
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 3'd1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                // ── STOP: wait one full bit, output result ─────────
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT[15:0] - 16'd1) begin
                        clk_cnt  <= 16'd0;
                        rx_data  <= shift_reg;
                        rx_valid <= 1'b1;
                        state    <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
