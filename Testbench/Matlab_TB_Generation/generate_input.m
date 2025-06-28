%% 随机生成矩阵、计算结果并输出文件
% 请修改 N、文件名等参数以适配实际需求

function generate_input(N)
%% 参数设置
% 方阵规模，可修改
% 随机矩阵生成范围为 0..2^16-1
% 若已有具体矩阵，请在此替换 A_uint16, B_uint16, C_uint16 的赋值

% 生成随机无符号 16 位矩阵
A_uint16 = uint16(randi([0, 2^16-1], N, N));
B_uint16 = uint16(randi([0, 2^16-1], N, N));
C_uint16 = uint16(randi([0, 2^16-1], N, N));

%% 硬件模拟参数
ACC_WIDTH = 36;
SHIFT = ACC_WIDTH - 16;           % 取高16位需要右移位数
mask40 = bitshift(uint64(1), ACC_WIDTH) - uint64(1);  % 2^40 - 1，用于保持低40位环绕

%% 计算输出矩阵 R（MxN 方阵，此处 M=N）
R_uint16 = zeros(N, N, 'uint16');
for i = 1:N
    for j = 1:N
        acc = uint64(0);
        % 累加 A(i,k)*B(k,j)
        for k = 1:N
            prod = uint64(A_uint16(i,k)) * uint64(B_uint16(k,j));
            acc = acc + prod;
            acc = bitand(acc, mask40);  % 保持低40位，无符号自然环绕
        end
        % 加 C(i,j) 也在 40 位累加器中环绕
        acc = acc + uint64(C_uint16(i,j));
        acc = bitand(acc, mask40);
        % 取高16位
        high16 = bitshift(acc, -SHIFT);
        R_uint16(i,j) = uint16(high16);
    end
end

%% 将 R 写入文件：按行优先，每行一个 4 位十六进制，不带 0x
result_fname = 'result.txt';
fidR = fopen(result_fname, 'w');
if fidR < 0
    error('无法打开文件 %s 写入结果', result_fname);
end
for i = 1:N
    for j = 1:N
        fprintf(fidR, '%04X\n', R_uint16(i,j));
    end
end
fclose(fidR);

%% 将 A、C、B 输出到另一文件，格式三列：1 元素值 地址
% 地址按行优先连续编址：A 从 0x0100 开始，C 从 0x0200 开始，C 编址完后 B 紧接
output_xyz_fname = 'abc_output.txt';
fidABC = fopen(output_xyz_fname, 'w');
if fidABC < 0
    error('无法打开文件 %s 写入 A/C/B', output_xyz_fname);
end

% 起始地址（十进制）
startA = hex2dec('0100');
startC = hex2dec('0200');
startB = startC + N * N;

% 输出 A：按列遍历元素，但地址按行优先计算
for col = 1:N
    for row = 1:N
        idx = (row-1)*N + (col-1);  % row-major offset，从0开始
        addr = startA + idx;
        val = A_uint16(row, col);
        fprintf(fidABC, '1 %04X %04X\n', val, addr);
    end
end

% 输出 C
for col = 1:N
    for row = 1:N
        idx = (row-1)*N + (col-1);
        addr = startC + idx;
        val = C_uint16(row, col);
        fprintf(fidABC, '1 %04X %04X\n', val, addr);
    end
end

% 输出 B
for col = 1:N
    for row = 1:N
        idx = (row-1)*N + (col-1);
        addr = startB + idx;
        val = B_uint16(row, col);
        fprintf(fidABC, '1 %04X %04X\n', val, addr);
    end
end

fclose(fidABC);

%% 可选：将 A,B,C,R 在命令行简单显示（如调试时使用），可注释掉
% disp('A (hex):');
% for i = 1:N
%     fprintf('%s\n', sprintf('%04X ', A_uint16(i,:)));
% end
% disp('B (hex):');
% for i = 1:N
%     fprintf('%s\n', sprintf('%04X ', B_uint16(i,:)));
% end
% disp('C (hex):');
% for i = 1:N
%     fprintf('%s\n', sprintf('%04X ', C_uint16(i,:)));
% end
% disp('R (hex):');
% for i = 1:N
%     fprintf('%s\n', sprintf('%04X ', R_uint16(i,:)));
% end

%% 结束提示
fprintf('Done. 结果写入 "%s"，A/C/B 输出写入 "%s"\n', result_fname, output_xyz_fname);
