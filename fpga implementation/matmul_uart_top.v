// ============================================================================
// Matrix Multiply Accelerator — UART Top Level
// ============================================================================
// Target: Edge Artix 7 (XC7A35T), 50 MHz, USB-UART at 115200 baud
//
// Protocol (PC → FPGA):
//   Byte 0     : 0xAA  (start marker)
//   Bytes 1-9  : Matrix A, row-major, signed 8-bit
//   Bytes 10-18: Matrix B, row-major, signed 8-bit
//
// Protocol (FPGA → PC):
//   Byte 0     : 0x55  (response marker)
//   Bytes 1-36 : Matrix C = A×B, row-major, 9 × 32-bit little-endian
//
// LED indicators:
//   led[0] = heartbeat (blinks ~1 Hz)
//   led[1] = computing (high during computation)
//   led[2] = UART activity (high while receiving/transmitting)
// ============================================================================
module matmul_uart_top (
    input  wire       clk,        // 50 MHz
    input  wire       rst_btn,    // active-high push button
    input  wire       uart_rxd,   // UART receive (from USB chip)
    output wire       uart_txd,   // UART transmit (to USB chip)
    output reg  [2:0] led         // status LEDs
);

    // ── Reset synchroniser (2-flop) ────────────────────────────────
    reg rst_sync1, rst_sync2;
    always @(posedge clk) begin
        rst_sync1 <= rst_btn;
        rst_sync2 <= rst_sync1;
    end
    wire rst = rst_sync2;

    // ── Heartbeat LED (~1 Hz blink from 50 MHz) ────────────────────
    reg [25:0] hb_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) hb_cnt <= 26'd0;
        else     hb_cnt <= hb_cnt + 26'd1;
    end

    // ── UART RX instance ───────────────────────────────────────────
    wire [7:0] rx_byte;
    wire       rx_valid;

    uart_rx #(.CLK_FREQ(50_000_000), .BAUD(115_200)) u_rx (
        .clk     (clk),
        .rst     (rst),
        .rx      (uart_rxd),
        .rx_data (rx_byte),
        .rx_valid(rx_valid)
    );

    // ── UART TX instance ───────────────────────────────────────────
    reg  [7:0] tx_byte;
    reg        tx_start;
    wire       tx_busy;

    uart_tx #(.CLK_FREQ(50_000_000), .BAUD(115_200)) u_tx (
        .clk     (clk),
        .rst     (rst),
        .tx_data (tx_byte),
        .tx_start(tx_start),
        .tx      (uart_txd),
        .tx_busy (tx_busy)
    );

    // ── Matrix storage registers ───────────────────────────────────
    reg signed [7:0] A [0:8];   // A[0]=a00, A[1]=a01, ... A[8]=a22
    reg signed [7:0] B [0:8];   // same layout

    // ── Individual wires for matmul ports ──────────────────────────
    wire signed [31:0] c00_w, c01_w, c02_w;
    wire signed [31:0] c10_w, c11_w, c12_w;
    wire signed [31:0] c20_w, c21_w, c22_w;

    // ── Result storage (latched from matmul) ───────────────────────
    reg signed [31:0] C_reg [0:8];

    // ── Matmul instance ────────────────────────────────────────────
    reg  matmul_start;
    wire matmul_done;

    matmul_3x3 u_matmul (
        .clk(clk), .rst(rst), .start(matmul_start),
        .a00(A[0]), .a01(A[1]), .a02(A[2]),
        .a10(A[3]), .a11(A[4]), .a12(A[5]),
        .a20(A[6]), .a21(A[7]), .a22(A[8]),
        .b00(B[0]), .b01(B[1]), .b02(B[2]),
        .b10(B[3]), .b11(B[4]), .b12(B[5]),
        .b20(B[6]), .b21(B[7]), .b22(B[8]),
        .c00(c00_w), .c01(c01_w), .c02(c02_w),
        .c10(c10_w), .c11(c11_w), .c12(c12_w),
        .c20(c20_w), .c21(c21_w), .c22(c22_w),
        .done(matmul_done)
    );

    // ── Protocol state machine ─────────────────────────────────────
    localparam [3:0]
        ST_IDLE        = 4'd0,
        ST_RECV_A      = 4'd1,
        ST_RECV_B      = 4'd2,
        ST_COMPUTE     = 4'd3,
        ST_WAIT_DONE   = 4'd4,
        ST_LATCH       = 4'd5,
        ST_SEND_MARK   = 4'd6,
        ST_MARK_SETTLE = 4'd7,   // 1-cycle wait for tx_busy to rise
        ST_SEND_WAIT   = 4'd8,
        ST_SEND_DATA   = 4'd9,
        ST_DATA_SETTLE = 4'd10,  // 1-cycle wait for tx_busy to rise
        ST_SEND_DWAIT  = 4'd11;

    reg [3:0] state;
    reg [3:0] byte_cnt;     // 0-8 for receiving
    reg [5:0] send_cnt;     // counts 0-35 for sending phase

    // Linearise the 9×4 = 36 result bytes for transmission
    // send_cnt 0..35 → element = send_cnt/4, byte_within = send_cnt%4
    wire [3:0] send_elem   = send_cnt[5:2];  // 0-8
    wire [1:0] send_byte_n = send_cnt[1:0];  // 0-3 (little-endian)

    // Select byte from current result element
    reg [7:0] result_byte;
    always @(*) begin
        case (send_byte_n)
            2'd0: result_byte = C_reg[send_elem][ 7: 0];
            2'd1: result_byte = C_reg[send_elem][15: 8];
            2'd2: result_byte = C_reg[send_elem][23:16];
            2'd3: result_byte = C_reg[send_elem][31:24];
        endcase
    end

    // ── Main FSM ───────────────────────────────────────────────────
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_IDLE;
            byte_cnt     <= 4'd0;
            send_cnt     <= 6'd0;
            matmul_start <= 1'b0;
            tx_start     <= 1'b0;
            tx_byte      <= 8'd0;
            led          <= 3'b000;
            for (i = 0; i < 9; i = i + 1) begin
                A[i] <= 8'd0;
                B[i] <= 8'd0;
                C_reg[i] <= 32'd0;
            end
        end else begin
            // defaults
            matmul_start <= 1'b0;
            tx_start     <= 1'b0;

            // LED outputs
            led[0] <= hb_cnt[25];    // heartbeat
            led[1] <= (state == ST_COMPUTE || state == ST_WAIT_DONE);
            led[2] <= (state != ST_IDLE);

            case (state)

                // ── Wait for start marker 0xAA ─────────────────────
                ST_IDLE: begin
                    byte_cnt <= 4'd0;
                    send_cnt <= 6'd0;
                    if (rx_valid && rx_byte == 8'hAA)
                        state <= ST_RECV_A;
                end

                // ── Receive 9 bytes for matrix A ───────────────────
                ST_RECV_A: begin
                    if (rx_valid) begin
                        A[byte_cnt] <= rx_byte;
                        if (byte_cnt == 4'd8) begin
                            byte_cnt <= 4'd0;
                            state    <= ST_RECV_B;
                        end else begin
                            byte_cnt <= byte_cnt + 4'd1;
                        end
                    end
                end

                // ── Receive 9 bytes for matrix B ───────────────────
                ST_RECV_B: begin
                    if (rx_valid) begin
                        B[byte_cnt] <= rx_byte;
                        if (byte_cnt == 4'd8) begin
                            byte_cnt <= 4'd0;
                            state    <= ST_COMPUTE;
                        end else begin
                            byte_cnt <= byte_cnt + 4'd1;
                        end
                    end
                end

                // ── Trigger matrix multiplication ──────────────────
                ST_COMPUTE: begin
                    matmul_start <= 1'b1;
                    state        <= ST_WAIT_DONE;
                end

                // ── Wait for matmul to finish (2 cycles) ───────────
                ST_WAIT_DONE: begin
                    if (matmul_done)
                        state <= ST_LATCH;
                end

                // ── Latch results into C_reg ───────────────────────
                ST_LATCH: begin
                    C_reg[0] <= c00_w;  C_reg[1] <= c01_w;  C_reg[2] <= c02_w;
                    C_reg[3] <= c10_w;  C_reg[4] <= c11_w;  C_reg[5] <= c12_w;
                    C_reg[6] <= c20_w;  C_reg[7] <= c21_w;  C_reg[8] <= c22_w;
                    state <= ST_SEND_MARK;
                end

                // ── Send response marker 0x55 ──────────────────────
                ST_SEND_MARK: begin
                    if (!tx_busy) begin
                        tx_byte  <= 8'h55;
                        tx_start <= 1'b1;
                        state    <= ST_MARK_SETTLE;
                    end
                end

                // ── 1-cycle settle: let tx_busy propagate ──────────
                ST_MARK_SETTLE: begin
                    state <= ST_SEND_WAIT;
                end

                // ── Wait for marker byte to finish transmitting ────
                ST_SEND_WAIT: begin
                    if (!tx_busy) begin
                        send_cnt <= 6'd0;
                        state    <= ST_SEND_DATA;
                    end
                end

                // ── Send 36 result bytes (9 elements × 4 bytes) ────
                ST_SEND_DATA: begin
                    if (!tx_busy) begin
                        tx_byte  <= result_byte;
                        tx_start <= 1'b1;
                        state    <= ST_DATA_SETTLE;
                    end
                end

                // ── 1-cycle settle: let tx_busy propagate ──────────
                ST_DATA_SETTLE: begin
                    state <= ST_SEND_DWAIT;
                end

                // ── Wait for data byte to finish, advance counter ──
                ST_SEND_DWAIT: begin
                    if (!tx_busy) begin
                        if (send_cnt == 6'd35) begin
                            state <= ST_IDLE;  // all done
                        end else begin
                            send_cnt <= send_cnt + 6'd1;
                            state    <= ST_SEND_DATA;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
