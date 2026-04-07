defmodule HephaestusEcto.Schema.Instance do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "workflow_instances" do
    field(:workflow, :string)
    field(:status, :string)
    field(:state, :map)
    timestamps()
  end

  @required [:id, :workflow, :status, :state]

  def changeset(instance \\ %__MODULE__{}, attrs) do
    instance
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_inclusion(:status, ~w(pending running waiting completed failed))
  end
end
