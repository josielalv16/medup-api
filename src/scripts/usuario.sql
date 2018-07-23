CREATE OR REPLACE FUNCTION Seguranca.inserirUsuario(
  pNome            VARCHAR,
  pSobrenome       VARCHAR,
  pEmail           VARCHAR,
  pCpf             CHAR,
  pCelular         CHAR,
  pDataNascimento  DATE,
  pIdTipoSanguineo INTEGER,
  pEndereco        JSON
)
  RETURNS JSON AS $$

/*
SELECT Seguranca.inserirUsuario(
           'Jamal',
           'Batata',
           'a@outlook.com',
           '12345678909',
           '16992417882',
           '12-02-1999',
           '1',
           '[{
             "cep": "14409015",
             "logradouro": "Rua Martiminiano Francisco de Andrade",
             "bairro": "Santa Adélia",
             "numero": 2245,
             "uf": "SP",
             "idCidade": 1
           }]' :: JSON
       )
*/
DECLARE
  vIdEndereco INTEGER;
  vIdUsuario  INTEGER;
BEGIN
  IF EXISTS(SELECT 1
            FROM Seguranca.usuario u
            WHERE u.email = pEmail)
  THEN
    RETURN json_build_object(
        'executionCode', 1,
        'message', 'Email já cadastrado'
    );
  END IF;

  IF EXISTS(SELECT 1
            FROM Seguranca.usuario u
            WHERE u.cpf = pCpf)
  THEN
    RETURN json_build_object(
        'executionCode', 2,
        'message', 'CPF já cadastrado'
    );
  END IF;

  INSERT INTO Seguranca.endereco (
    cep,
    logradouro,
    bairro,
    numero,
    uf,
    idcidade
  )
    SELECT
      e."cep",
      e."logradouro",
      e."bairro",
      e."numero",
      e."uf",
      e."idCidade"
    FROM json_to_recordset(pEndereco)
      AS e(
         "cep" CHAR(8),
         "logradouro" VARCHAR(70),
         "bairro" VARCHAR(50),
         "numero" SMALLINT,
         "uf" CHAR(2),
         "idCidade" INTEGER
         )
  RETURNING id
    INTO vIdEndereco;

  INSERT INTO Seguranca.usuario (
    nome,
    sobrenome,
    email,
    cpf,
    celular,
    datanascimento,
    idendereco,
    idtiposanguineo
  )
  VALUES (
    pNome,
    pSobrenome,
    pEmail,
    pCpf,
    pCelular,
    pDataNascimento,
    vIdEndereco,
    pIdTipoSanguineo
  )
  RETURNING id
    INTO vIdUsuario;

  RETURN json_build_object(
      'executionCode', 0,
      'message', 'Usuário inserido com sucesso',
      'content', json_build_object(
          'id', vIdUsuario
      )
  );
END;
$$
LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION Seguranca.selecionarUsuario(
  pFiltro VARCHAR(200),
  pLinhas INTEGER,
  pPagina INTEGER
)
  RETURNS TABLE(
    "totalLinhas" BIGINT,
    "id"          INTEGER,
    "nome"        VARCHAR(50),
    "sobrenome"   VARCHAR(50),
    "email"       VARCHAR(255)
  ) AS $$

/*
SELECT Seguranca.selecionarUsuario(
           'Gui',
           10,
           1
       )
       */
DECLARE
BEGIN
  RETURN QUERY
  SELECT
    COUNT(u.id)
    OVER (
      PARTITION BY 1 ),
    u.id,
    u.nome,
    u.sobrenome,
    u.email
  FROM Seguranca.usuario u
  WHERE
    CASE WHEN pFiltro IS NOT NULL
      THEN u.nome ILIKE '%' || pFiltro || '%'
    ELSE
      TRUE
    END
  LIMIT
    CASE WHEN pLinhas > 0 AND pPagina > 0
      THEN pLinhas
    ELSE
      NULL
    END
  OFFSET
    CASE WHEN pLinhas > 0 AND pPagina > 0
      THEN (pPagina - 1) * pLinhas
    ELSE
      NULL
    END;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION Seguranca.selecionarUsuarioPorId(
  pId INTEGER
)
  RETURNS TABLE(
    "id"              INTEGER,
    "nome"            VARCHAR(50),
    "sobrenome"       VARCHAR(50),
    "email"           VARCHAR(255),
    "cpf"             CHAR(11),
    "celular"         CHAR(11),
    "dataNascimento"  DATE,
    "idTipoSanguineo" INTEGER,
    "endereco"        JSON
  ) AS $$

/*
  SELECT Seguranca.selecionarUsuarioPorId(1)
*/

DECLARE

