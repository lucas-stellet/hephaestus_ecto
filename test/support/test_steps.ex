defmodule HephaestusEcto.Test.PassStep do
  @behaviour Hephaestus.Steps.Step

  @impl true
  def events, do: [:done]

  @impl true
  def execute(_instance, _config, _context), do: {:ok, :done}
end
