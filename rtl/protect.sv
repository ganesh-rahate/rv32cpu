/*
 * Copyright (c) 2016 C. Brett Witherspoon
 */

/**
 * Module: protect
 *
 * Memory protection and multiplexing.
 */
module protect (
    axi.slave  cache,
    axi.master code,
    axi.master data,
    axi.master mmio
);

    typedef enum logic [1:0] { NONE, CODE, DATA, MMIO } request_t;

    request_t read;
    request_t write;

    // Write state
    wire wcode = cache.awaddr >= core::CODE_BASE && cache.awaddr < core::CODE_BASE + core::CODE_SIZE;
    wire wdata = cache.awaddr >= core::DATA_BASE && cache.awaddr < core::DATA_BASE + core::DATA_SIZE;
    wire wmmio = cache.awaddr >= core::MMIO_BASE;

    always_comb
        if (wcode)      write = CODE;
        else if (wdata) write = DATA;
        else if (wmmio) write = MMIO;
        else            write = NONE;

    // Read state
    wire rcode = cache.araddr >= core::CODE_BASE && cache.araddr < core::CODE_BASE + core::CODE_SIZE;
    wire rdata = cache.araddr >= core::DATA_BASE && cache.araddr < core::DATA_BASE + core::DATA_SIZE;
    wire rmmio = cache.araddr >= core::MMIO_BASE;

    always_comb
        if (rcode)      read = CODE;
        else if (rdata) read = DATA;
        else if (rmmio) read = MMIO;
        else            read = NONE;


    // Write address channel
    assign code.awaddr   = cache.awaddr & (core::CODE_BASE-1);
    assign code.awprot   = cache.awprot;
    assign code.awvalid  = (write == CODE) ? cache.awvalid : '0;

    assign data.awaddr   = cache.awaddr & (core::DATA_BASE-1);
    assign data.awprot   = cache.awprot;
    assign data.awvalid  = (write == DATA) ? cache.awvalid : '0;

    assign mmio.awaddr   = cache.awaddr & (core::MMIO_BASE-1);
    assign mmio.awprot   = cache.awprot;
    assign mmio.awvalid  = (write == MMIO) ? cache.awvalid : '0;

    always_comb begin : awready
        unique case (write)
            CODE:    cache.awready = code.awready;
            DATA:    cache.awready = data.awready;
            MMIO:    cache.awready = mmio.awready;
            default: cache.awready = '0;
        endcase
    end : awready

    // Write data channel
    assign code.wdata  = cache.wdata;
    assign code.wstrb  = cache.wstrb;
    assign code.wvalid = (write == CODE) ? cache.wvalid : '0;

    assign data.wdata  = cache.wdata;
    assign data.wstrb  = cache.wstrb;
    assign data.wvalid = (write == DATA) ? cache.wvalid : '0;

    assign mmio.wdata  = cache.wdata;
    assign mmio.wstrb  = cache.wstrb;
    assign mmio.wvalid = (write == MMIO) ? cache.wvalid : '0;

    always_comb begin : wready
        unique case (write)
            CODE:    cache.wready = code.wready;
            DATA:    cache.wready = data.wready;
            MMIO:    cache.wready = mmio.wready;
            default: cache.wready = '0;
        endcase
    end : wready

    // Write response channel
    always_comb begin : bresp
        unique case (write)
            CODE:    cache.bresp = code.bresp;
            DATA:    cache.bresp = data.bresp;
            MMIO:    cache.bresp = mmio.bresp;
            default: cache.bresp = axi4::DECERR;
        endcase
    end : bresp

    always_comb begin : bvalid
        unique case (write)
            CODE:    cache.bvalid = code.bvalid;
            DATA:    cache.bvalid = data.bvalid;
            MMIO:    cache.bvalid = mmio.bvalid;
            default: cache.bvalid = '0;
        endcase
    end : bvalid

    assign code.bready  = (write == CODE) ? cache.bready : '0;
    assign data.bready  = (write == DATA) ? cache.bready : '0;
    assign mmio.bready  = (write == MMIO) ? cache.bready : '0;

    // Address read channel
    assign data.araddr  = cache.araddr & (core::DATA_BASE-1);
    assign data.arprot  = cache.arprot;
    assign data.araddr  = cache.araddr;
    assign data.arvalid = (read == DATA) ? cache.arvalid : '0;

    assign mmio.araddr  = cache.araddr & (core::MMIO_BASE-1);
    assign mmio.arprot  = cache.arprot;
    assign mmio.araddr  = cache.araddr;
    assign mmio.arvalid = (read == MMIO) ? cache.arvalid : '0;

    always_comb begin : arready
        unique case (read)
            DATA:    cache.arready = data.arready;
            MMIO:    cache.arready = mmio.arready;
            default: cache.arready = '0;
        endcase
    end : arready

    assign cache.rdata   = data.rdata;
    assign cache.rresp   = data.rresp;

    always_comb begin : rvalid
        unique case (read)
            DATA:    cache.rvalid = data.rvalid;
            MMIO:    cache.rvalid = mmio.rvalid;
            default: cache.rvalid = '0;
        endcase
    end : rvalid

    assign data.rready = (read == DATA) ? cache.rready : '0;
    assign mmio.rready = (read == MMIO) ? cache.rready : '0;

endmodule : protect