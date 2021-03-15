
module  dual_cam_ddr_lcd
(
    input   wire    sys_clk          , //系统时钟
    input   wire    sys_rst_n        ,//系统复位，低电平有效
//摄像头接口
    output  wire            cam_rst_n,  //摄像1与2头复位信号，低电平有效
    output  wire            cam_pwdn ,  //摄像1与2头时钟选择信号
    
    input   wire            cam1_pclk ,  //摄像1头数据像素时钟
    input   wire            cam1_vsync,  //摄像1头场同步信号
    input   wire            cam1_href ,  //摄像1头行同步信号
    input   wire    [7:0]   cam1_data ,  //摄像1头数据
    output  wire            sccb1_scl    ,  //摄像头1SCCB_SCL线
    inout   wire            sccb1_sda    ,  //摄像头1SCCB_SDA线
    
    input   wire            cam2_pclk ,  //摄像2头数据像素时钟
    input   wire            cam2_vsync,  //摄像2头场同步信号
    input   wire            cam2_href ,  //摄像2头行同步信号
    input   wire    [7:0]   cam2_data ,  //摄像2头数据
    output  wire            sccb2_scl    ,  //摄像头2SCCB_SCL线
    inout   wire            sccb2_sda    ,  //摄像头2SCCB_SDA线

    //lcd
    output  wire    [15:0]  rgb_tft     ,   //输出像素信息
    output  wire            hsync       ,   //输出行同步信号
    output  wire            vsync       ,   //输出场同步信号
    output  wire            tft_clk     ,   //输出TFT时钟信号
    output  wire            tft_de      ,   //输出TFT使能信号
    output  wire            tft_bl      ,    //输出背光信号


//DDR3接口
    inout [31:0]       ddr3_dq,
    inout [3:0]        ddr3_dqs_n,
    inout [3:0]        ddr3_dqs_p,
    output [14:0]      ddr3_addr,
    output [2:0]       ddr3_ba,
    output             ddr3_ras_n,
    output             ddr3_cas_n,
    output             ddr3_we_n,
    output             ddr3_reset_n,
    output [0:0]       ddr3_ck_p,
    output [0:0]       ddr3_ck_n,
    output [0:0]       ddr3_cke,
    output [0:0]       ddr3_cs_n,
    output [3:0]       ddr3_dm,
    output [0:0]       ddr3_odt

);
//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
//水平方向像素个数,用于设置SDRAM缓存大小
parameter   H_PIXEL     =   24'd800 ;   
//垂直方向像素个数,用于设置SDRAM缓存大小
parameter   V_PIXEL     =   24'd480 ;


//wire  define
wire      locked;
wire      clk_25m     ; 
wire      clk_320m     ; 
wire      rst_n        ; //复位信号(sys_rst_n & locked)
wire      wr_en        ; //sdram写使能
wire[15:0]wr_data      ; //sdram写数据
wire      rd_en        ; //sdram读使能
wire[15:0]rd_data      ; //sdram读数据
wire      ddr3_init_done; //系统初始化完成(SDRAM初始化)
wire            sys_init_done; //系统初始化完成(SDRAM初始化+摄像头初始化)
wire            cam1_cfg_done     ;   //摄像头初始化完成
wire            cam2_cfg_done     ;   //摄像头初始化完成
wire            cam1_wr_en        ;   //DDR写使能
wire   [15:0]   cam1_wr_data      ;   //DDR写数据
wire            cam2_wr_en        ;   //DDR写使能
wire   [15:0]   cam2_wr_data      ;   //DDR写数据
wire            cam1_rd_en        ;   //DDR读使能
wire   [15:0]   cam1_rd_data      ;   //DDR读数据
wire            cam2_rd_en        ;   //DDR读使能
wire   [15:0]   cam2_rd_data      ;   //DDR读数据
wire      ui_clk       ; //DDR3的读写时钟
wire      ui_rst       ; //ddr产生的复位信号
wire   [13:0] vga_x;
//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
assign  rst_n = sys_rst_n & ddr3_init_done&(~ui_rst);
assign sys_init_done=ddr3_init_done & cam1_cfg_done&cam2_cfg_done;

