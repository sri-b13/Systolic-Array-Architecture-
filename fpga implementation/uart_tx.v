// ============================================================================
// UART Transmitter - 115200 baud, 8N1, for Edge Artix 7 (50 MHz clock)
// ============================================================================
// Accepts tx_data[7:0] + tx_start pulse. Drives tx serial line.
// tx_busy stays high while a byte is being transmitted.
// ============================================================================
module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,     // byte to send
    input  wire       tx_start,    // pulse to begin transmission
    output reg        tx,          // serial output
    output reg        tx_busy      // high while transmitting
);

    // ── Baud-rate constant ─────────────────────────────────────────
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;  // 434

    // ── State encoding ─────────────────────────────────────────────
    localparam [2:0]
        S_IDLE  = 3'd0,
        S_START = 3'd1,
        S_DATA  = 3'd2,
        S_STOP  = 3'd3;

    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shift_reg;

    // ── Main state machine ─────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            clk_cnt   <= 16'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            tx        <= 1'b1;    // idle high
            tx_busy   <= 1'b0;
        end else begin
            case (state)

                // ── IDLE: wait for start command ───────────────────
                S_IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tx_busy   <= 1'b1;
                        state     <= S_START;
                    end
                end

                // ── START bit: drive low for one bit period ────────
                S_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT[15:0] - 16'd1) begin
                        clk_cnt <= 16'd0;
                        state   <= S_DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                // ── DATA: send 8 bits LSB first ────────────────────
                S_DATA: begin
                    tx <= shift_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT[15:0] - 16'd1) begin
                        clk_cnt <= 16'd0;
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

                // ── STOP bit: drive high for one bit period ────────
                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT[15:0] - 16'd1) begin
                        clk_cnt <= 16'd0;
                        tx_busy <= 1'b0;
                        state   <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 16'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
