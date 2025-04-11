-- =============================================
-- Script completo para base de dados
-- Autor: Yan Furlan
-- Banco: SQL Server
-- =============================================

-- DROP TABLES (ordem reversa se necessário)
IF OBJECT_ID('LogStatusCompra', 'U') IS NOT NULL DROP TABLE LogStatusCompra;
IF OBJECT_ID('CompraCurso', 'U') IS NOT NULL DROP TABLE CompraCurso;
IF OBJECT_ID('CursoMaterial', 'U') IS NOT NULL DROP TABLE CursoMaterial;
IF OBJECT_ID('CursoProfessor', 'U') IS NOT NULL DROP TABLE CursoProfessor;
IF OBJECT_ID('AlunoEmpresa', 'U') IS NOT NULL DROP TABLE AlunoEmpresa;
IF OBJECT_ID('Compra', 'U') IS NOT NULL DROP TABLE Compra;
IF OBJECT_ID('Material', 'U') IS NOT NULL DROP TABLE Material;
IF OBJECT_ID('Professor', 'U') IS NOT NULL DROP TABLE Professor;
IF OBJECT_ID('Curso', 'U') IS NOT NULL DROP TABLE Curso;
IF OBJECT_ID('EmpresaParceira', 'U') IS NOT NULL DROP TABLE EmpresaParceira;
IF OBJECT_ID('Aluno', 'U') IS NOT NULL DROP TABLE Aluno;

-- Tabelas principais
CREATE TABLE Aluno (
    AlunoID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    CPF CHAR(11),
    Email NVARCHAR(100)
);

CREATE TABLE EmpresaParceira (
    EmpresaID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    CNPJ CHAR(14)
);

CREATE TABLE AlunoEmpresa (
    AlunoID INT,
    EmpresaID INT,
    TipoDesconto NVARCHAR(50),
    PRIMARY KEY (AlunoID, EmpresaID),
    FOREIGN KEY (AlunoID) REFERENCES Aluno(AlunoID),
    FOREIGN KEY (EmpresaID) REFERENCES EmpresaParceira(EmpresaID)
);

CREATE TABLE Professor (
    ProfessorID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    Especialidade NVARCHAR(100)
);

CREATE TABLE Curso (
    CursoID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    Categoria NVARCHAR(100),
    Preco DECIMAL(10,2)
);

CREATE TABLE CursoProfessor (
    CursoID INT,
    ProfessorID INT,
    PRIMARY KEY (CursoID, ProfessorID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID),
    FOREIGN KEY (ProfessorID) REFERENCES Professor(ProfessorID)
);

CREATE TABLE Material (
    MaterialID INT PRIMARY KEY IDENTITY,
    Tipo NVARCHAR(50),
    Descricao NVARCHAR(255)
);

CREATE TABLE CursoMaterial (
    CursoID INT,
    MaterialID INT,
    PRIMARY KEY (CursoID, MaterialID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID),
    FOREIGN KEY (MaterialID) REFERENCES Material(MaterialID)
);

CREATE TABLE Compra (
    CompraID INT PRIMARY KEY IDENTITY,
    AlunoID INT,
    DataCompra DATE,
    FormaPagamento NVARCHAR(50),
    Status NVARCHAR(50),
    FOREIGN KEY (AlunoID) REFERENCES Aluno(AlunoID)
);

CREATE TABLE CompraCurso (
    CompraID INT,
    CursoID INT,
    PRIMARY KEY (CompraID, CursoID),
    FOREIGN KEY (CompraID) REFERENCES Compra(CompraID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID)
);

CREATE TABLE LogStatusCompra (
    LogID INT PRIMARY KEY IDENTITY,
    CompraID INT,
    StatusAntigo NVARCHAR(50),
    StatusNovo NVARCHAR(50),
    DataAlteracao DATETIME DEFAULT GETDATE()
);

-- TRIGGER para log de alterações de status da compra
CREATE TRIGGER trg_LogStatusCompra
ON Compra
AFTER UPDATE
AS
BEGIN
    INSERT INTO LogStatusCompra (CompraID, StatusAntigo, StatusNovo)
    SELECT i.CompraID, d.Status, i.Status
    FROM inserted i
    JOIN deleted d ON i.CompraID = d.CompraID
    WHERE i.Status <> d.Status;
