`timescale  1ns/1ns

module axi_ddr_top #
(
parameter  P0_DDR_WR_LEN=128,//写突发长度 128个64bit
parameter  P0_DDR_RD_LEN=128,//读突发长度 128个64bit
parameter  P1_DDR_WR_LEN=128,//写突发长度 128个64bit
parameter  P1_DDR_RD_LEN=128 //读突发长度 128个64bit
)

(
    //50m的时钟与复位信号
    input wire ddr3_clk ,
    input wire sys_rst_n,
    
    inout  [31:0] ddr3_dq   ,
    inout  [3:0]  ddr3_dqs_n,
    inout  [3:0]  ddr3_dqs_p,
    output [14:0] ddr3_addr ,
    output [2:0]  ddr3_ba   ,
    output        ddr3_ras_n,
    output        ddr3_cas_n,
    output        ddr3_we_n ,
    output        ddr3_reset_n,
    output [0:0]  ddr3_ck_p ,
    output [0:0]  ddr3_ck_n ,
    output [0:0]  ddr3_cke  ,
    output [0:0]  ddr3_cs_n ,
    output [3:0]  ddr3_dm   ,
    output [0:0]  ddr3_odt  ,
    
    input   wire      p0_pingpang   , //乒乓操作，1使能，0不使能
    
    input   wire[31:0]p0_wr_b_addr  , //写DDR首地址
    input   wire[31:0]p0_wr_e_addr  , //写DDR末地址
    input   wire      p0_user_wr_clk, //写FIFO写时钟
    input   wire      p0_data_wren  , //写FIFO写请求
//写进fifo数据长度，可根据写fifo的写端口数据长度自行修改
//写FIFO写数据 16位，此时用64位是为了兼容32,64位
    input   wire[63:0]p0_data_wr    , //写数据 低16有效    
    input   wire      p0_wr_rst     , //写地址复位
     
    input   wire[31:0]p0_rd_b_addr  , //读DDR首地址
    input   wire[31:0]p0_rd_e_addr  , //读DDR末地址    
    input   wire      p0_user_rd_clk, //读FIFO读时钟
    input   wire      p0_data_rden  , //读FIFO读请求  
//读出fifo数据长度，可根据读fifo的读端口数据长度自行修改
//读FIFO读数据,16位，此时用64位是为了兼容32,64位
    output  wire[63:0]p0_data_rd    , //读数据 低16有效 
    output  wire      p0_rd_valid   ,    
    input   wire      p0_rd_rst     , //读地址复位
    input   wire      p0_read_enable, //读使能
    
    
    input   wire      p1_pingpang   , //乒乓操作，1使能，0不使能
    
    input   wire[31:0]p1_wr_b_addr  , //写DDR首地址
    input   wire[31:0]p1_wr_e_addr  , //写DDR末地址
    input   wire      p1_user_wr_clk, //写FIFO写时钟
    input   wire      p1_data_wren  , //写FIFO写请求
//写进fifo数据长度，可根据写fifo的写端口数据长度自行修改
//写FIFO写数据 16位，此时用64位是为了兼容32,64位
    input   wire[63:0]p1_data_wr    , //写数据 低16有效    
    input   wire      p1_wr_rst     , //写地址复位
     
    input   wire[31:0]p1_rd_b_addr  , //读DDR首地址
    input   wire[31:0]p1_rd_e_addr  , //读DDR末地址    
    input   wire      p1_user_rd_clk, //读FIFO读时钟
    input   wire      p1_data_rden  , //读FIFO读请求  
//读出fifo数据长度，可根据读fifo的读端口数据长度自行修改
//读FIFO读数据,16位，此时用64位是为了兼容32,64位
    output  wire[63:0]p1_data_rd    , //读数据 低16有效
    output  wire      p1_rd_valid   ,    
    input   wire      p1_rd_rst     , //读地址复位
    input   wire      p1_read_enable, //读使能
    
    output  wire      ui_clk       , //输出时钟125m
    output  wire      ui_rst       , //输出复位，高有效
    output  wire      calib_done     //ddr初始化完成
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

//wire  define
 //axi写通道写地址
wire [3:0] M_AXI_WR_awid;   //写地址ID，用来标志一组写信号
wire [31:0]M_AXI_WR_awaddr; //写地址，给出一次写突发传输的写地址
wire [7:0] M_AXI_WR_awlen;  //突发长度，给出突发传输的次数
wire [2:0] M_AXI_WR_awsize; //突发大小，给出每次突发传输的字节数
wire [1:0] M_AXI_WR_awburst;//突发类型
wire [0:0] M_AXI_WR_awlock; //总线锁信号，可提供操作的原子性
wire [3:0] M_AXI_WR_awcache;//内存类型，表明一次传输是怎样通过系统的
wire [2:0] M_AXI_WR_awprot; //保护类型，表明一次传输的特权级及安全等级
wire [3:0] M_AXI_WR_awqos;  //质量服务QoS
wire       M_AXI_WR_awvalid;//有效信号，表明此通道的地址控制信号有效
wire       M_AXI_WR_awready;//表明“从”可以接收地址和对应的控制信号                           
//axi写通道读数据           
wire [63:0]M_AXI_WR_wdata;  //写数据
wire [7:0] M_AXI_WR_wstrb;  //写数据有效的字节线
                            //用来表明哪8bits数据是有效的
wire       M_AXI_WR_wlast;  //表明此次传输是最后一个突发传输
wire       M_AXI_WR_wvalid; //写有效，表明此次写有效
wire       M_AXI_WR_wready; //表明从机可以接收写数据                                                       
//axi写通道读应答           
wire [3:0] M_AXI_WR_bid;    //写响应ID TAG
wire [1:0] M_AXI_WR_bresp;  //写响应，表明写传输的状态
wire       M_AXI_WR_bvalid; //写响应有效
wire       M_AXI_WR_bready; //表明主机能够接收写响应                            
 //axi读通道写地址          
wire [3:0] M_AXI_RD_arid;   //读地址ID，用来标志一组写信号
wire [31:0]M_AXI_RD_araddr; //读地址，给出一次写突发传输的读地址
wire [7:0] M_AXI_RD_arlen;  //突发长度，给出突发传输的次数
wire [2:0] M_AXI_RD_arsize; //突发大小，给出每次突发传输的字节数
wire [1:0] M_AXI_RD_arburst;//突发类型
wire [1:0] M_AXI_RD_arlock; //总线锁信号，可提供操作的原子性
wire [3:0] M_AXI_RD_arcache;//内存类型，表明一次传输是怎样通过系统的
wire [2:0] M_AXI_RD_arprot; //保护类型，表明一次传输的特权级及安全等级
wire [3:0] M_AXI_RD_arqos;  //质量服务QOS
wire       M_AXI_RD_arvalid;//有效信号，表明此通道的地址控制信号有效
wire       M_AXI_RD_arready;//表明“从”可以接收地址和对应的控制信号
//axi读通道读数据
wire [3:0] M_AXI_RD_rid;    //读ID tag
wire [63:0]M_AXI_RD_rdata;  //读数据
wire [1:0] M_AXI_RD_rresp;  //读响应，表明读传输的状态
wire       M_AXI_RD_rlast;  //表明读突发的最后一次传输
wire       M_AXI_RD_rvalid; //表明此通道信号有效
wire       M_AXI_RD_rready; //表明主机能够接收读数据和响应信息

//axi主机用户写控制信号
wire        wr_burst_req   ;
wire [31:0] wr_burst_addr  ;
wire [9:0]  wr_burst_len   ; 
wire        wr_ready       ;
//axi写数据与使能fifo接口
wire        wr_fifo_re     ;
wire [63:0] wr_fifo_data   ;
wire        wr_burst_finish;
//axi主机用户读控制信号
wire        rd_burst_req   ;
wire [31:0] rd_burst_addr  ;
wire [9:0]  rd_burst_len   ; 
wire        rd_ready       ;
//axi读数据与使能fifo接口
wire        rd_fifo_we     ;
wire [63:0] rd_fifo_data   ;
wire        rd_burst_finish;

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- axi_ctrl_inst -------------
axi_ctrl
#(
.P0_DDR_WR_LEN(P0_DDR_WR_LEN),//写突发长度 128个64bit
.P0_DDR_RD_LEN(P0_DDR_RD_LEN),//读突发长度 128个64bit
.P1_DDR_WR_LEN(P1_DDR_WR_LEN),//写突发长度 128个64bit
.P1_DDR_RD_LEN(P1_DDR_RD_LEN) //读突发长度 128个64bit

)
axi_ctrl_inst
(
  .ui_clk     (ui_clk     ),
  .ui_rst     (ui_rst     ),
  
  .p0_pingpang   (p0_pingpang   ),//乒乓操作              
  .p0_wr_b_addr  (p0_wr_b_addr  ), //写DDR首地址
  .p0_wr_e_addr  (p0_wr_e_addr  ), //写DDR末地址
  .p0_user_wr_clk(p0_user_wr_clk), //写FIFO写时钟
  .p0_data_wren  (p0_data_wren  ), //写FIFO写请求            
  .p0_data_wr    (p0_data_wr    ), //写FIFO写数据 16位
                             //此时用64位是为了兼容32,64位
  .p0_wr_rst     (p0_wr_rst     ), //写地址复位                             
  .p0_rd_b_addr  (p0_rd_b_addr  ), //读DDR首地址
  .p0_rd_e_addr  (p0_rd_e_addr  ), //读DDR末地址    
  .p0_user_rd_clk(p0_user_rd_clk), //读FIFO读时钟
  .p0_data_rden  (p0_data_rden  ), //读FIFO读请求             
  .p0_data_rd    (p0_data_rd    ), //读FIFO读数据,16位，此时用64位是为了兼容32位
                             //64位，增强复用性，只需修改fifo即可
  .p0_rd_valid   (p0_rd_valid   ),                           
  .p0_rd_rst     (p0_rd_rst     ),
  .p0_read_enable(p0_read_enable),
  
  .p1_pingpang   (p1_pingpang   ),//乒乓操作              
  .p1_wr_b_addr  (p1_wr_b_addr  ), //写DDR首地址
  .p1_wr_e_addr  (p1_wr_e_addr  ), //写DDR末地址
  .p1_user_wr_clk(p1_user_wr_clk), //写FIFO写时钟
  .p1_data_wren  (p1_data_wren  ), //写FIFO写请求            
  .p1_data_wr    (p1_data_wr    ), //写FIFO写数据 16位
                             //此时用64位是为了兼容32,64位
  .p1_wr_rst     (p1_wr_rst     ), //写地址复位                             
  .p1_rd_b_addr  (p1_rd_b_addr  ), //读DDR首地址
  .p1_rd_e_addr  (p1_rd_e_addr  ), //读DDR末地址    
  .p1_user_rd_clk(p1_user_rd_clk), //读FIFO读时钟
  .p1_data_rden  (p1_data_rden  ), //读FIFO读请求             
  .p1_data_rd    (p1_data_rd    ), //读FIFO读数据,16位，此时用64位是为了兼容32位
                             //64位，增强复用性，只需修改fifo即可
  .p1_rd_valid   (p1_rd_valid   ),
  .p1_rd_rst     (p1_rd_rst     ),
  .p1_read_enable(p1_read_enable),
  
  //连接到axi写主机
  .wr_burst_req     (wr_burst_req   ),
  .wr_burst_addr    (wr_burst_addr  ),
  .wr_burst_len     (wr_burst_len   ),
  .wr_ready         (wr_ready       ),
  .wr_fifo_re       (wr_fifo_re     ),
  .wr_fifo_data     (wr_fifo_data   ),
  .wr_burst_finish  (wr_burst_finish),
  //连接到axi读主机                 
  .rd_burst_req     (rd_burst_req   ),
  .rd_burst_addr    (rd_burst_addr  ),
  .rd_burst_len     (rd_burst_len   ),
  .rd_ready         (rd_ready       ),
  .rd_fifo_we       (rd_fifo_we     ),
  .rd_fifo_data     (rd_fifo_data   ),
  .rd_burst_finish  (rd_burst_finish)
);

//------------- axi_master_write_inst -------------
axi_master_write axi_master_write_inst
(
  .ARESETN      (~ui_rst         ), //axi复位
  .ACLK         (ui_clk          ), //axi总时钟
  .M_AXI_AWID   (M_AXI_WR_awid   ), //写地址ID
  .M_AXI_AWADDR (M_AXI_WR_awaddr ), //写地址
  .M_AXI_AWLEN  (M_AXI_WR_awlen  ), //突发长度 
  .M_AXI_AWSIZE (M_AXI_WR_awsize ), //突发大小  
  .M_AXI_AWBURST(M_AXI_WR_awburst), //突发类型  
  .M_AXI_AWLOCK (M_AXI_WR_awlock ), //总线锁信号 
  .M_AXI_AWCACHE(M_AXI_WR_awcache), //内存类型
  .M_AXI_AWPROT (M_AXI_WR_awprot ), //保护类型
  .M_AXI_AWQOS  (M_AXI_WR_awqos  ), //质量服务QoS     
  .M_AXI_AWVALID(M_AXI_WR_awvalid), //有效信号
  .M_AXI_AWREADY(M_AXI_WR_awready), //握手信号awready
 
  .M_AXI_WDATA (M_AXI_WR_wdata   ), //写数据
  .M_AXI_WSTRB (M_AXI_WR_wstrb   ), //写数据有效的字节线
  .M_AXI_WLAST (M_AXI_WR_wlast   ), //表明此次传输是最后一个突发传输
  .M_AXI_WVALID(M_AXI_WR_wvalid  ), //写有效
  .M_AXI_WREADY(M_AXI_WR_wready  ), //表明从机可以接收写数据                         
  
  .M_AXI_BID   (M_AXI_WR_bid     ), //写响应ID TAG
  .M_AXI_BRESP (M_AXI_WR_bresp   ), //写响应
  .M_AXI_BVALID(M_AXI_WR_bvalid  ), //写响应有效
  .M_AXI_BREADY(M_AXI_WR_bready  ), //表明主机能够接收写响应  
  
  .WR_START    (wr_burst_req     ), //写突发触发信号
  .WR_ADRS     (wr_burst_addr    ), //地址  
  .WR_LEN      (wr_burst_len     ), //长度
  .WR_READY    (wr_ready         ), //写空闲
  .WR_FIFO_RE  (wr_fifo_re       ), //连接到写fifo的读使能
  .WR_FIFO_DATA(wr_fifo_data     ), //连接到fifo的读数据
  .WR_DONE     (wr_burst_finish  )  //完成一次突发              
);
 
//------------- axi_master_read_inst -------------    
axi_master_read axi_master_read_inst
(
  . ARESETN      (~ui_rst),
  . ACLK         (ui_clk),
  . M_AXI_ARID   (M_AXI_RD_arid   ), //读地址ID
  . M_AXI_ARADDR (M_AXI_RD_araddr ), //读地址
  . M_AXI_ARLEN  (M_AXI_RD_arlen  ), //突发长度
  . M_AXI_ARSIZE (M_AXI_RD_arsize ), //突发大小
  . M_AXI_ARBURST(M_AXI_RD_arburst), //突发类型
  . M_AXI_ARLOCK (M_AXI_RD_arlock ), //总线锁信号
  . M_AXI_ARCACHE(M_AXI_RD_arcache), //内存类型
  . M_AXI_ARPROT (M_AXI_RD_arprot ), //保护类型
  . M_AXI_ARQOS  (M_AXI_RD_arqos  ), //质量服务QOS
  . M_AXI_ARVALID(M_AXI_RD_arvalid), //有效信号
  . M_AXI_ARREADY(M_AXI_RD_arready), //握手信号arready
  
  . M_AXI_RID   (M_AXI_RD_rid   ), //读ID tag
  . M_AXI_RDATA (M_AXI_RD_rdata ), //读数据
  . M_AXI_RRESP (M_AXI_RD_rresp ), //读响应，表明读传输的状态
  . M_AXI_RLAST (M_AXI_RD_rlast ), //表明读突发的最后一次传输
  . M_AXI_RVALID(M_AXI_RD_rvalid), //表明此通道信号有效
  . M_AXI_RREADY(M_AXI_RD_rready), //表明主机能够接收读数据和响应信息

  . RD_START    (rd_burst_req   ), //读突发触发信号
  . RD_ADRS     (rd_burst_addr  ), //地址  
  . RD_LEN      (rd_burst_len   ), //长度
  . RD_READY    (rd_ready       ), //读空闲
  . RD_FIFO_WE  (rd_fifo_we     ), //连接到读fifo的写使能
  . RD_FIFO_DATA(rd_fifo_data   ), //连接到读fifo的写数据
  . RD_DONE     (rd_burst_finish)  //完成一次突发
);

//------------- u_axi_ddr -------------
//xilinx提供的mig ip核，开启axi4接口

axi_ddr  u_axi_ddr
(
  .ddr3_dq   (ddr3_dq   ),
  .ddr3_dqs_n(ddr3_dqs_n),
  .ddr3_dqs_p(ddr3_dqs_p),
  .ddr3_addr (ddr3_addr ),
  .ddr3_ba   (ddr3_ba   ),
  .ddr3_ras_n(ddr3_ras_n),
  .ddr3_cas_n(ddr3_cas_n),
  .ddr3_we_n (ddr3_we_n ),
  .ddr3_reset_n(ddr3_reset_n),
  .ddr3_ck_p (ddr3_ck_p ),
  .ddr3_ck_n (ddr3_ck_n ),
  .ddr3_cke  (ddr3_cke  ),
  .ddr3_cs_n (ddr3_cs_n ),
  .ddr3_dm   (ddr3_dm   ),
  .ddr3_odt  (ddr3_odt  ),
  
  .sys_clk_i(ddr3_clk),
  .clk_ref_i(ddr3_clk),
  .ui_clk   (ui_clk),
  .ui_clk_sync_rst(ui_rst),
  .mmcm_locked(),
  .aresetn    (sys_rst_n),
  .app_sr_req ('b0),
  .app_ref_req('b0),
  .app_zq_req ('b0),
  .app_sr_active(),
  .app_ref_ack(),
  .app_zq_ack(),
  
  .s_axi_awid    (M_AXI_WR_awid   ), 
  .s_axi_awaddr  (M_AXI_WR_awaddr ),
  .s_axi_awlen   (M_AXI_WR_awlen  ),
  .s_axi_awsize  (M_AXI_WR_awsize ),
  .s_axi_awburst (M_AXI_WR_awburst),
  .s_axi_awlock  (M_AXI_WR_awlock ),
  .s_axi_awcache (M_AXI_WR_awcache),
  .s_axi_awprot  (M_AXI_WR_awprot ),
  .s_axi_awqos   (M_AXI_WR_awqos  ),
  .s_axi_awvalid (M_AXI_WR_awvalid),
  .s_axi_awready (M_AXI_WR_awready),
  
  .s_axi_wdata   (M_AXI_WR_wdata  ),
  .s_axi_wstrb   (M_AXI_WR_wstrb  ),
  .s_axi_wlast   (M_AXI_WR_wlast  ),
  .s_axi_wvalid  (M_AXI_WR_wvalid ),
  .s_axi_wready  (M_AXI_WR_wready ),
  
  .s_axi_bid     (M_AXI_WR_bid    ),
  .s_axi_bresp   (M_AXI_WR_bresp  ),
  .s_axi_bvalid  (M_AXI_WR_bvalid ),
  .s_axi_bready  (M_AXI_WR_bready ),
  
  .s_axi_arid    (M_AXI_RD_arid   ),
  .s_axi_araddr  (M_AXI_RD_araddr ),
  .s_axi_arlen   (M_AXI_RD_arlen  ),
  .s_axi_arsize  (M_AXI_RD_arsize ),
  .s_axi_arburst (M_AXI_RD_arburst),
  .s_axi_arlock  (M_AXI_RD_arlock ),
  .s_axi_arcache (M_AXI_RD_arcache),
  .s_axi_arprot  (M_AXI_RD_arprot ),
  .s_axi_arqos   (M_AXI_RD_arqos  ),
  .s_axi_arvalid (M_AXI_RD_arvalid),
  .s_axi_arready (M_AXI_RD_arready),
  
  
  .s_axi_rid     (M_AXI_RD_rid    ),
  .s_axi_rdata   (M_AXI_RD_rdata  ),
  .s_axi_rresp   (M_AXI_RD_rresp  ),
  .s_axi_rlast   (M_AXI_RD_rlast  ),
  .s_axi_rvalid  (M_AXI_RD_rvalid ),
  .s_axi_rready  (M_AXI_RD_rready ),
  
  .init_calib_complete(calib_done),
  .sys_rst(sys_rst_n)
);



endmodule
