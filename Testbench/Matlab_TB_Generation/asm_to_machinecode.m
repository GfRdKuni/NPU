function asm_to_machinecode(input_filename, output_filename)
    % asm_to_machinecode 将汇编指令转换为 16 位机器码
    % 输入：
    %   input_filename: 汇编文本文件路径，每行一条指令
    %   output_filename: 输出文件路径，每行一个 16 位机器码（十六进制）
    %
    % 假设指令格式（基于前面讨论的编码规则）：
    %   LOAD:   opcode=000, [12:9]=rd,   [8:5]=rs,   [4:0]=imm5 (hex)
    %   STORE:  opcode=001, [12:9]=ignored/'/', [8:5]=rs1, [4:0]=rs2 (hex)
    %   MOV:    opcode=010, [12:9]=rd,   [8:1]=imm8 (hex), [0]=func ($0/$1)
    %   VLOAD:  opcode=100, [12:9]=vrd,  [8:5]=rs,   [4:0]=imm5 (hex)
    %   VSTORE: opcode=101, [12:9]=ignored/'/', [8:5]=rs, [4:0]=vrs
    %   VMAC-s: opcode=110, [12:9]=vrd,  [8:5]=vrs,  [4:1]=rs, [0]=func
    %
    % 所有立即数 token 均为十六进制字符串，如 '0A','28','A0' 等，不支持十进制立即数。
    %
    % 例：MOV r1 02 $1，02 表示 hex 0x02；Load r5 r3 0A 表示 imm5=0x0A。
    
    fid = fopen(input_filename, 'r');
    if fid < 0
        error('无法打开输入文件 %s', input_filename);
    end
    fid_out = fopen(output_filename, 'w');
    if fid_out < 0
        fclose(fid);
        error('无法打开输出文件 %s', output_filename);
    end
    
    lineNum = 0;
    while ~feof(fid)
        tline = strtrim(fgetl(fid));
        lineNum = lineNum + 1;
        if isempty(tline) || startsWith(tline, '%')
            continue;
        end
        
        tokens = strsplit(tline);
        instr = tokens{1};
        word = uint32(0);
        try
            switch lower(instr)
                case 'load'
                    % 格式: Load r<rd> r<rs> <imm5_hex>
                    if numel(tokens) < 4
                        error('LOAD 指令格式错误');
                    end
                    rd  = parse_register_or_slash(tokens{2});
                    rs  = parse_register_or_slash(tokens{3});
                    imm = parse_imm(tokens{4}, 5);
                    opcode = uint32(bin2dec('000'));
                    word = bitshift(opcode, 13) + bitshift(uint32(rd), 9) + bitshift(uint32(rs), 5) + uint32(imm);
                    
                case 'store'
                    % 格式: Store / r<rs1> r<rs2>
                    if numel(tokens) < 4
                        error('STORE 指令格式错误');
                    end
                    idx = 2;
                    if strcmp(tokens{idx}, '/')
                        idx = idx + 1;
                    end
                    rs1 = parse_register_or_slash(tokens{idx});
                    idx = idx + 1;
                    if idx > numel(tokens)
                        error('STORE 缺少第二寄存器');
                    end
                    rs2 = parse_register_or_slash(tokens{idx});
                    opcode = uint32(bin2dec('001'));
                    % [12:9]=0, [8:5]=rs1, [4:0]=rs2
                    word = bitshift(opcode, 13) + bitshift(uint32(rs1), 5) + bitshift(uint32(rs2),1);
                    
                case 'mov'
                    % 格式: MOV r<rd> <imm8_hex> $<func>
                    if numel(tokens) < 4
                        error('MOV 指令格式错误');
                    end
                    rd   = parse_register_or_slash(tokens{2});
                    imm8 = parse_imm_hex(tokens{3}, 8);
                    func = parse_imm(tokens{4}(2:end), 1); % tokens{4} 格式 '$0' 或 '$1'，去掉 '$'
                    opcode = uint32(bin2dec('010'));
                    word = bitshift(opcode, 13) + bitshift(uint32(rd), 9) + bitshift(uint32(imm8), 1) + uint32(func);
                    
                case 'vload'
                    % 格式: Vload vr<vd> r<rs> <imm5_hex>
                    if numel(tokens) < 4
                        error('VLOAD 指令格式错误');
                    end
                    vrd = parse_register_or_slash(tokens{2});
                    rs  = parse_register_or_slash(tokens{3});
                    imm = parse_imm(tokens{4}, 5);
                    opcode = uint32(bin2dec('100'));
                    word = bitshift(opcode, 13) + bitshift(uint32(vrd), 9) + bitshift(uint32(rs), 5) + uint32(imm);
                    
                case 'vstore'
                    % 格式: VStore / r<rs> vr<vs>
                    if numel(tokens) < 4
                        error('VSTORE 指令格式错误');
                    end
                    idx = 2;
                    if strcmp(tokens{idx}, '/')
                        idx = idx + 1;
                    end
                    rs  = parse_register_or_slash(tokens{idx});
                    idx = idx + 1;
                    if idx > numel(tokens)
                        error('VSTORE 缺少 vrs');
                    end
                    vrs = parse_register_or_slash(tokens{idx});
                    opcode = uint32(bin2dec('101'));
                    % [12:9]=0, [8:5]=rs, [4:0]=vrs
                    word = bitshift(opcode, 13) + bitshift(uint32(rs), 5) + bitshift(uint32(vrs),1);
                    
                case {'vmac-s','vmac_s'}
                    % 格式: VMAC-s vr<vd> r<rs> vr<vs> $<func>
                    if numel(tokens) < 5
                        error('VMAC-s 指令格式错误');
                    end
                    vrd_token = tokens{2};
                    rs_token  = tokens{3};
                    vrs_token = tokens{4};
                    func_token= tokens{5};
                    vrd = parse_register_or_slash(vrd_token);
                    rs  = parse_register_or_slash(rs_token);
                    vrs = parse_register_or_slash(vrs_token);
                    func = parse_imm(func_token(2:end), 1); % '$0'/'$1'
                    opcode = uint32(bin2dec('110'));
                    word = bitshift(opcode, 13) + bitshift(uint32(vrd), 9) + bitshift(uint32(rs), 5) + bitshift(uint32(vrs),1) + uint32(func);
                    
                otherwise
                    error('第 %d 行: 未知指令 "%s"', lineNum, instr);
            end
            
            % 限制为 16 位
            word16 = bitand(uint16(word), uint16(65535));
            fprintf(fid_out, '%04X\n', word16);
            
        catch ME
            warning('第 %d 行解析出错: %s\n  原行: %s', lineNum, ME.message, tline);
            % 跳过此行
        end
    end
    
    fclose(fid);
    fclose(fid_out);
    fprintf('汇编已转换完毕，机器码写入 %s\n', output_filename);
