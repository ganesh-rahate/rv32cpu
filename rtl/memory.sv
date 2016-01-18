/*  
 * Copyright (c) 2015, C. Brett Witherspoon
 */

/**
 * Module: reg2mem
 *
 * A private module for register to memory alignment.
 */
module reg2mem
    import core::op_t;
    import core::word_t;
    import core::strb_t;
(
    input  op_t   op,
    input  word_t addr,
    input  word_t din,
    output word_t dout,
    output strb_t strb
);
    always_comb
        unique case (op)
            core::STORE_WORD: begin
                dout = din;
                strb = '1;
            end
            core::STORE_HALF: begin
                if (addr[1]) begin
                    dout = din << 16;
                    strb = 4'b1100;
                end else begin
                    dout = din;
                    strb = 4'b0011;
                end
            end
            core::STORE_BYTE:
                unique case (addr[1:0])
                    2'b00: begin
                        dout = din;
                        strb = 4'b0001;
                    end
                    2'b01: begin
                        dout = din << 8;
                        strb = 4'b0010;
                    end
                    2'b10: begin
                        dout = din << 16;
                        strb = 4'b0100;
                    end
                    2'b11: begin
                        dout = din << 24;
                        strb = 4'b1000;
                    end
                endcase
            default: begin
                dout = 'x;
                strb = '0;
            end
        endcase
endmodule : reg2mem

/**
 * Module: mem2reg
 *
 * A private module for memory to register alignment.
 */
module mem2reg
    import core::op_t;
    import core::word_t;
(
    input  op_t        op,
    input  logic [1:0] addr,
    input  word_t      din,
    output word_t      dout
);
    always_comb
        unique case (op)
            core::LOAD_WORD:
                dout = din;
            core::LOAD_HALF:
                if (addr[1]) dout = {{16{din[31]}}, din[31:16]};
                else         dout = {{16{din[15]}}, din[15:0]};
            core::LOAD_BYTE:
                unique case (addr)
                    2'b00: dout = {{24{din[7]}},  din[7:0]};
                    2'b01: dout = {{24{din[15]}}, din[15:8]};
                    2'b10: dout = {{24{din[23]}}, din[23:16]};
                    2'b11: dout = {{24{din[31]}}, din[31:24]};
                endcase
            core::LOAD_HALF_UNSIGNED:
                if (addr[1]) dout = {16'h0000, din[31:16]};
                else         dout = {16'h0000, din[15:0]};
            core::LOAD_BYTE_UNSIGNED:
                unique case (addr)
                    2'b00: dout = {24'h000000, din[7:0]};
                    2'b01: dout = {24'h000000, din[15:8]};
                    2'b10: dout = {24'h000000, din[23:16]};
                    2'b11: dout = {24'h000000, din[31:24]};
                endcase
            default:
                dout = 'x;
        endcase
endmodule : mem2reg

/**
 * Module: memory
 *
 * A memory unit. Data MUST be naturally aligned.
 */
module memory
    import core::op_t;
    import core::mm_t;
    import core::strb_t;
    import core::wb_t;
    import core::word_t;
#(
    BASE = 32'h00000000,
    SIZE = 32'h00001000
)(
    output word_t bypass,
    axi.master    cache,
    axis.slave    slave,
    axis.master   master
);
    typedef enum logic [1:0] { IDLE, ADDR, DATA, RESP } state_t;

    state_t wstate = IDLE;
    state_t wnext;

    state_t rstate = IDLE;
    state_t rnext;

    wire wstart = wstate == IDLE && wnext == ADDR;
    wire wstop  = wstate == RESP && wnext == IDLE;
    wire rstart = rstate == IDLE && rnext == ADDR;
    wire rstop  = rstate == RESP && rnext == IDLE;

    mm_t mm;
    assign mm = slave.tdata;

    wb_t wb;
    assign master.tdata = wb;

    assign slave.tready = master.tready & wstate == IDLE && rstate == IDLE;

    //wire self = mm.alu >= BASE && mm.alu < BASE + SIZE;

    wire write = core::is_store(mm.ctrl.op) & slave.tvalid;

    wire read = core::is_load(mm.ctrl.op) & slave.tvalid;

