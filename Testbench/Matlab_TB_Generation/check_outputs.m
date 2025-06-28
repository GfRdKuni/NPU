    % 重排并校验理论输出与实际输出（每次输出8个16位hex一组）
    % 假设：
    %   theory.txt: 每行一个 4 位十六进制字符串
    %   actual.log: 每行格式类似 "Time=...: valid_o=1, data_out_o=0x..."，
    %               data_out_o 为 8 个16位值拼接的长 hex 字符串
    %
    % 生成 matched.txt: 展平后的实际输出，每行一个 4 位 hex
    % 生成 mismatches.txt: 不匹配报告

    theory_file = 'result.txt';
    actual_file = 'actual.log';
    matched_file = 'matched.txt';
    mismatch_file = 'mismatches.txt';

    % 读取理论输出
    if ~isfile(theory_file)
        error('找不到理论输出文件 %s', theory_file);
    end
    fid = fopen(theory_file,'r');
    theory = textscan(fid, '%s'); fclose(fid);
    theory = theory{1};
    n_theory = numel(theory);

    % 读取实际日志，提取 data_out_o，当 valid_o=1 时解析
    if ~isfile(actual_file)
        error('找不到实际输出文件 %s', actual_file);
    end
    fid = fopen(actual_file,'r');
    actual_flat = {};  % 展平后每个16位hex一行
    tline = fgetl(fid);
    while ischar(tline)
        % 检查 valid_o=1
        m = regexp(tline, 'valid_o\s*=\s*1', 'once');
        if ~isempty(m)
            % 提取 data_out_o=0x... 部分
            tok = regexp(tline, 'data_out_o\s*=\s*0x([0-9A-Fa-f]+)', 'tokens');
            if ~isempty(tok)
                hexstr = upper(tok{1}{1});
                L = length(hexstr);
                if mod(L,4)~=0
                    error('数据长度不是4的倍数，无法按16位分割: %s', hexstr);
                end
                num16 = L/4;
                % 期望每次输出正好8个16位
                if num16 ~= 8
                    error('每次 data_out_o 应包含8个16位 hex，但得到 %d 个: %s', num16, hexstr);
                end
                % 按大端顺序从左到右每4字符为一个值
                for k = 1:8
                    substr = hexstr((k-1)*4+1 : k*4);
                    actual_flat{end+1,1} = substr; %#ok<AGROW>
                end
            else
                warning('未找到 data_out_o 字段: %s', tline);
            end
        end
        tline = fgetl(fid);
    end
    fclose(fid);

    % 写 matched.txt
    fid = fopen(matched_file,'w');
    if fid<0, error('无法打开 %s', matched_file); end
    for i = 1:numel(actual_flat)
        fprintf(fid, '%s\n', actual_flat{i});
    end
    fclose(fid);
    fprintf('已生成 %s，共 %d 行实际输出\n', matched_file, numel(actual_flat));

    % 比较与理论
    mismatches = {};
    n_actual = numel(actual_flat);
    n = min(n_theory, n_actual);
    for i = 1:n
        if ~strcmp(theory{i}, actual_flat{i})
            mismatches{end+1,1} = sprintf('Idx %d: theory=%s, actual=%s', i, theory{i}, actual_flat{i}); %#ok<AGROW>
        end
    end
    if n_actual > n_theory
        for i = n_theory+1:n_actual
            mismatches{end+1,1} = sprintf('Extra actual[%d]=%s', i, actual_flat{i}); %#ok<AGROW>
        end
    elseif n_theory > n_actual
        for i = n_actual+1:n_theory
            mismatches{end+1,1} = sprintf('Missing actual for theory[%d]=%s', i, theory{i}); %#ok<AGROW>
        end
    end

    % 写 mismatches.txt
    if ~isempty(mismatches)
        fid = fopen(mismatch_file,'w');
        for k = 1:numel(mismatches)
            fprintf(fid, '%s\n', mismatches{k});
        end
        fclose(fid);
        fprintf('发现 %d 处不匹配，详情见 %s\n', numel(mismatches), mismatch_file);
    else
        if isfile(mismatch_file)
            delete(mismatch_file);
        end
        fprintf('全部 %d 项匹配！\n', n);
    end
