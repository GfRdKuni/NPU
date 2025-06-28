function generate_assemble_language(Scale, outputFile)
    % Base Address
    ICM_Base    = 0   ;
    Scalar_Base = 256 ;
    Vector_Base = 512 ;

    % Data Address offset
    Biasoffset   = 0                 ;
    Weightoffset = Scale * Scale     ;
    Resultoffset = Scale * Scale * 2 ;
    Inputoffset  = 0                 ; 
    
    % Data Start position
    BiasStart    = MMU(Vector_Base, Biasoffset)  ;
    WeightStart  = MMU(Vector_Base, Weightoffset);
    ResultStart  = MMU(Vector_Base, Resultoffset);
    InputStart   = MMU(Scalar_Base, Inputoffset) ;
    

    % Open File
    fid = fopen(outputFile, 'w');
    if fid < 0
        error('无法打开输出文件：%s', outputFile);
    end
    fprintf(fid, "MOV r1 %s $1\n", higher_part(dec2hex(BiasStart,4)));
    fprintf(fid, "MOV r1 %s $0\n", lower_part (dec2hex(BiasStart,4)));
    fprintf(fid, "MOV r2 %s $1\n", higher_part(dec2hex(WeightStart,4)));
    fprintf(fid, "MOV r2 %s $0\n", lower_part(dec2hex(WeightStart,4)));
    fprintf(fid, "MOV r3 %s $1\n", higher_part(dec2hex(InputStart,4)));
    fprintf(fid, "MOV r3 %s $0\n", lower_part(dec2hex(InputStart,4)));
    fprintf(fid, "MOV r4 %s $1\n", higher_part(dec2hex(ResultStart,4)));
    fprintf(fid, "MOV r4 %s $0\n", lower_part(dec2hex(ResultStart,4)));
    fprintf(fid, "MOV r6 %s $1\n", higher_part(dec2hex(WeightStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r6 %s $0\n", lower_part(dec2hex(WeightStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r7 %s $1\n", higher_part(dec2hex(BiasStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r7 %s $0\n", lower_part(dec2hex(BiasStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r8 %s $1\n", higher_part(dec2hex(InputStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r8 %s $0\n", lower_part(dec2hex(InputStart + Scale*floor(Scale/2) , 4)));
    fprintf(fid, "MOV r15 %s $0\n", num2str(Scale));
    fprintf(fid, "MOV r15 %s $1\n", onesZerosHex(Scale));
    
    for i = 1:Scale
        if ((i-1)*Scale < Scale * floor(Scale/2))
            fprintf(fid, "Vload vr1 r1 %d\n", (i-1)*Scale);
        else
            fprintf(fid, "Vload vr1 r7 %d\n", (i-1)*Scale - Scale * floor(Scale/2));
        end
        fprintf(fid, "VMAC-s vr2 / vr1 $1\n");
        for j = 1:Scale
            if ((i-1)*Scale+j-1 < Scale*floor(Scale/2))
                fprintf(fid, "Load r5 r3 %d\n", (i-1)*Scale+j-1);
            else
                fprintf(fid, "Load r5 r8 %d\n", (i-1)*Scale+j-1 - Scale*floor(Scale/2));
            end
            if ((j-1)*Scale < Scale*floor(Scale/2))
                fprintf(fid, "Vload vr1 r2 %d\n", (j-1)*Scale);
            else
                fprintf(fid, "Vload vr1 r6 %d\n", (j-1)*Scale - Scale*floor(Scale/2));
            end
            fprintf(fid, "VMAC-s vr2 r5 vr1 $0\n");
        end
        fprintf(fid, "VStore / r4 vr2\n");
        fprintf(fid, "MOV r4 %s $1\n", higher_part(dec2hex(ResultStart + Scale * i ,4)));
        fprintf(fid, "MOV r4 %s $0\n", lower_part(dec2hex(ResultStart + Scale * i ,4)));
    end

    fclose(fid);
end

