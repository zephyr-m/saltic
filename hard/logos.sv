module logos_cell #(
    parameter int ID = 0,
    parameter int COUNTER_BITS = 32,
    parameter int ADDRESS_BITS = 4
) (
    input  logic                    clock,
    input  logic                    reset,
    input  logic                    configure,
    input  logic [COUNTER_BITS-1:0] configure_counter,
    input  logic [1:0]              configure_up_kind,
    input  logic [ADDRESS_BITS-1:0] configure_up_target,
    input  logic [1:0]              configure_down_kind,
    input  logic [ADDRESS_BITS-1:0] configure_down_target,
    input  logic [1:0]              configure_zero_kind,
    input  logic [ADDRESS_BITS-1:0] configure_zero_target,
    input  logic                    inbox_valid,
    input  logic [1:0]              inbox_kind,
    output logic                    outbox_valid,
    output logic [1:0]              outbox_kind,
    output logic [ADDRESS_BITS-1:0] outbox_target,
    output logic [COUNTER_BITS-1:0] counter
);
    localparam logic [1:0] PULSE_UP   = 2'b00;
    localparam logic [1:0] PULSE_DOWN = 2'b01;
    localparam logic [1:0] PULSE_DONE = 2'b10;

    logic [1:0] up_kind;
    logic [ADDRESS_BITS-1:0] up_target;
    logic [1:0] down_kind;
    logic [ADDRESS_BITS-1:0] down_target;
    logic [1:0] zero_kind;
    logic [ADDRESS_BITS-1:0] zero_target;

    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= '0;
            outbox_valid <= 1'b0;
            outbox_kind <= PULSE_DONE;
            outbox_target <= '0;
            up_kind <= PULSE_DONE;
            up_target <= '0;
            down_kind <= PULSE_DONE;
            down_target <= '0;
            zero_kind <= PULSE_DONE;
            zero_target <= '0;
        end else begin
            outbox_valid <= 1'b0;

            if (configure) begin
                counter <= configure_counter;
                up_kind <= configure_up_kind;
                up_target <= configure_up_target;
                down_kind <= configure_down_kind;
                down_target <= configure_down_target;
                zero_kind <= configure_zero_kind;
                zero_target <= configure_zero_target;
            end else if (inbox_valid) begin
                case (inbox_kind)
                    PULSE_UP: begin
                        counter <= counter + 1'b1;
                        outbox_valid <= 1'b1;
                        outbox_kind <= up_kind;
                        outbox_target <= up_target;
                    end

                    PULSE_DOWN: begin
                        outbox_valid <= 1'b1;
                        if (counter == 0) begin
                            outbox_kind <= zero_kind;
                            outbox_target <= zero_target;
                        end else begin
                            counter <= counter - 1'b1;
                            outbox_kind <= down_kind;
                            outbox_target <= down_target;
                        end
                    end

                    default: begin
                        outbox_valid <= 1'b1;
                        outbox_kind <= PULSE_DONE;
                        outbox_target <= ID[ADDRESS_BITS-1:0];
                    end
                endcase
            end
        end
    end
endmodule

module logos_fabric #(
    parameter int CELLS = 4,
    parameter int COUNTER_BITS = 32,
    parameter int ADDRESS_BITS = $clog2(CELLS)
) (
    input  logic                    clock,
    input  logic                    reset,
    input  logic                    configure,
    input  logic [ADDRESS_BITS-1:0] configure_at,
    input  logic [COUNTER_BITS-1:0] configure_counter,
    input  logic [1:0]              configure_up_kind,
    input  logic [ADDRESS_BITS-1:0] configure_up_target,
    input  logic [1:0]              configure_down_kind,
    input  logic [ADDRESS_BITS-1:0] configure_down_target,
    input  logic [1:0]              configure_zero_kind,
    input  logic [ADDRESS_BITS-1:0] configure_zero_target,
    input  logic                    inject,
    input  logic [ADDRESS_BITS-1:0] inject_at,
    input  logic [1:0]              inject_kind,
    input  logic [ADDRESS_BITS-1:0] probe_at,
    output logic [COUNTER_BITS-1:0] probe_counter,
    output logic                    done,
    output logic [31:0]             pulses,
    output logic                    collision
);
    localparam logic [1:0] PULSE_DONE = 2'b10;

    logic [CELLS-1:0] inbox_valid;
    logic [1:0] inbox_kind [0:CELLS-1];
    logic [CELLS-1:0] outbox_valid;
    logic [1:0] outbox_kind [0:CELLS-1];
    logic [ADDRESS_BITS-1:0] outbox_target [0:CELLS-1];
    logic [COUNTER_BITS-1:0] counters [0:CELLS-1];
    integer route_source;
    integer route_target;
    integer pulse_source;

    generate
        genvar slot;
        for (slot = 0; slot < CELLS; slot = slot + 1) begin : cells
            logos_cell #(
                .ID(slot),
                .COUNTER_BITS(COUNTER_BITS),
                .ADDRESS_BITS(ADDRESS_BITS)
            ) logos (
                .clock,
                .reset,
                .configure(configure && configure_at == slot),
                .configure_counter,
                .configure_up_kind,
                .configure_up_target,
                .configure_down_kind,
                .configure_down_target,
                .configure_zero_kind,
                .configure_zero_target,
                .inbox_valid(inbox_valid[slot]),
                .inbox_kind(inbox_kind[slot]),
                .outbox_valid(outbox_valid[slot]),
                .outbox_kind(outbox_kind[slot]),
                .outbox_target(outbox_target[slot]),
                .counter(counters[slot])
            );
        end
    endgenerate

    always_comb begin
        inbox_valid = '0;
        collision = 1'b0;
        for (route_target = 0; route_target < CELLS; route_target = route_target + 1) begin
            inbox_kind[route_target] = 2'b00;
        end

        if (inject) begin
            inbox_valid[inject_at] = 1'b1;
            inbox_kind[inject_at] = inject_kind;
        end

        for (route_source = 0; route_source < CELLS; route_source = route_source + 1) begin
            if (outbox_valid[route_source] && outbox_kind[route_source] != PULSE_DONE) begin
                if (inbox_valid[outbox_target[route_source]]) begin
                    collision = 1'b1;
                end else begin
                    inbox_valid[outbox_target[route_source]] = 1'b1;
                    inbox_kind[outbox_target[route_source]] = outbox_kind[route_source];
                end
            end
        end
    end

    assign probe_counter = counters[probe_at];

    always_ff @(posedge clock) begin
        if (reset) begin
            done <= 1'b0;
            pulses <= 0;
        end else begin
            if (inject) pulses <= pulses + 1'b1;
            for (pulse_source = 0; pulse_source < CELLS; pulse_source = pulse_source + 1) begin
                if (outbox_valid[pulse_source]) begin
                    pulses <= pulses + 1'b1;
                    if (outbox_kind[pulse_source] == PULSE_DONE) done <= 1'b1;
                end
            end
        end
    end
endmodule
