module saltic_cpu #(
    parameter int WORD_BITS = 32,
    parameter int CODE_SIZE = 256,
    parameter int STACK_SIZE = 64
) (
    input  logic                 clock,
    input  logic                 reset,
    input  logic                 load,
    input  logic [$clog2(CODE_SIZE)-1:0] load_at,
    input  logic [15:0]          load_word,
    output logic                 show,
    output logic [WORD_BITS-1:0] value,
    output logic                 done,
    output logic [31:0]          cycles
);
    localparam logic [7:0] OP_NOP  = 8'h00;
    localparam logic [7:0] OP_PUSH = 8'h01;
    localparam logic [7:0] OP_ADD  = 8'h02;
    localparam logic [7:0] OP_SUB  = 8'h03;
    localparam logic [7:0] OP_MUL  = 8'h04;
    localparam logic [7:0] OP_EQ   = 8'h05;
    localparam logic [7:0] OP_LT   = 8'h06;
    localparam logic [7:0] OP_JUMP = 8'h07;
    localparam logic [7:0] OP_JZ   = 8'h08;
    localparam logic [7:0] OP_DUP  = 8'h09;
    localparam logic [7:0] OP_DROP = 8'h0a;
    localparam logic [7:0] OP_SHOW = 8'h0b;
    localparam logic [7:0] OP_HALT = 8'hff;

    logic [15:0] code [0:CODE_SIZE-1];
    logic [WORD_BITS-1:0] stack [0:STACK_SIZE-1];
    logic [$clog2(CODE_SIZE)-1:0] pc;
    logic [$clog2(STACK_SIZE)-1:0] depth;
    logic [15:0] instruction;
    logic [7:0] op;
    logic [7:0] arg;

    assign instruction = code[pc];
    assign op = instruction[15:8];
    assign arg = instruction[7:0];

    always_ff @(posedge clock) begin
        if (load) begin
            code[load_at] <= load_word;
        end

        if (reset) begin
            pc <= '0;
            depth <= '0;
            show <= 1'b0;
            value <= '0;
            done <= 1'b0;
            cycles <= '0;
        end else if (!done && !load) begin
            show <= 1'b0;
            cycles <= cycles + 1'b1;

            case (op)
                OP_NOP: pc <= pc + 1'b1;

                OP_PUSH: begin
                    stack[depth] <= {{(WORD_BITS-8){arg[7]}}, arg};
                    depth <= depth + 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_ADD: begin
                    stack[depth-2] <= stack[depth-2] + stack[depth-1];
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_SUB: begin
                    stack[depth-2] <= stack[depth-2] - stack[depth-1];
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_MUL: begin
                    stack[depth-2] <= stack[depth-2] * stack[depth-1];
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_EQ: begin
                    stack[depth-2] <= {{(WORD_BITS-1){1'b0}}, stack[depth-2] == stack[depth-1]};
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_LT: begin
                    stack[depth-2] <= {{(WORD_BITS-1){1'b0}}, $signed(stack[depth-2]) < $signed(stack[depth-1])};
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_JUMP: pc <= arg;

                OP_JZ: begin
                    depth <= depth - 1'b1;
                    pc <= stack[depth-1] == '0 ? arg : pc + 1'b1;
                end

                OP_DUP: begin
                    stack[depth] <= stack[depth-1];
                    depth <= depth + 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_DROP: begin
                    depth <= depth - 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_SHOW: begin
                    value <= stack[depth-1];
                    depth <= depth - 1'b1;
                    show <= 1'b1;
                    pc <= pc + 1'b1;
                end

                OP_HALT: done <= 1'b1;
                default: done <= 1'b1;
            endcase
        end
    end
endmodule
