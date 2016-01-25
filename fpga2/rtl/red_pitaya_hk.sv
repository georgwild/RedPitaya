////////////////////////////////////////////////////////////////////////////////
// Module: housekeeping
// Authors: Matej Oblak, Iztok Jeras <iztok.jeras@redpitaya.com>
// (c) Red Pitaya  (redpitaya.com)
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// GENERAL DESCRIPTION:
//
// House keeping module takes care of system identification.
//
// This module takes care of system identification via DNA readout at startup and
// ID register which user can define at compile time.
////////////////////////////////////////////////////////////////////////////////

module red_pitaya_hk #(
  // ID
  bit [57-1:0] DNA = 57'h0823456789ABCDE
)(
  // system bus
  sys_bus_if.s           bus
);

////////////////////////////////////////////////////////////////////////////////
//  Read device DNA
////////////////////////////////////////////////////////////////////////////////

logic          dna_dout ;
logic          dna_clk  ;
logic          dna_read ;
logic          dna_shift;
logic [ 9-1:0] dna_cnt  ;
logic [57-1:0] dna_value;
logic          dna_done ;

always_ff @(posedge bus.clk)
if (!bus.rstn) begin
  dna_clk   <= '0;
  dna_read  <= '0;
  dna_shift <= '0;
  dna_cnt   <= '0;
  dna_value <= '0;
  dna_done  <= '0;
end else begin
  if (!dna_done)
    dna_cnt <= dna_cnt + 1'd1;

  dna_clk <= dna_cnt[2] ;
  dna_read  <= (dna_cnt < 9'd10);
  dna_shift <= (dna_cnt > 9'd18);

  if ((dna_cnt[2:0]==3'h0) && !dna_done)
    dna_value <= {dna_value[57-2:0], dna_dout};

  if (dna_cnt > 9'd465)
    dna_done <= 1'b1;
end

// parameter specifies a sample 57-bit DNA value for simulation
DNA_PORT #(.SIM_DNA_VALUE (DNA)) i_DNA (
  .DOUT  (dna_dout ), // 1-bit output: DNA output data.
  .CLK   (dna_clk  ), // 1-bit input: Clock input.
  .DIN   (1'b0     ), // 1-bit input: User data input pin.
  .READ  (dna_read ), // 1-bit input: Active high load DNA, active low read input.
  .SHIFT (dna_shift)  // 1-bit input: Active high shift enable input.
);

////////////////////////////////////////////////////////////////////////////////
// Desing identification
////////////////////////////////////////////////////////////////////////////////

logic [32-1:0] id_value;

assign id_value = {28'h0,  // reserved
                    4'h1}; // board type   1 - release 1

////////////////////////////////////////////////////////////////////////////////
//  System bus connection
////////////////////////////////////////////////////////////////////////////////

// bus decoder width
localparam int unsigned BDW = 4;

always_ff @(posedge bus.clk)
if (!bus.rstn)  bus.err <= 1'b1;
else            bus.err <= 1'b0;

logic sys_en;
assign sys_en = bus.wen | bus.ren;

always_ff @(posedge bus.clk)
if (!bus.rstn) begin
  bus.ack <= 1'b0;
end else begin
  bus.ack <= sys_en;
  casez (bus.addr[BDW-1:0])
    // ID
    'h00:  bus.rdata <= {                id_value          };
    'h04:  bus.rdata <= {                dna_value[32-1: 0]};
    'h08:  bus.rdata <= {{64- 57{1'b0}}, dna_value[57-1:32]};
    default: bus.rdata <= '0;
  endcase
end

endmodule: red_pitaya_hk
