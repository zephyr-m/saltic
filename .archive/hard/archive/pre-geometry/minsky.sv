module saltic_minsky #(
    parameter int CODE_SIZE = 256,
    parameter int COUNTER_BITS = 32,
    parameter int COUNTER_COUNT = 2
) (
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  load,
    input  logic [7:0]            load_at,
    input  logic [31:0]           load_word,
    output logic                  done,
    output logic [31:0]           cycles,
    output logic [COUNTER_BITS-1:0] counter_0,
    output logic [COUNTER_BITS-1:0] counter_1
);
    localparam logic OP_UP   = 1'b0;
    localparam logic OP_DOWN = 1'b1;
    localparam logic [7:0] STOP = 8'hff;

    // up:   [31]=0 [24]=counter [23:16]=next
    // down: [31]=1 [24]=counter [23:16]=next [15:8]=zero
    logic [31:0] code [0:CODE_SIZE-1];
    logic [COUNTER_BITS-1:0] counters [0:COUNTER_COUNT-1];
    logic [7:0] pc;
    logic [31:0] instruction;
    logic op;
    logic counter;
    logic [7:0] next_pc;
    logic [7:0] zero_pc;
    integer index;

    assign instruction = code[pc];
    assign op = instruction[31];
    assign counter = instruction[24];
    assign next_pc = instruction[23:16];
    assign zero_pc = instruction[15:8];
    assign counter_0 = counters[0];
    assign counter_1 = counters[1];

    always_ff @(posedge clock) begin
        if (load) begin
            code[load_at] <= load_word;
        end

        if (reset) begin
            pc <= 0;
            done <= 0;
            cycles <= 0;
            for (index = 0; index < COUNTER_COUNT; index = index + 1) begin
                counters[index] <= 0;
            end
        end else if (!done && !load) begin
            if (pc == STOP) begin
                done <= 1;
            end else begin
                cycles <= cycles + 1;

                if (op == OP_UP) begin
                    counters[counter] <= counters[counter] + 1'b1;
                    pc <= next_pc;
                end else begin
                    if (counters[counter] == 0) begin
                        pc <= zero_pc;
                    end else begin
                        counters[counter] <= counters[counter] - 1'b1;
                        pc <= next_pc;
                    end
                end
            end
        end
    end
endmodule
