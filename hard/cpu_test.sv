module cpu_test;
    logic clock = 0;
    logic reset = 1;
    logic load = 0;
    logic [7:0] load_at = 0;
    logic [15:0] load_word = 0;
    logic show;
    logic [31:0] value;
    logic done;
    logic [31:0] cycles;

    saltic_cpu cpu (.*);

    always #5 clock = ~clock;

    task write(input logic [7:0] at, input logic [7:0] op, input logic [7:0] arg);
        @(negedge clock);
        load = 1;
        load_at = at;
        load_word = {op, arg};
        @(negedge clock);
        load = 0;
    endtask

    initial begin
        // Saltic idea: show((7 + 5) * 3) => 36
        write(0, 8'h01, 7);
        write(1, 8'h01, 5);
        write(2, 8'h02, 0);
        write(3, 8'h01, 3);
        write(4, 8'h04, 0);
        write(5, 8'h0b, 0);
        write(6, 8'hff, 0);

        @(negedge clock);
        reset = 0;

        wait (show);
        if (value != 36) $fatal(1, "expected 36, got %0d", value);
        wait (done);
        $display("ok value=%0d cycles=%0d", value, cycles);
        $finish;
    end

    initial begin
        repeat (100) @(posedge clock);
        $fatal(1, "cpu timeout");
    end
endmodule
