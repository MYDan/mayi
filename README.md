                         MYDan 说明


MYDan 工具集

===================================安装=====================================

    安装步骤：
        1: /path/to/your/perl Makefile.PL
        2: make
        3: make install mydan=/path/to/mydan  #指定工具集安装的目录，如不指定则
           不安装工具, 在指定mydan的同时可以通过conf指定配置，在conf目录中按
           照实际应用场景对配置进行了分类，如在 conf 中存在配置mydan，
           则可以通过 make install mydan=/path/to/mydan conf=mydan 在安装工具的
           同时指定mydan选择的配置


        4: ./dan/bootstrap/bin/bootstrap  --install 安装引导程序
