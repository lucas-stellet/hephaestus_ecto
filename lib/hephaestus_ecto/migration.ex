defmodule HephaestusEcto.Migration do
  @moduledoc """
  Defines the database migration for the `workflow_instances` table.

  Called by consumer migrations generated via `mix hephaestus_ecto.gen.migration`.

  ## Table structure

    * `id` — UUID primary key (provided by Hephaestus, not auto-generated)
    * `workflow` — workflow module name as string
    * `status` — instance status (`pending`, `running`, `waiting`, `completed`, `failed`)
    * `state` — JSONB field with serialized context, steps, and execution history
    * `inserted_at` / `updated_at` — timestamps

  ## Indexes

    * B-tree on `status`
    * B-tree on `workflow`
    * GIN on `state` using `jsonb_path_ops`
  """

  use Ecto.Migration

  @doc """
  Creates the `workflow_instances` table with indexes.
  """
  def up do
    create table(:workflow_instances, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:workflow, :string, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:state, :map, null: false, default: %{})
      timestamps()
    end

    create(index(:workflow_instances, [:status]))
    create(index(:workflow_instances, [:workflow]))

    execute(
      "CREATE INDEX idx_workflow_instances_state ON workflow_instances USING GIN (state jsonb_path_ops)"
    )
  end

  @doc """
  Drops the `workflow_instances` table and all its indexes.
  """
  def down do
    drop(table(:workflow_instances))
  end
end
