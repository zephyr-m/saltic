module logos_test;
    localparam logic [1:0] UP = 2'b00;
    localparam logic [1:0] DOWN = 2'b01;
    localparam logic [1:0] DONE = 2'b10;

    logic clock = 0;
    logic reset = 1;
    logic configure = 0;
    logic [1:0] configure_at = 0;
    logic [31:0] configure_counter = 0;
    logic [1:0] configure_up_kind = DONE;
    logic [1:0] configure_up_target = 0;
    logic [1:0] configure_down_kind = DONE;
    logic [1:0] configure_down_target = 0;
    logic [1:0] configure_zero_kind = DONE;
    logic [1:0] configure_zero_target = 0;
    logic inject = 0;
    logic [1:0] inject_at = 0;
    logic [1:0] inject_kind = DOWN;
    logic [1:0] probe_at = 0;
    logic [31:0] probe_counter;
    logic done;
    logic [31:0] pulses;
    logic collision;

    logos_fabric #(.CELLS(4)) fabric (.*);

    always #5 clock = ~clock;

    task set_cell(
        input [1:0] at,
        input [31:0] value,
        input [1:0] up_kind,
        input [1:0] up_target,
        input [1:0] down_kind,
        input [1:0] down_target,
        input [1:0] zero_kind,
        input [1:0] zero_target
    );
        @(negedge clock);
        configure = 1;
        configure_at = at;
        configure_counter = value;
        configure_up_kind = up_kind;
        configure_up_target = up_target;
        configure_down_kind = down_kind;
        configure_down_target = down_target;
        configure_zero_kind = zero_kind;
        configure_zero_target = zero_target;
        @(negedge clock);
        configure = 0;
    endtask

    initial begin
        @(negedge clock);
        reset = 0;

        // Logos 0 owns 3. Every UP asks Logos 1 for the next unit.
        set_cell(0, 3, DOWN, 1, DONE, 0, DONE, 0);
        // Logos 1 owns 2. DOWN transfers one unit to Logos 0; zero ends.
        set_cell(1, 2, DONE, 0, UP, 0, DONE, 0);
        // Logos 2 and 3 remain free mass.
        set_cell(2, 0, DONE, 0, DONE, 0, DONE, 0);
        set_cell(3, 0, DONE, 0, DONE, 0, DONE, 0);

        @(negedge clock);
        inject = 1;
        inject_at = 1;
        inject_kind = DOWN;
        @(negedge clock);
        inject = 0;

        wait (done);
        probe_at = 0;
        #1;
        if (probe_counter != 5) $fatal(1, "expected Logos 0 = 5, got %0d", probe_counter);
        probe_at = 1;
        #1;
        if (probe_counter != 0) $fatal(1, "expected Logos 1 = 0, got %0d", probe_counter);
        if (collision) $fatal(1, "unexpected fabric collision");
        $display("ok logos0=5 logos1=0 pulses=%0d", pulses);
        $finish;
    end

    initial begin
        repeat (100) @(posedge clock);
        $fatal(1, "Logos timeout");
    end
endmodule
