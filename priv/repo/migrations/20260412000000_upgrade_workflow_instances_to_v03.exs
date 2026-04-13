defmodule HephaestusEcto.TestRepo.Migrations.UpgradeWorkflowInstancesToV03 do
  use Ecto.Migration

  def up, do: HephaestusEcto.Migration.up(version: 3)
  def down, do: HephaestusEcto.Migration.down(version: 2)
end
