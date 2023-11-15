module video_display#(
    parameter IMAGE_WIDTH   = 5'd11       // 图像宽高位宽
)(
    input                               pix_clk     ,

    input   wire    [IMAGE_WIDTH-1:0]   pix_x       ,
    input   wire    [IMAGE_WIDTH-1:0]   pix_y       ,
    input   wire                        pix_req     ,
    output  reg     [23:0]              pix_data    ,

    input   wire    [IMAGE_WIDTH-1:0]   disp_w      ,
    input   wire    [IMAGE_WIDTH-1:0]   disp_h      ,

    output  reg                         pixel_req   ,
    input   wire    [23:0]              pixel_data  
);
/*************************parameter**************************/
localparam WHITE  = 24'b11111111_11111111_11111111;  //RGB888 白色
localparam BLACK  = 24'b00000000_00000000_00000000;  //RGB888 黑色
localparam RED    = 24'b11111111_00001100_00000000;  //RGB888 红色
localparam GREEN  = 24'b00000000_11111111_00000000;  //RGB888 绿色
localparam BLUE   = 24'b00000000_00000000_11111111;  //RGB888 蓝色
localparam YELLOW = 24'b11111111_11111111_00000000;  //RGB888 黄色
localparam PURPLE = 24'b11111111_00000000_11111111;  //RGB888 紫色
localparam CYAN   = 24'b00000000_11111111_11111111;  //RGB888 青色

/****************************wire****************************/
wire            req_valid   ;
reg             data_valid  ;

/********************combinational logic*********************/
assign req_valid = (pix_x < disp_w) && (pix_y < disp_h);

/**************************process***************************/
always@(posedge pix_clk)
begin
    data_valid <= req_valid;
end

always@(*)
begin
    if(data_valid)
        pix_data = pixel_data;
    else
        pix_data = WHITE;
end

always@(*)
begin
    if(req_valid)
        pixel_req = pix_req;
    else
        pixel_req = 1'b0;
end

endmodule