assign rd_data = (vga_x<=399)? cam1_rd_data:cam2_rd_data;


//ov5640_rst_n:摄像头复位,固定高电平
assign  cam_rst_n = 1'b1;
assign  cam_pwdn = 1'b0;


clk_wiz_0 clk_wiz_inst
(
    // Clock out ports  
    .clk_out1   (clk_25m    ),
    .clk_out2   (clk_320m   ),
    // Status and control signals               
    .reset      (~sys_rst_n ), 
    .locked     (locked     ),
    // Clock in ports
    .clk_in1    (sys_clk    )
);

ov5640_top  cam1(

    .sys_clk         (clk_25m       ),   //系统时钟
    .sys_rst_n       (rst_n         ),   //复位信号
    .sys_init_done   (sys_init_done ),   //系统初始化完成

    .ov5640_pclk     (cam1_pclk     ),   //摄像头像素时钟
    .ov5640_href     (cam1_href     ),   //摄像头行同步信号
    .ov5640_vsync    (cam1_vsync    ),   //摄像头场同步信号
    .ov5640_data     (cam1_data     ),   //摄像头图像数据

    .cfg_done        (cam1_cfg_done ),   //寄存器配置完成
    .sccb_scl        (sccb1_scl     ),   //SCL
    .sccb_sda        (sccb1_sda     ),   //SDA
    .ov5640_wr_en    (cam1_wr_en    ),   //图像数据有效使能信号
    .ov5640_data_out (cam1_wr_data  )    //图像数据
);

ov5640_top  cam2(

    .sys_clk         (clk_25m       ),   //系统时钟
    .sys_rst_n       (rst_n         ),   //复位信号
    .sys_init_done   (sys_init_done ),   //系统初始化完成

    .ov5640_pclk     (cam2_pclk     ),   //摄像头像素时钟
    .ov5640_href     (cam2_href     ),   //摄像头行同步信号
    .ov5640_vsync    (cam2_vsync    ),   //摄像头场同步信号
    .ov5640_data     (cam2_data     ),   //摄像头图像数据

    .cfg_done        (cam2_cfg_done ),   //寄存器配置完成
    .sccb_scl        (sccb2_scl     ),   //SCL
    .sccb_sda        (sccb2_sda     ),   //SDA
    .ov5640_wr_en    (cam2_wr_en    ),   //图像数据有效使能信号
    .ov5640_data_out (cam2_wr_data  )    //图像数据
);

