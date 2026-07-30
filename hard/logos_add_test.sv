module logos_add_test;
    localparam logic [1:0] NOP  = 2'b00;
    localparam logic [1:0] INC  = 2'b01;
    localparam logic [1:0] DEC  = 2'b10;
    localparam logic [1:0] HALT = 2'b11;

    logic clock = 0;
    logic reset = 1;
    logic configure = 0;
    logic seed_valid = 0;
    integer transfers = 0;

    logic left_in_valid, left_in_ready;
    logic [1:0] left_in_opcode;
    logic [63:0] left_in_data;
    logic left_out_valid, left_out_ready;
    logic [1:0] left_out_opcode;
    logic [63:0] left_out_data;
    logic [7:0] left_out_target;
    logic [63:0] left_counter;
    logic left_halted;

    logic acc_in_valid, acc_in_ready;
    logic [1:0] acc_in_opcode;
    logic [63:0] acc_in_data;
    logic acc_out_valid, acc_out_ready;
    logic [1:0] acc_out_opcode;
    logic [63:0] acc_out_data;
    logic [7:0] acc_out_target;
    logic [63:0] acc_counter;
    logic acc_halted;

    assign left_in_valid = seed_valid || (acc_out_valid && acc_out_target == 0);
    assign left_in_opcode = seed_valid ? DEC : acc_out_opcode;
    assign left_in_data = seed_valid ? 64'hadd : acc_out_data;
    // This two-cell protocol has exactly one sticker in flight, so the opposite
    // cell always has an empty outbox. Constant route readiness avoids a
    // combinational ready loop while preserving the lossless handshake.
    assign acc_out_ready = !seed_valid && acc_out_target == 0;

    assign acc_in_valid = left_out_valid && left_out_target == 1;
    assign acc_in_opcode = left_out_opcode;
    assign acc_in_data = left_out_data;
    assign left_out_ready = left_out_target == 1;

    logos_cell left (
        .clock, .reset, .configure,
        .configure_counter(64'd5),
        .configure_inc_valid(1'b0), .configure_inc_opcode(NOP), .configure_inc_target(8'd0),
        .configure_dec_valid(1'b1), .configure_dec_opcode(INC), .configure_dec_target(8'd1),
        .configure_zero_valid(1'b1), .configure_zero_opcode(HALT), .configure_zero_target(8'd1),
        .inbox_valid(left_in_valid), .inbox_ready(left_in_ready),
        .inbox_opcode(left_in_opcode), .inbox_data(left_in_data),
        .outbox_valid(left_out_valid), .outbox_ready(left_out_ready),
        .outbox_opcode(left_out_opcode), .outbox_data(left_out_data), .outbox_target(left_out_target),
        .counter(left_counter), .halted(left_halted)
    );

    logos_cell accumulator (
        .clock, .reset, .configure,
        .configure_counter(64'd3),
        .configure_inc_valid(1'b1), .configure_inc_opcode(DEC), .configure_inc_target(8'd0),
        .configure_dec_valid(1'b0), .configure_dec_opcode(NOP), .configure_dec_target(8'd0),
        .configure_zero_valid(1'b0), .configure_zero_opcode(NOP), .configure_zero_target(8'd0),
        .inbox_valid(acc_in_valid), .inbox_ready(acc_in_ready),
        .inbox_opcode(acc_in_opcode), .inbox_data(acc_in_data),
        .outbox_valid(acc_out_valid), .outbox_ready(acc_out_ready),
        .outbox_opcode(acc_out_opcode), .outbox_data(acc_out_data), .outbox_target(acc_out_target),
        .counter(acc_counter), .halted(acc_halted)
    );

    always #5 clock = ~clock;

    always @(posedge clock) begin
        if (!reset && !configure) begin
            if (left_in_valid && left_in_ready) begin
                transfers <= transfers + 1;
                if (left_in_data != 64'hadd) $fatal(1, "left lost transaction data");
            end
            if (acc_in_valid && acc_in_ready) begin
                transfers <= transfers + 1;
                if (acc_in_data != 64'hadd) $fatal(1, "accumulator lost transaction data");
            end
        end
    end

    initial begin
        repeat (2) @(negedge clock);
        reset = 0;
        configure = 1;
        @(negedge clock);
        configure = 0;
        seed_valid = 1;
        @(negedge clock);
        seed_valid = 0;

        repeat (30) begin
            @(negedge clock);
            if (acc_halted) begin
                if (left_counter != 0 || acc_counter != 8)
                    $fatal(1, "wrong result left=%0d accumulator=%0d", left_counter, acc_counter);
                if (left_out_valid || acc_out_valid)
                    $fatal(1, "halted with an undelivered sticker");
                if (transfers != 12)
                    $fatal(1, "wrong transfer count %0d", transfers);
                $display("ok RTL fixed Logos ADD(5,3)=%0d", acc_counter);
                $finish;
            end
        end
        $fatal(1, "ADD protocol did not halt");
    end
endmodule