BEGIN
  RETURN QUERY
  SELECT
    u.id,
    u.nome,
    u.sobrenome,
    u.email,
    u.cpf,
    u.celular,
    u.datanascimento,
    u.idtiposanguineo,
    (
      SELECT CASE WHEN json_agg(ende) IS NOT NULL
        THEN json_agg(ende)
             ELSE '[]' END
      FROM (
             SELECT
               ue.id         AS "id",
               ue.cep        AS "cep",
               ue.logradouro AS "logradouro",
               ue.bairro     AS "bairro",
               ue.numero     AS "numero",
               ue.uf         AS "uf",
               ue.idcidade   AS "idCidade"
             FROM Seguranca.endereco ue
             WHERE ue.id = u.idendereco
           ) ende
    ) AS "endereco"
  FROM
    Seguranca.usuario u
  WHERE pId = u.id;
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION Seguranca.atualizarUsuario(
  pIdUsuario       INTEGER,
  pNome            VARCHAR(50),
  pSobrenome       VARCHAR(50),
  pEmail           VARCHAR(255),
  pCpf             CHAR(11),
  pCelular         CHAR(11),
  pDataNascimento  DATE,
  pIdTipoSanguineo INTEGER,
  pEndereco        JSON
)
  RETURNS JSON AS $$

/*
SELECT Seguranca.atualizarUsuario(
            1,
           'Teste',
           'Alterando',
           'email@email.com',
           '46114968802',
           '1637034409',
           '09-25-1998',
           '4',
           '[{
             "id": 1,
             "cep": "14409013",
             "logradouro": "Rua Martinho da Vila",
             "bairro": "Jdm. Barão",
             "numero": 22,
             "uf": "SP",
             "idCidade": 1
           }]' :: JSON
       )
*/

BEGIN
  IF NOT EXISTS(SELECT 1
                FROM Seguranca.usuario u
                WHERE u.id = pIdUsuario)
  THEN
    RETURN
    json_build_object(
        'executionCode', 1,
        'message', 'Usuário não encontrado'
    );
  END IF;

  IF EXISTS(SELECT 1
            FROM Seguranca.usuario u
            WHERE u.email = pEmail AND u.id <> pIdUsuario)
  THEN
    RETURN json_build_object(
        'executionCode', 2,
        'message', 'Email já cadastrado'
    );
  END IF;

  IF EXISTS(SELECT 1
            FROM Seguranca.usuario u
            WHERE u.cpf = pCpf AND u.id <> pIdUsuario)
  THEN
    RETURN json_build_object(
        'executionCode', 3,
        'message', 'CPF já cadastrado'
    );
  END IF;

  UPDATE Seguranca.usuario u
  SET nome          = pNome,
    sobrenome       = pSobrenome,
    email           = pEmail,
    cpf             = pCpf,
    celular         = pCelular,
    datanascimento  = pDataNascimento,
    idtiposanguineo = pIdTipoSanguineo
  WHERE id = pIdUsuario;

  UPDATE Seguranca.endereco ue
  SET id       = ende."id",
    cep        = ende."cep",
    logradouro = ende."logradouro",
    bairro     = ende."bairro",
    numero     = ende."numero",
    uf         = ende."uf",
    idcidade   = ende."idCidade"
  FROM (
         SELECT
           "id",
           "cep",
           "logradouro",
           "bairro",
           "numero",
           "uf",
           "idCidade"
         FROM json_to_recordset(pEndereco)
           AS x(
              "id" INTEGER,
              "cep" CHAR(8),
              "logradouro" VARCHAR(70),
              "bairro" VARCHAR(50),
              "numero" SMALLINT,
              "uf" CHAR(2),
              "idCidade" INTEGER
              )
       ) ende
  WHERE ue.id = ende."id";

  RETURN json_build_object(
      'executionCode', 0,
      'message', 'Usuário atualizado com sucesso'
  );
END;
$$
LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION Seguranca.removerUsuario(
  pId INTEGER
)
  RETURNS JSON AS $$

/*
SELECT Seguranca.removerUsuario(2)
*/

DECLARE
  vIdEndereco INTEGER;
BEGIN
  IF NOT EXISTS(SELECT 1
                FROM Seguranca.usuario u
                WHERE u.id = pId)
  THEN
    RETURN json_build_object(
        'executionCode', 1,
        'message', 'Usuário não encontrado'
    );
  END IF;

  DELETE FROM Seguranca.usuario u
  WHERE u.id = pId
  RETURNING idendereco
    INTO vIdEndereco;

  DELETE FROM Seguranca.endereco ue
  WHERE ue.id = vIdEndereco;

  RETURN json_build_object(
      'executionCode', 1,
      'message', 'Usuário excluído com sucesso'
  );
END;
$$
LANGUAGE PLPGSQL;