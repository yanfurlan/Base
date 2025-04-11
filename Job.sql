USE msdb;
GO

-- Criação do Job
EXEC sp_add_job
    @job_name = N'JobRelatoriosMBA',
    @enabled = 1,
    @description = N'Executa relatórios automáticos do e-commerce de cursos MBA/Pós.',
    @start_step_id = 1,
    @notify_level_eventlog = 0,
    @notify_level_email = 0,
    @notify_level_netsend = 0,
    @notify_level_page = 0;
GO

-- Adicionando etapa para gerar o relatório de compras com cursos
EXEC sp_add_jobstep
    @job_name = N'JobRelatoriosMBA',
    @step_name = N'Relatório: Compras com Cursos',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_RelatorioComprasComCursos;',
    @database_name = N'sua_base_dados';
GO

-- Adicionando mais etapas se quiser rodar outros relatórios
EXEC sp_add_jobstep
    @job_name = N'JobRelatoriosMBA',
    @step_name = N'Relatório: Total Compras por Aluno',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_TotalComprasPorAluno;',
    @database_name = N'sua_base_dados';
GO

-- Adicionando o agendamento (todos os dias às 08:00)
EXEC sp_add_schedule
    @schedule_name = N'Diariamente08h',
    @freq_type = 4, -- diário
    @freq_interval = 1,
    @active_start_time = 080000; -- 08:00:00
GO

-- Associar o agendamento ao Job
EXEC sp_attach_schedule
    @job_name = N'JobRelatoriosMBA',
    @schedule_name = N'Diariamente08h';
GO

-- Ativar o Job no SQL Server Agent
EXEC sp_add_jobserver
    @job_name = N'JobRelatoriosMBA',
    @server_name = N'(LOCAL)';
GO



/*Substitua sua_base_dados pelo nome real do banco.

Esse Job não grava relatórios em arquivos, mas podemos modificar as procedures para:

Gravar os dados em uma tabela de histórico,

Enviar por email com sp_send_dbmail,

Exportar para arquivo via bcp ou Integration Services (SSIS).*/