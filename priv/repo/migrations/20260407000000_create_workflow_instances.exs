defmodule HephaestusEcto.TestRepo.Migrations.CreateWorkflowInstances do
  use Ecto.Migration

  def up, do: HephaestusEcto.Migration.up()
  def down, do: HephaestusEcto.Migration.down(version: 1)
end
