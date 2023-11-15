module input_ram_matrix #(
    parameter IMAGE_WIDTH   = 4'd11       // 图像宽高位宽
)(
    input                               clk             ,
    input                               rst_n           ,
        
    // DDR 模块信号
    input           [7:0]               i_ddr_data      , // DDR 数据

    // 控制模块信号
    input                               i_fifo_i_rst    , // 输入FIFO 复位信号
    input                               i_fifo_i_wr_line, // 输入FIFO 写行选择
    input           [IMAGE_WIDTH-1:0]   i_fifo_i_wr_addr, // 输入FIFO 写地址
    input                               i_fifo_i_wr_en  , // 输入FIFO 写使能
    input                               i_fifo_i_rd_line, // 输入FIFO 读行选择
    input           [IMAGE_WIDTH-1:0]   i_fifo_i_rd_addr, // 输入FIFO 读地址

    // 计算单元模块
    output          [7:0]               i_pix_data_00   , // 相邻的像素数据
    output          [7:0]               i_pix_data_01   , // 相邻的像素数据
    output          [7:0]               i_pix_data_10   , // 相邻的像素数据
    output          [7:0]               i_pix_data_11     // 相邻的像素数据
);
/*************************parameter**************************/


/****************************reg*****************************/
reg                         r_fifo_i_rd_line;

/****************************wire****************************/
wire                        line_0_wr_en    ;
wire                        line_1_wr_en    ;

wire    [7:0]               line_0_0_data   ;
wire    [7:0]               line_0_1_data   ;
wire    [7:0]               line_1_0_data   ;
wire    [7:0]               line_1_1_data   ;

wire    [IMAGE_WIDTH-1:0]   fifo_i_rd_addr  ;

/********************combinational logic*********************/
assign line_0_wr_en  = !i_fifo_i_wr_line & i_fifo_i_wr_en;
assign line_1_wr_en  =  i_fifo_i_wr_line & i_fifo_i_wr_en;

assign i_pix_data_00 = !r_fifo_i_rd_line ? line_0_0_data : line_1_0_data;
assign i_pix_data_01 = !r_fifo_i_rd_line ? line_0_1_data : line_1_1_data;
assign i_pix_data_10 =  r_fifo_i_rd_line ? line_0_0_data : line_1_0_data;
assign i_pix_data_11 =  r_fifo_i_rd_line ? line_0_1_data : line_1_1_data;

assign fifo_i_rd_addr= i_fifo_i_rd_addr + 1;

/***********************instantiation************************/
ram_s_d_2048x8 line_0_0(
    .wr_clk         (clk                ), // input
    .wr_rst         (i_fifo_i_rst || !rst_n), // input
    .wr_addr        (i_fifo_i_wr_addr   ), // input [10:0]
    .wr_en          (line_0_wr_en       ), // input
    .wr_data        (i_ddr_data         ), // input [7:0]
    .rd_clk         (clk                ), // input
    .rd_rst         (i_fifo_i_rst || !rst_n), // input
    .rd_addr        (i_fifo_i_rd_addr   ), // input [10:0]
    .rd_data        (line_0_0_data      )  // output [7:0]
);

ram_s_d_2048x8 line_0_1(
    .wr_clk         (clk                ), // input
    .wr_rst         (i_fifo_i_rst || !rst_n), // input
    .wr_addr        (i_fifo_i_wr_addr   ), // input [10:0]
    .wr_en          (line_0_wr_en       ), // input
    .wr_data        (i_ddr_data         ), // input [7:0]
    .rd_clk         (clk                ), // input
    .rd_rst         (i_fifo_i_rst || !rst_n), // input
    .rd_addr        (fifo_i_rd_addr     ), // input [10:0]
    .rd_data        (line_0_1_data      )  // output [7:0]
);

ram_s_d_2048x8 line_1_0(
    .wr_clk         (clk                ), // input
    .wr_rst         (i_fifo_i_rst || !rst_n), // input
    .wr_addr        (i_fifo_i_wr_addr   ), // input [10:0]
    .wr_en          (line_1_wr_en       ), // input
    .wr_data        (i_ddr_data         ), // input [7:0]
    .rd_clk         (clk                ), // input
    .rd_rst         (i_fifo_i_rst || !rst_n), // input
    .rd_addr        (i_fifo_i_rd_addr   ), // input [10:0]
    .rd_data        (line_1_0_data      )  // output [7:0]
);

ram_s_d_2048x8 line_1_1(
    .wr_clk         (clk                ), // input
    .wr_rst         (i_fifo_i_rst || !rst_n), // input
    .wr_addr        (i_fifo_i_wr_addr   ), // input [10:0]
    .wr_en          (line_1_wr_en       ), // input
    .wr_data        (i_ddr_data         ), // input [7:0]
    .rd_clk         (clk                ), // input
    .rd_rst         (i_fifo_i_rst || !rst_n), // input
    .rd_addr        (fifo_i_rd_addr     ), // input [10:0]
    .rd_data        (line_1_1_data      )  // output [7:0]
);

/****************************FSM*****************************/


/**************************process***************************/
always@(posedge clk)
begin
    r_fifo_i_rd_line <= i_fifo_i_rd_line;
end

/*---------------------------------------------------*/


endmodule