end

%% 辅助：解析寄存器或 '/' 占位
function regnum = parse_register_or_slash(token)
    token = strtrim(token);
    if strcmp(token, '/')
        regnum = 0;
        return;
    end
    if startsWith(token, 'vr', 'IgnoreCase', true)
        numStr = token(3:end);
    elseif startsWith(token, 'r', 'IgnoreCase', true)
        numStr = token(2:end);
    else
        error('寄存器格式错误: %s', token);
    end
    regnum = str2double(numStr);
    if isnan(regnum) || regnum < 0 || regnum > 15
        error('寄存器编号超出范围: %s', token);
    end
end

%% 辅助：解析立即数，仅按十六进制解析
function imm = parse_imm_hex(token, bitWidth)
    % token: 十六进制字符串，如 '0A','28','A0'，或 func 位则为 '0'/'1'
    token = strtrim(token);
    % 去掉可能的 '0x' 前缀
    if startsWith(token, '0x', 'IgnoreCase', true)
        token2 = token(3:end);
    else
        token2 = token;
    end
    % hex2dec 对大小写不敏感
    val = hex2dec(token2);
    maxVal = 2^bitWidth - 1;
    if val < 0 || val > maxVal
        error('立即数超出范围 (0 ~ %d): %s', maxVal, token);
    end
    imm = uint32(val);
end

function imm = parse_imm(token, bitWidth)
    token = strtrim(token);
    if startsWith(token, '$')
        token2 = token(2:end);
        val = str2double(token2);
    else
        % 支持十六进制或十进制
        if ~isempty(regexp(token, '[A-Fa-f]', 'once'))
            val = hex2dec(token);
        else
            val = str2double(token);
        end
    end
    if isnan(val)
        error('立即数解析失败: %s', token);
    end
    maxVal = 2^bitWidth - 1;
    if val < 0 || val > maxVal
        error('立即数超出范围 (0 ~ %d): %s', maxVal, token);
    end
    imm = uint32(val);
end