module video_processing_controller #(
    parameter SRC_W         = 11'd960   , // 源图像宽度
    parameter SRC_H         = 11'd540   , // 源图像高度
    parameter SCALE_FW      = 5'd8      , // 缩放倍数小数位数
    parameter IMAGE_WIDTH   = 5'd11       // 图像宽高位宽
)(
    input                               clk             ,
    input                               rst_n           ,

    // 配置信号
    input                               i_process_en    , // 开始一帧图像处理
    input           [IMAGE_WIDTH-1:0]   i_dst_w         , // 目的图像宽度
    input           [IMAGE_WIDTH-1:0]   i_dst_h         , // 目的图像高度
    output          [IMAGE_WIDTH-1:0]   o_dst_w         , // 处理后的宽度
    output          [IMAGE_WIDTH-1:0]   o_dst_h         , // 处理后的高度

    // DDR模块信号
    output                              o_process_start , // 一帧处理开始
    output  reg                         o_process_end   , // 一帧处理完成
    output  reg                         o_data_req      , // DDR 数据请求信号

    // 输入FIFO信号
    output                              o_fifo_i_rst    , // 输入FIFO 复位信号
    output                              o_fifo_i_wr_line, // 输入FIFO 写行选择
    output          [IMAGE_WIDTH-1:0]   o_fifo_i_wr_addr, // 输入FIFO 写地址
    output  reg                         o_fifo_i_wr_en  , // 输入FIFO 写使能
    output                              o_fifo_i_rd_line, // 输入FIFO 读行选择
    output          [IMAGE_WIDTH-1:0]   o_fifo_i_rd_addr, // 输入FIFO 读地址

    // 计算单元信号
    output  reg     [SCALE_FW-1:0]      o_offset_x      , // X方向偏移量
    output  reg     [SCALE_FW-1:0]      o_offset_y      , // Y方向偏移量
    output  reg                         o_bi_calc_en    , // 计算使能信号

    // 输出FIFO信号
    input                               i_fifo_o_full   , // 输出FIFO 将满信号

    // 显示信号
    input                               i_disp_vsync      // 显示的场同步信号
);
/*************************parameter**************************/
localparam ST_IDLE = 4'b0001; // 空闲
localparam ST_PREP = 4'b0010; // 准备数据，计算缩放比例
localparam ST_CALC = 4'b0100; // 计算
localparam ST_END  = 4'b1000; // 结束

localparam SCALE_WIDTH  = IMAGE_WIDTH + SCALE_FW; // 缩放倍数位宽

