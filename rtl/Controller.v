module Controller #(
    parameter KEY_NUM       = 3'd4      , // 按键数量
    parameter HDMI_W        = 11'd1920  , // HDMI 显示宽度
    parameter HDMI_H        = 11'd1080  , // HDMI 显示高度
    parameter CAM_W         = 11'd960   , // 摄像头 输入宽度
    parameter CAM_H         = 11'd540   , // 摄像头 输入高度
    parameter IMAGE_WIDTH   = 5'd11       // 图像宽高位宽
)(
    input                                   sys_clk                 , // 系统时钟
    input                                   sys_rst_n               , // 系统复位
    input           [KEY_NUM-1:0]           key                     , // 按键

    // HDMI 模块信号
    input                                   i_frame_end             , // 一帧完成
    output  reg     [IMAGE_WIDTH-1:0]       o_disp_w                , // 有效显示宽度
    output  reg     [IMAGE_WIDTH-1:0]       o_disp_h                  // 有效显示高度
);
/*************************parameter**************************/
localparam DELAY_TOP    = 20'd1_000_000;

/****************************reg*****************************/
reg     [KEY_NUM-1:0]       r_key           ; // 寄存按键信息
reg     [19:0]              delay_cnt       ; // 按键延时计数器
reg     [KEY_NUM-1:0]       key_value       ; // 消抖后的按键信息（高电平有效）
reg                         key_valid       ; // 按键信息有效信号

reg                         r_frame_end     ; // 寄存

reg     [IMAGE_WIDTH-1:0]   r_disp_w        ; // 临时有效显示宽度
reg     [IMAGE_WIDTH-1:0]   r_disp_h        ; // 临时有效显示高度

/****************************wire****************************/
wire                        key_trigger     ; // 等待完成信号

wire                        frame_end_pedge ; // 一帧完成信号上升沿

/********************combinational logic*********************/
assign key_trigger = (delay_cnt == DELAY_TOP - 1'b1) ? 1'b1 : 1'b0;

assign frame_end_pedge  = i_frame_end && !r_frame_end;

/**************************process***************************/
/*有效显示高宽改变---------------------------------------------------*/
always@(posedge sys_clk)
begin
    r_frame_end <= i_frame_end;
end

always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        begin
            r_disp_w <= HDMI_W;
            r_disp_h <= HDMI_H;
        end
    else if(key_valid)
        case(key_value)
            4'b0001:
                if(r_disp_w == HDMI_W)
                    r_disp_w <= r_disp_w;
                else
                    r_disp_w <= r_disp_w + 10;
            4'b0010:
                if(r_disp_w == 11'd250)
                    r_disp_w <= r_disp_w;
                else
                    r_disp_w <= r_disp_w - 10;
            4'b0100:
                if(r_disp_h == HDMI_H)
                    r_disp_h <= r_disp_h;
                else
                    r_disp_h <= r_disp_h + 10;
            4'b1000:
                if(r_disp_h == 11'd250)
                    r_disp_h <= r_disp_h;
                else
                    r_disp_h <= r_disp_h - 10;
            default:
                begin
                    r_disp_w <= r_disp_w;
                    r_disp_h <= r_disp_h;
                end
        endcase
end

always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        begin
            o_disp_w <= HDMI_W;
            o_disp_h <= HDMI_H;
        end
    else if(frame_end_pedge)
        begin
            o_disp_w <= r_disp_w;
            o_disp_h <= r_disp_h;
        end
    else
        begin
            o_disp_w <= o_disp_w;
            o_disp_h <= o_disp_h;
        end
end

/*按键消抖---------------------------------------------------*/
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        r_key <= {KEY_NUM{1'b1}};
    else
        r_key <= key;
end

// 当按键改变时，需等待一段时间再读取按键信息
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        delay_cnt <= 20'd0;
    else if((key == r_key) && (key != {KEY_NUM{1'b1}}))
        if(delay_cnt <= DELAY_TOP)
            delay_cnt <= delay_cnt + 1'b1;
        else
            delay_cnt <= DELAY_TOP;
    else // 当按键信息改变时清零计数器
        delay_cnt <= 20'd0;
end

always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        key_value <= {KEY_NUM{1'b0}};
    else if(key_trigger)
        key_value <= ~r_key;
    else
        key_value <= key_value;
end

// key_trigger信号延时一个周期
always@(posedge sys_clk or negedge sys_rst_n)
begin
    if(!sys_rst_n)
        key_valid <= 1'b0;
    else
        key_valid <= key_trigger;
end

/*---------------------------------------------------*/


endmodule