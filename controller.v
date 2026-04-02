module controller (
    input  clk,
    input  rst,
    input  start,
    output reg acc_clear,
    output reg compute_en,
    output reg output_valid
);
    // One-hot states for better synthesis
    localparam [2:0]
        IDLE    = 3'b00001,
        CLEAR   = 3'b00010,
        COMPUTE = 3'b00100,
        FLUSH   = 3'b01000,
        DONE    = 3'b10000;

    // Use 5-bit one-hot register
    reg [4:0] state;
    reg [3:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= 5'b00001;  // IDLE
            count        <= 4'd0;
            acc_clear    <= 1'b0;
            compute_en   <= 1'b0;
            output_valid <= 1'b0;
        end else begin
            // Default outputs
            acc_clear    <= 1'b0;
            compute_en   <= 1'b0;
            output_valid <= 1'b0;

            case (1'b1)   // one-hot case

                state[0]: begin // IDLE
                    count <= 4'd0;
                    if (start)
                        state <= 5'b00010; // → CLEAR
                end

                state[1]: begin // CLEAR
                    acc_clear  <= 1'b1;
                    compute_en <= 1'b1;
                    count      <= 4'd0;
                    state      <= 5'b00100; // → COMPUTE
                end

                state[2]: begin // COMPUTE (9 cycles)
                    compute_en <= 1'b1;
                    if (count == 4'd8) begin
                        count <= 4'd0;
                        state <= 5'b01000; // → FLUSH
                    end else begin
                        count <= count + 4'd1;
                    end
                end

state[3]: begin // FLUSH - wait 4 cycles not 2
    if (count == 4'd3) begin   // ← was 4'd2, now 4'd3
        count <= 4'd0;
        state <= 5'b10000;
    end else begin
        count <= count + 4'd1;
    end
end

                state[4]: begin // DONE
                    output_valid <= 1'b1;
                    state        <= 5'b00001; // → IDLE
                    count        <= 4'd0;
                end

                default: state <= 5'b00001;
            endcase
        end
    end

endmodule