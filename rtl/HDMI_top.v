module HDMI_top#(
    parameter IMAGE_WIDTH       = 5'd11     , // 图像宽高位宽
    parameter HDMI_DATA_WIDTH   = 5'd24     , // HDMI 数据位宽

    parameter X_BITS            = 12        , // 行扫描周期位宽
    parameter Y_BITS            = 12        , // 场扫描周期位宽
    
    parameter H_SYNC            = 12'd44    , // 行同步
    parameter H_BACK            = 12'd148   , // 行显示后沿
    parameter H_DISP            = 12'd1920  , // 行有效数据
    parameter H_FRONT           = 12'd88    , // 行显示前沿
    parameter H_TOTAL           = 12'd2200  , // 行扫描周期
    
    parameter V_SYNC            = 12'd5     , // 场同步
    parameter V_BACK            = 12'd36    , // 场显示后沿
    parameter V_DISP            = 12'd1080  , // 场有效数据
    parameter V_FRONT           = 12'd4     , // 场显示前沿
    parameter V_TOTAL           = 12'd1125    // 场扫描周期
)(
    input   wire                            sys_clk         ,
    input   wire                            hdmi_tx_pix_clk ,
    input   wire                            sys_rst_n       ,
    input   wire                            ddr_init_done   ,
    output  wire                            hdmi_tx_init    ,
    output  wire                            hdmi_rx_init    ,
    output  wire                            hdmi_rst_n      ,

    input   wire    [IMAGE_WIDTH-1:0]       disp_w          ,
    input   wire    [IMAGE_WIDTH-1:0]       disp_h          ,
    output  wire                            frame_end       ,
    
    output  wire                            pixel_req       ,
    input   wire    [HDMI_DATA_WIDTH-1:0]   pixel_data      ,
    
    output  wire                            hdmi_rx_scl     , // HDMI输入芯片SCL信号
    inout   wire                            hdmi_rx_sda     , // HDMI输入芯片SDA信号
    
    output  wire                            hdmi_tx_scl     , // HDMI输出芯片SCL信号
    inout   wire                            hdmi_tx_sda     , // HDMI输出芯片SDA信号
    
    output  wire                            hdmi_tx_vs      , // HDMI输出场同步信号
    output  wire                            hdmi_tx_hs      , // HDMI输出行同步信号
    output  wire                            hdmi_tx_de      , // HDMI输出数据有效信号
    output  wire    [HDMI_DATA_WIDTH-1:0]   hdmi_tx_data      // HDMI输出数据
);
/****************************reg*****************************/
reg     [15:0]          rst_1ms     ;

/****************************wire****************************/
wire                        rst_n       ;

wire    [IMAGE_WIDTH-1:0]   pix_x       ;
wire    [IMAGE_WIDTH-1:0]   pix_y       ;
wire                        pix_req     ;
wire    [23:0]              pix_data    ;

/********************combinational logic*********************/
assign hdmi_rst_n  = (rst_1ms == 16'd50_000);
assign rst_n       = sys_rst_n && hdmi_rst_n && ddr_init_done;

/***********************instantiation************************/
ms72xx_init u_ms72xx_init(
    .sys_clk        (sys_clk        ), //input       clk,
    .sys_rst_n      (hdmi_rst_n     ), //input       rst_n,
    .init_over_tx   (hdmi_tx_init   ), //output      init_over,
    .init_over_rx   (hdmi_rx_init   ), //output      init_over,
    
    .iic_scl_tx     (hdmi_tx_scl    ), //output      iic_scl,
    .iic_sda_tx     (hdmi_tx_sda    ), //inout       iic_sda
    .iic_scl_rx     (hdmi_rx_scl    ), //output      iic_scl,
    .iic_sda_rx     (hdmi_rx_sda    )  //inout       iic_sda
);

video_driver #(
    .IMAGE_WIDTH    (IMAGE_WIDTH    ), // 图像宽高位宽
    
    .H_SYNC         (H_SYNC         ), // 行同步
    .H_BACK         (H_BACK         ), // 行显示后沿
    .H_DISP         (H_DISP         ), // 行有效数据
    .H_FRONT        (H_FRONT        ), // 行显示前沿
    .H_TOTAL        (H_TOTAL        ), // 行扫描周期
    
    .V_SYNC         (V_SYNC         ), // 场同步
    .V_BACK         (V_BACK         ), // 场显示后沿
    .V_DISP         (V_DISP         ), // 场有效数据
    .V_FRONT        (V_FRONT        ), // 场显示前沿
    .V_TOTAL        (V_TOTAL        )  // 场扫描周期
)u_video_driver(
    .pix_clk        (hdmi_tx_pix_clk), // input
    .rst_n          (rst_n          ), // input
    
    .video_hs       (hdmi_tx_hs     ), // output
    .video_vs       (hdmi_tx_vs     ), // output
    .video_de       (hdmi_tx_de     ), // output
    .video_data     (hdmi_tx_data   ), // output
    
    .pix_x          (pix_x          ), // output
    .pix_y          (pix_y          ), // output
    .pix_req        (pix_req        ), // output
    .pix_data       (pix_data       ), // input

    .frame_end      (frame_end      )  // output
);

video_display #(
    .IMAGE_WIDTH    (IMAGE_WIDTH    )  // 图像宽高位宽
)u_video_display(
    .pix_clk        (hdmi_tx_pix_clk),

    .pix_x          (pix_x          ), // input
    .pix_y          (pix_y          ), // input
    .pix_req        (pix_req        ), // input
    .pix_data       (pix_data       ), // output

    .disp_w         (disp_w         ), // input
    .disp_h         (disp_h         ), // input

    .pixel_req      (pixel_req      ), // output
    .pixel_data     (pixel_data     )  // input
);

/**************************process***************************/
always @(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        rst_1ms <= 16'd0;
    else if(rst_1ms == 16'd50_000)
        rst_1ms <= rst_1ms;
    else
        rst_1ms <= rst_1ms + 1'b1;
end

endmodule
