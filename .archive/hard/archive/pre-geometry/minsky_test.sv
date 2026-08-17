module minsky_test;
    logic clock = 0;
    logic reset = 1;
    logic load = 0;
    logic [7:0] load_at = 0;
    logic [31:0] load_word = 0;
    logic done;
    logic [31:0] cycles;
    logic [31:0] counter_0;
    logic [31:0] counter_1;

    saltic_minsky cpu (.*);

    always #5 clock = ~clock;

    function automatic [31:0] up(input [6:0] counter, input [7:0] next_pc);
        up = {1'b0, counter, next_pc, 16'b0};
    endfunction

    function automatic [31:0] down(
        input [6:0] counter,
        input [7:0] next_pc,
        input [7:0] zero_pc
    );
        down = {1'b1, counter, next_pc, zero_pc, 8'b0};
    endfunction

    task write(input [7:0] at, input [31:0] word);
        @(negedge clock);
        load = 1;
        load_at = at;
        load_word = word;
        @(negedge clock);
        load = 0;
    endtask

    initial begin
        // Build 3 in c0, build 2 in c1, then move c1 into c0.
        write(0, up(0, 1));
        write(1, up(0, 2));
        write(2, up(0, 3));
        write(3, up(1, 4));
        write(4, up(1, 5));
        write(5, down(1, 6, 8'hff));
        write(6, up(0, 5));

        @(negedge clock);
        reset = 0;

        wait (done);
        if (counter_0 != 5) $fatal(1, "expected c0=5, got %0d", counter_0);
        if (counter_1 != 0) $fatal(1, "expected c1=0, got %0d", counter_1);
        $display("ok c0=%0d c1=%0d cycles=%0d", counter_0, counter_1, cycles);
        $finish;
    end

    initial begin
        repeat (100) @(posedge clock);
        $fatal(1, "minsky timeout");
    end
endmodule
