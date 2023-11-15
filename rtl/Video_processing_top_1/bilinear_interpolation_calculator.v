module bilinear_interpolation_calculator#(
    parameter SCALE_FW      = 5'd8           // 缩放倍数小数位数
)(
    input                           clk             ,
    input                           rst_n           ,

    input           [7:0]           i_pix_data_00   , // 相邻的像素数据
    input           [7:0]           i_pix_data_01   , // 相邻的像素数据
    input           [7:0]           i_pix_data_10   , // 相邻的像素数据
    input           [7:0]           i_pix_data_11   , // 相邻的像素数据

    input           [SCALE_FW-1:0]  i_offset_x      , // X方向偏移量
    input           [SCALE_FW-1:0]  i_offset_y      , // Y方向偏移量
    input                           i_bi_calc_en    , // 计算使能信号

    output  wire                    o_pix_data_valid, // 计算结果有效信号
    output  reg     [7:0]           o_pix_data        // 双线性插值结果
);
/*************************parameter**************************/
localparam DELAY_TIME_STEP_0 = 4'd5;
localparam DELAY_TIME_STEP_1 = 4'd5;
localparam DELAY_TIME_TOTAL  = DELAY_TIME_STEP_0 + DELAY_TIME_STEP_1;

/****************************reg*****************************/
reg     [DELAY_TIME_TOTAL-1:0]  r_bi_calc_en    ;
reg     [SCALE_FW-1:0]          r_offset_y[DELAY_TIME_STEP_0-1:0];

/****************************wire****************************/
wire    [SCALE_FW:0]            offset_x_bar    ;
wire    [SCALE_FW:0]            offset_y_bar    ;

wire    [7+SCALE_FW:0]          line_data_0     ;
wire    [7+SCALE_FW:0]          line_data_1     ;

wire    [7+SCALE_FW*2:0]        pix_data_temp   ;

/********************combinational logic*********************/
// 也许可以用 ~offset 代替 (1-offset)
assign offset_x_bar = {1'b0, ~i_offset_x} + 1;
assign offset_y_bar = {1'b0, ~r_offset_y[DELAY_TIME_STEP_0-1]} + 1;

assign o_pix_data_valid = r_bi_calc_en[DELAY_TIME_TOTAL-1];

/***********************instantiation************************/
mul_add_u8_u9_u8_u9 line_0(
    .clk        (clk                ), // input
    .rst        (!rst_n             ), // input
    .ce         (1'b1               ), // input
    .a0         (i_pix_data_00      ), // input [7:0]
    .b0         (offset_x_bar       ), // input [8:0]
    .a1         (i_pix_data_01      ), // input [7:0]
    .b1         ({1'b0, i_offset_x} ), // input [8:0]
    .p          (line_data_0        )  // output [17:0]
);

mul_add_u8_u9_u8_u9 line_1(
    .clk        (clk                ), // input
    .rst        (!rst_n             ), // input
    .ce         (1'b1               ), // input
    .a0         (i_pix_data_10      ), // input [7:0]
    .b0         (offset_x_bar       ), // input [8:0]
    .a1         (i_pix_data_11      ), // input [7:0]
    .b1         ({1'b0, i_offset_x} ), // input [8:0]
    .p          (line_data_1        )  // output [17:0]
);

mul_add_u9_u16_u9_u16 output_data(
    .clk        (clk                ), // input
    .rst        (!rst_n             ), // input
    .ce         (1'b1               ), // input
    .a0         (offset_y_bar       ), // input [8:0]
    .b0         (line_data_0        ), // input [15:0]
    .a1         ({1'b0, r_offset_y[DELAY_TIME_STEP_0-1]}), // input [8:0]
    .b1         (line_data_1        ), // input [15:0]
    .p          (pix_data_temp      )  // output [25:0]
);

/****************************FSM*****************************/


/**************************process***************************/
always@(posedge clk) r_offset_y[0] <= i_offset_y;
generate
    genvar j;
    for (j = 1; j < DELAY_TIME_STEP_0; j = j + 1) begin:step_0
        always@(posedge clk) r_offset_y[j] <= r_offset_y[j-1];
    end
endgenerate

always@(*)
begin
    if(pix_data_temp[SCALE_FW*2+:8] == 8'd255)
        o_pix_data = 8'd255;
    else
        o_pix_data = pix_data_temp[SCALE_FW*2-1] ? pix_data_temp[SCALE_FW*2+:8] + 1
                     : pix_data_temp[SCALE_FW*2+:8];
end

always@(posedge clk) r_bi_calc_en[0] <= i_bi_calc_en;
generate
    genvar i;
    for (i = 1; i < DELAY_TIME_TOTAL; i = i + 1) begin:delay
        always@(posedge clk) r_bi_calc_en[i] <= r_bi_calc_en[i-1];
    end
endgenerate

/*---------------------------------------------------*/


endmodule