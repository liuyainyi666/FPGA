module Video_processing_top_1 #(
    parameter DATA_CHANNEL  = 2'd3      , // 颜色通道数
    parameter SRC_WIDTH     = 11'd960   , // 源图像宽度
    parameter SRC_HEIGHT    = 11'd540   , // 源图像高度
    parameter SCALE_FW      = 5'd8      , // 缩放倍数小数位数
    parameter IMAGE_WIDTH   = 5'd11       // 图像宽高位宽
)(
    input                                   sys_clk                 , // 系统时钟
    input                                   output_clk              , // 后端时钟
    input                                   sys_rst_n               , // 系统复位

    // 图像信息
    input           [IMAGE_WIDTH-1:0]       i_dst_w                 , // 目的图像宽度
    input           [IMAGE_WIDTH-1:0]       i_dst_h                 , // 目的图像高度

    // 处理前信号
    output                                  o_raw_rst               , // 前端复位
    output                                  o_raw_data_req          , // 前端数据请求
    input           [8*DATA_CHANNEL-1:0]    i_raw_data              , // 前端输入数据

    // 处理后信号
    input                                   i_processed_data_req    , // 后端请求数据
    output          [8*DATA_CHANNEL-1:0]    o_processed_data        , // 后端输出数据
    input                                   i_fifo_o_rst            , // 输出FIFO 复位

    // 显示信号
    input                                   i_disp_vsync              // 显示的场同步信号
);
/*************************parameter**************************/


/****************************reg*****************************/
reg                             r_fifo_o_rst    ;
reg                             fifo_o_rst      ;

/****************************wire****************************/
wire                            fifo_i_rst      ; // 输入FIFO 复位信号
wire                            fifo_i_wr_line  ; // 输入FIFO 写行选择
wire    [IMAGE_WIDTH-1:0]       fifo_i_wr_addr  ; // 输入FIFO 写地址
wire                            fifo_i_wr_en    ; // 输入FIFO 写使能
wire                            fifo_i_rd_line  ; // 输入FIFO 读行选择
wire    [IMAGE_WIDTH-1:0]       fifo_i_rd_addr  ; // 输入FIFO 读地址
    
wire    [8*DATA_CHANNEL-1:0]    pix_data_00     ; // 相邻的像素数据
wire    [8*DATA_CHANNEL-1:0]    pix_data_01     ; // 相邻的像素数据
wire    [8*DATA_CHANNEL-1:0]    pix_data_10     ; // 相邻的像素数据
wire    [8*DATA_CHANNEL-1:0]    pix_data_11     ; // 相邻的像素数据

wire    [SCALE_FW-1:0]          offset_x        ; // X方向偏移量
wire    [SCALE_FW-1:0]          offset_y        ; // Y方向偏移量
wire                            bi_calc_en      ; // 计算使能信号
wire    [DATA_CHANNEL-1:0]      pix_data_valid  ; // 计算结果有效信号
wire    [8*DATA_CHANNEL-1:0]    pix_data        ; // 双线性插值结果

wire                            fifo_o_full     ; // 输出FIFO 将满信号
wire    [DATA_CHANNEL-1:0]      fifo_o_empty    ;
wire    [DATA_CHANNEL-1:0]      fifo_o_almost_full;

/********************combinational logic*********************/
assign fifo_o_full = |fifo_o_almost_full;

/***********************instantiation************************/
video_processing_controller #(
    .SRC_W                  (SRC_WIDTH          ), // 源图像宽度
    .SRC_H                  (SRC_HEIGHT         ), // 源图像高度
    .SCALE_FW               (SCALE_FW           ), // 缩放倍数小数位数
    .IMAGE_WIDTH            (IMAGE_WIDTH        )  // 图像宽高位宽
)u_video_processing_controller(
    .clk                    (sys_clk            ),
    .rst_n                  (sys_rst_n          ),

    // 图像信息
    .i_process_en           (i_disp_vsync       ),
    .i_dst_w                (i_dst_w            ), // 目的图像宽度
    .i_dst_h                (i_dst_h            ), // 目的图像高度

    // DDR模块信号
    .o_process_end          (o_raw_rst          ), // DDR 输出FIFO 复位信号
    .o_data_req             (o_raw_data_req     ), // DDR 数据请求信号

    // 输入FIFO信号
    .o_fifo_i_rst           (fifo_i_rst         ), // 输入FIFO 复位信号
    .o_fifo_i_wr_line       (fifo_i_wr_line     ), // 输入FIFO 写行选择
    .o_fifo_i_wr_addr       (fifo_i_wr_addr     ), // 输入FIFO 写地址
    .o_fifo_i_wr_en         (fifo_i_wr_en       ), // 输入FIFO 写使能
    .o_fifo_i_rd_line       (fifo_i_rd_line     ), // 输入FIFO 读行选择
    .o_fifo_i_rd_addr       (fifo_i_rd_addr     ), // 输入FIFO 读地址

    // 计算单元信号
    .o_offset_x             (offset_x           ), // X方向偏移量
    .o_offset_y             (offset_y           ), // Y方向偏移量
    .o_bi_calc_en           (bi_calc_en         ), // 计算使能信号

    // 输出FIFO信号
    .i_fifo_o_full          (fifo_o_full        )  // 输出FIFO 将满信号
);


