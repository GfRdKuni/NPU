function tb_generation(machineCodeFile, abcFile, outputFile)
% 合并机器码与 ABC 文件到三列格式输出

% 打开机器码文件读取
fid_mc = fopen(machineCodeFile, 'r');
if fid_mc < 0
    error('无法打开机器码文件 %s', machineCodeFile);
end

% 打开输出文件，若存在则覆盖
fid_out = fopen(outputFile, 'w');
if fid_out < 0
    fclose(fid_mc);
    error('无法打开输出文件 %s', outputFile);
end

% 逐行读取机器码，按三列格式写入：1 machinecode address
addr = uint32(0);
while ~feof(fid_mc)
    line = strtrim(fgetl(fid_mc));
    if isempty(line)
        continue;
    end
    % 假设 line 即机器码字符串，如 '4205'。若有其它格式请先处理。
    % 写：第一列 '1'，第二列机器码，第三列地址（从0开始，顺次+1），16进制4位
    fprintf(fid_out, '1 %s %04X\n', line, addr);
    addr = addr + 1;
end
fclose(fid_mc);

% 打开 ABC 文件读取，逐行 append 到输出文件尾
fid_abc = fopen(abcFile, 'r');
if fid_abc < 0
    fclose(fid_out);
    error('无法打开 ABC 文件 %s', abcFile);
end

% 可在两部分之间不插空行，直接追加。如需空行，可先 fprintf(fid_out, '\n');
while ~feof(fid_abc)
    line = fgetl(fid_abc);
    if ischar(line)
        fprintf(fid_out, '%s\n', line);
    end
end

fclose(fid_abc);
fclose(fid_out);

fprintf('已生成合并文件 %s\n', outputFile);
