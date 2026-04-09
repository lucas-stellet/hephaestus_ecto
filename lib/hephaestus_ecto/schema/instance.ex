defmodule HephaestusEcto.Schema.Instance do
  @moduledoc """
  Ecto schema for persisted workflow instances.

  Backed by the `workflow_instances` table with these fields:

    * `:id` — workflow instance UUID
    * `:workflow` — workflow module name as a string
    * `:status` — runtime status as a string
    * `:workflow_version` — integer workflow version persisted separately from state
    * `:state` — JSON-compatible serialized workflow state
    * `:inserted_at` / `:updated_at` — Ecto timestamps
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "workflow_instances" do
    field(:workflow, :string)
    field(:status, :string)
    field(:workflow_version, :integer, default: 1)
    field(:state, :map)
    timestamps()
  end

  @required [:id, :workflow, :status, :state]
  @cast @required ++ [:workflow_version]

  def changeset(instance \\ %__MODULE__{}, attrs) do
    instance
    |> cast(attrs, @cast)
    |> validate_required(@required)
    |> validate_inclusion(:status, ~w(pending running waiting completed failed))
    |> validate_number(:workflow_version, greater_than: 0)
  end
end