END;

-- VIEWS para relatórios
CREATE VIEW vw_RelatorioComprasComCursos AS
SELECT 
    c.CompraID,
    a.Nome AS Aluno,
    cu.Nome AS Curso,
    c.DataCompra,
    c.FormaPagamento,
    c.Status
FROM Compra c
JOIN Aluno a ON a.AlunoID = c.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID;

CREATE VIEW vw_CursosEProfessores AS
SELECT 
    cu.Nome AS Curso,
    p.Nome AS Professor,
    p.Especialidade
FROM Curso cu
JOIN CursoProfessor cp ON cp.CursoID = cu.CursoID
JOIN Professor p ON p.ProfessorID = cp.ProfessorID;

CREATE VIEW vw_MateriaisPorCurso AS
SELECT 
    cu.Nome AS Curso,
    m.Tipo AS TipoMaterial,
    m.Descricao
FROM Curso cu
JOIN CursoMaterial cm ON cm.CursoID = cu.CursoID
JOIN Material m ON m.MaterialID = cm.MaterialID;

CREATE VIEW vw_ComprasComEmpresasParceiras AS
SELECT 
    a.Nome AS Aluno,
    e.Nome AS Empresa,
    ae.TipoDesconto,
    c.CompraID,
    c.DataCompra,
    cu.Nome AS Curso
FROM AlunoEmpresa ae
JOIN Aluno a ON a.AlunoID = ae.AlunoID
JOIN EmpresaParceira e ON e.EmpresaID = ae.EmpresaID
JOIN Compra c ON c.AlunoID = a.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID;

CREATE VIEW vw_TotalComprasPorAluno AS
SELECT 
    a.Nome AS Aluno,
    COUNT(DISTINCT c.CompraID) AS TotalCompras,
    SUM(cu.Preco) AS ValorTotalGasto
FROM Aluno a
JOIN Compra c ON c.AlunoID = a.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID
GROUP BY a.Nome;

CREATE VIEW vw_CursosComProfessoresMateriaisAlunos AS
SELECT 
    cu.Nome AS Curso,
    COUNT(DISTINCT cp.ProfessorID) AS TotalProfessores,
    COUNT(DISTINCT cm.MaterialID) AS TotalMateriais,
    COUNT(DISTINCT co.AlunoID) AS TotalAlunos
FROM Curso cu
LEFT JOIN CursoProfessor cp ON cp.CursoID = cu.CursoID
LEFT JOIN CursoMaterial cm ON cm.CursoID = cu.CursoID
LEFT JOIN CompraCurso cc ON cc.CursoID = cu.CursoID
LEFT JOIN Compra co ON co.CompraID = cc.CompraID
GROUP BY cu.Nome;

-- Procedures para relatórios
CREATE PROCEDURE sp_RelatorioComprasComCursos
AS
BEGIN
    SELECT * FROM vw_RelatorioComprasComCursos ORDER BY DataCompra DESC;
END;

CREATE PROCEDURE sp_RelatorioCursosEProfessores
AS
BEGIN
    SELECT * FROM vw_CursosEProfessores ORDER BY Curso;
END;

CREATE PROCEDURE sp_MateriaisPorCurso
AS
BEGIN
    SELECT * FROM vw_MateriaisPorCurso ORDER BY Curso, TipoMaterial;
END;

CREATE PROCEDURE sp_ComprasComEmpresasParceiras
AS
BEGIN
    SELECT * FROM vw_ComprasComEmpresasParceiras ORDER BY Aluno;
END;

CREATE PROCEDURE sp_TotalComprasPorAluno
AS
BEGIN
    SELECT * FROM vw_TotalComprasPorAluno ORDER BY ValorTotalGasto DESC;
END;

CREATE PROCEDURE sp_CursosComProfessoresMateriaisAlunos
AS
BEGIN
    SELECT * FROM vw_CursosComProfessoresMateriaisAlunos ORDER BY TotalAlunos DESC;
END;

-- =============================================
-- Script completo para base de dados
-- Autor: Yan Furlan
-- Banco: SQL Server
-- =============================================

