defmodule HephaestusEcto.Migrations.Postgres.V02 do
  @moduledoc false

  use Ecto.Migration

  def up(%{prefix: prefix}) do
    alter table(:workflow_instances, prefix: prefix) do
      add_if_not_exists(:workflow_version, :integer, null: false, default: 1)
    end

    create(
      index(:workflow_instances, [:workflow, :workflow_version],
        prefix: prefix,
        name: :workflow_instances_workflow_workflow_version_index
      )
    )
  end

  def down(%{prefix: prefix}) do
    drop_if_exists(
      index(:workflow_instances, [:workflow, :workflow_version],
        prefix: prefix,
        name: :workflow_instances_workflow_workflow_version_index
      )
    )

    alter table(:workflow_instances, prefix: prefix) do
      remove_if_exists(:workflow_version, :integer)
    end
  end
end
