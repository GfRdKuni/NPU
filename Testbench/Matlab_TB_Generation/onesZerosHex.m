function hexStr = onesZerosHex(scale)
    % 输入 scale ∈ [0,8]
    if ~(isscalar(scale) && isnumeric(scale) && scale>=0 && scale<=8 && scale==floor(scale))
        error('scale 必须是 0 到 8 的整数');
    end
    % 生成 8 位二进制：高 scale 位全 1，低 (8-scale) 位全 0
    % 先构造低位全 1 的掩码 2^scale-1，再左移 (8-scale)
    if scale == 0
        pattern = uint8(0);
    else
        pattern = bitshift(uint8(2^scale - 1), 8 - scale);
    end
    % 转为 2 位十六进制字符串，不带 0x，大写，不足前导补零
    hexStr = dec2hex(pattern, 2);
end
