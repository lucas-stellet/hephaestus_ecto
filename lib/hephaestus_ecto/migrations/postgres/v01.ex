defmodule HephaestusEcto.Migrations.Postgres.V01 do
  @moduledoc false

  use Ecto.Migration

  def up(%{prefix: prefix, quoted_prefix: quoted}) do
    create_if_not_exists table(:workflow_instances, primary_key: false, prefix: prefix) do
      add(:id, :uuid, primary_key: true)
      add(:workflow, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:state, :map, null: false, default: %{})
      timestamps()
    end

    create_if_not_exists(index(:workflow_instances, [:status], prefix: prefix))
    create_if_not_exists(index(:workflow_instances, [:workflow], prefix: prefix))

    execute("""
    DO $$
    BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = '#{prefix}'
      AND tablename = 'workflow_instances'
      AND indexname = 'idx_workflow_instances_state'
    ) THEN
      CREATE INDEX idx_workflow_instances_state
      ON #{quoted}.workflow_instances USING GIN (state jsonb_path_ops);
    END IF;
    END$$;
    """)
  end

  def down(%{prefix: prefix}) do
    drop(table(:workflow_instances, prefix: prefix))
  end
end
