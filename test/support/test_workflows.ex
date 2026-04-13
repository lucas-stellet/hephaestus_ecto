defmodule HephaestusEcto.Test.SimpleWorkflow do
  use Hephaestus.Workflow, unique: [key: "testecto"]

  def start, do: HephaestusEcto.Test.PassStep

  def transit(HephaestusEcto.Test.PassStep, :done, _ctx), do: Hephaestus.Steps.Done
end