-- DROP TABLES (ordem reversa se necessário)
IF OBJECT_ID('LogStatusCompra', 'U') IS NOT NULL DROP TABLE LogStatusCompra;
IF OBJECT_ID('CompraCurso', 'U') IS NOT NULL DROP TABLE CompraCurso;
IF OBJECT_ID('CursoMaterial', 'U') IS NOT NULL DROP TABLE CursoMaterial;
IF OBJECT_ID('CursoProfessor', 'U') IS NOT NULL DROP TABLE CursoProfessor;
IF OBJECT_ID('AlunoEmpresa', 'U') IS NOT NULL DROP TABLE AlunoEmpresa;
IF OBJECT_ID('Compra', 'U') IS NOT NULL DROP TABLE Compra;
IF OBJECT_ID('Material', 'U') IS NOT NULL DROP TABLE Material;
IF OBJECT_ID('Professor', 'U') IS NOT NULL DROP TABLE Professor;
IF OBJECT_ID('Curso', 'U') IS NOT NULL DROP TABLE Curso;
IF OBJECT_ID('EmpresaParceira', 'U') IS NOT NULL DROP TABLE EmpresaParceira;
IF OBJECT_ID('Aluno', 'U') IS NOT NULL DROP TABLE Aluno;

-- Tabelas principais
CREATE TABLE Aluno (
    AlunoID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    CPF CHAR(11),
    Email NVARCHAR(100)
);

CREATE TABLE EmpresaParceira (
    EmpresaID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    CNPJ CHAR(14)
);

CREATE TABLE AlunoEmpresa (
    AlunoID INT,
    EmpresaID INT,
    TipoDesconto NVARCHAR(50),
    PRIMARY KEY (AlunoID, EmpresaID),
    FOREIGN KEY (AlunoID) REFERENCES Aluno(AlunoID),
    FOREIGN KEY (EmpresaID) REFERENCES EmpresaParceira(EmpresaID)
);

CREATE TABLE Professor (
    ProfessorID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    Especialidade NVARCHAR(100)
);

CREATE TABLE Curso (
    CursoID INT PRIMARY KEY IDENTITY,
    Nome NVARCHAR(100),
    Categoria NVARCHAR(100),
    Preco DECIMAL(10,2)
);

CREATE TABLE CursoProfessor (
    CursoID INT,
    ProfessorID INT,
    PRIMARY KEY (CursoID, ProfessorID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID),
    FOREIGN KEY (ProfessorID) REFERENCES Professor(ProfessorID)
);

CREATE TABLE Material (
    MaterialID INT PRIMARY KEY IDENTITY,
    Tipo NVARCHAR(50),
    Descricao NVARCHAR(255)
);

CREATE TABLE CursoMaterial (
    CursoID INT,
    MaterialID INT,
    PRIMARY KEY (CursoID, MaterialID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID),
    FOREIGN KEY (MaterialID) REFERENCES Material(MaterialID)
);

CREATE TABLE Compra (
    CompraID INT PRIMARY KEY IDENTITY,
    AlunoID INT,
    DataCompra DATE,
    FormaPagamento NVARCHAR(50),
    Status NVARCHAR(50),
    FOREIGN KEY (AlunoID) REFERENCES Aluno(AlunoID)
);

CREATE TABLE CompraCurso (
    CompraID INT,
    CursoID INT,
    PRIMARY KEY (CompraID, CursoID),
    FOREIGN KEY (CompraID) REFERENCES Compra(CompraID),
    FOREIGN KEY (CursoID) REFERENCES Curso(CursoID)
);

CREATE TABLE LogStatusCompra (
    LogID INT PRIMARY KEY IDENTITY,
    CompraID INT,
    StatusAntigo NVARCHAR(50),
    StatusNovo NVARCHAR(50),
    DataAlteracao DATETIME DEFAULT GETDATE()
);

-- TRIGGER para log de alterações de status da compra
CREATE TRIGGER trg_LogStatusCompra
ON Compra
AFTER UPDATE
AS
BEGIN
    INSERT INTO LogStatusCompra (CompraID, StatusAntigo, StatusNovo)
    SELECT i.CompraID, d.Status, i.Status
    FROM inserted i
    JOIN deleted d ON i.CompraID = d.CompraID
    WHERE i.Status <> d.Status;
