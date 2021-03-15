`timescale 1ns / 1ps

module axi_ctrl
#(
parameter  P0_DDR_WR_LEN=128,//写突发长度 128个64bit
parameter  P0_DDR_RD_LEN=128,//读突发长度 128个64bit
parameter  P1_DDR_WR_LEN=128,//写突发长度 128个64bit
parameter  P1_DDR_RD_LEN=128 //读突发长度 128个64bit

)
(
   input   wire        ui_clk     ,
   input   wire        ui_rst     ,
/////////////////////////////////////////////////////
//端口0
   input   wire        p0_pingpang   ,//乒乓操作
   
   input   wire [31:0] p0_wr_b_addr  ,   //写DDR首地址
   input   wire [31:0] p0_wr_e_addr  ,   //写DDR末地址
   input   wire        p0_user_wr_clk,   //写FIFO写时钟
   input   wire        p0_data_wren  ,   //写FIFO写请求
   //写进fifo数据长度，可根据写fifo的写端口数据长度自行修改
   //写FIFO写数据 16位，此时用64位是为了兼容32,64位
   input   wire [63:0] p0_data_wr    ,    
   input   wire        p0_wr_rst     ,
   
   input   wire [31:0] p0_rd_b_addr  ,   //读DDR首地址
   input   wire [31:0] p0_rd_e_addr  ,   //读DDR末地址    
   input   wire        p0_user_rd_clk,   //读FIFO读时钟
   input   wire        p0_data_rden  ,   //读FIFO读请求  
   //读出fifo数据长度，可根据读fifo的读端口数据长度自行修改
   //读FIFO读数据,16位，此时用64位是为了兼容32,64位
   output  wire [63:0] p0_data_rd    ,
   output  wire        p0_rd_valid   ,
   input   wire        p0_rd_rst     ,
   input   wire        p0_read_enable,

//////////////////////////////////////////////////////////
//端口1   
   input   wire        p1_pingpang   ,//乒乓操作   
   input   wire [31:0] p1_wr_b_addr  ,   //写DDR首地址
   input   wire [31:0] p1_wr_e_addr  ,   //写DDR末地址
   input   wire        p1_user_wr_clk,   //写FIFO写时钟
   input   wire        p1_data_wren  ,   //写FIFO写请求
   //写进fifo数据长度，可根据写fifo的写端口数据长度自行修改
   //写FIFO写数据 16位，此时用64位是为了兼容32,64位
   input   wire [63:0] p1_data_wr    ,    
   input   wire        p1_wr_rst     ,
   
   input   wire [31:0] p1_rd_b_addr  ,   //读DDR首地址
   input   wire [31:0] p1_rd_e_addr  ,   //读DDR末地址    
   input   wire        p1_user_rd_clk,   //读FIFO读时钟
   input   wire        p1_data_rden  ,   //读FIFO读请求  
   //读出fifo数据长度，可根据读fifo的读端口数据长度自行修改
   //读FIFO读数据,16位，此时用64位是为了兼容32,64位
   output  wire [63:0] p1_data_rd    ,
   output  wire        p1_rd_valid   ,
   input   wire        p1_rd_rst     ,
   input   wire        p1_read_enable,
      
   output  wire        wr_burst_req    , //写突发触发信号
   output  wire[31:0]  wr_burst_addr   , //地址  
   output  wire[9:0]   wr_burst_len    , //长度
   input   wire        wr_ready        , //写空闲
   input   wire        wr_fifo_re      , //连接到写fifo的读使能
   output  wire [63:0] wr_fifo_data    , //连接到fifo的读数据
   input   wire        wr_burst_finish , //完成一次突发
                                      
   output  wire        rd_burst_req    , //读突发触发信号
   output  wire[31:0]  rd_burst_addr   , //地址  
   output  wire[9:0]   rd_burst_len    ,  //长度
   input   wire        rd_ready        , //读空闲
   input   wire        rd_fifo_we      , //连接到读fifo的写使能
   input   wire[63:0]  rd_fifo_data    , //连接到读fifo的写数据
   input   wire        rd_burst_finish   //完成一次突发
   );
 
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

localparam WR_IDLE  = 3'b000;//写空闲
localparam WR_WAIT  = 3'b001;//写等待
localparam WR_START = 3'b011;//写开始
localparam WR_DONE  = 3'b010;//写结束
reg [2:0]   wr_state   ; //写状态寄存器

localparam RD_IDLE  = 3'b000;//读空闲
localparam RD_WAIT  = 3'b001;//读等待
localparam RD_START = 3'b011;//读开始
localparam RD_DONE  = 3'b010;//读结束
reg [2:0]   rd_state   ; //读状态寄存器

//reg define
reg       wr_ready_reg;
reg       wr_p0_p1;//1代表p0,0代表p1端口，用以选择fifo的哪一个接口
reg       p0_wr_req;
reg       p1_wr_req;
reg       wr_burst_req_reg ; //写突发寄存器
reg       wr_burst_req_reg1;
reg [31:0]p0_wr_burst_addr_reg; //写地址寄存器
reg [9:0] p0_wr_burst_len_reg ; //写长度寄存器
reg [31:0]p1_wr_burst_addr_reg; //写地址寄存器
reg [9:0] p1_wr_burst_len_reg ; //写长度寄存器

reg       rd_ready_reg;
reg       rd_p0_p1;//1代表p0,0代表p1端口，用以选择fifo的哪一个接口
reg       p0_rd_req;
reg       p1_rd_req;
reg       rd_burst_req_reg ; //读突发寄存器
reg       rd_burst_req_reg1;
reg [31:0]p0_rd_burst_addr_reg; //读地址寄存器
reg [9:0] p0_rd_burst_len_reg ; //读长度寄存器
reg [31:0]p1_rd_burst_addr_reg; //读地址寄存器
reg [9:0] p1_rd_burst_len_reg ; //读长度寄存器
//读写地址复位打拍寄存器
reg p0_wr_rst_reg1;
reg p0_wr_rst_reg2;
reg p0_rd_rst_reg1;
reg p0_rd_rst_reg2;

reg p1_wr_rst_reg1;
reg p1_wr_rst_reg2;
reg p1_rd_rst_reg1;
reg p1_rd_rst_reg2;

reg p0_pingpang_reg;//乒乓操作指示寄存器
reg p1_pingpang_reg;//乒乓操作指示寄存器

//wire define
//写fifo信号
wire        p0_wr_fifo_wr_clk        ;
wire        p0_wr_fifo_rd_clk        ;
wire [63:0] p0_wr_fifo_din           ;
wire        p0_wr_fifo_wr_en         ;
wire        p0_wr_fifo_rd_en         ;
wire [63:0] p0_wr_fifo_dout          ;
wire        p0_wr_fifo_full          ;
wire        p0_wr_fifo_almost_full   ;
wire        p0_wr_fifo_empty         ;
wire        p0_wr_fifo_almost_empty  ;
wire  [9:0] p0_wr_fifo_rd_data_count ;
wire  [9:0] p0_wr_fifo_wr_data_count ;

//读fifo信号
wire        p0_rd_fifo_wr_clk        ;
wire        p0_rd_fifo_rd_clk        ;
wire [63:0] p0_rd_fifo_din           ;
wire        p0_rd_fifo_wr_en         ;
wire        p0_rd_fifo_rd_en         ;
wire [63:0] p0_rd_fifo_dout          ;
wire        p0_rd_fifo_full          ;
wire        p0_rd_fifo_almost_full   ;
wire        p0_rd_fifo_empty         ;
wire        p0_rd_fifo_almost_empty  ;
wire  [9:0] p0_rd_fifo_rd_data_count ;
wire  [9:0] p0_rd_fifo_wr_data_count ;

//写fifo信号
wire        p1_wr_fifo_wr_clk        ;
wire        p1_wr_fifo_rd_clk        ;
wire [63:0] p1_wr_fifo_din           ;
wire        p1_wr_fifo_wr_en         ;
wire        p1_wr_fifo_rd_en         ;
wire [63:0] p1_wr_fifo_dout          ;
wire        p1_wr_fifo_full          ;
wire        p1_wr_fifo_almost_full   ;
wire        p1_wr_fifo_empty         ;
wire        p1_wr_fifo_almost_empty  ;
wire  [9:0] p1_wr_fifo_rd_data_count ;
wire  [9:0] p1_wr_fifo_wr_data_count ;

//读fifo信号
wire        p1_rd_fifo_wr_clk        ;
wire        p1_rd_fifo_rd_clk        ;
wire [63:0] p1_rd_fifo_din           ;
wire        p1_rd_fifo_wr_en         ;
wire        p1_rd_fifo_rd_en         ;
wire [63:0] p1_rd_fifo_dout          ;
wire        p1_rd_fifo_full          ;
wire        p1_rd_fifo_almost_full   ;
wire        p1_rd_fifo_empty         ;
wire        p1_rd_fifo_almost_empty  ;
wire  [9:0] p1_rd_fifo_rd_data_count ;
wire  [9:0] p1_rd_fifo_wr_data_count ;

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//



assign wr_burst_req  = wr_burst_req_reg;  //写突发请求
assign wr_burst_addr = (wr_p0_p1)? p0_wr_burst_addr_reg :p1_wr_burst_addr_reg; //写地址
assign wr_burst_len  = (wr_p0_p1)?P0_DDR_WR_LEN:P1_DDR_WR_LEN;        //写长度

assign rd_burst_req  = rd_burst_req_reg;  //读突发请求
assign rd_burst_addr = (rd_p0_p1)?p0_rd_burst_addr_reg:p1_rd_burst_addr_reg; //读地址
assign rd_burst_len  = (rd_p0_p1)?P0_DDR_RD_LEN:P1_DDR_RD_LEN;        //读长度

assign p0_rd_valid=~p0_wr_fifo_almost_empty;
assign p1_rd_valid=~p1_wr_fifo_almost_empty;
//P0写端口
//写fifo写时钟位用户端时钟
assign p0_wr_fifo_wr_clk = p0_user_wr_clk;
//写fifo读时钟位axi总时钟
assign p0_wr_fifo_rd_clk = ui_clk;
//写fifo非满为用户输入数据
assign p0_wr_fifo_din    = p0_data_wr;
//写fifo非满为用户输入数据使能
assign p0_wr_fifo_wr_en  = p0_data_wren;
//写fifo非空为axi写主机读取使能
assign p0_wr_fifo_rd_en  = (wr_p0_p1)? (wr_fifo_re): 1'b0;

//P1写端口
//写fifo写时钟位用户端时钟
assign p1_wr_fifo_wr_clk = p1_user_wr_clk;
//写fifo读时钟位axi总时钟
assign p1_wr_fifo_rd_clk = ui_clk;
//写fifo非满为用户输入数据
assign p1_wr_fifo_din    = p1_data_wr;
//写fifo非满为用户输入数据使能
assign p1_wr_fifo_wr_en  = p1_data_wren;
//写fifo非空为axi写主机读取使能
assign p1_wr_fifo_rd_en  = (~wr_p0_p1)?(wr_fifo_re):1'b0;

//写fifo非空为axi写主机读取数据
assign wr_fifo_data   = (wr_p0_p1)?(p0_wr_fifo_dout):(p1_wr_fifo_dout);

//P0读端口
//读fifo写时钟位axi读主机时钟
assign p0_rd_fifo_wr_clk=ui_clk;
//读fifo读时钟位用户时钟
assign p0_rd_fifo_rd_clk=p0_user_rd_clk;
//读fifo读使能为用户使能
assign p0_rd_fifo_rd_en =p0_data_rden;
//读fifo读数据为用户使能
assign p0_data_rd       =p0_rd_fifo_dout;
//读fifo写使能为axi读主机写使能
assign p0_rd_fifo_wr_en =(rd_p0_p1)?  (rd_fifo_we) :1'b0;
//读fifo写使能为axi读主机写数据
assign p0_rd_fifo_din   =(rd_p0_p1)?  (rd_fifo_data) :64'd0;

//assign p0_rd_fifo_din   =(p0_rd_fifo_almost_full&(~rd_p0_p1)  )?  64'd0 :64'hff00ff00ff00ff00;

//P1读端口
//读fifo写时钟位axi读主机时钟
assign p1_rd_fifo_wr_clk=ui_clk;
//读fifo读时钟位用户时钟
assign p1_rd_fifo_rd_clk=p1_user_rd_clk;
//读fifo读使能为用户使能
assign p1_rd_fifo_rd_en =p1_data_rden;
//读fifo读数据为用户使能
assign p1_data_rd       =p1_rd_fifo_dout;
//读fifo写使能为axi读主机写使能
assign p1_rd_fifo_wr_en =(~rd_p0_p1)?  (rd_fifo_we) :1'b0;
//读fifo写使能为axi读主机写数据
assign p1_rd_fifo_din   =(~rd_p0_p1)?  (rd_fifo_data) :64'd0;

//对写复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p0_wr_rst_reg1<=1'b0;
        p0_wr_rst_reg2<=1'b0;
    end
    else begin
        p0_wr_rst_reg1<=p0_wr_rst;
        p0_wr_rst_reg2<=p0_wr_rst_reg1;
    end

end

//对读复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p0_rd_rst_reg1<=1'b0;
        p0_rd_rst_reg2<=1'b0;
    end
    else begin
        p0_rd_rst_reg1<=p0_rd_rst;
        p0_rd_rst_reg2<=p0_rd_rst_reg1;
    end

end

//对写复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p1_wr_rst_reg1<=1'b0;
        p1_wr_rst_reg2<=1'b0;
    end
    else begin
        p1_wr_rst_reg1<=p1_wr_rst;
        p1_wr_rst_reg2<=p1_wr_rst_reg1;
    end

end

//对读复位信号的跨时钟域打2拍
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p1_rd_rst_reg1<=1'b0;
        p1_rd_rst_reg2<=1'b0;
    end
    else begin
        p1_rd_rst_reg1<=p1_rd_rst;
        p1_rd_rst_reg2<=p1_rd_rst_reg1;
    end

end


//写burst请求产生

always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p0_wr_req<=1'b0;
        p1_wr_req<=1'b0;
    end
    else begin
      if(((p0_wr_fifo_rd_data_count>=P0_DDR_WR_LEN)) ) 
      begin 
          p0_wr_req<=1'b1; 
  
      end
      else begin
         p0_wr_req<=1'b0;
      end
      if(((p1_wr_fifo_rd_data_count>=P1_DDR_WR_LEN)) ) 
      begin 
          p1_wr_req<=1'b1; 
  
      end
      else begin
          p1_wr_req<=1'b0;
      end
    end

end

always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        wr_burst_req_reg<=1'b0;
        wr_p0_p1<=1'b0;
        wr_state<=WR_IDLE;
    end
    //fifo数据长度大于一次突发长度并且axi写空闲
    else begin
    case (wr_state)
      WR_IDLE: begin
        wr_burst_req_reg<=1'b0;
        if(((p0_wr_req==1'b1) ||(p1_wr_req==1'b1))&&(wr_ready==1'b1)) begin
          wr_state<=WR_WAIT;
        end
        else begin
          wr_state<=WR_IDLE;
        end
      
      end
    
      WR_WAIT: begin
        if(wr_ready==1'b1) begin
          wr_state<=WR_START;
          if(p0_wr_req==1'b1 && p1_wr_req==1'b0) begin
            wr_p0_p1<=1'b1;
          end
          else if(p0_wr_req==1'b0 && p1_wr_req==1'b1) begin
              wr_p0_p1<=1'b0;
          end
          else if(p0_wr_req==1'b1 && p1_wr_req==1'b1) begin
              wr_p0_p1<=~wr_p0_p1;
          end
          else begin
            wr_p0_p1<=wr_p0_p1;
          end
          
        end
        else begin
          wr_state<=WR_WAIT;
          wr_p0_p1<=wr_p0_p1;
        end
      
      end
    
      WR_START: begin
        wr_burst_req_reg<=1'b1;
        wr_state<=WR_DONE;
      end
    
      WR_DONE: begin
        wr_burst_req_reg<=1'b0;
        wr_state<=WR_IDLE;
      end
    
      default: begin
        wr_burst_req_reg<=1'b0;
        wr_state<=WR_IDLE;
        wr_p0_p1<=wr_p0_p1;
      end
    
    endcase
    end
end

//完成一次突发对地址进行相加
//相加地址长度=突发长度x8,64位等于8字节
//128*8=1024
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p0_wr_burst_addr_reg<=p0_wr_b_addr;
        p0_pingpang_reg<=1'b0;
        
    end
    //写复位信号上升沿
    else if(p0_wr_rst_reg1&(~p0_wr_rst_reg2)) begin
        p0_wr_burst_addr_reg<=p0_wr_b_addr;
    end 
    else if((wr_burst_finish==1'b1)&&(wr_p0_p1==1'b1)) begin
        p0_wr_burst_addr_reg<=p0_wr_burst_addr_reg+P0_DDR_WR_LEN*8;
        //判断是否是乒乓操作
        if(p0_pingpang==1'b1) begin
        //结束地址为2倍的接受地址，有两块区域
            if(p0_wr_burst_addr_reg>=((p0_wr_e_addr-p0_wr_b_addr)*2+p0_wr_b_addr-P0_DDR_WR_LEN*8)) 
            begin
                p0_wr_burst_addr_reg<=p0_wr_b_addr;
            end
            //根据地址，pingpang_reg为0或者1
            //用于指示读操作与写操作地址不冲突
            if(p0_wr_burst_addr_reg<(p0_wr_e_addr)) begin
                p0_pingpang_reg<=1'b0;
            end
            else begin
                p0_pingpang_reg<=1'b1;
            end
        
        end
        //非乒乓操作
        else begin
            if(p0_wr_burst_addr_reg>=((p0_wr_e_addr-p0_wr_b_addr)+p0_wr_b_addr-P0_DDR_WR_LEN*8)) 
            begin
                p0_wr_burst_addr_reg<=p0_wr_b_addr;
            end
        end
    end
    else begin
        p0_wr_burst_addr_reg<=p0_wr_burst_addr_reg;
    end

end

always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p1_wr_burst_addr_reg<=p1_wr_b_addr;
        p1_pingpang_reg<=1'b0;
        
    end
    //写复位信号上升沿
    else if(p1_wr_rst_reg1&(~p1_wr_rst_reg2)) begin
        p1_wr_burst_addr_reg<=p1_wr_b_addr;
    end 
    else if((wr_burst_finish==1'b1)&&(wr_p0_p1==1'b0)) begin
        p1_wr_burst_addr_reg<=p1_wr_burst_addr_reg+P1_DDR_WR_LEN*8;
        //判断是否是乒乓操作
        if(p1_pingpang==1'b1) begin
        //结束地址为2倍的接受地址，有两块区域
            if(p1_wr_burst_addr_reg>=((p1_wr_e_addr-p1_wr_b_addr)*2+p1_wr_b_addr-P1_DDR_WR_LEN*8)) 
            begin
                p1_wr_burst_addr_reg<=p1_wr_b_addr;
            end
            //根据地址，pingpang_reg为0或者1
            //用于指示读操作与写操作地址不冲突
            if(p1_wr_burst_addr_reg<p1_wr_e_addr) begin
                p1_pingpang_reg<=1'b0;
            end
            else begin
                p1_pingpang_reg<=1'b1;
            end
        
        end
        //非乒乓操作
        else begin
            if(p1_wr_burst_addr_reg>=((p1_wr_e_addr-p1_wr_b_addr)+p1_wr_b_addr-P1_DDR_WR_LEN*8)) 
            begin
                p1_wr_burst_addr_reg<=p1_wr_b_addr;
            end
        end
    end
    else begin
        p1_wr_burst_addr_reg<=p1_wr_burst_addr_reg;
    end

end



//读burst请求产生

always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        p0_rd_req<=1'b0;
        p1_rd_req<=1'b0;
    end
    //fifo可写长度大于一次突发长度并且axi读空闲，fifo总长度1024
    else begin

        if(((p0_rd_fifo_wr_data_count<=(10'd512) &&p0_read_enable==1'b1))) 
        begin
            p0_rd_req<=1'b1;
        end
        else begin
            p0_rd_req<=1'b0;
        end
        if(((p1_rd_fifo_wr_data_count<=(10'd512) &&p1_read_enable==1'b1))) 
        begin
            p1_rd_req<=1'b1;
        end
        else begin
            p1_rd_req<=1'b0;
        end
        
    end
end

always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        rd_burst_req_reg<=1'b0;
        rd_p0_p1<=1'b0;
        rd_state<=RD_IDLE;

    end
    //fifo可写长度大于一次突发长度并且axi读空闲，fifo总长度1024
    else begin
    
        case (rd_state)
            RD_IDLE : begin
              rd_burst_req_reg<=1'b0;
              if(((p0_rd_req==1'b1) || (p1_rd_req==1'b1))&&(rd_ready==1'b1)) begin
                rd_state<=RD_WAIT;
              end
              else begin
                rd_state<=RD_IDLE;
              end
            end
            
            RD_WAIT : begin
              if(rd_ready==1'b1) begin
                rd_state<=RD_START;
                if(p0_rd_req==1'b1 && p1_rd_req==1'b0) begin
                  rd_p0_p1<=1'b1;
                end
                else if(p0_rd_req==1'b0 && p1_rd_req==1'b1) begin
                  rd_p0_p1<=1'b0;
                end
                else if(p0_rd_req==1'b1 && p1_rd_req==1'b1) begin
                  rd_p0_p1<=~rd_p0_p1;
                end
                else begin
                  rd_p0_p1<=rd_p0_p1;
                end
              end
              
              else begin
                rd_state<=RD_WAIT;
              end
            end
            RD_START : begin
                rd_burst_req_reg<=1'b1;
                rd_state<=RD_DONE;
            end
            RD_DONE : begin
              rd_burst_req_reg<=1'b0;
              rd_state<=RD_IDLE;
            end
            default : begin
              rd_burst_req_reg<=1'b0;
              rd_p0_p1<=rd_p0_p1;
              rd_state<=RD_IDLE;
            end
        
        endcase
    end
end

//完成一次突发对地址进行相加
//相加地址长度=突发长度x8,64位等于8字节
//128*8=1024
always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        if(p0_pingpang==1'b1) p0_rd_burst_addr_reg<=p0_rd_e_addr;
        else p0_rd_burst_addr_reg<=p0_rd_b_addr;
    end
     else if(p0_rd_rst_reg1&(~p0_rd_rst_reg2)) begin
        p0_rd_burst_addr_reg<=p0_rd_b_addr;
    end 
    else if(rd_burst_finish==1'b1&&(rd_p0_p1==1'b1)) begin
        p0_rd_burst_addr_reg<=p0_rd_burst_addr_reg+P0_DDR_RD_LEN*8;//地址累加
        //乒乓操作
         if(p0_pingpang==1'b1) begin
           //到达结束地址 
           if((p0_rd_burst_addr_reg==((p0_rd_e_addr-p0_rd_b_addr)+p0_rd_b_addr-P0_DDR_RD_LEN*8))||
              (p0_rd_burst_addr_reg==((p0_rd_e_addr-p0_rd_b_addr)*2+p0_rd_b_addr-P0_DDR_RD_LEN*8))) 
           begin
                //根据写指示地址信号，对读信号进行复位
               if(p0_pingpang_reg==1'b1) p0_rd_burst_addr_reg<=p0_rd_b_addr;
               else p0_rd_burst_addr_reg<=p0_rd_e_addr;
           end
                    
        end
        else begin  //非乒乓操作
            if(p0_rd_burst_addr_reg>=((p0_rd_e_addr-p0_rd_b_addr)+p0_rd_b_addr-P0_DDR_RD_LEN*8)) 
            begin
            p0_rd_burst_addr_reg<=p0_rd_b_addr;
            end
        end
    end
    else begin
        p0_rd_burst_addr_reg<=p0_rd_burst_addr_reg;
    end

end


always@(posedge ui_clk or posedge ui_rst) begin
    if(ui_rst==1'b1)begin
        if(p1_pingpang==1'b1) p1_rd_burst_addr_reg<=p1_rd_e_addr;
        else p1_rd_burst_addr_reg<=p1_rd_b_addr;
    end
     else if(p1_rd_rst_reg1&(~p1_rd_rst_reg2)) begin
        p1_rd_burst_addr_reg<=p1_rd_b_addr;
    end 
    else if(rd_burst_finish==1'b1&&(rd_p0_p1==1'b0)) begin
        p1_rd_burst_addr_reg<=p1_rd_burst_addr_reg+P1_DDR_RD_LEN*8;//地址累加
        //乒乓操作
         if(p1_pingpang==1'b1) begin
           //到达结束地址 
           if((p1_rd_burst_addr_reg==((p1_rd_e_addr-p1_rd_b_addr)+p1_rd_b_addr-P1_DDR_RD_LEN*8))||
              (p1_rd_burst_addr_reg==((p1_rd_e_addr-p1_rd_b_addr)*2+p1_rd_b_addr-P1_DDR_RD_LEN*8))) 
           begin
                //根据写指示地址信号，对读信号进行复位
               if(p1_pingpang_reg==1'b1) p1_rd_burst_addr_reg<=p1_rd_b_addr;
               else p1_rd_burst_addr_reg<=p1_rd_e_addr;
           end
                    
        end
        else begin  //非乒乓操作
            if(p1_rd_burst_addr_reg>=((p1_rd_e_addr-p1_rd_b_addr)+p1_rd_b_addr-P1_DDR_RD_LEN*8)) 
            begin
            p1_rd_burst_addr_reg<=p1_rd_b_addr;
            end
        end
    end
    else begin
        p1_rd_burst_addr_reg<=p1_rd_burst_addr_reg;
    end

end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//

//------------- wr_fifo_inst -------------
//写fifo
wr_fifo p0_wr_fifo_inst (
  .wr_rst(p0_wr_rst||ui_rst), // 写复位
  .rd_rst(p0_wr_rst||ui_rst), //读复位
  .wr_clk(p0_wr_fifo_wr_clk), // 写时钟
  .rd_clk(p0_wr_fifo_rd_clk), // 读时钟
  .din   (p0_wr_fifo_din   ), // 外部写进fifo的数据 16位
  .wr_en (p0_wr_fifo_wr_en ), // 写使能
  .rd_en (p0_wr_fifo_rd_en ), // 读使能
  .dout  (p0_wr_fifo_dout  ), // 输出给ddr的axi写数据，写进ddr 64位
  .full  (p0_wr_fifo_full  ), // fifo满信号
  .almost_full  (p0_wr_fifo_almost_full  ), //fifo几乎满信号
  .empty (p0_wr_fifo_empty ), //fifo空信号 
  .almost_empty (p0_wr_fifo_almost_empty ),
  .rd_data_count(p0_wr_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(p0_wr_fifo_wr_data_count)  // 可写数据个数
);

wr_fifo p1_wr_fifo_inst (
  .wr_rst(p1_wr_rst||ui_rst), // 写复位
  .rd_rst(p1_wr_rst||ui_rst), //读复位
  .wr_clk(p1_wr_fifo_wr_clk), // 写时钟
  .rd_clk(p1_wr_fifo_rd_clk), // 读时钟
  .din   (p1_wr_fifo_din   ), // 外部写进fifo的数据 16位
  .wr_en (p1_wr_fifo_wr_en ), // 写使能
  .rd_en (p1_wr_fifo_rd_en ), // 读使能
  .dout  (p1_wr_fifo_dout  ), // 输出给ddr的axi写数据，写进ddr 64位
  .full  (p1_wr_fifo_full  ), // fifo满信号
  .almost_full  (p1_wr_fifo_almost_full  ), //fifo几乎满信号
  .empty (p1_wr_fifo_empty ), //fifo空信号 
  .almost_empty (p1_wr_fifo_almost_empty ),
  .rd_data_count(p1_wr_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(p1_wr_fifo_wr_data_count)  // 可写数据个数
);
//------------- rd_fifo_inst -------------
//读fifo
rd_fifo p0_rd_fifo_inst (
  .wr_rst(p0_rd_rst||ui_rst), // 写复位
  .rd_rst(p0_rd_rst||ui_rst), //读复位
  .wr_clk(p0_rd_fifo_wr_clk), // 写时钟
  .rd_clk(p0_rd_fifo_rd_clk), // 读时钟
  .din   (p0_rd_fifo_din   ), // ddr读出的数据，写进fifo 64位
  .wr_en (p0_rd_fifo_wr_en ), // 写使能
  .rd_en (p0_rd_fifo_rd_en ), // 读使能
  .dout  (p0_rd_fifo_dout  ), // 最终我们读出的数据 64位
  .full  (p0_rd_fifo_full  ), // fifo满信号
  .almost_full  (p0_rd_fifo_almost_full  ),
  .empty (p0_rd_fifo_empty ), //fifo几乎满信号
  .almost_empty (p0_rd_fifo_almost_empty ),
  .rd_data_count(p0_rd_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(p0_rd_fifo_wr_data_count)  // 可写数据个数
);

rd_fifo p1_rd_fifo_inst (
  .wr_rst(p1_rd_rst||ui_rst), // 写复位
  .rd_rst(p1_rd_rst||ui_rst), //读复位
  .wr_clk(p1_rd_fifo_wr_clk), // 写时钟
  .rd_clk(p1_rd_fifo_rd_clk), // 读时钟
  .din   (p1_rd_fifo_din   ), // ddr读出的数据，写进fifo 64位
  .wr_en (p1_rd_fifo_wr_en ), // 写使能
  .rd_en (p1_rd_fifo_rd_en ), // 读使能
  .dout  (p1_rd_fifo_dout  ), // 最终我们读出的数据 64位
  .full  (p1_rd_fifo_full  ), // fifo满信号
  .almost_full  (p1_rd_fifo_almost_full  ),
  .empty (p1_rd_fifo_empty ), //fifo几乎满信号
  .almost_empty (p1_rd_fifo_almost_empty ),
  .rd_data_count(p1_rd_fifo_rd_data_count), // 可读数据个数
  .wr_data_count(p1_rd_fifo_wr_data_count)  // 可写数据个数
);
endmodule
