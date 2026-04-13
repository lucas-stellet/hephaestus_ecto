defmodule HephaestusEcto.Migrations.Postgres.V03 do
  @moduledoc false

  use Ecto.Migration

  def up(%{prefix: prefix, quoted_prefix: quoted}) do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = '#{prefix}'
        AND table_name = 'workflow_instances'
        AND column_name = 'id'
        AND data_type = 'uuid'
      ) THEN
        ALTER TABLE #{quoted}.workflow_instances
          ALTER COLUMN id TYPE varchar(255) USING id::text;
      END IF;
    END$$;
    """)
  end

  def down(%{prefix: _prefix}) do
    # Intentionally a no-op: the uuid -> varchar(255) type change is irreversible once
    # instances have been written with "key::value" IDs. Rolling back via down/1 only
    # resets the version comment; the column stays varchar(255).
    :ok
  end
end
