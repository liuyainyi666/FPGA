module divider #(
    parameter DIVIDEND_WIDTH    = 5'd19 , // 被除数位宽
    parameter DIVISOR_WIDTH     = 5'd11   // 除数位宽(0 < DIVISOR_WIDTH <= DIVIDEND_WIDTH)
)(
    input                                   clk         ,

    input                                   i_divide_en , // 计算使能
    input           [DIVIDEND_WIDTH-1:0]    i_dividend  , // 被除数
    input           [DIVISOR_WIDTH-1:0]     i_divisor   , // 除数

    output                                  o_data_valid, // 计算完成
    output          [DIVIDEND_WIDTH-1:0]    o_quotient  , // 商
    output          [DIVISOR_WIDTH-1:0]     o_remainder   // 余数
);
/*************************parameter**************************/


/****************************reg*****************************/
reg                                         r_divide_en [DIVIDEND_WIDTH:0];
reg     [DIVIDEND_WIDTH+DIVISOR_WIDTH:0]    r_dividend  [DIVIDEND_WIDTH:0];
reg     [DIVISOR_WIDTH-1:0]                 r_divisor   [DIVIDEND_WIDTH:0];

/****************************wire****************************/
wire    [DIVISOR_WIDTH:0]                   difference  [DIVIDEND_WIDTH-1:0]; // 被除数与除数的差
wire                                        quotient_en [DIVIDEND_WIDTH-1:0]; // 被除数大于等于除数

/********************combinational logic*********************/
generate
    genvar i;
    for (i = 0; i < DIVIDEND_WIDTH; i = i + 1) begin:sub
        assign difference[i]    = r_dividend[i][DIVIDEND_WIDTH+:DIVISOR_WIDTH+1] - {1'b0, r_divisor[i]};
        assign quotient_en[i]   = r_dividend[i][DIVIDEND_WIDTH+:DIVISOR_WIDTH+1] >= {1'b0, r_divisor[i]};
    end
endgenerate

assign o_data_valid = r_divide_en[DIVIDEND_WIDTH];
assign o_quotient   = r_dividend[DIVIDEND_WIDTH][DIVIDEND_WIDTH-1:0];
assign o_remainder  = r_dividend[DIVIDEND_WIDTH][DIVIDEND_WIDTH+1+:DIVISOR_WIDTH];

/**************************process***************************/
generate
    genvar j;
    always@(posedge clk) r_divide_en[0] <= i_divide_en;
    always@(posedge clk) r_dividend[0]  <= {{DIVISOR_WIDTH{1'b0}}, i_dividend, 1'b0};
    always@(posedge clk) r_divisor[0]   <= i_divisor;
    for (j = 1; j <= DIVIDEND_WIDTH; j = j + 1) begin:sub_reg
        always@(posedge clk) r_divide_en[j] <= r_divide_en[j-1];
        always@(posedge clk) r_divisor[j]   <= r_divisor[j-1];
        always@(posedge clk) r_dividend[j]  <= quotient_en[j-1] ? {(difference[j-1] << 1), r_dividend[j-1][DIVIDEND_WIDTH-2:0], 1'b1} : (r_dividend[j-1] << 1);
    end
endgenerate

/*---------------------------------------------------*/


endmodule