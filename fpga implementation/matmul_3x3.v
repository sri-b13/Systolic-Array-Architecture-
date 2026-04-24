// ============================================================================
// 3x3 Signed Matrix Multiplier  —  C = A × B
// ============================================================================
// Inputs:  9 signed 8-bit elements for A and B (row-major order)
// Output:  9 signed 32-bit elements for C (row-major order)
//
// Computation: C[i][j] = Σ_k  A[i][k] * B[k][j]   for k = 0,1,2
//
// Fully pipelined: assert 'start', result appears on 'done' (2 cycles later).
// ============================================================================
module matmul_3x3 (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    // Matrix A — row-major: a00 a01 a02  a10 a11 a12  a20 a21 a22
    input  wire signed [7:0] a00, a01, a02,
    input  wire signed [7:0] a10, a11, a12,
    input  wire signed [7:0] a20, a21, a22,

    // Matrix B — row-major
    input  wire signed [7:0] b00, b01, b02,
    input  wire signed [7:0] b10, b11, b12,
    input  wire signed [7:0] b20, b21, b22,

    // Matrix C — row-major, 32-bit signed results
    output reg signed [31:0] c00, c01, c02,
    output reg signed [31:0] c10, c11, c12,
    output reg signed [31:0] c20, c21, c22,

    output reg               done
);

    // ── Pipeline stage 1: 27 registered products ───────────────────
    reg signed [15:0] p00_0, p00_1, p00_2;  // products for C[0][0]
    reg signed [15:0] p01_0, p01_1, p01_2;  // products for C[0][1]
    reg signed [15:0] p02_0, p02_1, p02_2;  // products for C[0][2]
    reg signed [15:0] p10_0, p10_1, p10_2;  // products for C[1][0]
    reg signed [15:0] p11_0, p11_1, p11_2;  // products for C[1][1]
    reg signed [15:0] p12_0, p12_1, p12_2;  // products for C[1][2]
    reg signed [15:0] p20_0, p20_1, p20_2;  // products for C[2][0]
    reg signed [15:0] p21_0, p21_1, p21_2;  // products for C[2][1]
    reg signed [15:0] p22_0, p22_1, p22_2;  // products for C[2][2]

    reg stage1_valid;

    // ── Pipeline stage 2: sum 3 products → 9 results ───────────────
    reg stage2_valid;

    // ── Stage 1: multiply ──────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage1_valid <= 1'b0;
            {p00_0,p00_1,p00_2} <= 48'd0;
            {p01_0,p01_1,p01_2} <= 48'd0;
            {p02_0,p02_1,p02_2} <= 48'd0;
            {p10_0,p10_1,p10_2} <= 48'd0;
            {p11_0,p11_1,p11_2} <= 48'd0;
            {p12_0,p12_1,p12_2} <= 48'd0;
            {p20_0,p20_1,p20_2} <= 48'd0;
            {p21_0,p21_1,p21_2} <= 48'd0;
            {p22_0,p22_1,p22_2} <= 48'd0;
        end else begin
            stage1_valid <= start;
            if (start) begin
                // C[0][j] = A[0][k] * B[k][j]
                p00_0 <= a00 * b00;  p00_1 <= a01 * b10;  p00_2 <= a02 * b20;
                p01_0 <= a00 * b01;  p01_1 <= a01 * b11;  p01_2 <= a02 * b21;
                p02_0 <= a00 * b02;  p02_1 <= a01 * b12;  p02_2 <= a02 * b22;
                // C[1][j] = A[1][k] * B[k][j]
                p10_0 <= a10 * b00;  p10_1 <= a11 * b10;  p10_2 <= a12 * b20;
                p11_0 <= a10 * b01;  p11_1 <= a11 * b11;  p11_2 <= a12 * b21;
                p12_0 <= a10 * b02;  p12_1 <= a11 * b12;  p12_2 <= a12 * b22;
                // C[2][j] = A[2][k] * B[k][j]
                p20_0 <= a20 * b00;  p20_1 <= a21 * b10;  p20_2 <= a22 * b20;
                p21_0 <= a20 * b01;  p21_1 <= a21 * b11;  p21_2 <= a22 * b21;
                p22_0 <= a20 * b02;  p22_1 <= a21 * b12;  p22_2 <= a22 * b22;
            end
        end
    end

    // ── Stage 2: accumulate + output ───────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stage2_valid <= 1'b0;
            done <= 1'b0;
            {c00,c01,c02} <= 96'd0;
            {c10,c11,c12} <= 96'd0;
            {c20,c21,c22} <= 96'd0;
        end else begin
            done <= stage1_valid;
            if (stage1_valid) begin
                c00 <= {{16{p00_0[15]}}, p00_0} + {{16{p00_1[15]}}, p00_1} + {{16{p00_2[15]}}, p00_2};
                c01 <= {{16{p01_0[15]}}, p01_0} + {{16{p01_1[15]}}, p01_1} + {{16{p01_2[15]}}, p01_2};
                c02 <= {{16{p02_0[15]}}, p02_0} + {{16{p02_1[15]}}, p02_1} + {{16{p02_2[15]}}, p02_2};
                c10 <= {{16{p10_0[15]}}, p10_0} + {{16{p10_1[15]}}, p10_1} + {{16{p10_2[15]}}, p10_2};
                c11 <= {{16{p11_0[15]}}, p11_0} + {{16{p11_1[15]}}, p11_1} + {{16{p11_2[15]}}, p11_2};
                c12 <= {{16{p12_0[15]}}, p12_0} + {{16{p12_1[15]}}, p12_1} + {{16{p12_2[15]}}, p12_2};
                c20 <= {{16{p20_0[15]}}, p20_0} + {{16{p20_1[15]}}, p20_1} + {{16{p20_2[15]}}, p20_2};
                c21 <= {{16{p21_0[15]}}, p21_0} + {{16{p21_1[15]}}, p21_1} + {{16{p21_2[15]}}, p21_2};
                c22 <= {{16{p22_0[15]}}, p22_0} + {{16{p22_1[15]}}, p22_1} + {{16{p22_2[15]}}, p22_2};
            end
        end
    end

endmodule