localparam [SCALE_WIDTH-1:0] DIVIDEND_X   = {SRC_W - 1, {SCALE_FW{1'b0}}}; // 将宽度左移小数位作为被除数
localparam [SCALE_WIDTH-1:0] DIVIDEND_Y   = {SRC_H - 1, {SCALE_FW{1'b0}}}; // 将高度左移小数位作为被除数

/****************************reg*****************************/
reg     [IMAGE_WIDTH-1:0]   r_dst_w             ; // 目的图像宽度
reg     [IMAGE_WIDTH-1:0]   r_dst_h             ; // 目的图像高度
reg     [IMAGE_WIDTH-1:0]   dst_x               ; // 目的图像 X 坐标
reg     [IMAGE_WIDTH-1:0]   dst_y               ; // 目的图像 Y 坐标
reg     [SCALE_WIDTH-1:0]   src_x_mapping       ; // 将目的坐标映射回源坐标
reg     [SCALE_WIDTH-1:0]   src_y_mapping       ; // 将目的坐标映射回源坐标

reg     [IMAGE_WIDTH-1:0]   src_x               ; // 源图像 X 坐标
reg     [IMAGE_WIDTH-1:0]   src_y               ; // 源图像 Y 坐标
reg     [IMAGE_WIDTH-1:0]   src_x_store         ; // 存储源图像 X 坐标
reg     [IMAGE_WIDTH-1:0]   src_y_store         ; // 存储源图像 X 坐标

reg     [3:0]               fsm_c               ; // 当前状态
reg     [3:0]               fsm_n               ; // 下一个状态

reg                         r_process_start     ; // 寄存显示的场同步信号

reg     [3:0]               cnt_state           ; // 状态内计数器

reg                         scale_done          ; // 缩放倍数计算完成

reg                         bi_calc_valid       ; // 当前可以计算信号（输入缓存有对应数据）

/****************************wire****************************/
wire                        store_done          ; // 初始储存完毕
wire                        store_end           ; // 全部储存完毕

wire                        process_start_pedge ; // 显示的场同步信号上升沿

wire    [SCALE_WIDTH-1:0]   scale_x             ; // X轴缩放倍数
wire    [SCALE_WIDTH-1:0]   scale_y             ; // Y轴缩放倍数
wire                        scale_x_valid       ; // X轴缩放倍数计算完成
wire                        scale_y_valid       ; // X轴缩放倍数计算完成

wire    [SCALE_WIDTH-1:0]   src_x_mapping_next  ;
wire    [SCALE_WIDTH-1:0]   src_y_mapping_next  ;
wire    [IMAGE_WIDTH-1:0]   src_x_mapping_int   ; // 映射坐标的整数部分
wire    [IMAGE_WIDTH-1:0]   src_y_mapping_int   ; // 映射坐标的整数部分
wire    [IMAGE_WIDTH-1:0]   src_x_mapping_int_n ; // 下一像素目的X坐标的映射坐标的整数部分
wire    [IMAGE_WIDTH-1:0]   src_y_mapping_int_n ; // 下一行目的Y坐标的映射坐标的整数部分

wire    [IMAGE_WIDTH-1:0]   dst_w               ; // 宽度-1
wire    [IMAGE_WIDTH-1:0]   dst_h               ; // 高度-1

/********************combinational logic*********************/
assign process_start_pedge  = i_process_en & !r_process_start;

assign o_process_start      = (fsm_c == ST_PREP) && (cnt_state != 4'd15);
assign o_fifo_i_rst         = o_process_end;

assign src_x_mapping_int    = src_x_mapping[SCALE_FW+:IMAGE_WIDTH];
assign src_y_mapping_int    = src_y_mapping[SCALE_FW+:IMAGE_WIDTH];

assign src_x_mapping_next   = (src_x == SRC_W - 1) ? scale_x : src_x_mapping + scale_x;
assign src_x_mapping_int_n  = src_x_mapping_next[SCALE_FW+:IMAGE_WIDTH];
assign src_y_mapping_next   = src_y_mapping + scale_y;
assign src_y_mapping_int_n  = src_y_mapping_next[SCALE_FW+:IMAGE_WIDTH];

assign o_fifo_i_wr_addr     = src_x_store;
assign o_fifo_i_rd_addr     = src_x_mapping_int;
assign o_fifo_i_wr_line     = src_y_store[0];
assign o_fifo_i_rd_line     = src_y_mapping_int[0];

assign store_done           = (src_y_store == src_y_mapping_int + 1) && 
                              (src_x_store >= src_x_mapping_int);
assign store_end            = (src_x_store >= SRC_W - 1) && (src_y_store == SRC_H - 1);

assign dst_w                = r_dst_w - 1;
assign dst_h                = r_dst_h - 1;

assign o_dst_w              = r_dst_w;
assign o_dst_h              = r_dst_h;

/***********************instantiation************************/
divider #(
    .DIVIDEND_WIDTH     (SCALE_WIDTH        ), // 被除数位宽
    .DIVISOR_WIDTH      (IMAGE_WIDTH        )  // 除数位宽(0 < DIVISOR_WIDTH <= DIVIDEND_WIDTH)
)u_divider_x(
    .clk                (clk                ),

    .i_divide_en        (process_start_pedge), // 计算使能
    .i_dividend         (DIVIDEND_X         ), // 被除数
    .i_divisor          (dst_w              ), // 除数

    .o_data_valid       (scale_x_valid      ), // 计算完成
    .o_quotient         (scale_x            ), // 商
    .o_remainder        (                   )  // 余数
);
divider #(
    .DIVIDEND_WIDTH     (SCALE_WIDTH        ), // 被除数位宽
    .DIVISOR_WIDTH      (IMAGE_WIDTH        )  // 除数位宽(0 < DIVISOR_WIDTH <= DIVIDEND_WIDTH)
)u_divider_y(
    .clk                (clk                ),

    .i_divide_en        (process_start_pedge), // 计算使能
    .i_dividend         (DIVIDEND_Y         ), // 被除数
    .i_divisor          (dst_h              ), // 除数

    .o_data_valid       (scale_y_valid      ), // 计算完成
    .o_quotient         (scale_y            ), // 商
    .o_remainder        (                   )  // 余数
);

/****************************FSM*****************************/
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        fsm_c <= ST_IDLE;
    else
        fsm_c <= fsm_n;
end

always@(*)
begin
    case(fsm_c)
        ST_IDLE:
            if(process_start_pedge)
                fsm_n = ST_PREP;
            else
                fsm_n = ST_IDLE;
        ST_PREP:
            if(store_done && scale_done)
                fsm_n = ST_CALC;
            else
                fsm_n = ST_PREP;
        ST_CALC:
            if((dst_x == r_dst_w - 1) && (dst_y == r_dst_h - 1) && bi_calc_valid)
                fsm_n = ST_END;
            else
                fsm_n = ST_CALC;
        ST_END:
            if(cnt_state == 4'd15)
                fsm_n = ST_IDLE;
            else
                fsm_n = ST_END;
        default:
                fsm_n = ST_IDLE;
    endcase
end

/**************************process***************************/
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            r_dst_w <= i_dst_w;
            r_dst_h <= i_dst_h;
        end
    else if(process_start_pedge)
        begin
            r_dst_w <= i_dst_w;
            r_dst_h <= i_dst_h;
        end
    else
        begin
            r_dst_w <= r_dst_w;
            r_dst_h <= r_dst_h;
        end
end

// 目的图像坐标
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dst_x <= 11'd0;
    else if(process_start_pedge)
        dst_x <= 11'd0;
    else if(bi_calc_valid)
        if(dst_x == r_dst_w - 1)
            dst_x <= 11'd0;
        else
            dst_x <= dst_x + 1;
    else
        dst_x <= dst_x;
end
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dst_y <= 11'd0;
    else if(process_start_pedge)
        dst_y <= 11'd0;
    else if(bi_calc_valid && (dst_x == r_dst_w - 1))
        dst_y <= dst_y + 1;
    else
        dst_y <= dst_y;
end

// 映射坐标
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_x_mapping <= 'd0;
    else if(process_start_pedge)
        src_x_mapping <= 'd0;
    else if(bi_calc_valid)
        if(dst_x == r_dst_w - 1)
            src_x_mapping <= 'd0;
        else
            src_x_mapping <= src_x_mapping + scale_x;
    else
        src_x_mapping <= src_x_mapping;
end
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_y_mapping <= 'd0;
    else if(process_start_pedge)
        src_y_mapping <= 'd0;
    else if(bi_calc_valid && (dst_x == r_dst_w - 1))
        src_y_mapping <= src_y_mapping + scale_y;
    else
        src_y_mapping <= src_y_mapping;
end

// 寄存器
always@(posedge clk)
begin
    r_process_start <= i_process_en ;
    o_bi_calc_en    <= bi_calc_valid;
    o_fifo_i_wr_en  <= o_data_req   ;
end

// 缩放倍数
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        scale_done <= 1'b0;
    else case(fsm_c)
        ST_IDLE:
            scale_done <= 1'b0;
        ST_PREP:
            if(scale_x_valid && scale_y_valid)
                scale_done <= 1'b1;
            else
                scale_done <= scale_done;
        default:
            scale_done <= scale_done;
    endcase
end

always@(*)
begin
    case(fsm_c)
        ST_CALC:
            if(!i_fifo_o_full)                                  // 输出FIFO 非满
                if(store_end)
                    bi_calc_valid = 1'b1;
                else if(src_y_store > src_y_mapping_int + 1)    // 计算行超过存储行
                    bi_calc_valid = 1'b1;
                else if(src_y_store == src_y_mapping_int + 1)   // 计算行等于存储行
                    if(src_x_store == SRC_W)                    // 当前行已经储存完毕
                        bi_calc_valid = 1'b1;
                    else if(src_x_store > src_x_mapping_int + 1)// 储存像素超过计算像素
                        bi_calc_valid = 1'b1;
                    else
                        bi_calc_valid = 1'b0;
                else
                    bi_calc_valid = 1'b0;
            else
                bi_calc_valid = 1'b0;
        default:
            bi_calc_valid = 1'b0;
    endcase
end

// DDR 数据请求信号
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        o_data_req <= 1'b0;
    else case(fsm_c)
        ST_PREP:
            o_data_req <= 1'b1;
        ST_CALC:
            if(store_end)
                o_data_req <= 1'b0;
            else if(src_y_mapping_int == src_y_store - 1)       // 当前行是我想要的
                if(src_x_store == SRC_W - 2)
                    o_data_req <= 1'b0;
                else if(src_x_store > SRC_W - 2)                // 当前行都输入了
                    if(src_y_mapping_int_n == src_y_store - 1)  // 需要计算的下一行也是当前行
                        o_data_req <= 1'b0;
                    else                                        // 需要计算的下一行不是当前行
                        if(src_x_mapping_int_n != 0)
                            if(o_data_req && (src_x_mapping_int_n == 1))
                                o_data_req <= 1'b0;
                            else
                                o_data_req <= 1'b1;
                        else
                            o_data_req <= 1'b0;
                else
                    o_data_req <= 1'b1;
            else if(src_y_mapping_int == src_y_store - 2)       // 储存行已经开始覆盖当前行了
                if(o_data_req)                                  // 正在请求数据
                    if(src_x + 1 < src_x_mapping_int)
                        o_data_req <= 1'b1;
                    else
                        o_data_req <= 1'b0;
                else
                    if(src_x < src_x_mapping_int)
                        o_data_req <= 1'b1;
                    else
                        o_data_req <= 1'b0;
            else
                if(src_x_store == SRC_W - 2)
                    o_data_req <= 1'b0;
                else
                    o_data_req <= 1'b1;
        default:
            o_data_req <= 1'b0;
    endcase
end

// 偏移量
always@(posedge clk)
begin
    o_offset_x <= src_x_mapping[0+:SCALE_FW];
    o_offset_y <= src_y_mapping[0+:SCALE_FW];
end

// 源图像坐标
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_x <= 11'd0;
    else if(process_start_pedge)
        src_x <= 11'd0;
    else if(o_data_req)
        if(src_x == SRC_W - 1)
            src_x <= 11'd0;
        else
            src_x <= src_x + 1;
    else
        src_x <= src_x;
end
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_y <= 11'd0;
    else if(process_start_pedge)
        src_y <= 11'd0;
    else if(o_data_req && (src_x == SRC_W - 1))
        src_y <= src_y + 1;
    else
        src_y <= src_y;
end

// 源图像储存坐标
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_x_store <= 11'd0;
    else case(fsm_c)
        ST_PREP:
            if(o_data_req)
                src_x_store <= src_x;
            else
                src_x_store <= src_x_store;
        ST_CALC:
            if(store_end)
                src_x_store <= src_x_store;
            else if(src_x_store == SRC_W - 1)
                src_x_store <= src_x_store + 1;
            else if(o_data_req)
                src_x_store <= src_x;
            else
                src_x_store <= src_x_store;
        default:
            src_x_store <= 11'd0;
    endcase
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        src_y_store <= 11'd0;
    else case(fsm_c)
        ST_PREP:
            if(src_x_store == SRC_W - 1)
                src_y_store <= src_y;
            else
                src_y_store <= src_y_store;
        ST_CALC:
            if(store_end)
                src_y_store <= src_y_store;
            else if(o_data_req && (src_x_store == SRC_W))
                src_y_store <= src_y;
            else
                src_y_store <= src_y_store;
        default:
            src_y_store <= 11'd0;
    endcase
end

// 状态中计数器
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        cnt_state <= 4'd0;
    else case(fsm_c)
        ST_PREP:
            if(cnt_state == 4'd15)
                cnt_state <= cnt_state;
            else
                cnt_state <= cnt_state + 1;
        ST_END:
            cnt_state <= cnt_state + 1;
        default:
            cnt_state <= 4'd0;
    endcase
end

always@(posedge clk)
begin
    if(fsm_c == ST_END)
        o_process_end <= 1'b1;
    else
        o_process_end <= 1'b0;
end

/*---------------------------------------------------*/


endmodule