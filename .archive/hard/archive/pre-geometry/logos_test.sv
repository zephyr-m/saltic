module logos_test;
    localparam logic [1:0] NOP  = 2'b00;
    localparam logic [1:0] INC  = 2'b01;
    localparam logic [1:0] DEC  = 2'b10;
    localparam logic [1:0] HALT = 2'b11;

    logic clock = 0;
    logic reset = 1;
    logic configure = 0;
    logic [63:0] configure_counter = 0;
    logic configure_inc_valid = 1;
    logic [1:0] configure_inc_opcode = DEC;
    logic [7:0] configure_inc_target = 8'd9;
    logic configure_dec_valid = 1;
    logic [1:0] configure_dec_opcode = INC;
    logic [7:0] configure_dec_target = 8'd10;
    logic configure_zero_valid = 1;
    logic [1:0] configure_zero_opcode = HALT;
    logic [7:0] configure_zero_target = 8'd11;
    logic inbox_valid = 0;
    logic inbox_ready;
    logic [1:0] inbox_opcode = NOP;
    logic [63:0] inbox_data = 0;
    logic outbox_valid;
    logic outbox_ready = 1;
    logic [1:0] outbox_opcode;
    logic [63:0] outbox_data;
    logic [7:0] outbox_target;
    logic [63:0] counter;
    logic halted;

    logos_cell dut (.*);
    always #5 clock = ~clock;

    task automatic send(input [1:0] opcode, input [63:0] data);
        @(negedge clock);
        inbox_valid = 1;
        inbox_opcode = opcode;
        inbox_data = data;
        @(negedge clock);
        inbox_valid = 0;
    endtask

    initial begin
        repeat (2) @(negedge clock);
        reset = 0;
        configure = 1;
        configure_counter = 64'd1;
        @(negedge clock);
        configure = 0;

        send(INC, 64'h1234);
        if (counter != 2 || !outbox_valid || outbox_opcode != DEC ||
            outbox_target != 9 || outbox_data != 64'h1234)
            $fatal(1, "INC contract failed");

        outbox_ready = 0;
        inbox_valid = 1;
        inbox_opcode = DEC;
        inbox_data = 64'h5678;
        repeat (2) @(negedge clock);
        if (inbox_ready || counter != 2 || outbox_data != 64'h1234)
            $fatal(1, "backpressure contract failed");

        outbox_ready = 1;
        @(negedge clock);
        inbox_valid = 0;
        if (counter != 1 || !outbox_valid || outbox_opcode != INC ||
            outbox_target != 10 || outbox_data != 64'h5678)
            $fatal(1, "DEC contract failed");

        @(negedge clock);
        send(DEC, 64'h9abc);
        if (counter != 0) $fatal(1, "DEC to zero failed");
        @(negedge clock);
        send(DEC, 64'hdef0);
        if (counter != 0 || !outbox_valid || outbox_opcode != HALT ||
            outbox_target != 11 || outbox_data != 64'hdef0)
            $fatal(1, "zero reaction failed");

        @(negedge clock);
        send(HALT, 0);
        if (!halted || inbox_ready) $fatal(1, "HALT contract failed");

        $display("ok logos v0 counter=%0d halted=%0d", counter, halted);
        $finish;
    end
endmodule