END;

-- VIEWS para relatórios
CREATE VIEW vw_RelatorioComprasComCursos AS
SELECT 
    c.CompraID,
    a.Nome AS Aluno,
    cu.Nome AS Curso,
    c.DataCompra,
    c.FormaPagamento,
    c.Status
FROM Compra c
JOIN Aluno a ON a.AlunoID = c.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID;

CREATE VIEW vw_CursosEProfessores AS
SELECT 
    cu.Nome AS Curso,
    p.Nome AS Professor,
    p.Especialidade
FROM Curso cu
JOIN CursoProfessor cp ON cp.CursoID = cu.CursoID
JOIN Professor p ON p.ProfessorID = cp.ProfessorID;

CREATE VIEW vw_MateriaisPorCurso AS
SELECT 
    cu.Nome AS Curso,
    m.Tipo AS TipoMaterial,
    m.Descricao
FROM Curso cu
JOIN CursoMaterial cm ON cm.CursoID = cu.CursoID
JOIN Material m ON m.MaterialID = cm.MaterialID;

CREATE VIEW vw_ComprasComEmpresasParceiras AS
SELECT 
    a.Nome AS Aluno,
    e.Nome AS Empresa,
    ae.TipoDesconto,
    c.CompraID,
    c.DataCompra,
    cu.Nome AS Curso
FROM AlunoEmpresa ae
JOIN Aluno a ON a.AlunoID = ae.AlunoID
JOIN EmpresaParceira e ON e.EmpresaID = ae.EmpresaID
JOIN Compra c ON c.AlunoID = a.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID;

CREATE VIEW vw_TotalComprasPorAluno AS
SELECT 
    a.Nome AS Aluno,
    COUNT(DISTINCT c.CompraID) AS TotalCompras,
    SUM(cu.Preco) AS ValorTotalGasto
FROM Aluno a
JOIN Compra c ON c.AlunoID = a.AlunoID
JOIN CompraCurso cc ON cc.CompraID = c.CompraID
JOIN Curso cu ON cu.CursoID = cc.CursoID
GROUP BY a.Nome;

CREATE VIEW vw_CursosComProfessoresMateriaisAlunos AS
SELECT 
    cu.Nome AS Curso,
    COUNT(DISTINCT cp.ProfessorID) AS TotalProfessores,
    COUNT(DISTINCT cm.MaterialID) AS TotalMateriais,
    COUNT(DISTINCT co.AlunoID) AS TotalAlunos
FROM Curso cu
LEFT JOIN CursoProfessor cp ON cp.CursoID = cu.CursoID
LEFT JOIN CursoMaterial cm ON cm.CursoID = cu.CursoID
LEFT JOIN CompraCurso cc ON cc.CursoID = cu.CursoID
LEFT JOIN Compra co ON co.CompraID = cc.CompraID
GROUP BY cu.Nome;

-- Procedures para relatórios
CREATE PROCEDURE sp_RelatorioComprasComCursos
AS
BEGIN
    SELECT * FROM vw_RelatorioComprasComCursos ORDER BY DataCompra DESC;
END;

CREATE PROCEDURE sp_RelatorioCursosEProfessores
AS
BEGIN
    SELECT * FROM vw_CursosEProfessores ORDER BY Curso;
END;

CREATE PROCEDURE sp_MateriaisPorCurso
AS
BEGIN
    SELECT * FROM vw_MateriaisPorCurso ORDER BY Curso, TipoMaterial;
END;

CREATE PROCEDURE sp_ComprasComEmpresasParceiras
AS
BEGIN
    SELECT * FROM vw_ComprasComEmpresasParceiras ORDER BY Aluno;
END;

CREATE PROCEDURE sp_TotalComprasPorAluno
AS
BEGIN
    SELECT * FROM vw_TotalComprasPorAluno ORDER BY ValorTotalGasto DESC;
END;

CREATE PROCEDURE sp_CursosComProfessoresMateriaisAlunos
AS
BEGIN
    SELECT * FROM vw_CursosComProfessoresMateriaisAlunos ORDER BY TotalAlunos DESC;
END;

EXEC sp_RelatorioComprasComCursos
EXEC sp_TotalComprasPorAluno