///////////////////////////////////////////////////////////////////////////////

    /*
     * Cache write
     *
     * NOTE: Vivado 2015.4 synthesis grounds wdata and wstrb when initialized
     *       to zero in declaration like wire.
     */

    logic awvalid;
    logic wvalid;
    logic bready;
    word_t wdata;
    strb_t wstrb;

    reg2mem reg2mem (
        .op(mm.ctrl.op),
        .addr(mm.data.alu),
        .din(mm.data.rs2),
        .strb(wstrb),
        .dout(wdata)
    );

    assign cache.awprot = axi4::AXI4;

    // FIXME reduce logic
    always_comb
        unique case (wstate)
            IDLE: begin
                if (write) wnext = ADDR;
                else       wnext = IDLE;
                awvalid = write;
                wvalid  = write;
                bready  = write;
            end
            ADDR: begin
                if (cache.awready & cache.wready & cache.bvalid) begin
                    wnext   = IDLE;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b0;
                end else if (cache.awready & cache.wready) begin
                    wnext   = RESP;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b1;
                end else if (cache.awready) begin
                    wnext   = DATA;
                    awvalid = 1'b0;
                    wvalid  = 1'b1;
                    bready  = 1'b1;
                end else begin
                    wnext   = ADDR;
                    awvalid = 1'b1;
                    wvalid  = 1'b1;
                    bready  = 1'b1;
                end
            end
            DATA: begin
                if (cache.wready & cache.bvalid) begin
                    wnext   = IDLE;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b0;
                end else if (cache.wready) begin
                    wnext   = RESP;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b1;
                end else begin
                    wnext   = DATA;
                    awvalid = 1'b0;
                    wvalid  = 1'b1;
                    bready  = 1'b1;
                end
            end
            RESP: begin
                if (cache.bvalid) begin
                    wnext   = IDLE;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b0;
                end else begin
                    wnext   = RESP;
                    awvalid = 1'b0;
                    wvalid  = 1'b0;
                    bready  = 1'b1;
                end
            end
        endcase

    always_ff @(posedge cache.aclk)
        if (~cache.aresetn) begin
            wstate <= IDLE;
            cache.awvalid <= '0;
            cache.wvalid <= '0;
            cache.bready <= '0;
        end else begin
            wstate <= wnext;
            cache.awvalid <= awvalid;
            cache.wvalid <= wvalid;
            cache.bready <= bready;
            if (wstart) begin
                cache.awaddr <= mm.data.alu & (BASE-1);
                cache.wdata <= wdata;
                cache.wstrb <= wstrb;
            end
        end

///////////////////////////////////////////////////////////////////////////////

    /*
     * Cache read
     */

    logic arvalid;
    logic rready;

    assign cache.arprot = axi4::AXI4;

    // FIXME reduce logic
    always_comb
        unique case (rstate)
            IDLE: begin
                if (read) rnext = ADDR;
                else      rnext = IDLE;
                arvalid = read;
                rready  = read;
            end
            ADDR: begin
                if (cache.arready & cache.rvalid) begin
                    rnext   = IDLE;
                    arvalid = 1'b0;
                    rready  = 1'b0;
                end else if (cache.arready) begin
                    rnext   = RESP;
                    arvalid = 1'b0;
                    rready  = 1'b1;
                end else begin
                    rnext   = ADDR;
                    arvalid = 1'b1;
                    rready  = 1'b1;
                end
            end
            RESP: begin
                if (cache.rvalid) begin
                    rnext   = IDLE;
                    arvalid = 1'b0;
                    rready  = 1'b0;
                end else begin
                    rnext   = RESP;
                    arvalid = 1'b0;
                    rready  = 1'b1;
                end
            end
        endcase

    always_ff @(posedge cache.aclk)
        if (~cache.aresetn) begin
            rstate <= IDLE;
            cache.arvalid <= '0;
            cache.rready <= '0;
        end else begin
            rstate <= rnext;
            cache.arvalid <= arvalid;
            cache.rready <= rready;
            if (rstart) begin
                cache.araddr <= mm.data.alu & (BASE-1);
            end
        end

    op_t rop = core::NULL;
    logic [1:0] raddr = '0;

    always_ff @(posedge cache.aclk)
        if (rstart) begin
            rop <= mm.ctrl.op;
            raddr <= mm.data.alu[1:0];
        end

    word_t aligned;
    word_t delayed;

    mem2reg mem2reg (
        .op(rop),
        .addr(raddr),
        .din(cache.rdata),
        .dout(bypass)
    );

    always_ff @(posedge cache.aclk)
        if (rstop) aligned <= bypass;

///////////////////////////////////////////////////////////////////////////////

    /*
     * Streams
     */

     // FIXME not valid AXI
     assign wb.data.rd.data = core::is_load(rop) ? aligned : delayed; 

endmodule : memory