generate
    genvar i;
    for (i = 0; i < DATA_CHANNEL; i = i + 1) begin:data_channel
        input_ram_matrix #(
            .IMAGE_WIDTH            (IMAGE_WIDTH                )// 图像宽高位宽
        )u_input_ram_matrix(
            .clk                    (sys_clk                    ),
            .rst_n                  (sys_rst_n                  ),
                
            // DDR 模块信号
            .i_ddr_data             (i_raw_data[8*i+:8]         ), // DDR 数据

            // 控制模块信号
            .i_fifo_i_rst           (fifo_i_rst                 ), // 输入FIFO 复位信号
            .i_fifo_i_wr_line       (fifo_i_wr_line             ), // 输入FIFO 写行选择
            .i_fifo_i_wr_addr       (fifo_i_wr_addr             ), // 输入FIFO 写地址
            .i_fifo_i_wr_en         (fifo_i_wr_en               ), // 输入FIFO 写使能
            .i_fifo_i_rd_line       (fifo_i_rd_line             ), // 输入FIFO 读行选择
            .i_fifo_i_rd_addr       (fifo_i_rd_addr             ), // 输入FIFO 读地址

            // 计算单元模块
           .i_pix_data_00           (pix_data_00[8*i+:8]        ), // 相邻的像素数据
           .i_pix_data_01           (pix_data_01[8*i+:8]        ), // 相邻的像素数据
           .i_pix_data_10           (pix_data_10[8*i+:8]        ), // 相邻的像素数据
           .i_pix_data_11           (pix_data_11[8*i+:8]        )  // 相邻的像素数据
        );

        bilinear_interpolation_calculator u_bilinear_interpolation_calculator(
            .clk                    (sys_clk                    ),
            .rst_n                  (sys_rst_n                  ),

            .i_pix_data_00          (pix_data_00[8*i+:8]        ), // 相邻的像素数据
            .i_pix_data_01          (pix_data_01[8*i+:8]        ), // 相邻的像素数据
            .i_pix_data_10          (pix_data_10[8*i+:8]        ), // 相邻的像素数据
            .i_pix_data_11          (pix_data_11[8*i+:8]        ), // 相邻的像素数据
        
            .i_offset_x             (offset_x                   ), // X方向偏移量
            .i_offset_y             (offset_y                   ), // Y方向偏移量
            .i_bi_calc_en           (bi_calc_en                 ), // 计算使能信号

            .o_pix_data_valid       (pix_data_valid[i]          ), // 计算结果有效信号
            .o_pix_data             (pix_data[8*i+:8]           )  // 双线性插值结果
        );

        fifo_4096x8 u_fifo_4096x8(
            .wr_clk                 (sys_clk                    ), // input
            .wr_rst                 (i_fifo_o_rst || !sys_rst_n ), // input
            .wr_en                  (pix_data_valid[i]          ), // input
            .wr_data                (pix_data[8*i+:8]           ), // input [7:0]
            .wr_full                (                           ), // output
            .almost_full            (fifo_o_almost_full[i]      ), // output
            .rd_clk                 (output_clk                 ), // input
            .rd_rst                 (i_fifo_o_rst || !sys_rst_n ), // input
            .rd_en                  (i_processed_data_req       ), // input
            .rd_data                (o_processed_data[8*i+:8]   ), // output [7:0]
            .rd_empty               (fifo_o_empty[i]            ), // output
            .almost_empty           (                           )  // output
        );
    end
endgenerate

/****************************FSM*****************************/


/**************************process***************************/
always@(posedge output_clk)
begin
    r_fifo_o_rst <= i_fifo_o_rst;
end

always@(posedge output_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        fifo_o_rst <= 1'b0;
    else if(i_fifo_o_rst && ! r_fifo_o_rst)
        fifo_o_rst <= 1'b1;
    else if(&fifo_o_empty)
        fifo_o_rst <= 1'b0;
    else
        fifo_o_rst <= fifo_o_rst;
        
end

/*---------------------------------------------------*/


endmodule