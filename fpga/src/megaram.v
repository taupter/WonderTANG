module megaramSCC(
    input clk,
    input reset_n,
    input [15:0] addr,
    input [7:0] cdin,
    output [7:0] cdout,
    output busreq,
    input merq_n,
    input merq_scc_n,
    input enable,
    input sltsl_n,
    input iorq_n,
    input m1_n,
    input rd_n,
    input wr_n,
    output ram_ena,
    output cart_ena,
    output [22:0] mem_addr,
    output [14:0] scc_wave, 
    input scc_enable,
    input [1:0] megaram_type,
    input scc_addr
);

reg [7:0] ff_memreg[0:3];
reg ff_ram_ena;
reg ff_scc_ram;

integer i;

wire [1:0] switch_bank_w;

assign switch_bank_w = megaram_type == 2'b11 ? {~addr[12], addr[11]} :
                        megaram_type == 2'b10 ? {addr[12], ~addr[12]} : { addr[14], addr[13]};
                        
wire [1:0] page_select_w;
assign page_select_w =  megaram_type == 2'b10 ? {addr[15], addr[14]} : {addr[14], addr[13]};
assign bank_switch_enable_w = (~scc_addr || addr[12:11] == 2'b10) ? '1 : '0;
assign scc_bank_enable_w = (addr[15:0] == 16'h9000) ? '1 : '0;
assign megaram_port_ena_w = (addr[7:0] == 8'h8E && ~iorq_n && m1_n) ? '1 : '0;

always @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
        for (i=0; i<=3; i=i+1)
            ff_memreg[i] <= 3-i;
        ff_ram_ena <= 1'b0;
        ff_scc_ram <= 1'b0;
    end else begin
        if (enable) begin
            if (megaram_port_ena_w) begin
                if (wr_n == 0) begin
                    ff_ram_ena <= 1'b0; // enable rom mode, page selection
                end
                if (rd_n == 0) begin
                    ff_ram_ena <= 1'b1; // enable ram mode, disable page selection
                end
            end
            if (~ff_ram_ena && cart_ena) begin 
                if (~wr_n) begin

                    if (bank_switch_enable_w)
                        ff_memreg[ switch_bank_w ] <= cdin;

                    if (scc_bank_enable_w) begin
                        ff_scc_ram <= (cdin[5:0] == 6'h3F) ? scc_enable : 0;
                    end
                end
            end
        end
    end
end

wire scc_req_w;
wire wavemem_w;

megaram(
    .clk21m(enable),
    .reset(~reset_n),
    .clkena(1),
    .req(scc_req_w),
    //.ack(),
    .wrt(~wr_n),
    .adr(addr),
    .dbi(cdout),
    .dbo(cdin),
    //.ramreq(),
    //.ramwrt(),
    //.ramadr(),
    .ramdbi(8'h00),
    //.ramdbo(),
    .mapsel(2'b00), // SCC+ "-0":SCC+, "01":ASC8K, "11":ASC16K
    .wavl(scc_wave),
    .wavemem(wavemem_w)
    //.wavr()
);


assign ram_ena = ff_ram_ena;

wire [7:0] page_w;
assign page_w = ff_memreg[ page_select_w ];                            // Konami/KonamiSCC

wire [22:0] page_addr_w;
assign page_addr_w = (megaram_type == 2'b10) ? { 2'b0, page_w[6:0], addr[13:0] } :
                                               { 2'b0, page_w, addr[12:0] };
assign mem_addr = 23'h420000 + page_addr_w;

assign cart_ena = (addr[15:14] == 2'b01 || addr[15:14] == 2'b10) && ~sltsl_n && ~merq_n && iorq_n ? 1 : 0;

assign busreq    = ~sltsl_n && ~merq_scc_n && iorq_n && addr[15:11] == 5'b10011 && ~rd_n ? (scc_enable && ff_scc_ram) : 0;
assign scc_req_w = ~sltsl_n && ~merq_scc_n && iorq_n ? scc_enable : 0;

endmodule