//------------- ddr_rw_inst -------------
//DDR读写控制部分
axi_ddr_top #(
.P0_DDR_WR_LEN(64),//写突发长度 128个64bit
.P0_DDR_RD_LEN(64),//读突发长度 128个64bit
.P1_DDR_WR_LEN(64),//写突发长度 128个64bit
.P1_DDR_RD_LEN(64) //读突发长度 128个64bit
) 
ddr_rw_inst(

  .ddr3_clk         (clk_320m       ),
  .sys_rst_n        (sys_rst_n&locked),
  .p0_pingpang      (1'b1           ),
   //写用户接口
  .p0_user_wr_clk   (cam1_pclk      ), //写时钟 cam1_pclk
  .p0_data_wren     (cam1_wr_en     ), //写使能，高电平有效 cam1_wr_en 
  .p0_data_wr       (cam1_wr_data   ), //写数据16位 cam1_wr_data
  .p0_wr_b_addr     (30'd0          ), //写起始地址
  .p0_wr_e_addr     (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址，16位x2
  .p0_wr_rst        (1'b0           ), //写地址复位 wr_rst
  //读用户接口   
  .p0_user_rd_clk   (clk_25m         ), //读时钟
  .p0_data_rden     (rd_en          ), //读使能，高电平有效 cam1_rd_en
  .p0_data_rd       (cam1_rd_data   ), //读数据16位
  .p0_rd_b_addr     (30'd0          ), //读起始地址
  .p0_rd_e_addr     (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址,16位x2
  .p0_rd_valid      (               ),
  .p0_rd_rst        (1'b0           ), //读地址复位 rd_rst
  .p0_read_enable   (1'b1           ),
  
  .p1_pingpang      (1'b1           ),
   //写用户接口
  .p1_user_wr_clk   (cam2_pclk      ), //写时钟 cam2_pclk
  .p1_data_wren     (cam2_wr_en     ), //写使能，高电平有效 cam2_wr_en
  .p1_data_wr       (cam2_wr_data   ), //写数据16位 cam2_wr_data
  .p1_wr_b_addr     (H_PIXEL*V_PIXEL*8  ), //写起始地址
  .p1_wr_e_addr     (H_PIXEL*V_PIXEL*8+H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址，16位x2
  .p1_wr_rst        (1'b0           ), //写地址复位 wr_rst
  //读用户接口   
  .p1_user_rd_clk   (clk_25m         ), //读时钟
  .p1_data_rden     (rd_en          ), //读使能，高电平有效 cam2_rd_en
  .p1_data_rd       (cam2_rd_data   ), //读数据16位
  .p1_rd_b_addr     (H_PIXEL*V_PIXEL*8), //读起始地址
  .p1_rd_e_addr     (H_PIXEL*V_PIXEL*8+H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址,16位x2
  .p1_rd_valid      (               ),
  .p1_rd_rst        (1'b0           ), //读地址复位 rd_rst
  .p1_read_enable   (1'b1           ),
  
   
  .ui_rst           (ui_rst         ), //ddr产生的复位信号
  .ui_clk           (ui_clk         ), //ddr操作时钟
  .calib_done       (ddr3_init_done ), //代表ddr初始化完成
  
  //物理接口
  .ddr3_dq          (ddr3_dq        ),
  .ddr3_dqs_n       (ddr3_dqs_n     ),
  .ddr3_dqs_p       (ddr3_dqs_p     ),
  .ddr3_addr        (ddr3_addr      ),
  .ddr3_ba          (ddr3_ba        ),
  .ddr3_ras_n       (ddr3_ras_n     ),
  .ddr3_cas_n       (ddr3_cas_n     ),
  .ddr3_we_n        (ddr3_we_n      ),
  .ddr3_reset_n     (ddr3_reset_n   ), 
  .ddr3_ck_p        (ddr3_ck_p      ),
  .ddr3_ck_n        (ddr3_ck_n      ),
  .ddr3_cke         (ddr3_cke       ),
  .ddr3_cs_n        (ddr3_cs_n      ),
  .ddr3_dm          (ddr3_dm        ),
  .ddr3_odt         (ddr3_odt       )
   

);



tft_ctrl tft_ctrl_inst
(
    .clk_in     (clk_25m    ) ,   //输入时钟
    .sys_rst_n  (rst_n      ) ,   //系统复位,低电平有效
    .data_in    (rd_data    ) ,   //待显示数据
    .data_req   (rd_en      ) ,   //数据请求信号
    .pix_x      (vga_x      ) ,   //输出TFT有效显示区域像素点X轴坐标
    .pix_y      (           ) ,   //输出TFT有效显示区域像素点Y轴坐标
    .rgb_tft_16b(rgb_tft    ) ,   //TFT显示数据16bit
    .rgb_tft_24b(           ) ,   //TFT显示数据24bit
    .hsync      (hsync      ) ,   //TFT行同步信号
    .vsync      (vsync      ) ,   //TFT场同步信号
    .tft_clk    (tft_clk    ) ,   //TFT像素时钟
    .tft_de     (tft_de     ) ,   //TFT数据使能
    .tft_bl     (tft_bl     )     //TFT背光信号
);
endmodule
