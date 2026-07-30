module logos_cell #(
    parameter int ADDRESS_BITS = 8
) (
    input  logic                    clock,
    input  logic                    reset,

    input  logic                    configure,
    input  logic [63:0]             configure_counter,
    input  logic                    configure_inc_valid,
    input  logic [1:0]              configure_inc_opcode,
    input  logic [ADDRESS_BITS-1:0] configure_inc_target,
    input  logic                    configure_dec_valid,
    input  logic [1:0]              configure_dec_opcode,
    input  logic [ADDRESS_BITS-1:0] configure_dec_target,
    input  logic                    configure_zero_valid,
    input  logic [1:0]              configure_zero_opcode,
    input  logic [ADDRESS_BITS-1:0] configure_zero_target,

    input  logic                    inbox_valid,
    output logic                    inbox_ready,
    input  logic [1:0]              inbox_opcode,
    input  logic [63:0]             inbox_data,

    output logic                    outbox_valid,
    input  logic                    outbox_ready,
    output logic [1:0]              outbox_opcode,
    output logic [63:0]             outbox_data,
    output logic [ADDRESS_BITS-1:0] outbox_target,

    output logic [63:0]             counter,
    output logic                    halted
);
    localparam logic [1:0] OP_NOP  = 2'b00;
    localparam logic [1:0] OP_INC  = 2'b01;
    localparam logic [1:0] OP_DEC  = 2'b10;
    localparam logic [1:0] OP_HALT = 2'b11;

    logic inc_valid;
    logic [1:0] inc_opcode;
    logic [ADDRESS_BITS-1:0] inc_target;
    logic dec_valid;
    logic [1:0] dec_opcode;
    logic [ADDRESS_BITS-1:0] dec_target;
    logic zero_valid;
    logic [1:0] zero_opcode;
    logic [ADDRESS_BITS-1:0] zero_target;

    assign inbox_ready = !halted && (!outbox_valid || outbox_ready);

    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 64'd0;
            halted <= 1'b0;
            outbox_valid <= 1'b0;
            outbox_opcode <= OP_NOP;
            outbox_data <= 64'd0;
            outbox_target <= '0;
            inc_valid <= 1'b0;
            inc_opcode <= OP_NOP;
            inc_target <= '0;
            dec_valid <= 1'b0;
            dec_opcode <= OP_NOP;
            dec_target <= '0;
            zero_valid <= 1'b0;
            zero_opcode <= OP_NOP;
            zero_target <= '0;
        end else if (configure) begin
            counter <= configure_counter;
            halted <= 1'b0;
            outbox_valid <= 1'b0;
            inc_valid <= configure_inc_valid;
            inc_opcode <= configure_inc_opcode;
            inc_target <= configure_inc_target;
            dec_valid <= configure_dec_valid;
            dec_opcode <= configure_dec_opcode;
            dec_target <= configure_dec_target;
            zero_valid <= configure_zero_valid;
            zero_opcode <= configure_zero_opcode;
            zero_target <= configure_zero_target;
        end else begin
            if (outbox_valid && outbox_ready) begin
                outbox_valid <= 1'b0;
            end

            if (inbox_valid && inbox_ready) begin
                case (inbox_opcode)
                    OP_NOP: begin
                    end

                    OP_INC: begin
                        counter <= counter + 1'b1;
                        if (inc_valid) begin
                            outbox_valid <= 1'b1;
                            outbox_opcode <= inc_opcode;
                            outbox_data <= inbox_data;
                            outbox_target <= inc_target;
                        end
                    end

                    OP_DEC: begin
                        if (counter == 0) begin
                            if (zero_valid) begin
                                outbox_valid <= 1'b1;
                                outbox_opcode <= zero_opcode;
                                outbox_data <= inbox_data;
                                outbox_target <= zero_target;
                            end
                        end else begin
                            counter <= counter - 1'b1;
                            if (dec_valid) begin
                                outbox_valid <= 1'b1;
                                outbox_opcode <= dec_opcode;
                                outbox_data <= inbox_data;
                                outbox_target <= dec_target;
                            end
                        end
                    end

                    OP_HALT: begin
                        halted <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule
